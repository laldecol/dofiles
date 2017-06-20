# ---------------------------------------------------------------------------
# ftp2rasterLULC.py
# -------- #
# Run time: ~1 hour per year
#
# Description: Processes land use data for the particulates project. Steps:
# 1. Download tiles from the UMD ftp server
# 2. Mosaic tiles into yearly 500 m rasters
# 3. Reclassify raster values into our categories (water, trees, pasture, barren, crop, urban, other)
# 4. Convert to dummy rasters (one for each category)
# 5. Add up cells (k-by-k) to approximate ubergrid

# last modified: June 16, 2017 by Lorenzo
# ---------------------------------------------------------------------------
#Append dofiles\mylibrary to sys.path, to use programs defined there.
sys.path.append(os.path.abspath('..'))
#ftp2disk, aggregate defined in mylibrary
import ftplib, gzip, glob, os, sys, shutil, logging, time, arcpy, math, mylibrary

# Check Spatial Analysis Tool
arcpy.CheckOutExtension("spatial")

if __name__=='__main__':
    #Set up logging
    logging.basicConfig(format='%(asctime)s %(message)s', filename='ftp2raster.log', filemode='w', level=logging.DEBUG)
    logging.info('Starting ftp2raster.py.')
    
    #Definitions:
    #Local folder to keep source tiles while they are processed
    localfolder='..\\..\\..\\data\\MODIS_LULC\\source\\tiles'
    #Server address with source tiles
    ftpaddress='ftp.glcf.umd.edu'
    
    #Set of years we want to process
    years=[str(year) for year in range(2012,2013)]
    
    
    for year in years:
    ###1. Download files
        #logging.info('Downloading land cover tiles from %s' , str(year))        
        
        #shutil.rmtree(localfolder, ignore_errors=True)
        #os.mkdir(localfolder)
        
        ##Declare path within server that we want to search in 
        #yearpath='glcf/Global_LNDCVR/UMD_TILES/Version_5.1/'+year+'.01.01'
    
        ##Only files with this name pattern will be downloaded
        #pattern='.tif.gz'
        
        ##Connect to ftp server once to get list of all files in the desired path
        #ftp=ftplib.FTP(ftpaddress)
        #ftp.login()
        #ftp.cwd(yearpath)
        #dirlist=ftp.nlst()
        #ftp.quit()
        
        ##Final list of paths to feed into ftp2disk
        #pathlist=[yearpath+"/"+dirname for dirname in dirlist if '.jpg' not in dirname]
        #print pathlist
        
        ##Download compressed tiles into local folder
        #for serverpath in pathlist:
            #mylibrary.ftp2disk(ftpaddress, serverpath, localfolder, pattern)
            
        ##Extract tiles at the same location
        #for infilename in glob.glob(localfolder+"\\*.gz"):
            
            #outfilename=os.path.splitext(infilename)[0]
            #inF = gzip.open(infilename, 'rb')
            #outF = open(outfilename, 'wb')
            #outF.write( inF.read() )
            
            #inF.close()
            #outF.close()
        
        ###Mosaic all tiles of a given year
        ##Inputs to our aggregate function. All rasters matching the path pattern will be aggregated (mean) and saved as output_raster
        #expath="..\\..\\..\\data\\MODIS_LULC\\source\\tiles\\*"+year+"*.tif"
        output_raster="..\\..\\..\\data\\MODIS_LULC\\generated\\yearly\\"+year+".tif"

        #logging.info('Aggregating tiles from %s' , str(year))
        
        ##Aggregate rasters and clean up
        #mylibrary.aggregate(expath , output_raster)
        #shutil.rmtree(localfolder)

        ##Reclass
    
        #First, reclass into our main categories, as detailed in S:\particulates\data_processing\dofiles\ftp2rasterLULC\LULC_classes.xlsx
        temp_folder=os.path.dirname(output_raster)+"\\temp"+year
        reclass_tif=temp_folder+"\\reclassed_"+year+".tif"
        
        os.mkdir(temp_folder)
        logging.info('Reclassifying raster into our six categories.')
        arcpy.gp.Reclassify_sa(output_raster, "Value", "0 0;1 6 1;7 2;8 1;8 11 2;12 4;13 5;14 4;15 6;16 3;16 255 6", reclass_tif, "DATA")

        settingsdict=mylibrary.ubergridsettings()
        ubercol=settingsdict["COLUMNCOUNT"]
        uberrow=settingsdict["ROWCOUNT"]
        
        #Second, reclass into separate dummy rasters
        for dummyval in range(0,7):
            logging.info('Creating dummy raster for value %s', str(dummyval))
            
            valtxt=temp_folder+"\\val"+str(dummyval)+".txt"
            dummytif=temp_folder+"\\dummy"+str(dummyval)+".tif"
            
            mylibrary.dummyascii(0, 6, dummyval, valtxt)
            arcpy.gp.ReclassByASCIIFile_sa(reclass_tif, valtxt, dummytif, "DATA")
            
            ##Convert to a coarser sum raster for each class        
            desc=arcpy.Describe(dummytif)
            inputrow=desc.height
            inputcol=desc.width
            
            rowfactor=math.floor(int(inputrow)/int(uberrow))
            colfactor=math.floor(int(inputcol)/int(ubercol))
            
            print str(rowfactor), str(colfactor)
            
            #use aggregate_sa to get an output
            aggtif=temp_folder+"\\agg"+str(dummyval)+".tif"
            logging.info('Aggregating dummy raster by a factor of %s', str(colfactor))            
            arcpy.gp.Aggregate_sa(dummytif, aggtif, colfactor, "SUM", "EXPAND", "DATA")
            
            #Convert to ubergrid
            extent = "..\\..\\..\\data\\GPW4\\generated\\extent\\extent.shp"
            outprojection = "..\\..\\..\\data\\projections\\WGS 1984.prj"    
            
            logging.info('Converting aggregated dummy raster to ubergrid')            
            ubergridtif=os.path.dirname(output_raster)+"\\ubergrid\\"+year+"_dummy"+str(dummyval)+".tif"
            mylibrary.raster2ubergrid(aggtif, ubergridtif, extent, outprojection) 
        
        logging.info('Cleaning up year %s', year)            
        shutil.rmtree(temp_folder, ignore_errors=True)
        
    logging.info('Done with ftp2raster.py')
