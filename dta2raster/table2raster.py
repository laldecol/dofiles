# ---------------------------------------------------------------------------
# table2raster.py 
#
# (1) Convert stata lists to ascii for UFD paper variables
# (2) Convert the ascciis to rasters
#
# la  September 19, 2016 
#   Based on Matt's program rasterize_UFD2.py
# ---------------------------------------------------------------------------
# Import system modules
import logging, arcpy, os, sys
from arcpy import env
from multiprocessing import Pool

# Set environment settings
arcpy.env.overwriteOutput = True
arcpy.env.projectCompare = "Full"
arcpy.CheckOutExtension("spatial")
#env.workspace = wspace	   #Set workspace 
#env.scratchworkspace = wspace  #Set scratch workspace

print "...."
print "....starting table2raster"
print "...."

vnames=sys.argv[1:]
print str(sys.argv[1:])
currdir=os.getcwd()

#pause=raw_input("Press Enter to Continue")

for vname in vnames:
    print "...."
    print "....starting table2raster " + vname
    print "...."

    #Set up output raster settings as a dictionary. These come from settings.txt, written in make_xy_extent.py
    settingsdict={}
    with open("..\\..\\..\\data\\projections\generated\settings.txt", 'r') as settingfile:
        templines=settingfile.readlines()
        lines = [i.replace('\n','') for i in templines]
        for linecounter in range(len(lines)):        
            if linecounter % 2 ==0:
                print linecounter
                settingsdict[str(lines[linecounter])]=str(lines[linecounter+1])
    print settingsdict
    
    os.chdir("..\\..\\..\\data\\dta2raster")
    #asc   = "maps/"+ vname + ".txt"  #Output text ASCII text file
    asc   = os.getcwd() + "\\maps\\"+ vname + ".txt"  #Output text ASCII text file
    rst   = os.getcwd() + "\\maps\\" + vname + ".tif" #Output raster file
    
    in_txt  = open("temp/ready2map_"+vname+".txt", "r")     #Input list of STATA-made ubergrid
    
    ugrid = "..\\..\\..\\data\\GPW4\\generated\\projected\\projected_aggregated_gpw_2010.tif"  #Copy of ubergrid
    wspace   = "workspaces\\" + vname
    
    csize   = settingsdict['CELLSIZEX']  #raster cell width in metres
    width   = settingsdict['COLUMNCOUNT']   #width of ubergrid in cells (990m)
    height  = settingsdict['ROWCOUNT']   #height of ubergrid in cells (990m)
    nodata  = "-9999"  #value given to cells with no data
    l_ext   = settingsdict['LEFT'] #Extent of uberclip on left
    b_ext   = settingsdict['BOTTOM']   #Extent of uberclip on bottom    
    
    writeout = open(asc, "w")
    
    #First 7 lines to write
    first7 = "NCOLS " + str(width) + "\nNROWS " + str(height) + "\nXLLCORNER " + l_ext+ "\nYLLCORNER " + b_ext + "\nCELLSIZE " + csize + "\nNODATA_VALUE " + nodata + "\n" 

    try:

        print "Started writing lines to text file for " + vname

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
        writeout.close()
        in_txt.close()

        print "Finished writing lines to text file for " + vname

        print "Started converting ASCII to Raster for " + vname + " dir = "+ os.getcwd()
        print asc
        print rst
        #pause=raw_input("Check values of asc and rst")
        arcpy.ASCIIToRaster_conversion(asc, rst, "FLOAT")	
        print "Finished converting ASCII to Raster for " + vname
        print "Started defining projection of Raster for " + vname
        spatialref = arcpy.Describe(ugrid).spatialReference    #Get spatial reference information of ubergrid
        arcpy.DefineProjection_management(rst, spatialref)
        print "Finished defining projection of Raster for " + vname
        
        #print "Started adding colour map for " + vname
        #arcpy.AddColormap_management(rst, "", clrmap)
        #print "Finished adding colour map for " + vname

        print "....end rasterize "
        print "...."    
        
    except Exception as e:
        # If an error occurred, print line number and error message
        import traceback, sys
        tb = sys.exc_info()[2]
        print "An error occured on line %i" % tb.tb_lineno
        print str(e)

#pause=raw_input("Press Enter to Continue")

sys.exit("bye")

