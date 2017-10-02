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

# Check out the ArcGIS Spatial Analyst extension license and set overwrite environment:
arcpy.CheckOutExtension("Spatial")
arcpy.env.overwriteOutput = True

#------------define aggregate-----------
def timeaggregate(expath,output_raster):
    
    temp=os.path.dirname(expath)+"temp"
    gdb=temp+"\\geodatabase.gdb"
    env.workspace = temp
    env.scratchWorkspace=temp

    try:
        #######################################
        ## Step 1: Aggregate AOD daily files ##
        #######################################
        #Create list with all existing .tifs for the input satellite and year:
        cwdir=os.getcwd()
        print cwdir
        rasters=glob.glob(expath)
        print str(expath)
        print rasters
        
        #Concatenate list into a single string to feed into arcpy.RasterToGeodatabase
        inputs=';'.join(rasters)
        print inputs
        
        # Define spatial reference (World Sinusoidal)
        sr = arcpy.SpatialReference("..\\..\\..\\data\\projections\\WGS 1984.prj") 
        
        #Set up temporary directories
        shutil.rmtree(temp,ignore_errors=True)
        os.mkdir(temp)
        
        #Create geodatabase and raster catalog, and move rasters in list to said catalog.
        arcpy.CreateFileGDB_management(temp, "geodatabase", "CURRENT")
        arcpy.CreateRasterCatalog_management(gdb , "catalog", sr, sr, "", "0", "0", "0", "UNMANAGED", "")
        arcpy.RasterToGeodatabase_conversion(inputs, gdb+ "\\catalog")
        arcpy.CalculateDefaultGridIndex_management(gdb+ "\\catalog")
        
        #Aggregate rasters in catalog to mean raster
        arcpy.RasterCatalogToRasterDataset_management(gdb+"\\catalog", output_raster, "", "MEAN", "FIRST", "", "NONE", "16_BIT_SIGNED", "NONE", "NONE", "", "") 
        
        #Remove temporary directories
        shutil.rmtree(temp,ignore_errors=True)
        
        print inputs
        
    except Exception as e:
        # If an error occurred, print line number and error message
        tb = sys.exc_info()[2]
        print "An error occured on line %i" % tb.tb_lineno
        print str(e)
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
    print yearno
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
    
    t0=time.clock()    
    
    for index in range(len(expaths_cru)):
        timeaggregate(expaths_cru[index][0], expaths_cru[index][1])
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
    logging.info('Done with monthly2yearlyFIRE.py.')