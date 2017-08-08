# ---------------------------------------------------------------------------
# Include_oceansy.py
# Description: This program extends the raster gpw4-national-identifier. 
# Pixel belonging to countries get extended towards no-data pixels (which represent water bodies and oceans...)
# Country boundaries are extended assigning pixels according to the the density of other nearby pixels.
# See the arc expand tool for more information.
# Created Jun 16 2017, by Marcel
# Source and ubergrid identifier can be extended.
# Modified Jun 27 by Marcel
# ---------------------------------------------------------------------------

import arcpy, os, glob, logging, shutil, time, sys, linecache, math
sys.path.append("..\\mylibrary")
from rasters import dta2raster

# Check Spatial Analyst Tool 
arcpy.CheckOutExtension ("spatial")

#Set up logging
logging.basicConfig(format='%(asctime)s %(message)s', filename='Include Oceans.log', filemode='w', level=logging.DEBUG)
logging.info('Starting include_oceans.py.')

###############################Please Inform Function Inputs#######################################
# Define output folder
outputfolder = "..\\..\\..\\data\\GPW4\\generated\\Expanded Boundaries"
    
#Set overwrite environment (non-excel tables will be overwritten)
arcpy.env.overwriteOutput = True    
    
# Locate ubergrid  and source raster
ubergrid_nat_id = "..\\..\\..\data\\GPW4\\generated\\gpw-v4-national-identifier-grid\ubergrid\\gpw-v4-national-identifier-grid.tif"
source_nat_id = "..\\..\\..\\data\\GPW4\\source\\gpw-v4-national-identifier-grid\\gpw-v4-national-identifier-grid.tif"

# Read all the country values (manually pre-prepared by exporting txt from dta containing all countries): 
with open(outputfolder+"\\unique_countries.txt", 'r') as uc:
    
    data=uc.read().replace('\n', ';')

zone_values = data[:-1]


##Expand ubergrid:
#arcpy.gp.Expand_sa(ubergrid_nat_id, outputfolder+"\\expanded_countries_ubergrid.tif", "1", zone_values)
#logging.info('The ubergrid national identifier raster was expanded - number_cells equals 1.')

##Expand source 
# First, retrieve cellFactor
rowcount = linecache.getline("..\\..\\..\\data\\projections\generated\settings.txt", 16, module_globals=None)
cellFactor = round(17400/int(rowcount))
print("The inferred cellFactor is %d" %cellFactor)

# Compute the expanding number_cells
#expandFactor = math.ceil((cellFactor-1)/2)
expandFactor = cellFactor
print("The source raster will be expanded - number_cells equals %d" %expandFactor)

# First, collect the ubergrid cellFactor 
arcpy.gp.Expand_sa(source_nat_id, outputfolder+"\\expanded_nat_identifier_grid.tif", cellFactor, zone_values)

logging.info('The source national identifier raster was expanded - number_cells equals %d.' %expandFactor)

print("Program has ended. Bye")