# ---------------------------------------------------------------------------
# polygon2raster.py
# Created on: 2016-08-22 
# Last modified: 2019-02-07
# Description: This file projects a given polygon shapefile into the preset 
# projection, converts it into a raster, and then into ubergrid.

# ---------------------------------------------------------------------------
import sys, os
sys.path.append(os.path.abspath('..'))

import arcpy, shutil, glob, logging, mylibrary
from arcpy import env


def polygon2ubergrid(input_polygon,out_path,field,extent,outprojection):
    
    # Set overwrite environment
    arcpy.env.overwriteOutput = True
    
    #Extract input directory and basename
    out_dir=os.path.dirname(out_path)
    base=os.path.basename(out_path)
    out_name=os.path.splitext(base)[0]
    
    #Name auxiliary files
    temp_dir=out_dir+"\\temp"
    
    #Set workspace;
    arcpy.env.workspace = temp_dir
    arcpy.env.scratchWorkspace = temp_dir

        
    input_polygon_prj=temp_dir + "\\temp_prj.shp"
    out_raster=temp_dir+"\\temptif.tif"

    #Clean temp dir
    try:
        shutil.rmtree(temp_dir)
    except OSError:    
        pass
    
    try:
        os.mkdir(temp_dir)
    except OSError:
        pass
    
    #Set up output raster settings as a dictionary. These come from settings.txt, written in make_xy_extent.py
    settingsdict={}
    with open("..\\..\\..\\data\\projections\generated\settings.txt", 'r') as settingfile:
        templines=settingfile.readlines()
        lines = [i.replace('\n','') for i in templines]
        for linecounter in range(len(lines)):        
            if linecounter % 2 ==0:
                print linecounter
                settingsdict[str(lines[linecounter])]=str(lines[linecounter+1])    
    
    # Process: Project
    arcpy.Project_management(input_polygon,input_polygon_prj,outprojection)
    
    # Process: Polygon to Raster
    arcpy.PolygonToRaster_conversion(input_polygon_prj,field,out_raster,"CELL_CENTER", "NONE", settingsdict['CELLSIZEX'])
    
    #Raster to ubergrid
    try:
        os.remove(out_dir+"\\ubergrid\\"+ out_name + ".tif")
    except OSError:
        pass
    
    mylibrary.raster2ubergrid(out_raster, out_path, extent, outprojection)
    
    #Cleanup
    shutil.rmtree(temp_dir)
    
    #for file in glob.glob(out_dir + "\\"+ out_name +"_prj.*"):
        #os.remove(file)
    #os.remove(out_raster+".xml")
    #os.remove(out_raster)

if __name__=='__main__':
    
    #Set up logging
    logging.basicConfig(format='%(asctime)s %(message)s', filename='polygon2ubergrid.log', filemode='w', level=logging.DEBUG)
    logging.info('Starting polygon2ubergrid.py.')
    
    # Local variables:
    input_list=[]
    outdir_list=[]
    field_list=[]    
    
    #List of input polygon shps, with corresponding field;
    input_list.append("..\\..\\..\\data\\boundaries\\generated\\world_countries_2011.shp")
    outdir_list.append("..\\..\\..\\data\\boundaries\\generated")
    field_list.append("COUNTRY")
    
    #input_list.append("..\\..\\..\\data\\boundaries\\source\\city_50km_disk.shp")
    #outdir_list.append("..\\..\\..\\data\\boundaries\\generated")
    #field_list.append("URBANCODE")
    
    #inprojection="GEOGCS['GCS_WGS_1984',DATUM['D_WGS_1984',SPHEROID['WGS_1984',6378137.0,298.257223563]],PRIMEM['Greenwich',0.0],UNIT['Degree',0.0174532925199433]]"
    
    extent = "..\\..\\..\\data\\GPW4\\generated\\extent\\extent.shp"
    outprojection = "..\\..\\..\\data\\projections\\Cylindrical Equal Area (world).prj"
    
    
    #Create output folders
    #We need two loops to avoid deleting first output when two inputs are in the same directory
    for position in range(len(input_list)):
        
        #Extract input directory and basename
        out_dir=outdir_list[position]
        
        #Create ubergrid directory for output
        try:
            shutil.rmtree(out_dir+"\\ubergrid", ignore_errors=False)
        except OSError:
            pass
        
        try:
            os.mkdir(out_dir+"\\ubergrid")
        except OSError:
            pass
            
        
    #Convert polygon to ubergrid
    for position in range(len(input_list)):
        
        input_polygon=input_list[position]
        input_field=field_list[position]
        
        out_dir=outdir_list[position]
        out_name=os.path.splitext(os.path.basename(input_polygon))[0]        
        out_path=out_dir+"\\ubergrid\\"+out_name+".tif"
        
        polygon2ubergrid(input_polygon, out_path, input_field, extent, outprojection)
        
    logging.info('Done with polygon2ubergrid.py.')
