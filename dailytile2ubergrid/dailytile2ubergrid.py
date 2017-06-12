# ---------------------------------------------------------------------------
# daily2monthly.py
# -------- #
# Run time: ~1 hour per year
#
# 
# Description: This script converts the output of hdf2tif.py to global 1k
#rasters of data and fire counts. 
# created: April 9 2016 by la
# last modified: April 16 2016 by la
# ---------------------------------------------------------------------------

# Import arcpy module
import arcpy, glob, os, shutil, time, sys, logging
from functools import partial
from multiprocessing import Pool

# Check out any necessary licenses
arcpy.CheckOutExtension("spatial")

#Write function that gets tile numbers from set of files
def BandTIFtilename(inputfile):
    #D049_Y2000_H00_V08_B1
    namevars= os.path.basename(inputfile)
    print str(namevars)
    year=namevars[6:10]
    H=namevars[12:14]
    V=namevars[16:18]
    
    return H+V

def daily2yearlytile(HV,year,inputfolder,outfolder):
    """"""
    #Must define HV and year
    H=HV[0:2]
    V=HV[2:4]
    tile="_H"+H+"_V"+V
    print "Tile value is " + tile
    
    # Local variables:
    #Source tif folder
    
    tempfolder=outfolder+"\\temp"+tile
    
    shutil.rmtree(tempfolder, ignore_errors=True)
    os.mkdir(tempfolder)
    
    #Get list of tifs in tile position HV
    daylist=glob.glob(inputfolder+"\\*"+tile+"*.tif")
    print daylist
    
    outfirelist=[]
    outdatalist=[]
    
    t0=time.clock()
    for day in daylist:
        print "Processing "+ day
        outfilefire=tempfolder+"\\Fire"+os.path.basename(day)
        outfiledata=tempfolder+"\\Data"+os.path.basename(day)
        remapfires = "S:\\particulates\\data_processing\\dofiles\\dailytile2ubergrid\\remapfiresv2"
        remapdata = "S:\\particulates\\data_processing\\dofiles\\dailytile2ubergrid\\remapdatav2"

        # Process: Reclass by Table
        arcpy.gp.ReclassByTable_sa(day, remapfires, "FROM", "TO", "OUT", outfilefire, "NODATA")
        arcpy.gp.ReclassByTable_sa(day, remapdata, "FROM", "TO", "OUT", outfiledata, "NODATA")
        outfirelist.append(outfilefire)
        outdatalist.append(outfiledata)
        
    #Concatenate list into a single string to feed into arcpy.RasterToGeodatabase
    inputsfire=';'.join(outfirelist)
    inputsdata=';'.join(outdatalist)
    
    # Define spatial reference (World Sinusoidal)
    projection="S:\\particulates\\data_processing\\data\\projections\\WGS 1984.prj"
    sr = arcpy.SpatialReference(projection) 
    
    #Set up temporary directories
    outrasterfire=outfolder+"\\"+tile+"Fire.tif"
    outrasterdata=outfolder+"\\"+tile+"Data.tif"
    firegdb=tile+"Fire"
    datagdb=tile+"Data"
    
    #Create geodatabase and raster catalog, and move rasters in list to said catalog.
    for gdb in [firegdb,  datagdb]:
        
        if gdb==firegdb:
            inputs=inputsfire
            output_raster=outrasterfire
        if gdb==datagdb:
            inputs=inputsdata
            output_raster=outrasterdata
        
        arcpy.CreateFileGDB_management(tempfolder, gdb , "CURRENT")
        arcpy.CreateRasterCatalog_management(tempfolder+"\\" +gdb + ".gdb" , "catalog", sr, sr, "", "0", "0", "0", "UNMANAGED", "")
        arcpy.RasterToGeodatabase_conversion(inputs, tempfolder+"\\" +gdb + ".gdb\\catalog")
        arcpy.CalculateDefaultGridIndex_management(tempfolder+"\\" +gdb + ".gdb\\catalog")
        
        #Aggregate rasters in catalog to mean raster
        if os.path.exists(output_raster):
            os.remove(output_raster)    
        arcpy.RasterCatalogToRasterDataset_management(tempfolder+"\\" +gdb + ".gdb\\catalog", output_raster, "", "SUM", "FIRST", "", "NONE", "16_BIT_UNSIGNED", "NONE", "NONE", "", "") 
    
    t1=time.clock()
    print "Tile " + tile + " "+year+" took "+str((t1-t0)/60)+" minutes to process"    
    shutil.rmtree(tempfolder, ignore_errors=True)

if __name__=='__main__':  
    
    #Set up logging
    logging.basicConfig(format='%(asctime)s %(message)s', filename='dailytile2ubergrid.log', filemode='w', level=logging.DEBUG)
    logging.info('Starting dailytile2ubergrid.py.')
    
    yearstart=2000
    yearend=2015
    
    years=[str(year) for year in range(yearstart,yearend+1)]
    
    for year in years:
                    
        intiles="S:\\particulates\\data_processing\\data\\MODIS_FIRE\\source\\daily\\"+year+"\\*B*.tif"
        inputfolder="S:\\particulates\\data_processing\\data\\MODIS_FIRE\\source\\daily\\"+year
        outfolder="S:\\particulates\\data_processing\\data\\MODIS_FIRE\\generated\\yearly\\"+year    
        
        shutil.rmtree(outfolder, ignore_errors=True)
        os.mkdir(outfolder)
        
        #Get list of all tiles in folder
        filelist= glob.glob(intiles)
        
        #Using a set instead of a list to remove duplicates    
        HVs={BandTIFtilename(filename) for filename in filelist }
        HVs=list(HVs)
        
        nw=25
        
        logging.info('Aggregating daily tiles into yearly tiles in %s' , str(year))        
        t0=time.clock()
        partialdaily2yearlytile=partial(daily2yearlytile,year=year,inputfolder=inputfolder,outfolder=outfolder)
        pool=Pool(processes=nw)
        results=pool.map(partialdaily2yearlytile, HVs)
        
        #Clean up pooling
        t1=time.clock()
        pool.close
        pool.join
    
        logging.info('Done adding tiles over time.')        
        logging.info('Year %s took %s minutes.' , str(year), str((t1-t0)/60))        
        
        #Mosaic all rasters of the same type together.
        logging.info('Mosaicking tiles from %s  .' , str(year))        
        
        tempyear=outfolder+"\\temp"+year
        #gdb="alltiles"+year
        inputsfire=glob.glob("S:\\particulates\\data_processing\\data\\MODIS_FIRE\\generated\\yearly\\"+year+"\\*Fire.tif")
        outrasterfire="S:\\particulates\\data_processing\\data\\MODIS_FIRE\\generated\\yearly\\1k\\Fire"+year+".tif"
        
        inputsdata=glob.glob("S:\\particulates\\data_processing\\data\\MODIS_FIRE\\generated\\yearly\\"+year+"\\*Data.tif")
        outrasterdata="S:\\particulates\\data_processing\\data\\MODIS_FIRE\\generated\\yearly\\1k\\Data"+year+".tif"
        
        # Define spatial reference (WGS 1984)
        projection="S:\\particulates\\data_processing\\data\\projections\\WGS 1984.prj"
        sr = arcpy.SpatialReference(projection)
        
        firegdb="Fire"+year+"GDB"
        datagdb="Data"+year+"GDB"
        
        os.mkdir(tempyear)
        
        for gdb in [firegdb,  datagdb]:
        
            if gdb==firegdb:
                inputs=inputsfire
                output_raster=outrasterfire
                
            if gdb==datagdb:
                inputs=inputsdata
                output_raster=outrasterdata
        
            arcpy.CreateFileGDB_management(tempyear, gdb , "CURRENT")
            arcpy.CreateRasterCatalog_management(tempyear+"\\" +gdb + ".gdb" , "catalog", sr, sr, "", "0", "0", "0", "UNMANAGED", "")
            arcpy.RasterToGeodatabase_conversion(inputs, tempyear+"\\" +gdb + ".gdb\\catalog")
            arcpy.CalculateDefaultGridIndex_management(tempyear+"\\" +gdb + ".gdb\\catalog")
            
            #Aggregate rasters in catalog to sum raster
            if os.path.exists(output_raster):
                os.remove(output_raster)

            arcpy.RasterCatalogToRasterDataset_management(tempyear+"\\" +gdb + ".gdb\\catalog", output_raster, "", "SUM", "FIRST", "", "NONE", "16_BIT_UNSIGNED", "NONE", "NONE", "", "") 
            arcpy.DefineProjection_management (output_raster, projection)
            
        shutil.rmtree(tempyear, ignore_errors=True)
        shutil.rmtree(outfolder, ignore_errors=True)

        logging.info('Year %s took %s minutes.' , str(year), str((t1-t0)/60))        
        
    logging.info('Done with dailytile2ubergrid.py')
    