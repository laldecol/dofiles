# ---------------------------------------------------------------------------
# aggregate_raster.py
# Description: This program adds n x n blocks of cells from rasters in a folder
# and saves the resulting raster.
# Please inform the factor of aggregation in line 63 (cellFactor)

#Created Nov 3 2016, by Lorenzo
#Last modified June 13 2017, by Marcel
# ---------------------------------------------------------------------------

import arcpy, os, glob, logging, shutil, time

# Check Spatial Analyst Tool 
arcpy.CheckOutExtension ("spatial")

#Set up logging
logging.basicConfig(format='%(asctime)s %(message)s', filename='aggregate_raster.log', filemode='w', level=logging.DEBUG)
logging.info('Starting aggregate_raster.py.')


def aggregate_raster_general(inputpattern,outputfolder,cellFactor):

    # Clean and Create Output folder (overwrite any pre-existing aggregate data)
    shutil.rmtree(outputfolder, ignore_errors=True)
    os.mkdir(outputfolder)
        
    #Inform cellFactor
    logging.info('Rasters are going to be aggregated by a factor of %s',str(cellFactor))

    # Start Aggregating
    for rasters in glob.glob(inputpattern):
        t0 = time.clock()
    
        print "Aggregating " + str(rasters)
        #Collect existing name
        new_name = os.path.splitext(os.path.basename(rasters))[0]
    
        # Define output name
        outputfile = outputfolder+"aggregated_gpw_"+str(new_name)[-4:]+".tif"
    
        print "Aggregated file will be saved as %s.tif" % os.path.splitext(os.path.basename(outputfile))[0]
    
        # Aggregate
        arcpy.gp.Aggregate_sa(rasters, outputfile, cellFactor, "SUM", "EXPAND", "DATA")
    
        print "Aggregation for year %s is complete." % str(new_name)[-4:]
    
        t1 = time.clock()
        logging.info('Aggregation for year %s was completed in %s seconds.', str(new_name)[-4:], str(t1-t0))
    
    print "The program had ended. Good bye"

## -------------------------END OF PROGRAM--------------------------------- ##
    
if __name__ == '__main__':    
    
    ###############################Please Imform Function Inputs#######################################
    # Define output folder
    outputfolder = "..\\..\\..\\data\\GPW4\\generated\\aggregated\\"
    # Pattern of inputs/inputs
    inputpattern = "..\\..\\..\\data\\GPW4\\source\\gpw-v4-population-count*\\*.tif"
    # Set local variables
    cellFactor = 10
    ###################################################################################################    
    
    aggregate_raster_general(inputpattern, outputfolder, cellFactor)





