# ---------------------------------------------------------------------------
# monthly2yearly.py  [ORCHESTRATOR -- does NOT import arcpy]
# Description: Create a yearly mean raster for each CRU climate variable and
# year from monthly input rasters. Spawns monthly2yearly_worker.py via
# propy.bat for each (dtype, year) pair; workers do all arcpy work.
# Run time: ~20 seconds per pair; 150 pairs total (10 dtypes x 15 years).
#
# Updated from monthly2yearly.py to py3/ArcGIS Pro on 2026-08-31.
# Main changes in this version:
#   - Split into orchestrator (this file) + worker (monthly2yearly_worker.py).
#   - Pool workers now launch propy.bat subprocesses instead of calling arcpy
#     directly. All arcpy work is in monthly2yearly_worker.py.
#   - Replaced sequential for loop with Pool(8) for parallel processing.
#   - Dead satellite pool code removed (referenced undefined satyears, years).
#   - Python 2 syntax updated to Python 3.
# Previous version saved in _old/monthly2yearly.py.
# ---------------------------------------------------------------------------

import logging, os, shutil, subprocess, sys, time
from multiprocessing import Pool

# Path to propy.bat (ArcGIS Pro Python launcher) and the worker script.
PROPY_BAT = r"C:\Program Files\ArcGIS\Pro\bin\Python\scripts\propy.bat"
WORKER_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                             "monthly2yearly_worker.py")

WORKER_TIMEOUT = 600   # seconds; each pair should finish well under this
MAX_RUNS = 2           # one retry on failure; timeouts go straight to fatal


def run_pair_via_propy(pair):
    # Runs inside a Pool worker. Must NOT import arcpy.
    # Launches a licensed ArcGIS Pro Python process for one (expath, output_raster) pair.
    expath, output_raster = pair
    label = os.path.basename(output_raster)
    cmd = [PROPY_BAT, WORKER_SCRIPT, expath, output_raster]
    script_dir = os.path.dirname(os.path.abspath(__file__))
    try:
        env = os.environ.copy()
        env.pop("PYTHONHOME", None)
        env["PYTHONNOUSERSITE"] = "1"
        env["PYTHONUNBUFFERED"] = "1"
        p = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd=script_dir,
            env=env,
            creationflags=subprocess.CREATE_NEW_PROCESS_GROUP,
            timeout=WORKER_TIMEOUT
        )
        return [p.returncode, label, expath, output_raster, p.stdout, p.stderr]
    except subprocess.TimeoutExpired:
        return [998, label, expath, output_raster, "",
                "TIMEOUT: worker exceeded %ds" % WORKER_TIMEOUT]
    except Exception as e:
        return [999, label, expath, output_raster, "",
                "Exception launching subprocess: %r" % e]


if __name__ == '__main__':

    logging.basicConfig(format='%(asctime)s %(message)s',
                        filename='monthly2yearly.log', filemode='w',
                        level=logging.DEBUG)
    logging.info('Starting monthly2yearly.py.')

    # Clean temp/ to remove stale worker logs and scratch dirs from prior runs.
    _temp = os.path.join(os.path.dirname(os.path.abspath(__file__)), "temp")
    shutil.rmtree(_temp, ignore_errors=True)
    os.makedirs(_temp, exist_ok=True)
    logging.info('Cleaned temp/ directory.')

    # Set up input and output directories.
    out_folder_cru = "../../../data/CRU/generated/yearly"
    in_folder_cru  = "../../../data/CRU/generated/monthlies"
    shutil.rmtree(out_folder_cru, ignore_errors=True)
    os.makedirs(out_folder_cru, exist_ok=True)
    logging.info('Output folder: %s', out_folder_cru)

    # Year range.
    startyear = 2000
    endyear   = 2014

    # CRU data types to aggregate.
    dtypes = ["cld", "dtr", "frs", "pet", "pre", "tmn", "tmp", "tmx", "vap", "wet"]

    # Number of Pool workers.
    nw = 8

    logging.info('Year range: %d - %d', startyear, endyear)
    logging.info('Data types: %s', ' '.join(dtypes))
    logging.info('Workers: %d', nw)

    # Build list of (expath, output_raster) pairs -- one per dtype x year.
    pairs = [
        (in_folder_cru + "/" + dtype + "*" + str(year) + "*.tif",
         out_folder_cru + "/" + dtype + str(year) + ".tif")
        for year in range(startyear, endyear + 1)
        for dtype in dtypes
    ]
    total = len(pairs)
    logging.info('Total pairs to process: %d', total)
    print("Total pairs to process: %d" % total)

    t0 = time.process_time()
    run = 1
    pending = list(pairs)
    fatal = []

    while pending:
        if run > MAX_RUNS:
            logging.error('MAX_RUNS (%d) exceeded. Marking %d remaining as fatal.',
                          MAX_RUNS, len(pending))
            for _expath, _out in pending:
                logging.error('  FATAL: %s', os.path.basename(_out))
            fatal.extend(pending)
            pending = []
            break

        logging.info('Run %d: submitting %d pairs to pool.', run, len(pending))
        pool = Pool(processes=nw)
        results = pool.map(run_pair_via_propy, pending)
        pool.close()
        pool.join()

        pending = []
        for rc, label, expath, output_raster, out, err in results:
            logging.info('[%s] return code = %d', label, rc)
            if out:
                logging.info('[%s] stdout:\n%s', label, out)
            if err:
                logging.info('[%s] stderr:\n%s', label, err)
            if rc == 0:
                pass  # success
            elif rc == 998:
                logging.error('[%s] TIMEOUT -- marking as fatal, will not retry.', label)
                fatal.append((expath, output_raster))
            else:
                logging.warning('[%s] FAILED (rc=%d) -- will retry.', label, rc)
                pending.append((expath, output_raster))
        run += 1

    elapsed = time.process_time() - t0

    if fatal:
        logging.error('FATAL: %d of %d pairs did not complete:', len(fatal), total)
        for _expath, _out in fatal:
            logging.error('  %s', os.path.basename(_out))
        logging.error('Done with monthly2yearly.py -- ERRORS PRESENT.')
    else:
        logging.info('All %d pairs complete. Took %.1f minutes.', total, elapsed / 60)
        logging.info('Done with monthly2yearly.py.')

# Erase the failmarker created by run_python_particulates.ado.
# Reaching this line means the script completed without an unhandled exception.
# If the script crashed earlier, Python never gets here and the marker remains,
# which tells Stata to halt the pipeline.
try:
    os.remove('failmarker.txt')
except FileNotFoundError:
    pass
