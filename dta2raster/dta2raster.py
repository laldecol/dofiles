# ---------------------------------------------------------------------------
# dta2raster.py 
#
# (1) Convert stata lists to ascii file
# (2) Using "table2raster", converts the resulting ascii file into an ubergrid raster
#
# Created by Marcel in 6/21/2017
# ---------------------------------------------------------------------------


# Import system modules
import logging, arcpy, os, sys, shutil, glob, subprocess, time
from arcpy import env

#Set up logging
logging.basicConfig(format='%(asctime)s %(message)s', filename='dta2raster.log', filemode='w', level=logging.DEBUG)
logging.info('Starting dta2raster.py.')


# Provide the folder that contains the dtas

inputfolder = "..\\..\\..\\data\\MODIS_LULC\\generated\\Temp_aggregate_lc_check\\"
storefolder = inputfolder+"ubergrid\\"

# Create folders
shutil.rmtree(storefolder, ignore_errors=True)
os.mkdir(storefolder)
# Generate ascii folder
os.mkdir(storefolder+"ascii")


## (1) Generate tables - using stata transfer

print("Starting conversion to txt files...")
for dta in glob.glob(inputfolder+"*.dta"):
    # Time     
    t0 = time.clock()
    print("...")
    
    # Extract the name
    name =  os.path.splitext(os.path.basename(dta))[0]
    logging.info('Converting %s to a .txt file.' %name)
    
    # Convert to txt (comma delimited for now)
    os.system("st %sdummy_lc_raster2000.dta %s\\ascii\\%s.txt \y" %(inputfolder, storefolder, name))
    
    t1 = time.clock()
    logging.info('The file %s was completed in %s seconds.', str(name), str(t1-t0))    

print("Conversion from dta to ascii was completed. Proceed to step 2.")

## (2) Generate raster - based on table2raster

# Set environment settings
arcpy.env.overwriteOutput = True
arcpy.env.projectCompare = "Full"
arcpy.CheckOutExtension("spatial")


print "Starting conversion to rasters"

#Set up output raster settings as a dictionary. These come from settings.txt, written in make_xy_extent.py
settingsdict={}
with open("..\\..\\..\\data\\projections\generated\settings.txt", 'r') as settingfile:
    templines=settingfile.readlines()
    lines = [i.replace('\n','') for i in templines]
    for linecounter in range(len(lines)):        
        if linecounter % 2 ==0:
            #print linecounter
            settingsdict[str(lines[linecounter])]=str(lines[linecounter+1])

# Collect dictionary settings
csize   = settingsdict['CELLSIZEX']  #raster cell width in metres
width   = settingsdict['COLUMNCOUNT']   #width of ubergrid in cells (990m)
height  = settingsdict['ROWCOUNT']   #height of ubergrid in cells (990m)
nodata  = "-9999"  #value given to cells with no data
l_ext   = settingsdict['LEFT'] #Extent of uberclip on left
b_ext   = settingsdict['BOTTOM']   #Extent of uberclip on bottom 

# Collect any copy of ubergrid
ugrid = "..\\..\\..\\data\\GPW4\\generated\\projected\\projected_aggregated_gpw_2010.tif"  

# Create the directory for ascii ready to read
shutil.rmtree(storefolder+"ascii_rtr\\", ignore_errors=True)
os.mkdir(storefolder+"ascii_rtr\\")

#Change directory
os.chdir(storefolder)
# Collect all ascii files:
asciifiles = glob.glob(os.getcwd()+"\\ascii\\*.txt")
number_dtas = len(asciifiles)
print asciifiles
print str(number_dtas)

for asciifile in asciifiles:
    
    # Define input file
    name = os.path.splitext(os.path.basename(asciifile))[0]
    print name
    in_txt  = open(asciifile, "r")     #Input list of STATA-made ubergrid


    # "Intermediate" and final outputs
    outputraster = os.getcwd()+"\\"+name+".tif"
    asc   = os.getcwd()+"\\ascii_rtr\\"+name+"_rtr.txt"
    print outputraster
 

    # Start creating intermediate file
    print('Creating ascii ready-to-read file %s' %str(name))
    writeout = open(asc, "w")
    
    #First 7 lines to write
    first7 = "NCOLS " + str(width) + "\nNROWS " + str(height) + "\nXLLCORNER " + l_ext+ "\nYLLCORNER " + b_ext + "\nCELLSIZE " + csize + "\nNODATA_VALUE " + nodata + "\n" 

    print ("Started writing lines to text file for %s " %name) 

    writeout.write(first7)	#Write the first 7 lines of the ASCII file that describes the data

    lc = 0 #line count of lines that have been looped through
    wl = 0 #lines from in text that have been written to current line in ascii out
    for line in in_txt:
        lc += 1
        if lc >= 2:
            cell = line.strip("\n")
            writeout.write(cell + " ")  #Write the cell value to the ASCII file
            wl += 1
            if wl == width:
                writeout.write("\n")
                wl = 0
            
    # Close txt files            
    writeout.close()
    in_txt.close()

    ## At this point, we should have a txt whose first 7 collumns belong in the settings, and the rest are the pixel values

    print("Started converting ASCII to Raster for %s"  %name)
    print asc
    print outputraster

    # Execute conversion
    arcpy.ASCIIToRaster_conversion(asc, outputraster, "INTEGER")    # you still have to change this integer

    # Define projection
    spatialref = arcpy.Describe(ugrid).spatialReference    
    arcpy.DefineProjection_management(outputraster, spatialref)
    print ("Finished defining projection of Raster")
    
    print ("Done with %s" %name)

    # Restore directory:
    os.chdir(storefolder)
    
print("%d dta files were converted to raster" %number_dtas)    

