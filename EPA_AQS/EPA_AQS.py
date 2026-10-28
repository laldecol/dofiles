# ---------------------------------------------------------------------------
# EPA_AQS.py  [ORCHESTRATOR -- does NOT import arcpy]
# Description: Convert four annual EPA AQS PM2.5 monitor ZIP files to
# uber_grid-aligned rasters.  Each ZIP is unzipped here; the worker does
# pure-Python cell assignment then the final arcpy raster conversion.
# Spawns EPA_AQS_worker.py via propy.bat for each year.
#
# Created 2026-08-31.
#
# Requires (inputs):
#   ../../../data/EPA_AQS/source/annual_conc_by_monitor_YYYY.zip  (4 files)
# Produces (outputs):
#   ../../../data/EPA_AQS/generated/EPA_AQS_PM25_YYYY.tif
# ---------------------------------------------------------------------------

import logging, os, re, shutil, subprocess, sys, time, zipfile
from multiprocessing import Pool

PROPY_BAT     = r"C:\Program Files\ArcGIS\Pro\bin\Python\scripts\propy.bat"
WORKER_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                             "EPA_AQS_worker.py")
WORKER_TIMEOUT = 900   # seconds per year (CSV processing + ASCII write + arcpy)
MAX_RUNS       = 2     # one retry on failure; timeouts are fatal, not retried


def run_pair_via_propy(pair):
    # Runs inside a Pool worker. Must NOT import arcpy.
    # Launches a licensed ArcGIS Pro Python process for one (csv_path, output_raster) pair.
    csv_path, output_raster = pair
    label = os.path.basename(output_raster)
    cmd = [PROPY_BAT, WORKER_SCRIPT, csv_path, output_raster]
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
        return [p.returncode, label, csv_path, output_raster, p.stdout, p.stderr]
    except subprocess.TimeoutExpired:
        return [998, label, csv_path, output_raster, "",
                "TIMEOUT: worker exceeded %ds" % WORKER_TIMEOUT]
    except Exception as e:
        return [999, label, csv_path, output_raster, "",
                "Exception launching subprocess: %r" % e]


# Failmarker flag: set True inside __main__ only when ALL years succeed.
_clean_exit = False


if __name__ == '__main__':

    logging.basicConfig(format='%(asctime)s %(message)s',
                        filename='EPA_AQS.log', filemode='w',
                        level=logging.DEBUG)
    logging.info('Starting EPA_AQS.py.')

    script_dir = os.path.dirname(os.path.abspath(__file__))

    # Clean temp/ from prior runs; recreate it.
    _temp = os.path.join(script_dir, "temp")
    shutil.rmtree(_temp, ignore_errors=True)
    os.makedirs(_temp, exist_ok=True)
    logging.info('Cleaned temp/ directory.')

    source_dir    = "../../../data/EPA_AQS/source"
    generated_dir = "../../../data/EPA_AQS/generated"
    os.makedirs(generated_dir, exist_ok=True)
    logging.info('Output folder: %s', generated_dir)

    # Check source directory exists.
    if not os.path.isdir(source_dir):
        logging.error('FATAL: source directory not found: %s', source_dir)
        sys.exit(1)

    # Unzip each annual ZIP to temp/ and build (csv_path, output_raster) pairs.
    # Year is parsed from the zip filename: annual_conc_by_monitor_YYYY.zip
    zip_files = sorted(f for f in os.listdir(source_dir) if f.endswith('.zip'))
    if not zip_files:
        logging.error('FATAL: no .zip files found in %s', source_dir)
        sys.exit(1)

    pairs = []
    for zname in zip_files:
        m = re.search(r'(\d{4})\.zip$', zname)
        if not m:
            logging.warning('Could not parse year from zip name: %s -- skipping', zname)
            continue
        year     = m.group(1)
        zip_path = os.path.join(source_dir, zname)
        csv_name = "annual_conc_%s.csv" % year
        csv_path = os.path.join(_temp, csv_name)

        logging.info('Unzipping %s -> %s', zname, csv_name)
        with zipfile.ZipFile(zip_path, 'r') as zf:
            # The ZIP may contain one CSV; extract the first .csv found.
            csv_members = [n for n in zf.namelist() if n.lower().endswith('.csv')]
            if not csv_members:
                logging.error('FATAL: no CSV found inside %s', zname)
                sys.exit(1)
            with zf.open(csv_members[0]) as src, open(csv_path, 'wb') as dst:
                shutil.copyfileobj(src, dst)
        logging.info('Extracted %s (%d bytes)', csv_name, os.path.getsize(csv_path))

        out_path = generated_dir + "/EPA_AQS_PM25_" + year + ".tif"
        pairs.append((csv_path, out_path))
        logging.info('Queued: %s -> %s', csv_name, os.path.basename(out_path))

    if not pairs:
        logging.error('FATAL: no valid zip files to process.')
        sys.exit(1)

    total = len(pairs)
    nw = min(8, total)
    logging.info('Total years to process: %d  Workers: %d', total, nw)
    print("Total years to process: %d" % total)

    t0 = time.process_time()
    run = 1
    pending = list(pairs)
    fatal   = []

    while pending:
        if run > MAX_RUNS:
            logging.error('MAX_RUNS (%d) exceeded. Marking %d remaining as fatal.',
                          MAX_RUNS, len(pending))
            for _csv, _out in pending:
                logging.error('  FATAL: %s', os.path.basename(_out))
            fatal.extend(pending)
            pending = []
            break

        logging.info('Run %d: submitting %d years to pool.', run, len(pending))
        pool = Pool(processes=nw)
        results = pool.map(run_pair_via_propy, pending)
        pool.close()
        pool.join()

        pending = []
        for rc, label, csv_path, output_raster, out, err in results:
            logging.info('[%s] return code = %d', label, rc)
            if out:
                logging.info('[%s] stdout:\n%s', label, out)
            if err:
                logging.info('[%s] stderr:\n%s', label, err)
            if rc == 0:
                pass  # success
            elif rc == 998:
                logging.error('[%s] TIMEOUT -- marking as fatal, will not retry.', label)
                fatal.append((csv_path, output_raster))
            else:
                logging.warning('[%s] FAILED (rc=%d) -- will retry.', label, rc)
                pending.append((csv_path, output_raster))
        run += 1

    elapsed = time.process_time() - t0

    if fatal:
        logging.error('FATAL: %d of %d years did not complete:', len(fatal), total)
        for _csv, _out in fatal:
            logging.error('  %s', os.path.basename(_out))
        logging.error('Done with EPA_AQS.py -- ERRORS PRESENT. Failmarker NOT removed.')
    else:
        logging.info('All %d years complete. Took %.1f minutes.', total, elapsed / 60)
        logging.info('Done with EPA_AQS.py.')
        _clean_exit = True

# Remove the failmarker only when all years completed successfully.
if _clean_exit:
    try:
        os.remove('failmarker.txt')
    except FileNotFoundError:
        pass
