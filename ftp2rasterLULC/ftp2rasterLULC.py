# ---------------------------------------------------------------------------
# ftp2rasterLULC.py  [ORCHESTRATOR -- does NOT import arcpy]
# Description: Processes land use data. Reclassifies yearly LULC rasters
# into dummy rasters for each land cover category.
# Run time: ~1 hour per year.
#
# Updated from ftp2rasterLULC.py to py3/ArcGIS Pro on 2026-07-06.
# Main changes in this version:
#   - Pool workers now launch propy.bat subprocesses instead of calling arcpy
#     directly. All arcpy work is in ftp2rasterLULC_worker.py.
#   - Pool capped at 8 workers to reduce arcpy license collisions.
#   - Download section remains commented out (data already on disk).
#   - Python 2 syntax updated to Python 3.
# Previous version saved in _old/.
# ---------------------------------------------------------------------------

import logging, os, subprocess, sys, time
from multiprocessing import Pool

# Path to the ArcGIS Pro Python launcher and the worker script.
PROPY_BAT = r"C:\Program Files\ArcGIS\Pro\bin\Python\scripts\propy.bat"
WORKER_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                             "ftp2rasterLULC_worker.py")

WORKER_TIMEOUT = 7200  # seconds; worker killed and marked fatal if exceeded
MAX_RUNS = 3           # 2026-07-07: cap retries so persistent failures don't loop forever

def run_year_via_propy(year):
    # Runs inside a Pool worker. Must NOT import arcpy.
    # Launches a licensed ArcGIS Pro Python process for one year.
    cmd = [PROPY_BAT, WORKER_SCRIPT, str(year)]
    try:
        script_dir = os.path.dirname(os.path.abspath(__file__))
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
        return [p.returncode, year, p.stdout, p.stderr]
    except subprocess.TimeoutExpired:
        return [998, year, "", "TIMEOUT: worker exceeded %ds" % WORKER_TIMEOUT]
    except Exception as e:
        return [999, year, "", f"Exception launching subprocess: {e!r}"]

if __name__ == '__main__':

    logging.basicConfig(format='%(asctime)s %(message)s',
                        filename='ftp2raster.log', filemode='w',
                        level=logging.DEBUG)
    logging.info('Starting ftp2rasterLULC.py.')

    # Set of years we want to process.
    years = [str(year) for year in range(2001, 2013)]

    # Number of Pool workers (capped to reduce arcpy license collisions).
    nw = 8

    t0 = time.process_time()
    run = 1
    pending = list(years)
    fatal = []  # accumulated across all runs

    # Pool workers call propy.bat to run the worker script for each year.
    # Non-zero return codes trigger retries up to MAX_RUNS.
    while pending:
        # Stop retrying after MAX_RUNS attempts; mark survivors as fatal.
        if run > MAX_RUNS:
            logging.error('MAX_RUNS (%d) exceeded. Marking %d remaining as fatal: %s',
                          MAX_RUNS, len(pending), ' '.join(str(y) for y in pending))
            fatal.extend(pending)
            pending = []
            break

        logging.info('Run %d: submitting %d years to pool.', run, len(pending))
        pool = Pool(processes=nw)
        results = pool.map(run_year_via_propy, pending)
        pool.close()
        pool.join()

        pending = []
        for rc, year, out, err in results:
            logging.info('[%s] return code = %d', year, rc)
            if out:
                logging.info('[%s] stdout:\n%s', year, out)
            if err:
                logging.info('[%s] stderr:\n%s', year, err)
            if rc == 0:
                pass  # success
            elif rc == 998:
                logging.error('[%s] TIMEOUT -- marking as fatal, will not retry.', year)
                fatal.append(year)
            else:
                logging.warning('[%s] FAILED -- will retry.', year)
                pending.append(year)
        run += 1

    if fatal:
        logging.error('FATAL: the following years did not complete: %s',
                      ' '.join(str(y) for y in fatal))

    elapsed = time.process_time() - t0
    logging.info('All years complete. Took %s minutes.', str(elapsed / 60))
    logging.info('Done with ftp2rasterLULC.py.')

# Erase the failmarker created by run_python_particulates.ado.
# Reaching this line means the script completed without an unhandled exception.
try:
    os.remove('failmarker.txt')
except FileNotFoundError:
    pass
