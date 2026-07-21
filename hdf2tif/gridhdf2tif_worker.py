# ---------------------------------------------------------------------------
# gridhdf2tif_worker.py  [WORKER -- imports arcpy; launched by propy.bat]
#
# Converts one MOD14A1 HDF tile (sinusoidal projection) to per-day GeoTIFFs
# in WGS84 geographic projection.
#
# Called by gridhdf2tif.py (the orchestrator) via:
#     propy.bat gridhdf2tif_worker.py <hdfpath> <outfolder>
# NOT called by Stata directly; no failmarker logic needed here.
#
# Created 2026-07-17 as part of py3 / ArcGIS Pro 3.1 refactor.
# HEGtool (hegtool.exe / resample.exe) replaced with:
#   1. arcpy.management.ExtractSubDataset  -- extract FireMask from HDF
#   2. arcpy.sa.ExtractBand               -- isolate one day-band
#   3. arcpy.management.ProjectRaster     -- reproject sinusoidal -> WGS84
#
# Previous single-file version is in _old/gridhdf2tif.py.
# ---------------------------------------------------------------------------

import datetime, os, sys, time

# ---------------------------------------------------------------------------
# Per-worker log -- written BEFORE arcpy import so we can tell whether a
# worker hung at DLL loading vs. never started at all.
# ---------------------------------------------------------------------------
_pid = os.getpid()
os.makedirs("temp", exist_ok=True)
_logpath = "temp/worker_%d.log" % _pid


def _wlog(msg):
    """Append a timestamped line to the per-worker log and flush to stdout."""
    line = datetime.datetime.now().strftime("%H:%M:%S") + " [pid %d] " % _pid + msg
    print(line, flush=True)
    with open(_logpath, "a") as fh:
        fh.write(line + "\n")


_wlog("Worker started -- about to import arcpy")

import arcpy
from arcpy.sa import ExtractBand

_wlog("arcpy imported successfully")

# ---------------------------------------------------------------------------
# Per-worker scratch workspace -- each worker gets its own directory to
# prevent file-lock contention when workers run concurrently.
# ---------------------------------------------------------------------------
_scratch = os.path.abspath("temp/scratch_%d" % _pid)
os.makedirs(_scratch, exist_ok=True)

arcpy.env.scratchWorkspace  = _scratch
arcpy.env.workspace         = _scratch
arcpy.env.overwriteOutput   = True
arcpy.env.pyramid           = "NONE"    # skip pyramid building (saves minutes)
arcpy.env.rasterStatistics  = "NONE"   # skip stats building (saves minutes)

_wlog("Scratch workspace: " + _scratch)
_wlog("Checking out Spatial Analyst extension...")
_lic = arcpy.CheckOutExtension("Spatial")
_wlog("CheckOutExtension returned: " + str(_lic))

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# WGS84 geographic CRS used consistently throughout this project.
WGS84 = (
    'GEOGCS["GCS_WGS_1984",'
    'DATUM["D_WGS_1984",SPHEROID["WGS_1984",6378137.0,298.257223563]],'
    'PRIMEM["Greenwich",0.0],'
    'UNIT["Degree",0.0174532925199433]]'
)

# Output pixel size in decimal degrees.
# 30 arc-seconds = 30/3600 = 0.008333... degrees (~1 km along the equator).
# This matches the original HEGtool OUTPUT_PIXEL_SIZE = 30.000047779492313".
OUT_CELL_SIZE = "0.00833333333333"


# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

def modis_tilename(filename):
    """
    Parse day-of-year, year, H tile, and V tile from a MOD14A1 filename.

    Example filename: MOD14A1.A2000049.h00v08.006.2015041132347.hdf
      namevars[1] = 'A2000049'  ->  year='2000', day='049'
      namevars[2] = 'h00v08'   ->  H='00',  V='08'
    """
    namevars = os.path.basename(filename).split(".")
    year = namevars[1][1:5]
    day  = namevars[1][5:]
    H    = namevars[2][1:3]
    V    = namevars[2][4:]
    return day, year, H, V


def find_firemask_index(hdfpath):
    """
    Return the subdataset index (as a string) for the FireMask layer inside
    the HDF container.  Uses arcpy.Describe to search by name so the index
    is not hardcoded.  Falls back to '0' if the search fails (standard
    position for MOD14A1.006).
    """
    try:
        desc = arcpy.Describe(hdfpath)
        if hasattr(desc, 'children'):
            for idx, child in enumerate(desc.children):
                if 'FireMask' in child.name:
                    _wlog("FireMask found at subdataset index %d (name: %s)"
                          % (idx, child.name))
                    return str(idx)
        _wlog("FireMask not found by name search; falling back to index 0")
    except Exception as e:
        _wlog("WARNING: arcpy.Describe failed (%s); falling back to index 0" % str(e))
    return "0"


# ---------------------------------------------------------------------------
# Main conversion function
# ---------------------------------------------------------------------------

def convert_hdf(hdfpath, outfolder):
    """
    Extract all FireMask day-bands from a single MOD14A1 HDF tile and write
    each band as a GeoTIFF reprojected to WGS84.

    Workflow:
      1. Locate the FireMask subdataset inside the HDF container.
      2. ExtractSubDataset -> multi-band FireMask raster (one band per day).
      3. Read band count from the extracted raster (dynamic; usually 1 for the
         daily MOD14A1 product).
      4. For each band:
           a. ExtractBand -> single-band sinusoidal raster (temp file).
           b. ProjectRaster -> WGS84 GCS, nearest-neighbour, ~30 arc-sec cell.
           c. Save to outfolder as D<doy>_Y<year>_H<H>_V<V>_B<band>.tif.

    Returns True on success, False if any exception occurs.
    """
    basename = os.path.basename(hdfpath)
    _wlog("Starting: " + basename)

    try:
        day, year, H, V = modis_tilename(hdfpath)
        outname = "D%s_Y%s_H%s_V%s" % (day, year, H, V)

        # Temporary folder for intermediate files for this tile.
        tile_temp = os.path.join(_scratch, outname)
        os.makedirs(tile_temp, exist_ok=True)

        # Step 1: Find FireMask subdataset index.
        fire_idx = find_firemask_index(hdfpath)

        # Step 2: Extract FireMask as a multi-band raster.
        # MOD14A1.006 FireMask is typically 1 band (one day per file), but
        # we read bandCount below rather than assuming.
        fireMask_path = os.path.join(tile_temp, outname + "_FireMask.tif")
        _wlog("%s: extracting FireMask (subdataset %s)" % (outname, fire_idx))
        arcpy.management.ExtractSubDataset(hdfpath, fireMask_path, fire_idx)
        _wlog("%s: FireMask extracted -> %s" % (outname, fireMask_path))

        # Step 3: Count bands in the extracted raster.
        fire_desc  = arcpy.Describe(fireMask_path)
        num_bands  = fire_desc.bandCount
        _wlog("%s: FireMask has %d band(s)" % (outname, num_bands))

        # Step 4: Per-band extraction and reprojection.
        for bandnum in range(1, num_bands + 1):

            # Intermediate single-band raster (still in sinusoidal projection).
            band_sino = os.path.join(
                tile_temp, "%s_B%d_sino.tif" % (outname, bandnum))

            # Final output raster (WGS84 geographic).
            band_out = os.path.join(
                outfolder, "%s_B%d.tif" % (outname, bandnum))

            # 4a. Isolate one day-band from the multi-band FireMask raster.
            _wlog("%s: extracting band %d of %d" % (outname, bandnum, num_bands))
            single_band = ExtractBand(fireMask_path, [bandnum])
            single_band.save(band_sino)

            arcpy.management.DefineProjection(
                in_dataset=band_sino,
                coor_system='PROJCS["World_Sinusoidal",GEOGCS["GCS_WGS_1984",DATUM["D_WGS_1984",SPHEROID["WGS_1984",6378137.0,298.257223563]],PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]],PROJECTION["Sinusoidal"],PARAMETER["False_Easting",0.0],PARAMETER["False_Northing",0.0],PARAMETER["Central_Meridian",0.0],UNIT["Meter",1.0]]'
            )


            # 4b. Reproject from sinusoidal (WKID 54008) to WGS84 GCS.
            # NEAREST resampling preserves integer fire-class codes (0-9).
            _wlog("%s: reprojecting band %d to WGS84" % (outname, bandnum))
    #         arcpy.management.ProjectRaster(
    # in_raster="D1_Y0001_H05_V_B1_sino.tif",
    # out_raster=r"S:\particulates\data_processing\data\MODIS_FIRE\generated\unit_tests\inter_test",
    # out_coor_system='GEOGCS["GCS_WGS_1984",DATUM["D_WGS_1984",SPHEROID["WGS_1984",6378137.0,298.257223563]],PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]]',
    # resampling_type="NEAREST",
    # cell_size="9.0133729813833E-06 9.0133729813833E-06",
    # geographic_transform=None,
    # Registration_Point=None,
    # in_coor_system='PROJCS["World_Sinusoidal",GEOGCS["GCS_WGS_1984",DATUM["D_WGS_1984",SPHEROID["WGS_1984",6378137.0,298.257223563]],PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]],PROJECTION["Sinusoidal"],PARAMETER["False_Easting",0.0],PARAMETER["False_Northing",0.0],PARAMETER["Central_Meridian",0.0],UNIT["Meter",1.0]]',
    # vertical="NO_VERTICAL"
# )
            arcpy.management.ProjectRaster(
                in_raster=band_sino,
                out_raster="S:\\particulates\\data_processing\\data\\MODIS_FIRE\\generated\\unit_tests\\inter_test.tif",
                out_coor_system='GEOGCS["GCS_WGS_1984",DATUM["D_WGS_1984",SPHEROID["WGS_1984",6378137.0,298.257223563]],PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]]',
                geographic_transform=None,
                Registration_Point=None,
                in_coor_system='PROJCS["World_Sinusoidal",GEOGCS["GCS_WGS_1984",DATUM["D_WGS_1984",SPHEROID["WGS_1984",6378137.0,298.257223563]],PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]],PROJECTION["Sinusoidal"],PARAMETER["False_Easting",0.0],PARAMETER["False_Northing",0.0],PARAMETER["Central_Meridian",0.0],UNIT["Meter",1.0]]',
                resampling_type="NEAREST",
                cell_size=OUT_CELL_SIZE
            )
            _wlog("%s: band %d -> %s" % (outname, bandnum,
                                          os.path.basename(band_out)))

        _wlog("%s: all %d band(s) done." % (outname, num_bands))
        return True

    except Exception as e:
        import traceback
        tb = sys.exc_info()[2]
        _wlog("ERROR on line %d: %s" % (tb.tb_lineno, str(e)))
        _wlog(traceback.format_exc())
        return False


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    # if len(sys.argv) < 3:
    #     print("Usage: gridhdf2tif_worker.py <hdfpath> <outfolder>")
    #     sys.exit(1)

    # hdfpath   = sys.argv[1]
    # outfolder = sys.argv[2]

    hdfpath   = "S:\\particulates\\data_processing\\data\\MODIS_FIRE\\source\\monthly\\MOD14CMH.200011.005.01.hdf"
    outfolder = "S:\\particulates\\data_processing\\data\\MODIS_FIRE\\generated\\unit_tests"

    t0 = time.process_time()
    success = convert_hdf(hdfpath, outfolder)
    elapsed = time.process_time() - t0

    print("[%s] %.1fs  success=%s"
          % (os.path.basename(hdfpath), elapsed, success))

    # sys.exit(0 if success else 1)
