# ---------------------------------------------------------------------------
# rasters.py
# -------- #
# Description: This file holds functions that manipulate/process rasters

# created: June 2 2017 by Lorenzo
# last modified: July 12 2017 by Marcel
# ---------------------------------------------------------------------------

import os, glob, arcpy, shutil, sys, subprocess, time, logging
from arcpy import env

arcpy.env.overwriteOutput = True

def aggregate(expath,output_raster):
# mosaics a set of .tifs, averaging if they overlap, and saves the result
# This function is meant to aggregate rasters both in time and space, depending on the set of rasters we feed it
    
#Inputs:
    #expath: pathname that defines which .tifs are aggregated. This is fed to glob.glob, so can include wildcard characters.
    #output_raster: file location to save output
    
    #Temporary file locations
    temp=os.path.dirname(expath)+"temp"
    gdb=temp+"\\geodatabase.gdb"
    env.workspace = temp
    env.scratchWorkspace=temp
    
    try:
        #Write list of rasters to aggregate
        cwdir=os.getcwd()
        print cwdir
        rasters=glob.glob(expath)
        print str(expath)
        print rasters
        
        #Concatenate list into a single string to feed into arcpy.RasterToGeodatabase
        inputs=';'.join(rasters)
        print inputs
        
        # Define spatial reference (can become input to the function in the future)
        sr = arcpy.SpatialReference("..\\..\\..\\data\\projections\\WGS 1984.prj") 
        
        #Set up temporary directories
        shutil.rmtree(temp,ignore_errors=True)
        os.mkdir(temp)
        
        #Create geodatabase and raster catalog, and move rasters in list to said catalog.
        arcpy.CreateFileGDB_management(temp, "geodatabase", "CURRENT")
        arcpy.CreateRasterCatalog_management(gdb , "catalog", sr, sr, "", "0", "0", "0", "UNMANAGED", "")
        arcpy.RasterToGeodatabase_conversion(inputs, gdb+ "\\catalog")
        arcpy.CalculateDefaultGridIndex_management(gdb+ "\\catalog")
        
        #Aggregate rasters in catalog to mean raster
        #arcpy.RasterCatalogToRasterDataset_management(gdb+"\\catalog", output_raster, "", "MEAN", "FIRST", "", "NONE", "16_BIT_SIGNED", "NONE", "NONE", "", "") 
        
        # Second option, which includes real numbers (not only integer-type output)
        arcpy.RasterCatalogToRasterDataset_management(gdb+"\\catalog", output_raster, "", "MEAN", "FIRST", "", "NONE", "32_BIT_FLOAT", "NONE", "NONE", "", "") 
       
        #Remove temporary directories
        shutil.rmtree(temp,ignore_errors=True)
        
        print inputs
        
    except Exception as e:
        # If an error occurred, print line number and error message
        tb = sys.exc_info()[2]
        print "An error occured on line %i" % tb.tb_lineno
        print str(e)

def dummyascii(lowerval, higherval, onvalue, outpath):
#Writes an ASCII file usable by Arc's "Reclass by ASCII" tool.
#Output file converts an integer raster to a dummy raster. Ideally, the input raster takes sequential values.
#Inputs:
    #lowerval: lowest value taken by the input raster's cells
    #higherval: largest value taken by the input raster's cells
    #onvalue: Single numerical value mapped to 1. All other values are mapped to 0.
    #outpath: Absolute full path to output .txt
    
    #List with all input raster's values
    inlist=range(lowerval,higherval+1)
    
    #List with mapped values
    outlist=[int(x==onvalue) for x in inlist]    
    
    #Write ASCII file in Arc's expected format
    with open(outpath, 'w') as asciifile:
        for i in range(len(inlist)):
            asciifile.write(str(inlist[i])+' : '+str(outlist[i])+"\n")
            
def raster2ubergrid(input_raster, outpath, extent, outprojection):
    
#Converts a raster to homogeneous ubergrid, using the input extent and projection.
#This function expects an ubergrid setting file, written by make_xy_extent.py

#Ubergrid extent and settings for the particulates project are found in (starting from a folder within dofiles)
    #extent = "..\\..\\..\\data\\GPW4\\generated\\extent\\extent.shp"
    #outprojection = "..\\..\\..\\data\\projections\\WGS 1984.prj"    
    
#Inputs:
    #input_raster: raster to convert
    #outpath: full path (including filename and extension) for output raster
    #extent: ubergrid extent shapefile. Input will be clipped to this.
    #outprojection: .prj with output projection
    
    #Extract input directory and basename
    base=os.path.basename(input_raster)
    in_name=os.path.splitext(base)[0]
    
    temp_dir=os.path.dirname(outpath)+"\\"+in_name+"_temp"
    os.mkdir(temp_dir)
    
    #Name auxiliary and output rasters
    raster_proj = temp_dir+"\\prj.tif"
    raster_clip = outpath
    #"..\\..\\data\\MODIS_AOD\\manual\\aqua2002avg_ProjectRaster_Cl.tif"
    
    #Set up output raster settings as a dictionary. These come from settings.txt, written in make_xy_extent.py
    settingsdict=ubergridsettings()
    #with open("..\\..\\..\\data\\projections\generated\settings.txt", 'r') as settingfile:
        #templines=settingfile.readlines()
        #lines = [i.replace('\n','') for i in templines]
        #for linecounter in range(len(lines)):        
            #if linecounter % 2 ==0:
                ##print linecounter
                #settingsdict[str(lines[linecounter])]=str(lines[linecounter+1])
    #print settingsdict
    
    #Project raster using target projection, cell size, and reference point. 
    cell_size=settingsdict['CELLSIZEX']+" "+settingsdict['CELLSIZEY']
    regist_point=settingsdict['LEFT']+" "+settingsdict['TOP']
    arcpy.ProjectRaster_management(in_raster=input_raster, out_raster=raster_proj, 
                                  out_coor_system=outprojection, 
                                  resampling_type="NEAREST",
                                  cell_size=cell_size, 
                                  geographic_transform="",
                                  Registration_Point=regist_point)
    #Clip raster to ubergrid extent
    arcpy.Clip_management(raster_proj, "", raster_clip, extent, "-9999", "NONE", "MAINTAIN_EXTENT")
    
    #Remove temporary files.
    shutil.rmtree(temp_dir, ignore_errors=True)
    
def ubergridsettings():
#Reads ubergrid settings from "..\\..\\..\\data\\projections\generated\settings.txt" and returns them as a python dictionary
#Settings can be accessed with the normal dictionary syntax, e.g. columno=settingsdict["COLUMNCOUNT"]
    #Available settings are:
    #TOP: Topmost raster coordinate (in ubergrid units, probably degrees)
    #LEFT: Leftmost raster coordinate
    #RIGHT: Rightmost raster coordinate
    #BOTTOM: Bottom raster coordinate
    #CELLSIZEX: Horizontal size of pixel (in ubergrid units) 
    #CELLSIZEY: Vertical size of pixel
    #COLUMNCOUNT: Number of raster columns
    #ROWCOUNT: Number of raster rows

    settingsdict={}

    with open("..\\..\\..\\data\\projections\generated\settings.txt", 'r') as settingfile:
        templines=settingfile.readlines()
        lines = [i.replace('\n','') for i in templines]
        for linecounter in range(len(lines)):        
            if linecounter % 2 ==0:
                print linecounter
                settingsdict[str(lines[linecounter])]=str(lines[linecounter+1])
    return settingsdict
 
 ## ----------------------------------------------------------------------------------------------##
 
 
def dta2raster(inputfile,datatype, outputfolder):
    
    # ---------------------------------------------------------------------------
    # dta2raster
    #
    # (0) Prepares a dta file that contains a variable named either "v1" or "uber_code"
    # to be converted. All the rasters will be saved in outputfolder (including log)
    # (1) Converts every variable (except uber_code) in the original dta to an ascii file, saved in the
    # folder ascii
    # (2) Converts the ascii file to raster, using ubergrid settings.
    #
    # Created by Marcel in 6/21/2017, based on table2raster
    # Last modified by Marcel in 6/23/2017
    # ---------------------------------------------------------------------------
    
    # Try to create outputfolder. If it exists, proceed.
    try:
        os.mkdir(outputfolder)
    except Exception:
        print("Output folder already exists. Proceed.")
    
    #Set up logging
    logging.basicConfig(format='%(asctime)s %(message)s', filename=outputfolder+'\\dta2raster.log', filemode='w', level=logging.DEBUG)
    logging.info('Starting dta2raster.py.')    

    # Extract folder where inputfile is
    inputfolder = os.path.dirname(os.path.abspath(inputfile))+"\\"
    
    # dta preparation folder and dofile
    shutil.rmtree(outputfolder+"\\temporary_dtas", ignore_errors=True)
    os.mkdir(outputfolder+"\\temporary_dtas")
    
    shutil.rmtree(outputfolder+"\\mapping_str_variables", ignore_errors=True)
    os.mkdir(outputfolder+"\\mapping_str_variables")
    
    #Set target dofile
    dofile = "..\\mylibrary\\prepare_dta.do"
    
    # Generate dta spawns:
    cmd = ["C:\Program Files (x86)\Stata13\StataMP-64", "do", dofile, outputfolder, inputfile]    
    subprocess.call(cmd, shell = 'true')     
    logging.info('Done creating dta spawns.')
        
    
    # Provide the folder that contains the dtas
    storefolder = outputfolder+"\\ubergrid_"+os.path.splitext(os.path.basename(inputfile))[0]+"\\"
    
    # Create folders
    shutil.rmtree(storefolder, ignore_errors=True)
    os.mkdir(storefolder)
    # Generate ascii folder
    os.mkdir(storefolder+"ascii")
    
    
    ## (1) Generate tables - using stata transfer
    
    print("Starting conversion to txt files...")
    for dta in glob.glob(outputfolder+"\\temporary_dtas\\*.dta"):
        
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
    number_dtas = 0
    number_fails = 0
    
    
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
        try:
            arcpy.ASCIIToRaster_conversion(asc, outputraster, datatype)  

            # Define projection
            spatialref = arcpy.Describe(ugrid).spatialReference    
            arcpy.DefineProjection_management(outputraster, spatialref)
          
            # Restore directory:
            os.chdir(storefolder)
        
            t1 = time.clock()
            logging.info('The variable %s was converted into a raster file in %s seconds.', str(name), str(t1-t0))
            
            print ("Done with %s" %name)
            
            number_dtas+=1
        except Exception:
            #Print error message
            logging.info('An error occurred whyle converting %s .', str(name))
            number_fails+=1
            
            # Restore directory:
            os.chdir(storefolder)            
            
        
        
    logging.info("%d dta files (variables) were converted to raster" %number_dtas) 
    logging.info("Failed to convert %d dta files (variables) to raster" %number_fails)   
    
    ## Final cleaning

    try:
        shutil.rmtree(outputfolder+"\\temporary_dtas")
    except Exception:
        logging.info("Failed to delete temporary_dta folder." %number_fails)
        
    print("Done with dta2raster. Use your rasters wisely.")   
 
if __name__=='__main__':
    #This section of the code is meant to test-run functions and should generally be empty.
    print("Imported raster routines.")