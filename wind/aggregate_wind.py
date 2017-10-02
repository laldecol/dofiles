# ---------------------------------------------------------------------------
# aggregate_raster.py
# Description: This program adds n x n blocks of cells from rasters in a folder
# and saves the resulting raster.
# Please inform the factor of aggregation in line 63 (cellFactor)

#Created Nov 3 2016, by Lorenzo
#Last modified June 13 2017, by Marcel
# ---------------------------------------------------------------------------

import arcpy, os, glob, logging, shutil, time, numpy, sys
sys.path.append("..\\mylibrary")
from rasters import aggregate

# Check Spatial Analyst Tool 
arcpy.env.overwriteOutput = True

#Set up logging
logging.basicConfig(format='%(asctime)s %(message)s', filename='netCDF2raster.log', filemode='w', level=logging.DEBUG)
logging.info('Starting netCDF2raster.py.')

#Define which variables we want to bring to raster (function of)
variables = ['uwnd', 'vwnd']

## Now average across months (optional 1==1)

year_folder = "..\\..\\..\\data\\CCMP\\generated\\yearly\\"
shutil.rmtree(year_folder, ignore_errors=True)
os.mkdir(year_folder)

years = numpy.linspace(2000, 2015, 16)

for variable in variables:
    
    for year in years:
        
        inputpattern = "..\\..\\..\\data\\CCMP\\generated\\monthly\\"+variable+"_"+str(int(year))+"*.tif"
        output_raster = year_folder+variable+"_"+str(int(year))+".tif"
        x = glob.glob(inputpattern)
        print(x)
        print(output_raster)
        aggregate(inputpattern, output_raster)
        
