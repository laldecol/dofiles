# ---------------------------------------------------------------------------
# distance_rasters.py
# -------- #
#
# Description: Create ubergrid rasters with distance to oceans and international
#borders.
# Steps:
# 1. Create line feature classes with the borders of interest
# 2. Convert feature classes to raster
# 3. Convert raster to ubergrid
# 4. Extract border cells
# 5. Use Euclidean Distance tool to generate distance to feature for each cell
# created: Aug 14 2017 by Lorenzo
# last updated: Aug 15 2017 by Lorenzo
# ---------------------------------------------------------------------------

#Import python modules
import arcpy, os, sys

#Import own modules
sys.path.append(os.path.abspath('..\mylibrary'))
import rasters

def line2ubergrid(linefile, outraster, extent, outprojection):
    settingsdict=rasters.ubergridsettings()
    cell_size=settingsdict["CELLSIZEX"]

    temp_raster=os.path.dirname(outraster)+"\\tempraster.tif"
    
    arcpy.FeatureToRaster_conversion(linefile, "FID", temp_raster , cell_size)
    rasters.raster2ubergrid(temp_raster, outraster, extent, outprojection)
    
    os.remove(temp_raster)
    
linefile="..\\..\\..\\data\\boundaries\\manual\\borderlines.shp"
extent ="..\\..\\..\\data\\GPW4\\generated\\extent\\extent.shp"
outprojection ="..\\..\\..\\data\\projections\\WGS 1984.prj"  
outraster="..\\..\\..\\data\\boundaries\\manual\\border_ubergrid.tif"

line2ubergrid(linefile, outraster, extent, outprojection)