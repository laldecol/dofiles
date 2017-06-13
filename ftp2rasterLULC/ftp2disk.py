
import ftplib, gzip, glob, os, sys, shutil, logging, time, arcpy, math
arcpy.CheckOutExtension("spatial")

#Append dofiles\mylibrary to sys.path, to use programs defined there.
sys.path.append(os.path.abspath('..'))

#ftp2disk, aggregate defined in mylibrary
import mylibrary

if __name__=='__main__':
    #Set up logging
    logging.basicConfig(format='%(asctime)s %(message)s', filename='ftp2raster.log', filemode='w', level=logging.DEBUG)
    logging.info('Starting ftp2raster.py.')
    
    #Definitions:
    #Local folder to keep source tiles while they are processed
    localfolder='S:\\particulates\\data_processing\\data\\MODIS_LULC\\source\\tiles'
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
        #expath="S:\\particulates\\data_processing\\data\\MODIS_LULC\\source\\tiles\\*"+year+"*.tif"
        output_raster="S:\\particulates\\data_processing\\data\\MODIS_LULC\\generated\\yearly\\"+year+".tif"

        #logging.info('Aggregating tiles from %s' , str(year))
        
        ##Aggregate rasters and clean up
        #mylibrary.aggregate(expath , output_raster)
        #shutil.rmtree(localfolder)

        ##Reclass
    
        #First, reclass into our main categories, as detailed in S:\particulates\data_processing\dofiles\ftp2rasterLULC\LULC_classes.xlsx
        temp_folder=os.path.dirname(output_raster)+"\\temp"+year
        reclass_tif=temp_folder+"\\reclassed_"+year+".tif"
        
        os.mkdir(temp_folder)        
        #arcpy.gp.Reclassify_sa(output_raster, "Value", "0 0;1 6 1;7 2;8 1;8 11 2;12 4;13 5;14 4;15 6;16 3;16 255 6", reclass_tif, "DATA")
        
        #Second, reclass into separate dummy rasters
        for dummyval in range(0,7):
            valtxt=temp_folder+"\\val"+str(dummyval)+".txt"
            dummytif=os.path.dirname(output_raster)+"\\counts\\"+year+"_dummy"+str(dummyval)+".tif"
            
            mylibrary.dummyascii(0, 6, dummyval, valtxt)
            #arcpy.gp.ReclassByASCIIFile_sa(, valtxt, Reclass_tif1, "DATA")
            
        ##Convert to a coarser sum raster for each class
        settingsdict=mylibrary.ubergridsettings()
        ubercol=settingsdict["COLUMNCOUNT"]
        uberrow=settingsdict["ROWCOUNT"]
        
        desc=arcpy.Describe(dummytif)
        inputrow=desc.height
        inputcol=desc.width
        
        rowfactor=math.floor(int(inputrow)/int(uberrow))
        colfactor=math.floor(int(inputcol)/int(ubercol))
        
        print str(rowfactor), str(colfactor)
        #use aggregate_sa to get an output
        
        ##Convert to ubergrid
        #shutil.rmtree(temp_folder, ignore_errors=True)
        
    #logging.info('Done with ftp2raster.py')
