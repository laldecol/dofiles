# ---------------------------------------------------------------------------
# dta2raster.py 
# (0) Prepare a dta file that contains a variable named either "v1" or "uber_code"
# to be converted. All the rasters will be saved in a folder created in the path of the
# original file with the name of ubergrid_(name of dta file).
# (1) Convert stata lists to ascii file
# (2) Using "table2raster", converts the resulting ascii file into an ubergrid raster
#
#INPUTS:
# # inputfile - any dta file, provided that it has its ubergrid code variable named either "v1" or "uber_code". Strings are automatically
# categorized, and the mapping (categories <-> corresponding number) is saved in a folder named mapping_str_variables.
# # datatype - it is the type of raster that will be created. It applies to all the variables in the dta file. If in doubt, 
#use float. INTEGER should be used when the dta is categorized.
#
#
# THIS CODE PERFORMS THE FOLLOWING PROCEDURES:
# 1 - Breaks down the target dta file into several spawns (one for each variable, except uber_code), saves them in temporary folder.
# This is done by the dofile prepare_dta
# 2 - Converts the spawns, one by one, to ascii.
# 3 - Take the ascii spawns and modify them, using ubergrid settings, so that they can be used by AsciitoRaster
# 4 - Convert them all to rasters.
# Created by Marcel in 6/21/2017
# Last modified by Marcel in 6/23/2017
# ---------------------------------------------------------------------------


# Import system modules
import logging, arcpy, os, sys, shutil, glob, subprocess, time
from arcpy import env

def dta2raster(inputfile,datatype):
    
    #Set up logging
    logging.basicConfig(format='%(asctime)s %(message)s', filename='dta2raster.log', filemode='w', level=logging.DEBUG)
    logging.info('Starting dta2raster.py.')    

    # Extract folder where inputfile is
    inputfolder = os.path.dirname(os.path.abspath(inputfile))+"\\"
    

    # dta preparation folder and dofile
    shutil.rmtree(inputfolder+"temporary_dtas", ignore_errors=True)
    os.mkdir(inputfolder+"temporary_dtas")
    dofile = "S:\particulates\data_processing\dofiles_mp\dofiles\dta2raster\prepare_dta.do"
    
    # Generate dta spawns:
    cmd = ["C:\Program Files (x86)\Stata13\StataMP-64", "do", dofile, inputfolder, inputfile]    
    subprocess.call(cmd, shell = 'true')     
    logging.info('Done creating dta spawns.')
        
    
    # Provide the folder that contains the dtas
    storefolder = inputfolder+"ubergrid_"+os.path.splitext(os.path.basename(inputfile))[0]+"\\"
    
    # Create folders
    shutil.rmtree(storefolder, ignore_errors=True)
    os.mkdir(storefolder)
    # Generate ascii folder
    os.mkdir(storefolder+"ascii")
    
    
    ## (1) Generate tables - using stata transfer
    
    print("Starting conversion to txt files...")
    for dta in glob.glob(inputfolder+"temporary_dtas\\*.dta"):
        
        # Time     
        t0 = time.clock()
        print("...")
        
        # Extract the name
        name =  os.path.splitext(os.path.basename(dta))[0]
        logging.info('Converting %s to a .txt file.' %name)
        
        # Convert to txt (comma delimited for now)
        os.system("st %s %s\\ascii\\%s.txt \y" %(dta, storefolder, name))
        
        t1 = time.clock()
        logging.info('The file %s was converted to ascii in %s seconds.', str(name), str(t1-t0))    
    
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
    
    logging.info('Successgully collected ubergrid settings.')
    
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
    
    for asciifile in asciifiles:
        # Time     
        t0 = time.clock()    
        
        # Define input file
        name = os.path.splitext(os.path.basename(asciifile))[0]
        in_txt  = open(asciifile, "r")     #Input list of STATA-made ubergrid
        
        logging.info('Starting conversion of %s to a raster file.' %name)
    
        # "Intermediate" and final outputs
        outputraster = os.getcwd()+"\\"+name+".tif"
        asc   = os.getcwd()+"\\ascii_rtr\\"+name+"_rtr.txt"
    
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
    
        # Execute conversion
        arcpy.ASCIIToRaster_conversion(asc, outputraster, datatype)  
    
        # Define projection
        spatialref = arcpy.Describe(ugrid).spatialReference    
        arcpy.DefineProjection_management(outputraster, spatialref)
        
        print ("Done with %s" %name)
    
        # Restore directory:
        os.chdir(storefolder)
        
        t1 = time.clock()
        logging.info('The variable %s was converted into a raster file in %s seconds.', str(name), str(t1-t0))
        
    logging.info("%d dta files (variables) were converted to raster" %number_dtas)    
    
    ## Final cleaning
    
    shutil.rmtree(inputfolder+"temporary_dtas")
    
    print("Done with dta2raster. Use your rasters wisely.")   
    
    

if __name__ == '__main__':    
    
    ###############################Please Imform Function Inputs#######################################
    # Define input folder (ouput automatically stored within it)
    inputfile = "S:\\particulates\\data_processing\\analysis\\AODvariation10k\\miss_climate\\nonmissingclimate.dta"
    # Define type of data ("FLOAT" or "INTEGER")
    datatype = "FLOAT"
    ###################################################################################################    
    
    dta2raster(inputfile, datatype)
    
