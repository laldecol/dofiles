# ---------------------------------------------------------------------------
# generate_pop_by_country.py
# Description: This program generates a table of aggregate country gpw (population count) data for each raster.
# It is set to run over all the gpw (count) source raster, and also over all the ubergrid gpw rasters.


#Created Jun 6 2017, by Marcel
# ---------------------------------------------------------------------------

import arcpy, os, glob, logging, shutil, time

# Check Spatial Analyst Tool 
arcpy.CheckOutExtension ("spatial")

#Set up logging
logging.basicConfig(format='%(asctime)s %(message)s', filename='compute_pop_by_country.log', filemode='w', level=logging.DEBUG)
logging.info('Starting generate_pop_by_country.py.')


def gen_pop_country(inputpattern, inputpattern_uber, outputfolder,country_source, country_source_uber):

    # Clean and Create Output folder (overwrite any pre-existing aggregate data)
    shutil.rmtree(outputfolder, ignore_errors=True)
    os.mkdir(outputfolder)

    #Set overwrite environment
    arcpy.env.overwriteOutput = True    

    # Start Aggregating (source)
    for rasters in glob.glob(inputpattern):
        t0 = time.clock()
    
        print "Computing the populations in " + str(rasters)
        
        #Collect existing name
        new_name = os.path.splitext(os.path.basename(rasters))[0]
    
        # Define output names
        name = outputfolder+"name"
        output_excel = outputfolder+"pop_by_country_"+str(new_name)+".xls"
    
        print "Country population table will be saved as %s" % os.path.splitext(os.path.basename(output_excel))[0]
        
        #Convert "Value" to integer (otherwise it is double, zonal statistic does not work)        
        arcpy.gp.Int_sa(country_source, outputfolder+"temp_integer_raster.tif")        
        
        # Generate Table
        arcpy.gp.ZonalStatisticsAsTable_sa(outputfolder+"temp_integer_raster.tif", "VALUE", rasters, name, "DATA", "SUM")
        
        # Convert to excel
        arcpy.TableToExcel_conversion(name, output_excel, "NAME", "CODE")
    
        # Finally, delete temporary file
        for temp in glob.glob(outputfolder+"temp_integer_raster*"):
            os.remove(temp)
        
        print "Computing population for year %s is complete." % str(new_name)[-4:]
    
        t1 = time.clock()
        logging.info('Computing population for raster %s was completed in %s seconds.', str(new_name), str(t1-t0))
        
    logging.info('All source data were aggregated by country. Proceeding to aggregation for the uber rasters.')
        
    # Start Aggregating (ubergrid)
    for rasters in glob.glob(inputpattern_uber):
        t0 = time.clock()
        
        print "Computing the populations in " + str(rasters)
            
        #Collect existing name
        new_name = os.path.splitext(os.path.basename(rasters))[0]
        
        # Define output names (they are already different from the beginning, so I just keep the pattern)
        name = outputfolder+"name"
        output_excel = outputfolder+"pop_by_country_"+str(new_name)+".xls"
        
        print "Country population table will be saved as %s" % os.path.splitext(os.path.basename(output_excel))[0]
            
        # Generate Table
        arcpy.gp.ZonalStatisticsAsTable_sa(country_source_uber, "VALUE", rasters, name, "DATA", "SUM")
            
        # Convert to excel
        arcpy.TableToExcel_conversion(name, output_excel, "NAME", "CODE")
        
        print "Computing population for year %s is complete." % str(new_name)[-4:]
        
        t1 = time.clock()
        logging.info('Computing population for raster %s was completed in %s seconds.', str(new_name), str(t1-t0))  
        
    logging.info('All ubergrid data were aggregated by country.')   
        
    #Delete temporary folder
    shutil.rmtree(outputfolder+"info")
    
    
    print "The program had ended. Good bye"

## -------------------------END OF PROGRAM--------------------------------- ##
    
if __name__ == '__main__':    
    
    ###############################Please Inform Function Inputs#######################################
    # Define output folder
    outputfolder = "..\\..\\..\\data\\GPW4\\generated\\Temp_aggregate_pop_check\\"
    
    # Pattern of inputs/inputs
    inputpattern = "..\\..\\..\\data\\GPW4\\source\\gpw-v4-population-count*\\*.tif"
    inputpattern_uber = "..\\..\\..\\data\\GPW4\\generated\\aggregated*\\*.tif"
    

    # Country source
    country_source = "S:\\particulates\\data_processing\\data\\GPW4\\source\\gpw-v4-national-identifier-grid\\gpw-v4-national-identifier-grid.tif"
    #country_source_uber = "S:\\particulates\\data_processing\\data\\GPW4\\generated\\gpw-v4-national-identifier-grid\\ubergrid\\gpw-v4-national-identifier-grid.tif"
    country_source_uber = "S:\\particulates\\data_processing\\data\\GPW4\\generated\\Expanded Boundaries\\ubergrid\\expanded_countries_source.tif"
    
    
    ###################################################################################################    
    
    gen_pop_country(inputpattern, inputpattern_uber, outputfolder, country_source, country_source_uber)





