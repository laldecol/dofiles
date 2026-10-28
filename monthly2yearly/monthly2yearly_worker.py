# ---------------------------------------------------------------------------
# monthly2yearly_worker.py  [WORKER -- imports arcpy; called by propy.bat]
# Description: Aggregate monthly CRU rasters for one (expath, output_raster)
# pair into a yearly mean raster using arcpy.sa.CellStatistics.
# Called by monthly2yearly.py via propy.bat; NOT called by Stata directly.
#
# Created 2026-08-31 as part of py3/ArcGIS Pro refactor.
# ---------------------------------------------------------------------------

import datetime, os, sys, time

# Write a per-worker log before importing arcpy so we can diagnose whether
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
from arcpy.sa import *

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
arcpy.env.workspace = _scratch
arcpy.env.overwriteOutput = True
arcpy.env.pyramid = "NONE"
arcpy.env.rasterStatistics = "NONE"
_wlog("Scratch workspace: " + _scratch)

arcpy.CheckOutExtension("Spatial")
_wlog("Spatial extension checked out")


def run_aggregate(expath, output_raster):
    # Calls rasters.aggregate() for one (expath, output_raster) pair.
    # Returns True on success, False if rasters.aggregate() raises.
    try:
        _wlog("Starting aggregate: " + expath + " -> " + output_raster)
        rasters.aggregate(expath, output_raster)
        _wlog("Done: " + output_raster)
        return True
    except Exception as e:
        _wlog("ERROR: " + str(e))
        return False


if __name__ == "__main__":
    # Entry point when called by propy.bat from monthly2yearly.py.
    # Arguments: expath output_raster
    expath        = sys.argv[1]
    output_raster = sys.argv[2]

    t0 = time.process_time()
    success = run_aggregate(expath, output_raster)
    elapsed = time.process_time() - t0

    print("[%s] completed in %.1fs. success=%s" % (
        os.path.basename(output_raster), elapsed, str(success)))

    sys.exit(0 if success else 1)
