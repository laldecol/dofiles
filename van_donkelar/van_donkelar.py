# ---------------------------------------------------------------------------
# van_donkelar.py  [ORCHESTRATOR -- does NOT import arcpy]
# Description: Reproject and snap three annual Van Donkelaar PM2.5 NetCDF
# files to the project uber_grid and save as TIF rasters.
# Spawns van_donkelar_worker.py via propy.bat for each file.
#
# Created 2026-08-31.
#
# Requires (inputs):
#   ../../../data/VanDonkelar_annual/source/V5GL0502.*.nc  (3 annual files)
# Produces (outputs):
#   ../../../data/VanDonkelar_annual/generated/vandonkelar_<year>.tif
# ---------------------------------------------------------------------------

import logging, os, re, shutil, subprocess, sys, time
from multiprocessing import Pool

PROPY_BAT     = r"C:\Program Files\ArcGIS\Pro\bin\Python\scripts\propy.bat"
WORKER_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                             "van_donkelar_worker.py")
WORKER_TIMEOUT = 600   # seconds per file; reprojection of a global 0.05-deg raster
MAX_RUNS       = 2     # one retry on failure; timeouts are fatal, not retried


def run_pair_via_propy(pair):
    # Runs inside a Pool worker. Must NOT import arcpy.
    # Launches a licensed ArcGIS Pro Python process for one (nc_filepath, output_raster) pair.
    nc_filepath, output_raster = pair
    label = os.path.basename(output_raster)
    cmd = [PROPY_BAT, WORKER_SCRIPT, nc_filepath, output_raster]
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
        return [p.returncode, label, nc_filepath, output_raster, p.stdout, p.stderr]
    except subprocess.TimeoutExpired:
        return [998, label, nc_filepath, output_raster, "",
                "TIMEOUT: worker exceeded %ds" % WORKER_TIMEOUT]
    except Exception as e:
        return [999, label, nc_filepath, output_raster, "",
                "Exception launching subprocess: %r" % e]


# Failmarker flag: set True inside __main__ only when ALL files succeed.
# Checked at the bottom (outside __main__) to decide whether to remove
# the marker created by run_python_particulates.ado.
_clean_exit = False


if __name__ == '__main__':

    logging.basicConfig(format='%(asctime)s %(message)s',
                        filename='van_donkelar.log', filemode='w',
                        level=logging.DEBUG)
    logging.info('Starting van_donkelar.py.')

    # Clean temp/ from prior runs; recreate it.
    _temp = os.path.join(os.path.dirname(os.path.abspath(__file__)), "temp")
    shutil.rmtree(_temp, ignore_errors=True)
    os.makedirs(_temp, exist_ok=True)
    logging.info('Cleaned temp/ directory.')

    source_dir    = "../../../data/VanDonkelar_annual/source"
    generated_dir = "../../../data/VanDonkelar_annual/generated"
    os.makedirs(generated_dir, exist_ok=True)
    logging.info('Output folder: %s', generated_dir)

    # Check source directory exists before doing anything.
    if not os.path.isdir(source_dir):
        logging.error('FATAL: source directory not found: %s', source_dir)
        sys.exit(1)

    # Build list of (nc_filepath, output_raster) pairs from source .nc files.
    # Year is the first 4 digits of the date range in the filename,
    # e.g. "...Global.200401-200412.nc" -> year "2004".
    nc_files = sorted(f for f in os.listdir(source_dir) if f.endswith('.nc'))
    if not nc_files:
        logging.error('FATAL: no .nc files found in %s', source_dir)
        sys.exit(1)

    pairs = []
    for fname in nc_files:
        m = re.search(r'\.(\d{4})\d{2}-', fname)
        if not m:
            logging.warning('Could not parse year from filename: %s -- skipping', fname)
            continue
        year     = m.group(1)
        nc_path  = source_dir + "/" + fname
        out_path = generated_dir + "/vandonkelar_" + year + ".tif"
        pairs.append((nc_path, out_path))
        logging.info('Queued: %s -> %s', fname, os.path.basename(out_path))

    if not pairs:
        logging.error('FATAL: no valid .nc files to process.')
        sys.exit(1)

    total = len(pairs)
    nw = min(8, total)
    logging.info('Total files to process: %d  Workers: %d', total, nw)
    print("Total files to process: %d" % total)

    t0 = time.process_time()
    run = 1
    pending = list(pairs)
    fatal   = []

    while pending:
        if run > MAX_RUNS:
            logging.error('MAX_RUNS (%d) exceeded. Marking %d remaining as fatal.',
                          MAX_RUNS, len(pending))
            for _nc, _out in pending:
                logging.error('  FATAL: %s', os.path.basename(_out))
            fatal.extend(pending)
            pending = []
            break

        logging.info('Run %d: submitting %d files to pool.', run, len(pending))
        pool = Pool(processes=nw)
        results = pool.map(run_pair_via_propy, pending)
        pool.close()
        pool.join()

        pending = []
        for rc, label, nc_filepath, output_raster, out, err in results:
            logging.info('[%s] return code = %d', label, rc)
            if out:
                logging.info('[%s] stdout:\n%s', label, out)
            if err:
                logging.info('[%s] stderr:\n%s', label, err)
            if rc == 0:
                pass  # success
            elif rc == 998:
                logging.error('[%s] TIMEOUT -- marking as fatal, will not retry.', label)
                fatal.append((nc_filepath, output_raster))
            else:
                logging.warning('[%s] FAILED (rc=%d) -- will retry.', label, rc)
                pending.append((nc_filepath, output_raster))
        run += 1

    elapsed = time.process_time() - t0

    if fatal:
        logging.error('FATAL: %d of %d files did not complete:', len(fatal), total)
        for _nc, _out in fatal:
            logging.error('  %s', os.path.basename(_out))
        logging.error('Done with van_donkelar.py -- ERRORS PRESENT. Failmarker NOT removed.')
    else:
        logging.info('All %d files complete. Took %.1f minutes.', total, elapsed / 60)
        logging.info('Done with van_donkelar.py.')
        _clean_exit = True

# Remove the failmarker created by run_python_particulates.ado ONLY when all
# files completed successfully.  If any workers failed, or if __main__ raised
# an unhandled exception, _clean_exit stays False and the marker remains,
# telling Stata to halt the pipeline.  This is stricter than some other
# orchestrators (which always remove the marker) -- with only 3 required
# files any failure should halt the pipeline.
if _clean_exit:
    try:
        os.remove('failmarker.txt')
    except FileNotFoundError:
        pass
