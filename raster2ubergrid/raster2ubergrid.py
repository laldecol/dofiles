# -*- coding: utf-8 -*-
# ---------------------------------------------------------------------------
# raster2ubergrid.py
# Created on: 2016-08-12 13:14:21.00000
#   (generated by ArcGIS/ModelBuilder)
# Description: 
# ---------------------------------------------------------------------------

# Import modules
#Append dofiles\mylibrary to sys.path, to use programs defined there.
import sys, os
sys.path.append(os.path.abspath('..'))

import arcpy, shutil, glob, logging, time, mylibrary
from arcpy import env

def raster2ubergrid(input_raster,extent,outprojection):
    
    arcpy.env.overwriteOutput = True
    
    #Extract input directory and basename
    base=os.path.basename(input_raster)
    out_name=os.path.splitext(base)[0]
    out_dir=os.path.dirname(input_raster)
    
    #Name auxiliary and output rasters
    raster_proj = out_dir+"\\ubergrid\\"+ out_name + "_prj.tif"
    raster_clip = out_dir+"\\ubergrid\\"+ out_name + ".tif"
    #"..\\..\\data\\MODIS_AOD\\manual\\aqua2002avg_ProjectRaster_Cl.tif"
    
    #Set up output raster settings as a dictionary. These come from settings.txt, written in make_xy_extent.py
    settingsdict={}
    with open("..\\..\\..\\data\\projections\generated\settings.txt", 'r') as settingfile:
        templines=settingfile.readlines()
        lines = [i.replace('\n','') for i in templines]
        for linecounter in range(len(lines)):        
            if linecounter % 2 ==0:
                #print linecounter
                settingsdict[str(lines[linecounter])]=str(lines[linecounter+1])
    print settingsdict
    
    #Project raster using target projection, cell size, and reference point. 
    
    cell_size=settingsdict['CELLSIZEX']+" "+settingsdict['CELLSIZEY']
    regist_point=settingsdict['LEFT']+" "+settingsdict['TOP']
    
    arcpy.ProjectRaster_management(input_raster,raster_proj,outprojection,"NEAREST",cell_size,"",regist_point,in_coor_system=None)

    #Clip raster to ubergrid extent
    arcpy.Clip_management(raster_proj, "", raster_clip, extent, "-9999", "NONE", "MAINTAIN_EXTENT")
    
    #Remove temporary files.
    for file in glob.glob(out_dir+"\\ubergrid\\"+ out_name + "_prj*"):
        os.remove(file)

if __name__=='__main__':
    
    #Set up logging
    logging.basicConfig(format='%(asctime)s %(message)s', filename='raster2ubergrid.log', filemode='w', level=logging.DEBUG)
    logging.info('Starting raster2ubergrid.py.')
    
    #Local variables:
    #extent = "..\\..\\data\\GPW4\\generated\\extent\\extent.shp"
    #outprojection = "..\\..\\data\\projections\\WGS 1984.prj"    
    
    #Ubergrid extent and settings for the particulates project are found in (starting from a folder within dofiles)
    extent = "..\\..\\..\\data\\GPW4\\generated\\extent\\extent.shp"
    outprojection = "..\\..\\..\\data\\projections\\WGS 1984.prj"    
    
    folders = []
    deletebin=[]    
    
    #List of input folders
      
    #folders.append("..\\..\\..\\data\\MODIS_AOD\\generated\\yearly")
    #folders.append("..\\..\\..\\data\\GPW4\\source\\gpw-v4-national-identifier-grid")
    #folders.append("..\\..\\..\\data\\GPW4\\source\gpw-v4-data-quality-indicators-mean-administrative-unit-area")
    #folders.append("..\\..\\..\\data\\MODIS_FIRE\\generated\\yearly")
    #folders.append("..\\..\\..\\data\\CRU\\generated\\yearly")
    folders.append("..\\..\\..\\data\\MODIS_LULC\\generated\\yearly\\dummy")
        
    #Logging info
    rastercount=0
    t0=time.clock()
    
    for input_folder in folders:
        
        #Set output directory

        #If the folder that's provided is in a source subdirectory, we don't want to create folders and write generated data within them.
        #Therefore, whenever this happens, we must move the output to a corresponding directory within data\\folder\\generated\\.
        #To keep the source folder as potentially read only, we copy the file to be processed into a twin directory and then delete it when we're done.       
        
        if input_folder.find("source")>=0:
            folder_generated=input_folder.replace("source","generated")
            shutil.rmtree(folder_generated,ignore_errors=True)
            os.makedirs(folder_generated)
            
            for raster in glob.glob(input_folder+"\\*.tif"):
                shutil.copy(raster, folder_generated)
                deletebin.append(raster.replace("source","generated"))
            
            input_folder=folder_generated
        
        #Set up directories
        shutil.rmtree(input_folder+"\\ubergrid", ignore_errors=True)
        os.makedirs(input_folder+"\\ubergrid")
        
        
        #Convert rasters to ubergrid
        for raster in glob.glob(input_folder+"\\*.tif"):
            base=os.path.basename(raster)
            out_name=os.path.splitext(base)[0]            
            outpath=input_folder+"\\ubergrid\\"+out_name+".tif"
            
            print "Processing " + str(raster)
            
            logging.info('Processing %s', str(raster))
            mylibrary.raster2ubergrid(raster, outpath, extent, outprojection)
            rastercount+=1
            
        #Cleanup
        for raster in deletebin:
            try:
                os.remove(raster)
            except OSError:
                pass        

    t1=time.clock()
    logging.info('Converted %s rasters to ubergrids in %s minutes', rastercount, str((t1-t0)/60))
    logging.info('Done with raster2ubergrid.py.')
    