# ---------------------------------------------------------------------------
# aggregate_raster.py
# Description: This program adds n x n blocks of cells from rasters in a folder
# and saves the resulting raster.
# Please inform the factor of aggregation in line 63 (cellFactor)

#Created Nov 3 2016, by Lorenzo
#Last modified June 13 2017, by Marcel
# ---------------------------------------------------------------------------

import arcpy, os, glob, logging, shutil, time, numpy

# Check Spatial Analyst Tool 
arcpy.env.overwriteOutput = True

#Set up logging
logging.basicConfig(format='%(asctime)s %(message)s', filename='netCDF2raster.log', filemode='w', level=logging.DEBUG)
logging.info('Starting netCDF2raster.py.')

#Define which variables we want to bring to raster (function of)
variables = ['uwnd', 'vwnd']
# Define inputfolder (convert all files within folder)
inputfolder = "..\\..\\..\\data\\CCMP\\source"

#Define outputfolder
outputfolder = "..\\..\\..\\data\\CCMP\\generated\\monthly"
shutil.rmtree(outputfolder, ignore_errors=True)
os.mkdir(outputfolder)

ncs = glob.glob(inputfolder+"\\*.nc")
print ncs

for nc in ncs:
    # Extract file name
    name = os.path.splitext(os.path.basename(nc))[0]
    YYYY = name[19:23]
    print(YYYY)
    MM = name[24:26]
    print(MM)
    for variable in variables:
        # Name paths
        outpath= outputfolder+"\\"+variable+"_"+str(YYYY)+"_"+str(MM)+".tif"
        print(outpath)
        # Create Layer
        arcpy.MakeNetCDFRasterLayer_md(nc, variable, "longitude", "latitude", "temp_Layer", "", "", "BY_VALUE")
        # Process: Copy Raster
        arcpy.CopyRaster_management("temp_Layer", outpath, "", "", "-9.999000e+003", "NONE", "NONE", "", "NONE", "NONE")


