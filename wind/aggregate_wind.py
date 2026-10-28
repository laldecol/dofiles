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


if __name__ == '__main__':

    logging.basicConfig(format='%(asctime)s %(message)s',
                        filename=os.path.join(HERE, 'aggregate_wind.log'),
                        filemode='w', level=logging.DEBUG)
    logging.info('Starting aggregate_wind.py.')

    shutil.rmtree(out_folder, ignore_errors=True)
    os.makedirs(out_folder, exist_ok=True)

    t0 = time.perf_counter()
    written = 0
    partial = []   # written from fewer than 12 months
    missing = []   # no monthly rasters at all: nothing to write
    failed  = []   # arcpy error while aggregating

    for variable in variables:
        for year in range(startyear, endyear + 1):

            inputpattern  = os.path.join(in_folder, '%s_%d*.tif' % (variable, year))
            output_raster = os.path.join(out_folder, '%s_%d.tif' % (variable, year))
            label = os.path.basename(output_raster)

            n = len(glob.glob(inputpattern))
            if n == 0:
                logging.warning('[%s] MISSING: no monthly rasters match %s -- skipped.',
                                label, inputpattern)
                missing.append(label)
                continue
            if n != 12:
                logging.warning('[%s] PARTIAL: %d monthly rasters found (expected 12); '
                                'averaging the available months.', label, n)
                partial.append('%s(%d)' % (label, n))

            try:
                rasters.aggregate(inputpattern, output_raster)
                logging.info('[%s] done (%d months).', label, n)
                written += 1
            except Exception as e:
                logging.error('[%s] FAILED: %s', label, e)
                failed.append(label)

    minutes = (time.perf_counter() - t0) / 60
    arcpy.CheckInExtension("Spatial")

    # Summary of what was and was not written.
    total = len(variables) * (endyear - startyear + 1)
    logging.info('Wrote %d of %d rasters. Took %.1f minutes.', written, total, minutes)
    if partial:
        logging.warning('Partial years (months used): %s', ' '.join(partial))
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
