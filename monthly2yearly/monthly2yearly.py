# ---------------------------------------------------------------------------
# monthly2yearly.py
# -------- #
# Run time: ~20 seconds per year
#
# Description: Create a global raster for each satellite year, from monthly
# fires data. 
# created: Dec 11 2016 by la
# ---------------------------------------------------------------------------
# Import system modules

import arcpy, glob, logging, os, shutil, subprocess, sys, time, traceback
from arcpy import env
from arcpy.sa import *
from functools import partial
from multiprocessing import Pool

arcpy.CheckOutExtension("Spatial")
arcpy.env.overwriteOutput = True

#Append dofiles\functions to sys.path, to use programs defined there.
sys.path.append(os.path.abspath('..\mylibrary'))

#aggregate defined in rasters.py
import rasters

if __name__=='__main__':
    
    #Set up logging
    logging.basicConfig(format='%(asctime)s %(message)s', filename='monthly2yearly.log', filemode='w', level=logging.DEBUG)
    logging.info('Starting monthly2yearly.py.')
    #Set up directories for output:
    
    #Declare start and end year:
    startyear=2000
    endyear=2014
    yearno=endyear-startyear
    print yearno
    #Define satellite prefix list and year list:
    #sats=["A", "T"]
    sats=["T"]
    
    out_folder_cru="..\\..\\..\\data\\CRU\\generated\\yearly"
    in_folder_cru="..\\..\\..\\data\\CRU\\generated\\monthlies"
    
    dtypes=["cld", "dtr","frs","pet","pre","tmn","tmp", "tmx", "vap", "wet"]
    
    shutil.rmtree(out_folder_cru, ignore_errors=True)
    os.mkdir(out_folder_cru)
    #Generate all expansion paths and output names to feed into aggregate. One per year and data type pair.
    expaths_cru=[[in_folder_cru+"\\"+dtype+"*"+str(year)+"*.tif", out_folder_cru+"\\"+dtype+str(year)+".tif" ] for year in range(startyear,endyear+1) for dtype in dtypes]
    
    t0=time.clock()    
    
    for index in range(len(expaths_cru)):
        rasters.aggregate(expaths_cru[index][0], expaths_cru[index][1])
    t1=time.clock()    

    ##Set number of workers:
    #nw=8
    #print years
    
    #Create list of satellite years to process:            
    
    ##Set up pooling:
    #partialaggregate=partial(aggregate,prod="3K")
    #pool=Pool(processes=nw)
    
    ##Process all satellite years through partialaggregate.py
    #results=pool.map(partialaggregate, satyears)
    #t1=time.clock()    
    
    ##Clean up pooling
    #pool.close
    #pool.join
    
    #print "All year x satellite took " + str((t1-t0)/60) + " minutes." 
    logging.info('Program took %s minutes.', str((t1-t0)/60) )
    logging.info('Done with monthly2yearly.py.')