# ---------------------------------------------------------------------------
# daily2yearlyAOD_worker.py  [WORKER -- imports arcpy; called by propy.bat]
# Description: Create a global AOD raster for one satellite-year token.
# Called by daily2yearlyAOD.py via propy.bat; NOT called by Stata directly.
#
# Created 2026-07-06 as part of py3/ArcGIS Pro refactor.
# Previous single-file version saved in _old/daily2yearlyAOD.py.
# ---------------------------------------------------------------------------

import datetime, glob, os, shutil, sys, time

# Per-worker log written before arcpy import so we can tell whether the process
# started but hung at DLL loading versus never started at all.
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
from arcpy import env
from arcpy.sa import *

_wlog("arcpy imported successfully")

# Give each worker its own scratch workspace to prevent lock contention when
# multiple workers run concurrently. Placed in temp/ alongside this script,
# not in the OS temp directory.
_scratch = os.path.abspath("temp/scratch_%d" % _pid)
os.makedirs(_scratch, exist_ok=True)
arcpy.env.scratchWorkspace = _scratch
arcpy.env.workspace = _scratch
_wlog("Scratch workspace: " + _scratch)

_wlog("Calling CheckOutExtension('Spatial')...")
_lic_result = arcpy.CheckOutExtension("Spatial")
_wlog("CheckOutExtension returned: " + str(_lic_result))
arcpy.env.overwriteOutput = True
arcpy.env.pyramid = "NONE"
arcpy.env.rasterStatistics = "NONE"

def aggregate(satyear, prod):
    # Aggregate all daily AOD .tif files for a satellite-year into one yearly raster.

    # Split satyear token into satellite name and year.
    if satyear[0] == "A":
        sat = "Aqua"
    elif satyear[0] == "T":
        sat = "Terra"

    year = satyear[1:5]
    print("year is " + year)
    print("sat is " + sat)

    # Set directories.
    data_aod = "../../../data/MODIS_AOD"
    # in_folder="S:\particulates\data_processing\data\MODIS_AOD\\arcpro_unit_tests\daily_AOD"
    in_folder = data_aod + "/source/daily"
    out_folder = data_aod + "/generated/yearly"
    # out_folder= "S:\particulates\data_processing\data\MODIS_AOD\\arcpro_unit_tests\yearly_aggregated"
    raster_name = sat + year + "avg.tif"
    output_raster = out_folder + "/" + raster_name
     
    try:
        # Build list of daily .tif files for this satellite and year.
        rasters = glob.glob(in_folder + "/*" + prod + "_" + sat + "_" + year + "*tif")
        rasters = [os.path.abspath(r).replace('\\', '/') for r in rasters]
        _wlog("%s: found %d rasters" % (satyear, len(rasters)))

        # Define spatial reference (World Sinusoidal).
        sr = arcpy.SpatialReference(54008)

        # Per-cell mean across all daily rasters, ignoring NoData days.
        # 2026-07-07: Replaced MosaicToNewRaster (wrong tool -- produced tiny output)
        # with CellStatistics, which is the correct ArcGIS Pro replacement for
        # RasterCatalogToRasterDataset MEAN. CellStatistics computes per-cell
        # statistics across co-registered rasters of the same extent; "DATA" means
        # NoData cells are excluded from each cell's mean rather than forcing NoData.
        _wlog("%s: starting CellStatistics" % satyear)
        
    
        with arcpy.EnvManager(outputCoordinateSystem='GEOGCS["GCS_WGS_1984",DATUM["D_WGS_1984",SPHEROID["WGS_1984",6378137.0,298.257223563]],PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]]', extent='-180 -59.9999999999918 180.000000000002 85.0000000000092 GEOGCS["GCS_WGS_1984",DATUM["D_WGS_1984",SPHEROID["WGS_1984",6378137.0,298.257223563]],PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]]', cellSize="S:\\particulates\\data_processing\\data\\GPW4\\generated\\aggregated\\aggregated_gpw_2010.tif", geographicTransformations=None):
            out_raster = arcpy.ia.CellStatistics(
            in_rasters_or_constants=rasters,
            statistics_type="MEAN",
            ignore_nodata="DATA",
            process_as_multiband="SINGLE_BAND",
            percentile_value=90,
            percentile_interpolation_type="AUTO_DETECT"
            )
            out_raster.save(output_raster)
            _wlog("%s: CellStatistics done, saving..." % satyear)
            _wlog("%s: done" % satyear)
        return True
    except Exception as e:
        tb = sys.exc_info()[2]
        print("An error occured on line %i" % tb.tb_lineno)
        print(str(e))
        return False

if __name__ == "__main__":
    # Entry point when called by propy.bat from the orchestrator.
    prod    = sys.argv[1]
    satyear = sys.argv[2]

    #Test for debug 
    # prod="3K"
    # satyear="T2000"

    t0 = time.process_time()
    success = aggregate(satyear, prod)
    elapsed = time.process_time() - t0
    print("[%s] completed in %.1fs. success=%s" % (satyear, elapsed, str(success)))

    sys.exit(0 if success else 1)
