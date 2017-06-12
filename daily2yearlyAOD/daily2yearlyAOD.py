# ---------------------------------------------------------------------------
# daily2monthly.py
# -------- #
# Run time: ~1 hour per year
#
# 
# Description: Create a global raster for each year.
# created: August 10 2016 by la
# ---------------------------------------------------------------------------
# Import system modules
import arcpy, glob, logging, os, shutil, subprocess, sys, time, traceback
from arcpy import env
from arcpy.sa import *
from functools import partial
from multiprocessing import Pool

arcpy.CheckOutExtension("Spatial")
arcpy.env.overwriteOutput = True

#------------define aggregate-----------
def aggregate(satyear, prod):
    
    #Local variables:
    data_aod = "..\\..\\data\\MODIS_AOD"
    
    #Split satyear input into satellite name and year
    if satyear[0]=="A":
        sat="Aqua"
    elif satyear[0]=="T":
        sat="Terra"
    
    year = satyear[1:5]
    print "year is " + year
    print "sat is " + sat
    
    # Set directories:
    in_folder = data_aod + "\\source\\daily"
    out_folder = data_aod + "\\generated\\yearly"
    output_raster=out_folder+"\\"+sat+year+"avg.tif"
    temp_year=data_aod + "\\temp"+"_"+sat+"_"+year
    
    # Set environment settings:
    env.workspace = temp_year
    env.scratchWorkspace=temp_year
    
    # Check out the ArcGIS Spatial Analyst extension license and set overwrite environment:

    try:
        #######################################
        ## Step 1: Aggregate AOD daily files ##
        #######################################
        #Create list with all existing .tifs for the input satellite and year:
        rasters=glob.glob(in_folder+"\\"+prod+"_"+sat+"_"+year+"*tif")
        
        #Concatenate list into a single string to feed into arcpy.RasterToGeodatabase
        inputs=';'.join(rasters)
        
        # Define spatial reference (World Sinusoidal)
        sr = arcpy.SpatialReference(54008) 
        
        #Set up temporary directories
        shutil.rmtree(temp_year,ignore_errors=True)
        os.mkdir(temp_year)
        
        #Create geodatabase and raster catalog, and move rasters in list to said catalog.
        arcpy.CreateFileGDB_management(temp_year, year, "CURRENT")
        arcpy.CreateRasterCatalog_management(temp_year+"\\" +year + ".gdb" , "catalog", sr, sr, "", "0", "0", "0", "UNMANAGED", "")
        arcpy.RasterToGeodatabase_conversion(inputs, temp_year+"\\" +year + ".gdb\\catalog")
        arcpy.CalculateDefaultGridIndex_management(temp_year+"\\" +year + ".gdb\\catalog")
        
        #Aggregate rasters in catalog to mean raster
        arcpy.RasterCatalogToRasterDataset_management(temp_year+"\\" +year + ".gdb\\catalog", output_raster, "", "MEAN", "FIRST", "", "NONE", "16_BIT_SIGNED", "NONE", "NONE", "", "") 
        
        #Remove temporary directories
        shutil.rmtree(temp_year,ignore_errors=True)
        
        print inputs
        
    except Exception as e:
        # If an error occurred, print line number and error message
        tb = sys.exc_info()[2]
        print "An error occured on line %i" % tb.tb_lineno
        print str(e)
#----------- end define aggregate--------

if __name__=='__main__':
    
    #Set up logging
    logging.basicConfig(format='%(asctime)s %(message)s', filename='daily2yearlyAOD.log', filemode='w', level=logging.DEBUG)
    logging.info('Starting daily2yearlyAOD.py.')
    #Set up directories for output:
    shutil.rmtree("..\\..\\data\\MODIS_AOD\\generated\\yearly", ignore_errors=True)
    os.mkdir("..\\..\\data\\MODIS_AOD\\generated\\yearly")
    
    #Declare start and end year:
    startyear=2000
    endyear=2014
    
    #Define satellite prefix list and year list:
    #sats=["A", "T"]

    sats=["T"]
    
    years=[str(year) for year in range(startyear,endyear+1)]
    
    #Set number of workers:
    nw=15
    print years
    
    #Create list of satellite years to process:            
    satyears=[sat+year for sat in sats for year in years]
    print satyears
    
    #Set up pooling:
    partialaggregate=partial(aggregate,prod="3K")
    pool=Pool(processes=nw)
    
    #Process all satellite years through partialaggregate.py
    t0=time.clock()    
    results=pool.map(partialaggregate, satyears)
    t1=time.clock()    
    
    #Clean up pooling
    pool.close
    pool.join
    
    print "All year x satellite took " + str((t1-t0)/60) + " minutes." 
    logging.info('Program took %s minutes for %s satelliteXyears.', str((t1-t0)/60) , str(len(satyears)))
    logging.info('Done with daily2yearlyAOD.py.')