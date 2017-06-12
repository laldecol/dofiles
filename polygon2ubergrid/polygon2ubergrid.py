# ---------------------------------------------------------------------------
# polygon2raster.py
# Created on: 2016-08-22 
# Description: This file projects a given vector shapefile into the preset 
# projection, converts it into a raster, and then into ubergrid.
# ---------------------------------------------------------------------------

import arcpy, os, sys, shutil, glob, logging
from arcpy import env
sys.path.append("..\\raster2ubergrid")
from raster2ubergrid import raster2ubergrid

def polygon2ubergrid(input_polygon,field,extent,outprojection):
    
    arcpy.env.overwriteOutput = True
    #Extract input directory and basename
    out_dir=os.path.dirname(input_polygon)    
    base=os.path.basename(input_polygon)
    out_name=os.path.splitext(base)[0]
    
    #Name auxiliary files
    input_polygon_prj=out_dir + "\\"+ out_name +"_prj.shp"
    out_raster=out_dir + "\\"+ out_name +".tif"
    
    #Set up output raster settings as a dictionary. These come from settings.txt, written in make_xy_extent.py
    settingsdict={}
    with open("..\\..\\data\\projections\generated\settings.txt", 'r') as settingfile:
        templines=settingfile.readlines()
        lines = [i.replace('\n','') for i in templines]
        for linecounter in range(len(lines)):        
            if linecounter % 2 ==0:
                print linecounter
                settingsdict[str(lines[linecounter])]=str(lines[linecounter+1])    
    
    # Process: Project
    arcpy.Project_management(input_polygon,input_polygon_prj,outprojection,"",)
    
    # Process: Polygon to Raster
    arcpy.PolygonToRaster_conversion(input_polygon_prj,field,out_raster,"CELL_CENTER", "NONE", settingsdict['CELLSIZEX'])
    
    #Raster to ubergrid
    try:
        os.remove(out_dir+"\\ubergrid\\"+ out_name + ".tif")
    except OSError:
        pass
    raster2ubergrid(out_raster,extent,outprojection)
    
    #Cleanup
    for file in glob.glob(out_dir + "\\"+ out_name +"_prj.*"):
        os.remove(file)
    os.remove(out_raster+".xml")
    os.remove(out_raster)

if __name__==__main__:
    
    #Set up logging
    logging.basicConfig(format='%(asctime)s %(message)s', filename='polygon2ubergrid.log', filemode='w', level=logging.DEBUG)
    logging.info('Starting polygon2ubergrid.py.')
    
    # Local variables:
    input_polygon = "S:\\particulates\\data_processing\\data\\boundaries\\generated\\world_countries_2011.shp"
    #input_polygon_prj = "S:\\particulates\\data_processing\\data\\boundaries\\manual\\world_countries_2011prj.shp"
    outprojection = "..\\..\\data\\projections\\Cylindrical Equal Area (world).prj"
    #inprojection="GEOGCS['GCS_WGS_1984',DATUM['D_WGS_1984',SPHEROID['WGS_1984',6378137.0,298.257223563]],PRIMEM['Greenwich',0.0],UNIT['Degree',0.0174532925199433]]"
    field="COUNTRY"
    extent = "..\\..\\data\\MODIS_AOD\\manual\\extent.shp"
    outprojection = "..\\..\\data\\projections\\Cylindrical Equal Area (world).prj"
    
    #Extract input directory and basename
    out_dir=os.path.dirname(input_polygon)
    
    #Create ubergrid directory for output
    shutil.rmtree(out_dir+"\\ubergrid", ignore_errors=True)
    os.mkdir(out_dir+"\\ubergrid")
    
    polygon2ubergrid(input_polygon, field, extent, outprojection)
    
    logging.info('Done with polygon2ubergrid.py.')
    
