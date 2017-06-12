# ---------------------------------------------------------------------------
# aggregate_raster.py
# Description: This program adds 5 x 5 blocks of cells from rasters in a folder
# and saves the resulting raster.

#Created Nov 3 2016, by Lorenzo
#Last modified June 6 2017, by Lorenzo
# ---------------------------------------------------------------------------

# Import arcpy module
import arcpy, glob, shutil, os, logging, time

#def aggregate_kbyk(inputpattern, ):
    
    
# Check out any necessary licenses
arcpy.CheckOutExtension("spatial")

# Local variables:
inputpattern = "..\\..\\..\\data\\GPW4\\source\\gpw-v4-population-count*\\*.tif"
outputfolder = "..\\..\\..\\data\\GPW4\\generated\\aggregated\\"

#Set up folders:
shutil.rmtree(outputfolder, ignore_errors=True)
os.mkdir(outputfolder)

#Set up logging
logging.basicConfig(format='%(asctime)s %(message)s', filename='aggregate_raster.log', filemode='w', level=logging.DEBUG)
logging.info('Starting aggregate_raster.py.')

#For each file name that matches the pattern, run arcpy's Aggregate tool.
t0=time.clock()
for name in glob.glob(inputpattern):

    print "Aggregating " + str(name)    
    #Extract base name from input and use it to name output file. 
    base=os.path.splitext(os.path.basename(name))[0]
    outputfile=outputfolder+"aggregated_gpw_"+str(base)[-4:]+".tif"
    
    #Aggregate 5x5 blocks by summing their values, and ignore no data cells. 
    arcpy.gp.Aggregate_sa(name, outputfile, "5", "SUM", "EXPAND", "DATA")
    
    print "Done aggregating " + str(name)
    
print "Done aggregating files of the form "+ str(inputpattern)
t1=time.clock()

logging.info('Aggregated %s rasters in %s seconds.',str(len(glob.glob(inputpattern))),str(t1-t0))
logging.info('Done with aggregate_raster.py')
