# ---------------------------------------------------------------------------
# generate_aod_by_country.py
# Description: This program generates a table of aggregate country AOD data for each raster.
# It is set to run over all the AOD source raster, and also over all the ubergrid AOD rasters.

# Created Jun 16 2017, by Marcel
# Modified Jun 27 by Marcel
# ---------------------------------------------------------------------------

import arcpy, os, glob, logging, shutil, time

# Check Spatial Analyst Tool 
arcpy.CheckOutExtension ("spatial")

#Set up logging
logging.basicConfig(format='%(asctime)s %(message)s', filename='compute_aod_by_country.log', filemode='w', level=logging.DEBUG)
logging.info('Starting generate_pop_by_country.py.')


def gen_aod_country(inputpattern,inputpattern_uber,outputfolder,country_source, country_source_uber):

    # Clean and Create Output folder (overwrite any pre-existing aggregate data)
    shutil.rmtree(outputfolder, ignore_errors=True)
    os.mkdir(outputfolder)
    
    #Set overwrite environment (non-excel tables will be overwritten)
    arcpy.env.overwriteOutput = True    
    

    # Start Summing the source data
    for rasters in glob.glob(inputpattern):
        t0 = time.clock()
    
        print "Computing the AOD data by country in " + str(rasters)
        
        #Collect existing name
        new_name = os.path.splitext(os.path.basename(rasters))[0]
    
        # Define output names
        name = outputfolder+"name"    #just the table, will disappear
        output_excel = outputfolder+"aod_by_country_"+str(new_name)+".xls"
    
        print "Country aod table will be saved as %s" % os.path.splitext(os.path.basename(output_excel))[0]
        
        # Generate Table (use mean, due to the way AOD data is generated)
        arcpy.gp.ZonalStatisticsAsTable_sa(country_source, "UNSDCODE", rasters, name, "DATA", "MEAN")
        
        # Convert to excel
        arcpy.TableToExcel_conversion(name, output_excel, "NAME", "CODE")
    
        print "Computing aod for year %s is complete." % str(new_name)[-7:-3]
    
        t1 = time.clock()
        logging.info('Computing aod for raster %s was completed in %s seconds.', str(new_name), str(t1-t0))
    
    logging.info('All source data were aggregated by country. Proceeding to aggregation for the uber rasters.')
    
    
        # Start Summing the source data
    for rasters in glob.glob(inputpattern_uber):
        t0 = time.clock()
            
        print "Computing the AOD data by country in " + str(rasters)
                
        #Collect existing name
        new_name = os.path.splitext(os.path.basename(rasters))[0]
            
        # Define output names
        name = "..\\..\\..\\data\\GPW4\\generated\\Temp_aggregate_pop_check\\name"
        output_excel = outputfolder+"aod_by_country_ubergrid_"+str(new_name)+".xls"
            
        print "Country aod table will be saved as %s" % os.path.splitext(os.path.basename(output_excel))[0]
                
        # Generate Table
        arcpy.gp.ZonalStatisticsAsTable_sa(country_source_uber, "VALUE", rasters, name, "DATA", "MEAN")
                
        # Convert to excel
        arcpy.TableToExcel_conversion(name, output_excel, "NAME", "CODE")
            
        print "Computing population for year %s is complete." % str(new_name)[-7:-3]
            
        t1 = time.clock()
        logging.info('Computing aod for raster %s was completed in %s seconds.', str(new_name), str(t1-t0))
            
    logging.info('All uber-raster data were aggregated by country.')
            
    
    #Delete temporary folder
    shutil.rmtree(outputfolder+"info")    
    
    print "The program had ended. Good bye"

## -------------------------END OF PROGRAM--------------------------------- ##
    
if __name__ == '__main__':    
    
    ###############################Please Inform Function Inputs#######################################
    # Define output folder
    outputfolder = "..\\..\\..\\data\\MODIS_AOD\\generated\\Temp_aggregate_aod_check\\"
    
    # Pattern of inputs/inputs
    inputpattern = "..\\..\\..\\data\\MODIS_AOD\\generated\\yearly\\*.tif"
    inputpattern_uber= "..\\..\\..\\data\\MODIS_AOD\\generated\\yearly\\ubergrid\\*.tif"
    
    # Country source
    country_source = "S:\\particulates\\data_processing\\data\\GPW4\\source\\gpw-v4-national-identifier-grid\\gpw-v4-national-identifier-grid.tif"
    country_source_uber = "S:\\particulates\\data_processing\\data\\GPW4\\generated\\gpw-v4-national-identifier-grid\\ubergrid\\gpw-v4-national-identifier-grid.tif"
    
    ###################################################################################################    
    
    gen_aod_country(inputpattern, inputpattern_uber, outputfolder, country_source, country_source_uber)





