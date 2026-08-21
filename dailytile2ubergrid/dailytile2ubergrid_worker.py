# ---------------------------------------------------------------------------
# dailytile2ubergrid_worker.py  [WORKER -- imports arcpy; called by propy.bat]
#
# Processes one MODIS fire tile or mosaics all tiles for one year.
# Called by dailytile2ubergrid.py (the orchestrator) via propy.bat.
# NOT called by Stata directly.
#
# Two modes (first argv):
#
#   tile HV YEAR INPUT_FOLDER OUT_FOLDER INFO_DIR
#       Reclassify all daily FireMask TIF files for tile HV using the
#       INFO remap tables, then sum across days using CellStatistics.
#       Writes <OUT_FOLDER>/_H??_V??Fire.tif and _H??_V??Data.tif.
#
#   mosaic YEAR OUT_YEARLY OUT_1K
#       Mosaic all per-tile yearly fire and data rasters from OUT_YEARLY
#       into single global GeoTIFFs in OUT_1K.
#
# Created 2026-07-21 as part of py3 / ArcGIS Pro 3.1 refactor.
# Previous single-file version saved in _old/dailytile2ubergrid.py.
# ---------------------------------------------------------------------------

import datetime, glob, os, shutil, sys, time

# ---------------------------------------------------------------------------
# Per-worker log -- written BEFORE arcpy import so we can diagnose a hang
# at DLL loading vs. a hang that happens later during processing.
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


_wlog("Worker started (mode=%s) -- about to import arcpy"
      % (sys.argv[1] if len(sys.argv) > 1 else "?"))

import arcpy
from arcpy.sa import CellStatistics, ReclassByTable

_wlog("arcpy imported successfully")

# ---------------------------------------------------------------------------
# Per-worker scratch workspace -- each worker gets its own directory so
# concurrent Pool workers do not contend for the same file locks.
# ---------------------------------------------------------------------------
_scratch = os.path.abspath("temp/scratch_%d" % _pid)
os.makedirs(_scratch, exist_ok=True)

arcpy.env.scratchWorkspace = _scratch
arcpy.env.workspace        = _scratch
arcpy.env.overwriteOutput  = True
arcpy.env.pyramid          = "NONE"   # skip pyramid building (saves time)
arcpy.env.rasterStatistics = "NONE"   # skip stats building (saves time)

_wlog("Scratch workspace: " + _scratch)
_wlog("Checking out Spatial Analyst extension...")
_lic = arcpy.CheckOutExtension("Spatial")
_wlog("CheckOutExtension returned: " + str(_lic))


# ---------------------------------------------------------------------------
# Tile-aggregation mode
# ---------------------------------------------------------------------------

def process_tile(HV, year, input_folder, out_folder, remap_fire_file, remap_data_file):
    """
    Reclassify all daily FireMask TIF files for one HV tile and year,
    then sum across days with CellStatistics to produce yearly rasters.

    The reclassification uses two ArcInfo INFO tables stored in info_dir/info/:
      REMAPFIRESV2 -- maps FireMask values to fire-occurrence indicator
      REMAPDATAV2  -- maps FireMask values to data-availability indicator

    In arcpy, an INFO table named REMAPFIRESV2 in <dir>/info/ is referenced
    as <dir>/REMAPFIRESV2 (arcpy discovers the info/ subdirectory automatically).

    CellStatistics "SUM" with ignore_nodata="DATA" sums fire/data values
    across all valid days; pixels with NoData on a given day are excluded
    from the sum rather than forcing NoData in the output.

    Input files:  INPUT_FOLDER/*_H??_V??_B*.tif
    Output files:
        OUT_FOLDER/_H{H}_V{V}Fire.tif  -- annual fire-count raster
        OUT_FOLDER/_H{H}_V{V}Data.tif  -- annual data-count raster
    """
    H    = HV[0:2]
    V    = HV[2:4]
    tile = "_H" + H + "_V" + V
    _wlog("process_tile: HV=%s year=%s tile=%s" % (HV, year, tile))

    # INFO table paths: arcpy finds the info/ subdirectory automatically
    # when given the parent folder path + table name.

    # Tile-specific temp folder for intermediate reclassified rasters.
    # Located inside the per-worker scratch workspace to avoid cross-worker
    # lock contention.
    tempfolder = os.path.join(_scratch, "tile" + tile)
    shutil.rmtree(tempfolder, ignore_errors=True)
    os.makedirs(tempfolder, exist_ok=True)

    # Find all daily TIF files for this tile (all bands and days).
    daylist = glob.glob(os.path.join(input_folder, "*" + tile + "*.tif"))
    if not daylist:
        _wlog("ERROR: no daily TIF files found for tile %s in %s"
              % (tile, input_folder))
        return False

    _wlog("Found %d daily file(s) for tile %s" % (len(daylist), tile))

    try:
        fire_files = []
        data_files = []

        # Reclassify each day's raster using the INFO remap tables.
        # ReclassByTable returns a Raster object; save it to a temp file so
        # CellStatistics can work from a stable on-disk list rather than
        # holding all rasters in memory simultaneously.
        for day in daylist:
            basename    = os.path.basename(day)
            out_fire    = os.path.join(tempfolder, "Fire_" + basename)
            out_data    = os.path.join(tempfolder, "Data_" + basename)

            _wlog("Reclassifying: " + basename)
            fire_r = arcpy.sa.ReclassByASCIIFile(day, remap_fire_file)
            fire_r.save(out_fire)
            data_r = arcpy.sa.ReclassByASCIIFile(day, remap_data_file)
            data_r.save(out_data)

            fire_files.append(out_fire)
            data_files.append(out_data)

        # Output paths for this tile's yearly aggregates.
        outrasterfire = os.path.join(out_folder, tile + "Fire.tif")
        outrasterdata = os.path.join(out_folder, tile + "Data.tif")

        # Sum reclassified rasters across all days.
        _wlog("CellStatistics SUM over %d fire file(s)..." % len(fire_files))
        out_fire = CellStatistics(fire_files, "SUM", "DATA")
        out_fire.save(outrasterfire)
        _wlog("Saved fire raster: " + outrasterfire)

        _wlog("CellStatistics SUM over %d data file(s)..." % len(data_files))
        out_data = CellStatistics(data_files, "SUM", "DATA")
        out_data.save(outrasterdata)
        _wlog("Saved data raster: " + outrasterdata)

    except Exception as e:
        import traceback
        _wlog("ERROR in process_tile: " + str(e))
        _wlog(traceback.format_exc())
        return False
    finally:
        # Always clean up the tile-level temp files regardless of success/failure.
        shutil.rmtree(tempfolder, ignore_errors=True)

    _wlog("process_tile done: " + tile)
    return True


# ---------------------------------------------------------------------------
# Mosaic mode
# ---------------------------------------------------------------------------

def run_mosaic(year, out_yearly, out_1k):
    """
    Mosaic all per-tile yearly fire and data rasters into single global GeoTIFFs.

    MosaicToNewRaster with mosaic_method="SUM" combines spatially non-overlapping
    MODIS tiles into a single global raster. For non-overlapping areas (the normal
    case) SUM == FIRST; the SUM method matches the original code's behavior and
    handles any small edge overlaps between tiles consistently.

    Input files:  OUT_YEARLY/*Fire.tif, OUT_YEARLY/*Data.tif
    Output files:
        OUT_1K/Fire{year}.tif  -- global yearly fire count
        OUT_1K/Data{year}.tif  -- global yearly data count
    """
    _wlog("run_mosaic: year=%s" % year)

    inputs_fire = glob.glob(os.path.join(out_yearly, "*Fire.tif"))
    inputs_data = glob.glob(os.path.join(out_yearly, "*Data.tif"))

    if not inputs_fire:
        _wlog("ERROR: no *Fire.tif files found in " + out_yearly)
        return False

    _wlog("Mosaicking %d fire tile(s) and %d data tile(s)."
          % (len(inputs_fire), len(inputs_data)))

    # WGS84 geographic coordinate system (WKID 4326).
    sr = arcpy.SpatialReference(4326)

    try:
        for raster_label, inputs, outname in [
            ("Fire", inputs_fire, "Fire" + year + ".tif"),
            ("Data", inputs_data, "Data" + year + ".tif"),
        ]:
            out_raster = os.path.join(out_1k, outname)

            # Remove any existing output so MosaicToNewRaster can write cleanly.
            if arcpy.Exists(out_raster):
                arcpy.management.Delete(out_raster)

            _wlog("%s: MosaicToNewRaster -> %s" % (raster_label, outname))
            arcpy.management.MosaicToNewRaster(
                input_rasters=inputs,
                output_location=out_1k,
                raster_dataset_name_with_extension=outname,
                coordinate_system_for_the_raster=sr,
                pixel_type="16_BIT_UNSIGNED",
                cellsize=None,
                number_of_bands=1,
                mosaic_method="SUM",
                mosaic_colormap_mode="FIRST"
            )
            _wlog("%s: mosaic done -> %s" % (raster_label, out_raster))

    except Exception as e:
        import traceback
        _wlog("ERROR in run_mosaic: " + str(e))
        _wlog(traceback.format_exc())
        return False

    _wlog("run_mosaic done for year " + year)
    return True


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage:")
        print("  dailytile2ubergrid_worker.py tile HV YEAR INPUT_FOLDER OUT_FOLDER")
        print("  dailytile2ubergrid_worker.py mosaic YEAR OUT_YEARLY OUT_1K")
        sys.exit(1)

    mode = sys.argv[1]
    # mode = "tile"
    # mode = "mosaic"
    t0   = time.process_time()

    if mode == "tile":
        if len(sys.argv) < 7:
            print("tile mode requires: HV YEAR INPUT_FOLDER OUT_FOLDER")
            sys.exit(1)
        HV           = sys.argv[2]
        year         = sys.argv[3]
        input_folder = sys.argv[4]
        out_folder   = sys.argv[5]

        # HV           = "3110"
        # year         = "2001"
        # input_folder = "S:\\particulates\\data_processing\\data\\MODIS_FIRE\\source\\unit_tests"
        # out_folder   = "S:\\particulates\\data_processing\\data\\MODIS_FIRE\\generated\\unit_tests"
        remap_fire_file="S:\\particulates\\data_processing\\data\\MODIS_FIRE\\source\\unit_tests\\fire_remap.txt"
        remap_data_file="S:\\particulates\\data_processing\\data\\MODIS_FIRE\\source\\unit_tests\\data_remap.txt"

        success = process_tile(HV, year, input_folder, out_folder, remap_fire_file, remap_data_file )

    elif mode == "mosaic":
        if len(sys.argv) < 5:
            print("mosaic mode requires: YEAR OUT_YEARLY OUT_1K")
            sys.exit(1)
        year       = sys.argv[2]
        out_yearly = sys.argv[3]
        out_1k     = sys.argv[4]
        year       = "2000"
        out_yearly = "S:\\particulates\\data_processing\\data\\MODIS_FIRE\\generated\\yearly\\2000"
        out_1k     = "S:\\particulates\\data_processing\\data\\MODIS_FIRE\\generated\\yearly\\1k"

        success = run_mosaic(year, out_yearly, out_1k)

    else:
        print("Unknown mode: %s  (expected 'tile' or 'mosaic')" % mode)
        sys.exit(1)

    elapsed = time.process_time() - t0
    _wlog("Worker done. mode=%s success=%s elapsed=%.1fs" % (mode, success, elapsed))
    sys.exit(0 if success else 1)
