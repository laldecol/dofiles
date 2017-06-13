0#This program:
#1. Projects GPW v4 raster data and resamples it to a 5k resolution. 
#2. Extracts the resulting extent and the raster settings.

#created July 23, 2016 by la
#updated Oct 6, 2016 by la

import os, shutil, time, glob, logging
import arcpy
from arcpy import env

def makexyextent(inputraster,outputprojection,cellsize=""):
    
    # Local variables:
    outputraster = "..\\..\\..\\data\\GPW4\\generated\\projected\\projected_" + os.path.basename(os.path.splitext(inputraster)[0]) + ".tif"
    arcpy.env.snapRaster = outputraster
    
    if cellsize=="":
        arcpy.ProjectRaster_management(inputraster, outputraster, outputprojection)
    else:
        arcpy.ProjectRaster_management(inputraster, outputraster, outputprojection,cell_size=str(cellsize)+" "+ str(cellsize))

    ##Set up extent creation
    
    extent_shp = "..\\..\\..\\data\\GPW4\\generated\\extent\\extent.shp"
    
    #create Describe object with input raster characteristics
    rasterdesc=arcpy.Describe(outputraster)
    
    #extract origin and end corner coordinates to feed into fishnet
    origin= str(rasterdesc.extent.lowerLeft)
    xmin = str(rasterdesc.extent.XMin)
    ymax = str(rasterdesc.extent.YMax)
    corner= str(rasterdesc.extent.upperRight)
    
    #Create a 1x1 fishnet to get extent. We must provide a desired "rotation" of the fishnet (!= origin); to keep extent unrotated,
    #we just draw the y axis again using xmin and ymax.
    arcpy.CreateFishnet_management(extent_shp, origin, xmin + " " + ymax, "0", "0","1", "1", corner, "NO_LABELS", outputraster, "POLYLINE")
    
    #List raster settings we want to save. 
    settings=["TOP", "LEFT", "RIGHT", "BOTTOM", "CELLSIZEX", "CELLSIZEY", "COLUMNCOUNT", "ROWCOUNT"]
    
    shutil.rmtree("..\\..\\..\\data\\projections\settings.txt", ignore_errors=True)
    
    #Read raster properties and print them to settings. txt
    with open("..\\..\\..\\data\\projections\generated\settings.txt", 'w') as fileoutput:
        for setting in settings:
            value=arcpy.GetRasterProperties_management(outputraster, setting)
            fileoutput.write(setting + "\n")
            fileoutput.write(str(value)+ "\n") 

if __name__=="__main__":
    
    logging.basicConfig(format='%(asctime)s %(message)s', filename='make_xy_extent.log', filemode='w', level=logging.DEBUG)
    logging.info('Starting make_xy_extent.py.')    
    
    t0=time.clock()
    #Environments(from program body)
    arcpy.CheckOutExtension("spatial")
    arcpy.env.overwriteOutput = True
    
    #Set up directories
    inputraster = "..\\..\\..\\data\\GPW4\\generated\\aggregated"
    outputprojection = "..\\..\\..\\data\\projections\\WGS 1984.prj"
    cellsize=""

    shutil.rmtree("..\\..\\..\\data\\GPW4\\generated\\extent",ignore_errors=True)
    os.mkdir("..\\..\\..\\data\\GPW4\\generated\\extent")

    shutil.rmtree("..\\..\\..\\data\\GPW4\\generated\\projected",ignore_errors=True)
    os.mkdir("..\\..\\..\\data\\GPW4\\generated\\projected")
    
    #..\\..\\data\\GPW4\\generated\\projected
    
    #Loop through all rasters to reproject and set cell size. Resulting extent and settings correspond to last
    #raster in the list. 
    for raster in glob.glob(inputraster+"\\*.tif"):
        print "Creating extent for "+str(raster)
        makexyextent(raster, outputprojection, cellsize)
    t1=time.clock()
    print "Run took " +str(t1-t0) + "seconds."
    print "End of file"
    
    logging.info('Processed %s rasters in %s seconds.',str(len(glob.glob(inputraster+"*\\*.tif"))),str(t1-t0))
    logging.info('Done with make_xy_extent.py.')
    
