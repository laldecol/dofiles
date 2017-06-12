# ---------------------------------------------------------------------------
# hdf2tif.py
# -------- #
# aod_1_ftp2tif #
# -------- #
# Run time: ~4 minutes per month
#
# 
# Description:
#
# (1) Convert all .HDF files to .TIF and make a list of .HDF files that we process through HEG tool.

#
# created: July 6 2015 by ngc
# modified: September 17 2015 by ngc
# modified: jan 16 2016 sp
# ---------------------------------------------------------------------------

import calendar, datetime, glob, logging, os, shutil, subprocess, sys, time, traceback

#------------define converter-----------
#################################################
## Step 1: Convert 1 month of hdf files to tif ##
#################################################
def converter(prod,sat,year,month,i):
    #Local variables:
    downloads = "S:/subways_AOD/data_proccessing/data/modis_aod/downloads"
    source = "S:/subways_AOD/data_proccessing/data/modis_aod/source_converted"
    temp = "S:/subways_AOD/data_proccessing/dofiles/aod_1_ftp2tif/temp"
    
    #Set directories:
    in_folder = downloads + "/" + prod + "/" + sat + "/" + year + "/" + month.zfill(2) + "/" + str(i).zfill(2) # Input folder
    out_folder = source + "/" + prod + "/" + sat + "/" + year + "/" + month.zfill(2) + "/" + str(i).zfill(2)   # Output folder
    diagnostics = "S:/subways_AOD/data_proccessing/dofiles/aod_1_ftp2tif/diagnostics"+ "/" + prod + "/" + sat + "/" + year + "/" + month.zfill(2) + "/" + str(i).zfill(2)
    
    os.chdir(in_folder) # Change current directory to input folder
    shutil.rmtree(out_folder, ignore_errors=True) # Remove output folder if it already exists
    os.makedirs(out_folder) # Create new output folder

    # Set logging
    log_file = diagnostics + "/convert" + "_" + prod + "_" + sat + "_" + year + "_" + month.zfill(2) + "_" + str(i).zfill(2) + ".log" 
    logging.basicConfig(filename= log_file,format="%(asctime)s %(message)s", datefmt="%I:%M:%S %p", filemode="w", level=logging.DEBUG)        

    counter = 0 # Set counter to 0
    n_errors = 0 # Set number of errors to 0

    logging.info("... Started converting hdf files to tif for (prod/sat/year/month/day) " + prod + "/" + sat + "/" + year + "/" + month.zfill(2) + "/" + str(i).zfill(2))
    print "... Started converting hdf files to tif for (prod/sat/year/month/day) " + prod + "/" + sat + "/" + year + "/" + month.zfill(2) + "/" + str(i).zfill(2)
    
    try:
        for granule in glob.glob("*.hdf"): # The glob module finds all the pathnames matching a specified pattern in current folder (e.g. ending with ".hdf")
            try:
                logging.info("... Started converting " + granule + " to tif")
                print "... Started converting " + granule +  " to tif"
                input = in_folder + "/" + granule[0:-4] # Input is the pathname to the granule (excluding the last 4 characters (".hdf")
                output = out_folder + "/" + granule[9:-27] + "_" + granule[18:-22] # Output is the pathname to the output tif file
                # Hard code a parameter file with unix style EOL.
                f = open(input + ".prm",'wb') # Write a parameter file for the granule
                f.write('\n')
                f.write('NUM_RUNS = 1\n')
                f.write('\n')
                f.write('BEGIN\n')
                f.write('INPUT_FILENAME = ')
                f.write(input)
                f.write('.hdf\n')
                f.write('OBJECT_NAME = mod04\n')
                f.write('FIELD_NAME = Optical_Depth_Land_And_Ocean|\n')
                f.write('BAND_NUMBER = 1\n')
                if prod == "10K":
                    f.write('OUTPUT_PIXEL_SIZE_X = 10000.0\n')
                    f.write('OUTPUT_PIXEL_SIZE_Y = 10000.0\n')
                else:
                    f.write('OUTPUT_PIXEL_SIZE_X = 3000.0\n')
                    f.write('OUTPUT_PIXEL_SIZE_Y = 3000.0\n')                
                f.write('SPATIAL_SUBSET_UL_CORNER = ( 90.0 -180.0 )\n')
                f.write('SPATIAL_SUBSET_LR_CORNER = ( -90.0 180.0 )\n')
                f.write('RESAMPLING_TYPE = NN\n')
                f.write('OUTPUT_PROJECTION_TYPE = SIN\n')
                f.write('ELLIPSOID_CODE = WGS84\n')
                f.write('OUTPUT_PROJECTION_PARAMETERS = ( 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0  )\n')
                f.write('OUTPUT_FILENAME = ')
                f.write(output)
                f.write('_out.tif\n')
                f.write('OUTPUT_TYPE = GEO\n')
                f.write('END\n')
                f.write('\n')
                f.close()
    
                parameters = input + ".prm"
    
                callheg = "C:/HEGtools/HEG_Win/bin/swtif.exe -P " + parameters
                os.environ["MRTDATADIR"] = "C:/HEGtools/HEG_Win/data" # Set environment variables for HEG tool
                os.environ["MRTBINDIR"] = "C:/HEGtools/HEG_Win/bin" # Set environment variables for HEG tool
                os.environ["PGSHOME"] = "C:/HEGtools/HEG_Win/TOOLKIT_MTD" # Set environment variables for HEG tool
                os.environ["HEGUSER"] = "mturner1" # Set environment variables for HEG tool
                os.environ["PWD"] = temp # Set environment variables for HEG tool
                ret = subprocess.call(callheg, shell=False) # Call HEG tool to convert the granule to tif using the parameter file defined above
    
                if ret != 0:
                    logging.info("... HEG command failed for " + granule)
                    print "... HEG command failed for " + granule
                    f = open(diagnostics + "/" + "convert_errors_list.txt", 'ab') # Create a text file with all the granules that couldn't be converted
                    f.write(granule[:-4])
                    f.write('\n')
                    f.close()
                    n_errors += 1 # Count the number of errors that we get when trying to convert hdf files to tif
                else:
                    logging.info("... Done with " + granule + " : Successful conversion")
                    print "... Done with " + granule + " : Succesful conversion"
                    f = open(diagnostics + "/" + "convert_success_list.txt", 'ab') # Create a text file with all the granules that we succesfully converted (to be used in tif2daily)
                    f.write(granule[:-4])
                    f.write('\n')
                    f.close()
                
                counter += 1
            except Exception as ee:
                # If an error occurred, print line number and error message
                tb = sys.exc_info()[2]
                print "An error occured on line %i" % tb.tb_lineno
                print str(ee)
                logging.info("An error occured in title on line %i" % tb.tb_lineno)
                logging.info("in :" + str(ee))
                logging.info("There was a problem with " + prod + "/" +  sat + "/" + year + "/" + month.zfill(2) + "/" + str(i).zfill(2) + ":" + granule)
                
        logging.info("Couldn't convert " + str(n_errors) + " hdf files out of " + str(counter) + " for (prod/sat/year/month/day) " + prod + "/" + sat + "/" + year + "/" + month.zfill(2) + "/" + str(i).zfill(2))
        print ".... Couldn't convert " + str(n_errors) + " hdf files out of " + str(counter) + " for (prod/sat/year/month/day) " + prod + "/" +  sat + "/" + year + "/" + month.zfill(2) + "/" + str(i).zfill(2)
        logging.info("... Done converting hdf files to tif for (prod/sat/year/month/day) " + prod + "/" +  sat + "/" + year + "/" + month.zfill(2) + "/" + str(i).zfill(2))
        print "... Done converting hdf files to tif for (prod/sat/year/month/day) " + prod + "/" +  sat + "/" + year + "/" + month.zfill(2) + "/" + str(i).zfill(2)    
        shutil.rmtree(in_folder, ignore_errors=True) # Remove input folder (trash downloads day by day as soon as we process them).
        ###############
        ## THE END   ##
        ###############
        
    except Exception as e:
        # If an error occurred, print line number and error message
        tb = sys.exc_info()[2]
        print "An error occured on line %i" % tb.tb_lineno
        print str(e)
        logging.info("An error occured in title on line %i" % tb.tb_lineno)
        logging.info("in :" + str(e))
#----------- end define converter--------