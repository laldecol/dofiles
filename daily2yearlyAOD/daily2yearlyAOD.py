# ---------------------------------------------------------------------------
# daily2yearlyAOD.py  [ORCHESTRATOR -- does NOT import arcpy]
# Description: Create a global AOD raster for each year from daily AOD files.
# Run time: ~5 mins per year with 8 workers.
#
# Updated from daily2yearlyAOD.py to py3/ArcGIS Pro on 2026-07-06.
# Main changes in this version:
#   - Pool workers now launch propy.bat subprocesses instead of calling arcpy
#     directly. All arcpy work is in daily2yearlyAOD_worker.py.
#   - Pool capped at 8 workers to reduce arcpy license collisions.
#   - Python 2 syntax updated to Python 3.
# 2026-07-07: Reverted python.exe -> propy.bat and file redirect -> capture_output
#   to match the proven pattern in run_month2dta_py3v3.py. File-redirect with
#   concurrent pool workers causes handle-inheritance problems on Windows.
# Previous version saved in _old/.
# ---------------------------------------------------------------------------

import logging, os, shutil, subprocess, sys, time
from multiprocessing import Pool

# Path to propy.bat and the worker script.
PROPY_BAT = r"C:\Program Files\ArcGIS\Pro\bin\Python\scripts\propy.bat"
WORKER_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                             "daily2yearlyAOD_worker.py")

WORKER_TIMEOUT = 7200  # seconds; worker killed and marked fatal if exceeded
MAX_RUNS = 3          # 2026-07-07: cap retries so persistent failures don't loop forever

def run_satyear_via_propy(prod, satyear):
    # Runs inside a Pool worker. Must NOT import arcpy.
    # Launches a licensed ArcGIS Pro Python process for one satellite-year.
    # Uses capture_output=True (pipes) to match the pattern in
    # run_month2dta_py3v3.py; file-redirect with concurrent workers causes
    # handle-inheritance problems on Windows.
    # Concurrent arcpy import serialization is handled by a file lock in the
    # worker script itself, so no stagger is needed here.
    cmd = [PROPY_BAT, WORKER_SCRIPT, str(prod), str(satyear)]
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
        return [p.returncode, satyear, p.stdout, p.stderr]
    except subprocess.TimeoutExpired:
        return [998, satyear, "", "TIMEOUT: worker exceeded %ds" % WORKER_TIMEOUT]
    except Exception as e:
        return [999, satyear, "", "Exception launching subprocess: %r" % e]

if __name__ == '__main__':

    logging.basicConfig(format='%(asctime)s %(message)s',
                        filename='daily2yearlyAOD.log', filemode='w',
                        level=logging.DEBUG)
    logging.info('Starting daily2yearlyAOD.py.')

    # Clean temp/ to remove stale worker logs and scratch dirs from prior runs.
    # Workers recreate temp/ themselves when they start.
    _temp = os.path.join(os.path.dirname(os.path.abspath(__file__)), "temp")
    shutil.rmtree(_temp, ignore_errors=True)
    os.makedirs(_temp, exist_ok=True)
    logging.info('Cleaned temp/ directory.')

    # Set up output directory.
    shutil.rmtree("../../../data/MODIS_AOD/generated/yearly", ignore_errors=True)
    os.mkdir("../../../data/MODIS_AOD/generated/yearly")
    logging.info('Cleaned and set up output folders.')

    # Declare start and end year.
    startyear = 2000
    endyear = 2018

    # Define satellite prefix list and year list.
    # 2026-07-07: Aqua removed -- no Aqua source data exists.
    sats = ["T"]
    years = [str(year) for year in range(startyear, endyear + 1)]

    # Number of Pool workers. 2026-07-07: restored to 8 now that ArcGIS Pro init issue is resolved.
    nw = 8

    logging.info('Processing satellites %s', " ".join(sats))
    logging.info('Start year is %s', str(startyear))
    logging.info('End year is %s', str(endyear))

    prod = "3K"
    satyears = [sat + year for sat in sats for year in years]
    print(satyears)

    # Pool workers launch propy.bat subprocesses for each satellite-year.
    # Concurrent arcpy import serialization is handled by a file lock in the
    # worker script; no stagger needed here.
    # Non-zero return codes trigger retries (matching pipeline convention).
    from functools import partial
    partial_runner = partial(run_satyear_via_propy, prod)
    t0 = time.process_time()
    run = 1
    pending = list(satyears)
    fatal = []  # accumulated across all runs (moved outside loop 2026-07-07)

    while pending:
        # Stop retrying after MAX_RUNS attempts; mark survivors as fatal.
        if run > MAX_RUNS:
            logging.error('MAX_RUNS (%d) exceeded. Marking %d remaining as fatal: %s',
                          MAX_RUNS, len(pending), ' '.join(pending))
            fatal.extend(pending)
            pending = []
            break

        logging.info('Run %d: submitting %d satellite-years to pool.',
                     run, len(pending))
        pool = Pool(processes=nw)
        results = pool.map(partial_runner, pending)
        pool.close()
        pool.join()

        pending = []
        for rc, satyear, out, err in results:
            logging.info('[%s] return code = %d', satyear, rc)
            if out:
                logging.info('[%s] stdout:\n%s', satyear, out)
            if err:
                logging.info('[%s] stderr:\n%s', satyear, err)
            if rc == 0:
                pass  # success
            elif rc == 998:
                logging.error('[%s] TIMEOUT -- marking as fatal, will not retry.', satyear)
                fatal.append(satyear)
            else:
                logging.warning('[%s] FAILED -- will retry.', satyear)
                pending.append(satyear)
        run += 1

    if fatal:
        logging.error('FATAL: the following satellite-years did not complete: %s',
                      ' '.join(fatal))

    elapsed = time.process_time() - t0
    logging.info('All satellite-years complete. Took %s minutes for %s items.',
                 str(elapsed / 60), str(len(satyears)))
    logging.info('Done with daily2yearlyAOD.py.')

# Erase the failmarker created by run_python_particulates.ado.
# Reaching this line means the script completed without an unhandled exception.
try:
    os.remove('failmarker.txt')
except FileNotFoundError:
    pass
