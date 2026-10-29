# ---------------------------------------------------------------------------
# aggregate_wind.py
# Description: Average monthly CCMP wind rasters (uwnd, vwnd; world extent)
# into one yearly mean raster per variable and year, using
# rasters.aggregate() from mylibrary (arcpy.sa.CellStatistics, MEAN).
#   Input:  data/CCMP/generated/monthly/<var>_<year>*.tif
#   Output: data/CCMP/generated/yearly/<var>_<year>.tif
# Run with the ArcGIS Pro Python (propy.bat).
#
# Created Nov 3 2016, by Lorenzo. Last modified June 13 2017, by Marcel.
# Updated 2026-10-28 to py3/ArcGIS Pro:
#   - Old header (n x n block aggregation, cellFactor) described another
#     script; replaced.
#   - Removed the hard-coded os.chdir to S:\; paths are built from this
#     file's location, so the script runs from any working directory.
#   - Checks out Spatial Analyst, which CellStatistics needs.
#   - numpy.linspace years replaced by range(); numpy no longer needed.
#   - Years with fewer than 12 monthly rasters are averaged over the months
#     available; years with none are skipped. Both are logged, and the loop
#     never stops: partial, missing and failed rasters are listed at the end.
#   - If a year fails, each monthly raster is checked; unreadable ones (e.g.
#     empty or truncated .tifs) are dropped and the rest are averaged.
# Previous version saved in _old/aggregate_wind.py.
# ---------------------------------------------------------------------------

import glob, logging, os, shutil, sys, time

import arcpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.join(HERE, '..', 'mylibrary'))
import rasters

arcpy.env.overwriteOutput = True
arcpy.CheckOutExtension("Spatial")

# Variables and years to aggregate.
variables = ['uwnd', 'vwnd']
startyear = 2000
endyear   = 2015

# Input and output folders.
data_dir   = os.path.normpath(os.path.join(HERE, '..', '..', '..', 'data'))
in_folder  = os.path.join(data_dir, 'CCMP', 'generated', 'monthly')
out_folder = os.path.join(data_dir, 'CCMP', 'generated', 'yearly')


def first_line(e):
    # First non-empty line of an exception message (arcpy messages are long).
    lines = [l for l in str(e).splitlines() if l.strip()]
    return lines[0].strip() if lines else repr(e)


def readable(path):
    # Returns (True, '') if arcpy can compute on this raster, else (False, reason).
    # Runs the same operation as the yearly average, on the one file.
    if os.path.getsize(path) == 0:
        return False, 'empty file'
    try:
        r = arcpy.sa.CellStatistics([path], "MEAN", "DATA")
        del r
        return True, ''
    except Exception as e:
        return False, first_line(e)


if __name__ == '__main__':

    # Log to aggregate_wind.log and echo the same lines to the console, so
    # progress is visible in the cmd window while the script runs.
    logging.basicConfig(format='%(asctime)s %(message)s', level=logging.DEBUG,
                        handlers=[logging.FileHandler(os.path.join(HERE, 'aggregate_wind.log'),
                                                      mode='w'),
                                  logging.StreamHandler(sys.stdout)])
    logging.info('Starting aggregate_wind.py.')

    shutil.rmtree(out_folder, ignore_errors=True)
    os.makedirs(out_folder, exist_ok=True)

    t0 = time.perf_counter()
    total = len(variables) * (endyear - startyear + 1)
    k = 0
    written = 0
    partial = {}   # name -> months used, for rasters written from fewer than 12
    missing = []   # no monthly rasters at all: nothing to write
    failed  = []   # arcpy error while aggregating

    for variable in variables:
        for year in range(startyear, endyear + 1):

            k += 1
            inputpattern  = os.path.join(in_folder, '%s_%d*.tif' % (variable, year))
            output_raster = os.path.join(out_folder, '%s_%d.tif' % (variable, year))
            name  = os.path.basename(output_raster)
            label = '%d/%d %s' % (k, total, name)

            n = len(glob.glob(inputpattern))
            if n == 0:
                logging.warning('[%s] MISSING: no monthly rasters match %s -- skipped.',
                                label, inputpattern)
                missing.append(name)
                continue
            if n != 12:
                logging.warning('[%s] PARTIAL: %d monthly rasters found (expected 12); '
                                'averaging the available months.', label, n)
                partial[name] = n

            try:
                rasters.aggregate(inputpattern, output_raster)
                logging.info('[%s] done (%d months).', label, n)
                written += 1
                continue
            except Exception as e:
                partial.pop(name, None)
                logging.warning('[%s] aggregate failed (%s); checking each month.',
                                label, first_line(e))

            # Fallback: find the monthly rasters that cannot be read and average
            # the rest. Same call as rasters.aggregate(), on the readable files.
            good, bad = [], []
            for f in sorted(glob.glob(inputpattern)):
                ok, why = readable(f)
                if ok:
                    good.append(f)
                else:
                    bad.append(f)
                    logging.warning('[%s] UNREADABLE: %s (%s)', label, os.path.basename(f), why)

            if not bad:
                logging.error('[%s] FAILED: every month is readable, so the error is not '
                              'an input file. Rerun this year alone to see the full error.', label)
                failed.append(name)
                continue
            if not good:
                logging.error('[%s] FAILED: no readable monthly rasters.', label)
                failed.append(name)
                continue

            try:
                arcpy.sa.CellStatistics(good, "MEAN", "DATA").save(output_raster)
                logging.warning('[%s] PARTIAL: averaged %d readable months (dropped %d).',
                                label, len(good), len(bad))
                partial[name] = len(good)
                written += 1
            except Exception as e:
                logging.error('[%s] FAILED on readable months: %s', label, first_line(e))
                failed.append(name)

    minutes = (time.perf_counter() - t0) / 60
    arcpy.CheckInExtension("Spatial")

    # Summary of what was and was not written.
    logging.info('Wrote %d of %d rasters. Took %.1f minutes.', written, total, minutes)
    if partial:
        logging.warning('Partial years (months used): %s',
                        ' '.join('%s(%d)' % (k_, v) for k_, v in partial.items()))
    if missing:
        logging.warning('Missing inputs, not written: %s', ' '.join(missing))
    if failed:
        logging.error('Failed in arcpy, not written: %s', ' '.join(failed))
    logging.info('Done with aggregate_wind.py.')

    # If run through run_python_particulates.ado: erase its failmarker so
    # Stata continues. Missing or partial inputs do not stop the pipeline;
    # they are listed in the log above.
    try:
        os.remove('failmarker.txt')
    except FileNotFoundError:
        pass
