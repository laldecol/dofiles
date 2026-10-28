# ---------------------------------------------------------------------------
# van_donkelar_worker.py  [WORKER -- imports arcpy; called by propy.bat]
# Description: Convert one Van Donkelaar PM2.5 NetCDF file to the project
# uber_grid and save as a TIF raster.
# Called by van_donkelar.py via propy.bat; NOT called by Stata directly.
#
# Arguments: nc_filepath  output_raster
#
# Created 2026-08-31.
# ---------------------------------------------------------------------------

import datetime, os, sys, time

# Write a per-worker log before importing arcpy so we can tell whether
# the process started but hung at DLL loading vs never started at all.
_pid = os.getpid()
os.makedirs("temp", exist_ok=True)
_logpath = "temp/worker_%d.log" % _pid

def _wlog(msg):
    line = datetime.datetime.now().strftime("%H:%M:%S") + " " + msg
    print(line, flush=True)
    with open(_logpath, "a") as f:
        f.write(line + "\n")

_wlog("Worker started (PID %d) -- about to import arcpy" % _pid)

import arcpy

_wlog("arcpy imported successfully")

# Add mylibrary to sys.path so rasters.py can be imported.
sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                             '..', 'mylibrary'))
import rasters

# Give each worker its own scratch workspace to prevent lock contention when
# multiple workers run concurrently.
_scratch = os.path.abspath("temp/scratch_%d" % _pid)
os.makedirs(_scratch, exist_ok=True)
arcpy.env.scratchWorkspace = _scratch
arcpy.env.workspace        = _scratch
arcpy.env.overwriteOutput  = True
arcpy.env.pyramid          = "NONE"
arcpy.env.rasterStatistics = "NONE"
_wlog("Scratch workspace: " + _scratch)


def run_convert(nc_filepath, output_raster):
    # Converts one Van Donkelaar NetCDF file to an uber_grid-aligned TIF.
    # Returns True on success, False on failure.
    try:
        _wlog("Starting conversion: " + nc_filepath)

        temp_raster = os.path.join(_scratch, "vd_raw.tif")
        layer_name  = "vd_layer_%d" % _pid

        # Extract the PM2.5 raster layer from the NetCDF.
        # ACAG V5GL05.02: variable "GWRPM25", dimensions "lon" (x) and "lat" (y).
        # Confirmed by diagnose_nc.py on 2026-08-31.
        try:
            arcpy.md.MakeNetCDFRasterLayer(
                in_netCDF_file=nc_filepath,
                variable="GWRPM25",
                x_dimension="lon",
                y_dimension="lat",
                out_raster_layer=layer_name
            )
        except Exception as nc_err:
            _wlog("MakeNetCDFRasterLayer failed: " + str(nc_err))
            _wlog("Listing NetCDF contents to help diagnose variable/dimension names:")
            try:
                nc_info = arcpy.md.GetNetCDFInfo(nc_filepath)
                _wlog("  Variables:  " + str(nc_info.variables))
                _wlog("  Dimensions: " + str(nc_info.dimensions))
            except Exception as info_err:
                _wlog("  GetNetCDFInfo also failed: " + str(info_err))
            raise

        _wlog("NetCDF layer created successfully")

        # Save the in-memory layer to a temp TIF before reprojecting.
        arcpy.management.CopyRaster(layer_name, temp_raster)
        _wlog("Raw raster saved to: " + temp_raster)

        # Reproject and clip to the exact project uber_grid.
        # raster2ubergrid uses ProjectRaster with cell size + registration
        # point from settings.txt, then clips to the standard extent rectangle.
        # The extent shapefile argument is vestigial (ignored internally since
        # the 2026-07-07 fix) but kept for function signature compatibility.
        rasters.raster2ubergrid(
            temp_raster,
            output_raster,
            "../../../data/GPW4/generated/extent/extent.shp",
            "../../../data/projections/WGS 1984.prj"
        )
        _wlog("Done: " + output_raster)
        return True

    except Exception as e:
        _wlog("ERROR: " + str(e))
        return False


if __name__ == "__main__":
    nc_filepath   = sys.argv[1]
    output_raster = sys.argv[2]

    t0 = time.process_time()
    success = run_convert(nc_filepath, output_raster)
    elapsed = time.process_time() - t0

    print("[%s] completed in %.1fs. success=%s" % (
        os.path.basename(output_raster), elapsed, str(success)))

    sys.exit(0 if success else 1)
