# ---------------------------------------------------------------------------
# monthly2yearly.py
# -------- #
# Run time: ~20 seconds per year
#
# Description: Create a global raster for each satellite year, from monthly
# fires data.
# created: Dec 11 2016 by la
# Updated 2026-07-06: Python 2->3 syntax fixes (print, time.clock->time.process_time);
#   added failmarker cleanup for run_python_particulates.
# ---------------------------------------------------------------------------
# Import system modules

import arcpy, glob, logging, os, shutil, subprocess, sys, time, traceback
from arcpy import env
from arcpy.sa import *
from functools import partial
from multiprocessing import Pool

# Check out the ArcGIS Spatial Analyst extension license and set overwrite environment:
arcpy.CheckOutExtension("Spatial")
arcpy.env.overwriteOutput = True

#------------define aggregate-----------
def timeaggregate(expath, output_raster):
    # 2026-07-06: Replaced RasterCatalog workflow (removed in ArcGIS Pro 3.x)
    # with MosaicToNewRaster using MEAN mosaic method.
    try:
        rasters = glob.glob(expath)
        print(str(expath))
        print(rasters)

        if not rasters:
            print("No rasters found for pattern -- skipping: " + str(expath))
            return

        inputs = ';'.join(rasters)
        print(inputs)

        # Per-cell mean across all monthly rasters, ignoring NoData.
        # 2026-07-07: Replaced MosaicToNewRaster with CellStatistics (same fix as
        # daily2yearlyAOD_worker.py -- MosaicToNewRaster is wrong for time-averaging).
        mean_raster = CellStatistics(rasters, "MEAN", "DATA")
        mean_raster.save(output_raster)

        print(inputs)

    except Exception as e:
        tb = sys.exc_info()[2]
        print("An error occured on line %i" % tb.tb_lineno)
        print(str(e))
#----------- end define aggregate--------

if __name__=='__main__':

    #Set up logging
    logging.basicConfig(format='%(asctime)s %(message)s', filename='monthly2yearlyFIRE.log', filemode='w', level=logging.DEBUG)
    logging.info('Starting monthly2yearlyFIRE.py.')
    #Set up directories for output:

    #Declare start and end year:
    startyear=2000
    endyear=2014
    yearno=endyear-startyear
    print(yearno)
    #Define satellite prefix list and year list:
    #sats=["A", "T"]
    sats=["T"]

    out_folder_cru="..\\..\\..\\data\\CRU\\generated\\yearly"
    in_folder_cru="..\\..\\..\\data\\CRU\\generated\\monthlies"

    dtypes=["cld", "dtr","frs","pet","tmn","tmp", "tmx", "vap", "wet"]

    shutil.rmtree(out_folder_cru, ignore_errors=True)
    os.mkdir(out_folder_cru)
    #Generate all expansion paths and output names to feed into timeaggregate. One per year and data type pair.
    expaths_cru=[[in_folder_cru+"\\"+dtype+"*"+str(year)+"*.tif", out_folder_cru+"\\"+dtype+str(year)+".tif" ] for year in range(startyear,endyear+1) for dtype in dtypes]

    t0=time.process_time()

    for index in range(len(expaths_cru)):
        timeaggregate(expaths_cru[index][0], expaths_cru[index][1])
    t1=time.process_time()

    ##Set number of workers:
    #nw=8
    #print years

    #Create list of satellite years to process:

    ##Set up pooling:
    #partialaggregate=partial(aggregate,prod="3K")
    #pool=Pool(processes=nw)

    ##Process all satellite years through partialaggregate.py
    #results=pool.map(partialaggregate, satyears)
    #t1=time.process_time()

    ##Clean up pooling
    #pool.close()
    #pool.join()

    #print "All year x satellite took " + str((t1-t0)/60) + " minutes."
    logging.info('Program took %s minutes.', str((t1-t0)/60) )
    logging.info('Done with monthly2yearlyFIRE.py.')

# Erase the failmarker created by run_python_particulates.ado.
try:
    os.remove('failmarker.txt')
except FileNotFoundError:
    pass
