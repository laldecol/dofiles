# ---------------------------------------------------------------------------
# HEGhdf2tif.py
# -------- #
# -------- #
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

import calendar, datetime, glob, logging, os, shutil, subprocess, sys, time, traceback, math


def MODIStilename(filename):
    #This function takes a MODIS tile file and extracts day, year, and tile information from its name
    namevars= filename.split(".")
    
    year=namevars[1][1:5]
    day=namevars[1][5:]
    H=namevars[2][1:3]
    V=namevars[2][4:]    
    
    return [day, year, H, V]
    
#MODIStilecorner(H,V) calculates the latitude and longitude of the corners that define a MODIS tile
def MODIStilecorner(H,V):
    #Compute lat and lon in radians, using formulas from Active Fire Documentation
    #Found in page 27 of https://lpdaac.usgs.gov/sites/default/files/public/product_documentation/mod14_user_guide.pdf
    R=6371007.181
    T=1111950
    xmin= -20015109
    ymax= 10007555    
    
    lat=(ymax-V*T)/R
    print str(lat) + " latitude"
    coslat=math.cos(lat)
    print str(coslat) + " cosine of latitude"
    lon=(H*T+xmin)/(R*coslat)
    #Convert output to degrees
    lat=lat*180/math.pi
    lon=lon*180/math.pi
    return (lat,lon)

def writeprm(infolder,outfolder,day):
    input=""
    counter=0
    for filename in glob.glob(infolder+"\\*.*"+day+".*.*.*.hdf"):
        if counter<180:
            counter+=1
            print str(filename)
            input = input+str(filename)+"|"
        elif counter==180:
            counter+=1  
            print str(filename)
            input = input+str(filename)          
            
            # Input is the list of hdfs to process
    output = outfolder + "\\stitch" + day # Output is the pathname to the output prm file
    # Hard code a parameter file with unix style EOL.
    f = open(output + ".prm",'wb') # Write a parameter file for the granule
    f.write('\n')
    f.write('NUM_RUNS = 1\n')
    f.write('\n')
    f.write('BEGIN\n')
    f.write('NUMBER_INPUTFILES='+str(180)+'\n')
    f.write('INPUT_FILENAMES = ')
    f.write(input)
    f.write('\n')
    f.write('OBJECT_NAME = MODIS_Grid_Daily_Fire|\n')
    f.write('FIELD_NAME = FireMask|\n')
    f.write('BAND_NUMBER = 1\n')
    f.write('SPATIAL_SUBSET_UL_CORNER = ( 90.0 -180.0 )\n')
    f.write('SPATIAL_SUBSET_LR_CORNER = ( -90.0 180.0 )\n')
    f.write('OUTPUT_OBJECT_NAME = MODIS_Grid_Daily_Fire|\n')
    f.write('OUTGRID_X_PIXELSIZE = 0.041666667\n')
    f.write('OUTGRID_Y_PIXELSIZE = 0.041666667\n')
    f.write('OUTPUT_FILENAME = ')
    f.write(output)
    f.write('_out.tif\n')
    f.write('SAVE_STITCHED_FILE=YES\n')
    f.write('OUTPUT_STITCHED_FILENAME=')
    f.write(output)
    f.write('_stitch.hdf')
    f.write('RESAMPLING_TYPE = NN\n')
    f.write('OUTPUT_PROJECTION_TYPE = SIN\n')
    f.write('OUTPUT_PROJECTION_PARAMETERS = ( 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0  )\n')
    f.write('OUTPUT_TYPE = GEO\n')
    f.write('END\n')
    f.write('\n')
    f.close()

    parameters = input + ".prm"    
    
    
    
#End of program
    
    

##------------define converter-----------
##################################################
### Step 1: Convert 1 month of hdf files to tif ##
##################################################
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
                f.write('INPUT_FILENAMES = ')
                f.write(input)
                f.write('\n')
                f.write('OBJECT_NAME = MODIS_Grid_Daily_Fire|\n')
                f.write('FIELD_NAME = FireMask|\n')
                f.write('BAND_NUMBER = 1\n')
                f.write('SPATIAL_SUBSET_UL_CORNER = ( 90.0 -180.0 )\n')
                f.write('SPATIAL_SUBSET_LR_CORNER = ( -90.0 180.0 )\n')
                f.write('OUTPUT_OBJECT_NAME = MODIS_Grid_Daily_Fire|\n')
                f.write('OUTGRID_X_PIXELSIZE = 0.041666667\n')
                f.write('OUTGRID_Y_PIXELSIZE = 0.041666667\n')
                f.write('OUTPUT_FILENAME = ')
                f.write(output)
                f.write('_out.tif\n')
                f.write('SAVE_STITCHED_FILE=YES\n')
                f.write('OUTPUT_STITCHED_FILENAME=')
                f.write(output)
                f.write('_stitch.hdf')
                f.write('RESAMPLING_TYPE = NN\n')
                f.write('OUTPUT_PROJECTION_TYPE = SIN\n')
                f.write('OUTPUT_PROJECTION_PARAMETERS = ( 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0  )\n')
                f.write('OUTPUT_TYPE = GEO\n')
                f.write('END\n')
                f.write('\n')
                f.close()
    
                parameters = input + ".prm"
    
                callheg = "C:/HEGtools2/HEG_Win/bin/swtif.exe -P " + parameters
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
##----------- end define converter--------

#(testlat,testlong)=MODIStilecorner(18,4)
#print (testlat, testlong)

#[day,year,H,V]=MODIStilename("MOD14A1.A2000049.h18v00.006.2015041132252.hdf")
#print str([day,year,H,V])

#filelist=glob.glob("G:\\Aldeco\\particulates\\data\\MODIS_fire\\2000\\*"+str(year)+day+"*.hdf")
#for filename in filelist:
    #print filename
#print len(filelist)

##parameterfile="C:\\HEGtools2\\HEG\\HEG_Win\\bin\\HegGridStitch.prm_mturner"
#parameterfile="G:\\Aldeco\\particulates\\data\\manual\\testhdf\\col18\\parameters\\stitchcol18E_gridstitch.prm"
hdffile="S:\\particulates\\data_processing\\data\\MODIS_FIRE\\manual\\source\\single\\MOD14A1.A2000049.h00v08.006.2015041132347.hdf"
resampletool="C:\\HEGtools2\\HEG\\HEG_Win\\bin\\resample.exe -P "
grid_stitchtool= "C:\\HEGtools2\\HEG\\HEG_Win\\bin\\subset_stitch_grid.exe -P "
hegtool= "C:\\HEGtools2\\HEG\\HEG_Win\\bin\\hegtool -s "

#os.environ["MRTDATADIR"] = "C:\\HEGtools2\\HEG\\HEG_Win\\data" # Set environment variables for HEG tool
#os.environ["MRTBINDIR"] = "C:\\HEGtools2\\HEG\\HEG_Win\\bin" # Set environment variables for HEG tool
#os.environ["PGSHOME"] = "C:\\HEGtools2\\HEG\\HEG_Win\\TOOLKIT_MTD" # Set environment variables for HEG tool
#os.environ["HEGUSER"] = "mturner1" # Set environment variables for HEG tool
#os.environ["PWD"] = "G:\\Aldeco\\particulates\\data\\manual\\temp" # Set environment variables for HEG tool

#print os.environ["MRTDATADIR"] 
#print os.environ["MRTBINDIR"] 
#print os.environ["PGSHOME"] 
##print os.environ["HEGUSER"] 
##print os.environ["PWD"] 

day ="049"
outfolder="G:\\Aldeco\\particulates\\data\\MODIS_fire\\2000\\prmfiles"
infolder="G:\\Aldeco\\particulates\\data\\MODIS_fire\\2000"

#parameterfile = outfolder + "\\stitch" + day +".prm -standalone"
parameterfile = "G:\\Aldeco\\particulates\\data\\manual\\testhdf\\col18\\parameters\\stitchcol18E_gridstitch.prm"

print parameterfile

writeprm(infolder , outfolder, day )

command=hegtool+hdffile
print str(command)

retcode=subprocess.call(command, shell=False)
print str(retcode)
#subprocess.call("C:\\HEGtools2\\HEG_Win\\bin\\hegtool.exe -h " + hdffile +" -standalone", shell=False)

