# ---------------------------------------------------------------------------
# hdf2tif.py
# -------- #
# Run time: ~3 seconds per month
#
# Description:
#
# Convert all .HDF files in a folder to .TIF directly (without using HEGTool).
# This tool only works on hdfs that cover all Earth.
#
# (1) Extracts a layer of data from the hdf and converts it to ascii using ArcMap
# (2) Calculates cell size from row/col number and write spatial reference to ASCII
# (3) Converts ASCII, now properly georeferenced, to .tif

# created: Dec 10 2016 by la
# ---------------------------------------------------------------------------

# Import arcpy module
import arcpy, shutil, os, glob

def hdf2tif(filehdf,outfolder,projection):
    
    in_dir=os.path.dirname(filehdf)    
    base=os.path.basename(filehdf)
    basename=os.path.splitext(base)[0]
    
    tempfolder=outfolder+"\\temp"+basename
    os.mkdir(tempfolder)
    
    filetif=tempfolder+"\\in" + basename + ".tif"
    filetxt=tempfolder+"\\in" + basename + ".txt"
    outputtxt=tempfolder+"\\out" + basename + ".txt"
    outputtif=outfolder+"\\" + basename + ".tif"
    
    # Process: Extract Subdataset
    arcpy.ExtractSubDataset_management(filehdf, filetif, "1")
    
    # Process: Raster to ASCII
    arcpy.RasterToASCII_conversion(filetif, filetxt)
    
    #Modify Raster
    with open(filetxt, mode='r') as inascii:
        with open(outputtxt, mode='w') as outascii:
            #Keep first two lines unchanged
            line= inascii.readline()
            outascii.write(line)
            ncols=float(line[14:])
            print ncols
            print 360/ncols
            
            line= inascii.readline()
            outascii.write(line)        
    
            #Change xllcorner=-180 and yllcorner=-90
            line= inascii.readline()
            outascii.write(line[:14]+"-180\n")
            
            line= inascii.readline()
            outascii.write(line[:14]+"-90\n")  
            
            #Change cellsize to keep proper extent
            line= inascii.readline()
            outascii.write(line[:14]+str(float(360/ncols))+"\n")
            
            shutil.copyfileobj(inascii, outascii)    
            
    # Process: ASCII to Raster
    arcpy.ASCIIToRaster_conversion(outputtxt, outputtif, "INTEGER")
    
    # Process: Define Projection
    arcpy.DefineProjection_management(outputtif, "GEOGCS['GCS_WGS_1984',DATUM['D_WGS_1984',SPHEROID['WGS_1984',6378137.0,298.257223563]],PRIMEM['Greenwich',0.0],UNIT['Degree',0.0174532925199433]]")

    shutil.rmtree(tempfolder)
    
# Local variables:
#filehdf = "S:\\particulates\\data_processing\\data\\lor_manual\\fires\\MOD14CMH.201001.005.01.hdf"
filetif = "S:\\particulates\\data_processing\\data\\lor_manual\\fires\\temp\\input.tif"
input_TXT = "S:\\particulates\\data_processing\\data\\lor_manual\\fires\\temp\\input.txt"
output_tif = "S:\\particulates\\data_processing\\data\\lor_manual\\fires\\temp\\output.tif"
projection = "S:\particulates\data_processing\data\projections\WGS 1984.prj"
output_TXT = "S:\\particulates\\data_processing\\data\\lor_manual\\fires\\temp\\output.txt"


outputfolder="S:\particulates\data_processing\data\MODIS_FIRE\generated\monthly"
inputfolder="S:\particulates\data_processing\data\MODIS_FIRE\source\monthly"

for filehdf in glob.glob(inputfolder+"\\*.hdf"):
    print "Working on " + str(filehdf)
    hdf2tif(filehdf,outputfolder,projection)
