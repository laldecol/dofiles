# ---------------------------------------------------------------------------
# dailytile2ubergrid.py  [ORCHESTRATOR -- does NOT import arcpy]
#
# Description: Converts daily per-tile MODIS FireMask GeoTIFFs (output of
# gridhdf2tif.py) into global yearly fire-count and data-count rasters.
#
# Updated from dailytile2ubergrid.py to py3 / ArcGIS Pro 3.1 on 2026-07-21.
# Main changes in this version:
#   - Pool workers now launch propy.bat subprocesses (same pattern as
#     daily2yearlyAOD.py) so each worker checks out its own ArcGIS Pro license.
#   - arcpy.CreateRasterCatalog_management and RasterCatalogToRasterDataset_management
#     (both removed in ArcGIS Pro) replaced with:
#       * arcpy.sa.CellStatistics(SUM) for per-tile daily->yearly aggregation
#       * arcpy.management.MosaicToNewRaster for the global tile mosaic step
#   - arcpy.gp.ReclassByTable_sa replaced with arcpy.sa.ReclassByTable (returns
#     a Raster object; caller saves it with .save()).
#   - Remap table paths corrected: old code used "\\remapfiresv2" (wrong
#     root-drive-absolute path). Tables are ArcInfo INFO tables stored in
#     info/ subfolder; correct path is os.path.join(SCRIPT_DIR, "REMAPFIRESV2").
#   - Input folder updated from source/daily/ to generated/daily/ to match
#     output location of the refactored gridhdf2tif.py.
#   - Fixed path-construction bugs: original lines 121-122 were missing a
#     backslash before "data" (e.g. "..\\..\\..data\\" instead of
#     "..\\..\\..\\data\\").
#   - Retry logic added (MAX_RUNS attempts before marking tile as fatal).
#   - Per-worker scratch workspace in temp/scratch_<pid>/.
#   - Python 2 -> 3 syntax throughout (print, time.process_time,
#     pool.close(), pool.join()).
# Previous version saved in _old/dailytile2ubergrid.py.
#
# Requires (inputs from earlier stages):
#   - data/MODIS_FIRE/generated/daily/<year>/*_H??_V??_B*.tif
#       produced by gridhdf2tif.py
#
# Produces (outputs for later stages):
#   - data/MODIS_FIRE/generated/yearly/<year>/*Fire.tif  (per-tile yearly fire count)
#   - data/MODIS_FIRE/generated/yearly/<year>/*Data.tif  (per-tile yearly data count)
#   - data/MODIS_FIRE/generated/yearly/1k/Fire<year>.tif (global yearly fire count)
#   - data/MODIS_FIRE/generated/yearly/1k/Data<year>.tif (global yearly data count)
# ---------------------------------------------------------------------------

import glob, logging, os, shutil, subprocess, sys, time
from functools import partial
from multiprocessing import Pool

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Path to ArcGIS Pro Python launcher.
PROPY_BAT = r"C:\Program Files\ArcGIS\Pro\bin\Python\scripts\propy.bat"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
WORKER_SCRIPT = os.path.join(SCRIPT_DIR, "dailytile2ubergrid_worker.py")

# Year range to process.
START_YEAR = 2000
END_YEAR   = 2000

# Number of concurrent pool workers (ArcGIS Pro license constraint).
NW = 8

# Seconds before a tile worker is declared timed-out and marked fatal.
# Per-tile processing covers up to 365 reclassify+save operations.
WORKER_TIMEOUT = 7200  # 2 hours per tile

# Seconds for the per-year global mosaic worker (runs sequentially, not pooled).
MOSAIC_TIMEOUT = 3600  # 1 hour per year mosaic

# Max retry attempts before a failing tile is marked permanently failed.
MAX_RUNS = 2


# ---------------------------------------------------------------------------
# Worker launcher functions (run inside Pool.map; must NOT import arcpy)
# ---------------------------------------------------------------------------

def run_tile_via_propy(year, input_folder, out_folder, HV):
    """
    Launch one tile worker via propy.bat for a single HV tile.
    Returns [returncode, HV, stdout_text, stderr_text].
    Pool.map calls this with HV as the mapped argument; year/input_folder/
    out_folder are bound via functools.partial.
    """
    cmd = [PROPY_BAT, WORKER_SCRIPT, "tile",
           HV, year, input_folder, out_folder, SCRIPT_DIR]
    try:
        env = os.environ.copy()
        env.pop("PYTHONHOME", None)    # prevent ArcGIS Pro from picking up
        env["PYTHONNOUSERSITE"] = "1"  # the wrong site-packages
        env["PYTHONUNBUFFERED"] = "1"
        p = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd=SCRIPT_DIR,
            env=env,
            creationflags=subprocess.CREATE_NEW_PROCESS_GROUP,
            timeout=WORKER_TIMEOUT
        )
        return [p.returncode, HV, p.stdout, p.stderr]
    except subprocess.TimeoutExpired:
        return [998, HV, "", "TIMEOUT: worker exceeded %ds" % WORKER_TIMEOUT]
    except Exception as e:
        return [999, HV, "", "Exception launching subprocess: %r" % e]


def run_mosaic_via_propy(year, out_yearly_folder, out_1k_folder):
    """
    Launch the mosaic worker for one year via propy.bat. Blocking (not pooled).
    Returns (returncode, stdout_text, stderr_text).
    """
    cmd = [PROPY_BAT, WORKER_SCRIPT, "mosaic",
           year, out_yearly_folder, out_1k_folder]
    try:
        env = os.environ.copy()
        env.pop("PYTHONHOME", None)
        env["PYTHONNOUSERSITE"] = "1"
        env["PYTHONUNBUFFERED"] = "1"
        p = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd=SCRIPT_DIR,
            env=env,
            creationflags=subprocess.CREATE_NEW_PROCESS_GROUP,
            timeout=MOSAIC_TIMEOUT
        )
        return p.returncode, p.stdout, p.stderr
    except subprocess.TimeoutExpired:
        return 998, "", "TIMEOUT: mosaic worker exceeded %ds" % MOSAIC_TIMEOUT
    except Exception as e:
        return 999, "", "Exception launching mosaic subprocess: %r" % e


def BandTIFtilename(inputfile):
    """
    Extract the two-digit H and V tile numbers from a daily TIF filename.
    Expected naming convention from gridhdf2tif.py: D049_Y2000_H00_V08_B1.tif
    Returns a 4-character string like "0008" (H="00", V="08").
    """
    namevars = os.path.basename(inputfile)
    H = namevars[12:14]
    V = namevars[16:18]
    return H + V


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if __name__ == '__main__':

    logging.basicConfig(
        format='%(asctime)s %(message)s',
        filename='dailytile2ubergrid.log',
        filemode='w',
        level=logging.DEBUG
    )
    logging.info('Starting dailytile2ubergrid.py.')

    # Verify prerequisites exist before doing any work.
    if not os.path.isfile(PROPY_BAT):
        logging.error('FATAL: propy.bat not found at %s', PROPY_BAT)
        sys.exit(1)
    if not os.path.isfile(WORKER_SCRIPT):
        logging.error('FATAL: worker script not found at %s', WORKER_SCRIPT)
        sys.exit(1)
    # Verify the remap INFO tables exist in the info/ subdirectory.
    # for tbl in ("REMAPFIRESV2", "REMAPDATAV2"):
    #     # ArcInfo INFO tables are referenced by the parent folder + table name;
    #     # the actual data files are in info/ but we verify via the arc.dir file.
    #     info_arc_dir = os.path.join(SCRIPT_DIR, "info", "arc.dir")
    #     if not os.path.isfile(info_arc_dir):
    #         logging.error('FATAL: INFO directory not found at %s/info/', SCRIPT_DIR)
    #         sys.exit(1)

    # Clean temp/ to remove stale worker logs and scratch dirs from prior runs.
    # Workers recreate temp/ themselves when they start.
    temp_dir = os.path.join(SCRIPT_DIR, "temp")
    shutil.rmtree(temp_dir, ignore_errors=True)
    os.makedirs(temp_dir, exist_ok=True)
    logging.info('Cleaned temp/ directory.')

    # Ensure the global mosaic output folder (1k/) exists.
    out_1k = os.path.abspath(os.path.join(
        SCRIPT_DIR, '..', '..', '..', 'data',
        'MODIS_FIRE', 'generated', 'yearly', '1k'))
    os.makedirs(out_1k, exist_ok=True)
    logging.info('Global mosaic output folder: %s', out_1k)

    years = [str(y) for y in range(START_YEAR, END_YEAR + 1)]
    all_fatal = []
    t0 = time.process_time()

    for year in years:
        logging.info('--- Year %s ---', year)

        # Build absolute paths so they survive being passed as argv to the worker.
        input_folder = os.path.abspath(os.path.join(
            SCRIPT_DIR, '..', '..', '..', 'data',
            'MODIS_FIRE', 'source', 'daily', year))
        out_folder = os.path.abspath(os.path.join(
            SCRIPT_DIR, '..', '..', '..', 'data',
            'MODIS_FIRE', 'generated', 'yearly', year))

        # Verify the daily input folder exists before processing this year.
        if not os.path.isdir(input_folder):
            logging.error('Input folder not found: %s -- skipping year %s.',
                          input_folder, year)
            all_fatal.append(year + '/no-input-folder')
            continue

        # Rebuild the per-tile yearly output folder.
        shutil.rmtree(out_folder, ignore_errors=True)
        os.makedirs(out_folder, exist_ok=True)

        # Collect all daily B-band TIF files and extract unique HV tile IDs.
        filelist = glob.glob(os.path.join(input_folder, '*B*.tif'))
        if not filelist:
            logging.warning('No *B*.tif files in %s -- skipping year %s.',
                            input_folder, year)
            continue

        # Use a set to deduplicate HV IDs across days and bands.
        HVs = list({BandTIFtilename(f) for f in filelist})
        logging.info('Year %s: %d unique tiles, %d daily files total.',
                     year, len(HVs), len(filelist))

        # ------------------------------------------------------------------
        # Stage 1: Per-tile daily -> yearly aggregation (pooled workers)
        # ------------------------------------------------------------------
        tile_runner = partial(run_tile_via_propy, year, input_folder, out_folder)
        pending_hvs = list(HVs)
        year_fatal  = []
        run = 1

        while pending_hvs:
            if run > MAX_RUNS:
                logging.error(
                    'MAX_RUNS (%d) exceeded for year %s. '
                    'Marking %d tile(s) as permanently failed: %s',
                    MAX_RUNS, year, len(pending_hvs), ' '.join(pending_hvs))
                year_fatal.extend(pending_hvs)
                pending_hvs = []
                break

            logging.info('Year %s, run %d: submitting %d tile(s) to pool.',
                         year, run, len(pending_hvs))
            pool = Pool(processes=NW)
            results = pool.map(tile_runner, pending_hvs)
            pool.close()
            pool.join()

            pending_hvs = []
            for rc, HV, out, err in results:
                logging.info('[%s %s] rc=%d', year, HV, rc)
                if out:
                    logging.info('[%s %s] stdout:\n%s', year, HV, out)
                if err:
                    logging.info('[%s %s] stderr:\n%s', year, HV, err)
                if rc == 0:
                    pass  # success
                elif rc == 998:
                    logging.error('[%s %s] TIMEOUT -- marking as fatal, no retry.', year, HV)
                    year_fatal.append(HV)
                else:
                    logging.warning('[%s %s] FAILED (rc=%d) -- will retry.', year, HV, rc)
                    pending_hvs.append(HV)
            run += 1

        if year_fatal:
            logging.error('Year %s: %d tile(s) failed permanently: %s',
                          year, len(year_fatal), ' '.join(year_fatal))
            all_fatal.extend('%s/%s' % (year, HV) for HV in year_fatal)

        tile_fire_count = len(glob.glob(os.path.join(out_folder, '*Fire.tif')))
        tile_data_count = len(glob.glob(os.path.join(out_folder, '*Data.tif')))
        logging.info('Year %s: %d Fire tile(s) and %d Data tile(s) written.',
                     year, tile_fire_count, tile_data_count)

        if tile_fire_count == 0:
            logging.error(
                'Year %s: no Fire tiles produced -- skipping mosaic.', year)
            all_fatal.append(year + '/mosaic-no-input')
            continue

        # ------------------------------------------------------------------
        # Stage 2: Mosaic all tiles into a single global raster (sequential)
        # ------------------------------------------------------------------

        logging.info('Year %s: mosaicking %d tile(s) into global raster.',
                     year, tile_fire_count)
        rc, out, err = run_mosaic_via_propy(year, out_folder, out_1k)
        logging.info('[%s mosaic] rc=%d', year, rc)
        if out:
            logging.info('[%s mosaic] stdout:\n%s', year, out)
        if err:
            logging.info('[%s mosaic] stderr:\n%s', year, err)
        if rc != 0:
            logging.error('[%s mosaic] FAILED -- global raster not produced.', year)
            all_fatal.append(year + '/mosaic-failed')
        else:
            logging.info('Year %s: mosaic complete.', year)

    elapsed = time.process_time() - t0
    logging.info('All years processed in %.1f minutes.', elapsed / 60)

    if all_fatal:
        logging.error('FATAL: failures in: %s', ' '.join(all_fatal))
        logging.info('Done with dailytile2ubergrid.py (completed with errors).')
        sys.exit(1)

    logging.info('Done with dailytile2ubergrid.py.')

# Erase the failmarker created by run_python_particulates.ado.
# Reaching this line means __main__ exited normally (no unhandled exception,
# no sys.exit(1)).
# Note: this script is not currently in the master pipeline; the failmarker
# block is included for when it is added.
try:
    os.remove('failmarker.txt')
except FileNotFoundError:
    pass
