# ---------------------------------------------------------------------------
# gridhdf2tif.py  [ORCHESTRATOR -- does NOT import arcpy]
#
# Updated from gridhdf2tif.py to py3 / ArcGIS Pro 3.1 on 2026-07-17.
# Main changes in this version:
#   - HEGtool (hegtool.exe / resample.exe) replaced entirely with pure arcpy:
#     ExtractSubDataset + ExtractBand + ProjectRaster in the worker script.
#   - Pool workers now launch propy.bat subprocesses (same pattern as
#     daily2yearlyAOD.py) so each worker checks out its own ArcGIS Pro license.
#   - Pool capped at 8 workers (ArcGIS Pro license constraint).
#   - Python 2 -> 3 syntax throughout.
#   - Source HDF files are NO LONGER DELETED after processing (source/ is
#     read-only per project convention; deletion was a bug in the old version).
#   - Failmarker cleanup added for run_python_particulates.ado.
# Previous version saved in _old/gridhdf2tif.py.
#
# Requires (inputs from earlier stages):
#   - data/MODIS_FIRE/source/tiles/<year>/*.hdf  (MODIS MOD14A1 daily tiles)
#
# Produces (outputs for later stages):
#   - data/MODIS_FIRE/generated/daily/<year>/*.tif  (per-band GeoTIFFs, WGS84)
#
# ---------------------------------------------------------------------------

import glob, logging, os, shutil, subprocess, sys, time
from functools import partial
from multiprocessing import Pool

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

PROPY_BAT = r"C:\Program Files\ArcGIS\Pro\bin\Python\scripts\propy.bat"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
WORKER_SCRIPT = os.path.join(SCRIPT_DIR, "gridhdf2tif_worker.py")

# Seconds before a worker is declared timed-out and marked fatal (not retried).
# Allow 10 min per tile: extraction + per-band reproject of an 8-band 1km tile.
WORKER_TIMEOUT = 600

# Max attempts before a failing tile is marked permanently failed.
MAX_RUNS = 2

# Number of concurrent propy.bat workers (ArcGIS Pro license constraint).
NW = 8

# Year range to process.
START_YEAR = 2000
END_YEAR   = 2015


# ---------------------------------------------------------------------------
# Worker launcher (runs inside multiprocessing.Pool, must not import arcpy)
# ---------------------------------------------------------------------------

def run_hdf_via_propy(outfolder, hdfpath):
    """
    Launch one propy.bat worker process for a single HDF tile.
    Returns [returncode, hdfpath, stdout_text, stderr_text].
    """
    cmd = [PROPY_BAT, WORKER_SCRIPT, hdfpath, outfolder]
    try:
        env = os.environ.copy()
        env.pop("PYTHONHOME", None)   # prevent ArcGIS Pro python from picking
        env["PYTHONNOUSERSITE"] = "1" # up the wrong site-packages
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
        return [p.returncode, hdfpath, p.stdout, p.stderr]
    except subprocess.TimeoutExpired:
        return [998, hdfpath, "",
                "TIMEOUT: worker exceeded %ds" % WORKER_TIMEOUT]
    except Exception as e:
        return [999, hdfpath, "",
                "Exception launching subprocess: %r" % e]


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if __name__ == '__main__':

    logging.basicConfig(
        format='%(asctime)s %(message)s',
        filename='gridhdf2tif.log',
        filemode='w',
        level=logging.DEBUG
    )
    logging.info('Starting gridhdf2tif.py.')

    # Verify propy.bat exists before doing any work.
    if not os.path.isfile(PROPY_BAT):
        logging.error('FATAL: propy.bat not found at %s', PROPY_BAT)
        sys.exit(1)

    # Clean temp/ so worker logs and scratch dirs from prior runs do not confuse
    # diagnosis. Workers recreate temp/ themselves on startup.
    temp_dir = os.path.join(SCRIPT_DIR, "temp")
    shutil.rmtree(temp_dir, ignore_errors=True)
    os.makedirs(temp_dir, exist_ok=True)
    logging.info('Cleaned temp/ directory.')

    years = [str(y) for y in range(START_YEAR, END_YEAR + 1)]
    t0 = time.process_time()

    total_hdfs = 0
    all_failed = []   # hdfpath strings that never succeeded across all years

    for year in years:
        logging.info('--- Year %s ---', year)

        # Build absolute paths so relative-path behaviour is unambiguous when
        # paths are passed as arguments to the worker subprocess.
        infolder  = os.path.abspath(os.path.join(
            SCRIPT_DIR, '..', '..', '..', 'data',
            'MODIS_FIRE', 'source', 'tiles', year))
        outfolder = os.path.abspath(os.path.join(
            SCRIPT_DIR, '..', '..', '..', 'data',
            'MODIS_FIRE', 'generated', 'daily', year))

        # Build the output folder fresh for this year.
        shutil.rmtree(outfolder, ignore_errors=True)
        os.makedirs(outfolder, exist_ok=True)

        # Collect all HDF tiles for this year.
        hdfs = glob.glob(os.path.join(infolder, '*.hdf'))
        if not hdfs:
            logging.warning('No .hdf files in %s -- skipping year.', infolder)
            continue

        total_hdfs += len(hdfs)
        logging.info('Year %s: %d HDF files found.', year, len(hdfs))

        # Write an audit list of all input HDFs (informational; does NOT delete
        # source files -- source/ folder is read-only per project convention).
        hdflist_path = os.path.join(infolder, year + '_hdflist.txt')
        with open(hdflist_path, 'w') as f:
            for h in hdfs:
                f.write(h + '\n')

        # Run pool workers with retry.
        runner = partial(run_hdf_via_propy, outfolder)
        pending    = list(hdfs)
        year_fatal = []
        run = 1

        while pending:
            if run > MAX_RUNS:
                logging.error(
                    'MAX_RUNS (%d) exceeded for year %s. '
                    'Marking %d tile(s) as permanently failed.',
                    MAX_RUNS, year, len(pending))
                year_fatal.extend(pending)
                pending = []
                break

            logging.info('Year %s, run %d: submitting %d tile(s) to pool.',
                         year, run, len(pending))
            pool = Pool(processes=NW)
            results = pool.map(runner, pending)
            pool.close()
            pool.join()

            pending = []
            for rc, hdfpath, out, err in results:
                name = os.path.basename(hdfpath)
                logging.info('[%s] rc=%d', name, rc)
                if out:
                    logging.info('[%s] stdout:\n%s', name, out)
                if err:
                    logging.info('[%s] stderr:\n%s', name, err)

                if rc == 0:
                    pass   # success
                elif rc == 998:
                    logging.error('[%s] TIMEOUT -- marking as fatal (no retry).',
                                  name)
                    year_fatal.append(hdfpath)
                else:
                    logging.warning('[%s] FAILED (rc=%d) -- will retry.', name, rc)
                    pending.append(hdfpath)
            run += 1

        # Report and quarantine permanently-failed tiles.
        if year_fatal:
            unprocessed = os.path.join(infolder, 'unprocessed')
            os.makedirs(unprocessed, exist_ok=True)
            problem_file = os.path.join(infolder, year + '_problemlist.txt')
            with open(problem_file, 'w') as f:
                for hdfpath in year_fatal:
                    f.write(hdfpath + '\n')
                    try:
                        shutil.copy(hdfpath,
                                    os.path.join(unprocessed,
                                                 os.path.basename(hdfpath)))
                    except Exception as copy_err:
                        logging.warning('Could not copy %s to unprocessed/: %s',
                                        os.path.basename(hdfpath), str(copy_err))
            logging.error(
                'Year %s: %d tile(s) failed permanently: %s',
                year, len(year_fatal),
                ' '.join(os.path.basename(h) for h in year_fatal))
            all_failed.extend(year_fatal)
        else:
            logging.info('Year %s: all tiles processed successfully.', year)

        tif_count = len(glob.glob(os.path.join(outfolder, '*.tif')))
        logging.info('Year %s: %d TIF file(s) written to generated/daily/%s.',
                     year, tif_count, year)

    elapsed = time.process_time() - t0
    logging.info('Total: %d HDF files submitted across all years in %.1f minutes.',
                 total_hdfs, elapsed / 60)

    if all_failed:
        logging.error(
            'FATAL: %d tile(s) failed permanently across all years: %s',
            len(all_failed),
            ' '.join(os.path.basename(h) for h in all_failed))
        logging.info('Done with gridhdf2tif.py (completed with errors).')
        # Exit non-zero so the failmarker (created by run_python_particulates.ado)
        # is not erased and Stata halts the pipeline.
        sys.exit(1)

    logging.info('Done with gridhdf2tif.py.')

# Erase the failmarker created by run_python_particulates.ado.
# This line is reached only when __main__ exits normally (all tiles succeeded).
# A sys.exit(1) above raises SystemExit, which skips this line and leaves the
# failmarker in place so Stata detects the failure.
try:
    os.remove('failmarker.txt')
except FileNotFoundError:
    pass
