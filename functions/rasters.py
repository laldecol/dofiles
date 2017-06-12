# ---------------------------------------------------------------------------
# rasters.py
# -------- #
# Description: This file holds functions that manipulate/process rasters

# created: June 2 2017 by Lorenzo
# last modified: June 2 2017 by Lorenzo
# ---------------------------------------------------------------------------

import os, glob, arcpy, shutil, sys
from arcpy import env

arcpy.env.overwriteOutput = True

def aggregate(expath,output_raster):
# mosaics a set of .tifs, averaging if they overlap, and saves the result
# This function is meant to aggregate rasters both in time and space, depending on the set of rasters we feed it
    
#Inputs:
    #expath: pathname that defines which .tifs are aggregated. This is fed to glob.glob, so can include wildcard characters.
    #output_raster: file location to save output
    
    #Temporary file locations
    temp=os.path.dirname(expath)+"temp"
    gdb=temp+"\\geodatabase.gdb"
    env.workspace = temp
    env.scratchWorkspace=temp
    
    try:
        #Write list of rasters to aggregate
        cwdir=os.getcwd()
        print cwdir
        rasters=glob.glob(expath)
        print str(expath)
        print rasters
        
        #Concatenate list into a single string to feed into arcpy.RasterToGeodatabase
        inputs=';'.join(rasters)
        print inputs
        
        # Define spatial reference (can become input to the function in the future)
        sr = arcpy.SpatialReference("..\\..\\data\\projections\\WGS 1984.prj") 
        
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

def dummyascii(lowerval, higherval, onvalue, outpath):
#Writes an ASCII file usable by Arc's "Reclass by ASCII" tool.
#Output file converts an integer raster to a dummy raster. Ideally, the input raster takes sequential values.
#Inputs:
    #lowerval: lowest value taken by the input raster's cells
    #higherval: largest value taken by the input raster's cells
    #onvalue: Single numerical value mapped to 1. All other values are mapped to 0.
    #outpath: Absolute full path to output .txt
    
    #List with all input raster's values
    inlist=range(lowerval,higherval+1)
    
    #List with mapped values
    outlist=[int(x==onvalue) for x in inlist]    
    
    #Write ASCII file in Arc's expected format
    with open(outpath, 'w') as asciifile:
        for i in range(len(inlist)):
            asciifile.write(str(inlist[i])+' : '+str(outlist[i])+"\n")
            
#if __name__=='__main__':
=======
def raster2ubergrid(input_raster, outpath, extent, outprojection):
#Converts a raster to homogeneous ubergrid, using the input extent and projection.
#This function expects an ubergrid setting file, written by make_xy_extent.py
    
#Inputs:
    #input_raster: raster to convert
    #outpath: full path (including filename and extension) for output raster
    #extent: ubergrid extent shapefile. Input will be clipped to this.
    #outprojection: .prj with output projection
    
    #Extract input directory and basename
    base=os.path.basename(input_raster)
    in_name=os.path.splitext(base)[0]
    
    temp_dir=os.path.dirname(outpath)+in_name+"_temp"
    os.mkdir(temp_dir)
    
    #Name auxiliary and output rasters
    raster_proj = temp_dir+"\\"+ in_name + "_prj.tif"
    raster_clip = outpath
    #"..\\..\\data\\MODIS_AOD\\manual\\aqua2002avg_ProjectRaster_Cl.tif"
    
    #Set up output raster settings as a dictionary. These come from settings.txt, written in make_xy_extent.py
    settingsdict={}
    with open("..\\..\\data\\projections\generated\settings.txt", 'r') as settingfile:
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
    shutil.rmtree(temp_dir, ignore_errors=True)
    
if __name__=='__main__':
    #This section of the code is meant to test-run functions and should generally be empty.
    input_raster="S:\\particulates\\data_processing\\data\\MODIS_FIRE\\generated\\yearly\\Data2000.tif"
    outpath="S:\\particulates\\data_processing\\data\\MODIS_FIRE\\manual\\Data2000_ubertest.tif"
    #Local variables:
    extent = "..\\..\\data\\GPW4\\generated\\extent\\extent.shp"
    outprojection = "..\\..\\data\\projections\\WGS 1984.prj"
    
    raster2ubergrid(input_raster, outpath, extent, outprojection)