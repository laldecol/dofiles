# ---------------------------------------------------------------------------
# hdf2tif.py
# -------- #
# Run time: ~3 seconds per month
#
# Description:
#
# (1) Convert all .HDF files in a folder to .TIF directly (without using HEGTool).
#
# created: Dec 10 2016 by la
# ---------------------------------------------------------------------------

# Import arcpy module
import arcpy, shutil, os, glob, math

arcpy.env.overwriteOutput = True

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
    #Corner is top left
    #Found in page 27 of https://lpdaac.usgs.gov/sites/default/files/public/product_documentation/mod14_user_guide.pdf
    R=6371007.181
    T=1111950
    xmin= -20015109
    ymax= 10007555    
    colno= 1200
    
    lat=(ymax-V*T)/R
    print str(H)+ ","+str(V)+": "+str(lat) + " latitude"
    coslat=math.cos(lat)
    print str(coslat) + " cosine of latitude"
    lon=(H*T+xmin)/(R*coslat)
    #Convert output to degrees
    lat=lat*180/math.pi
    lon=lon*180/math.pi
    return (lat,lon)

def tilehdf2tif(filehdf,outfolder,projection,subdatanum,bandnum):
    
    (day, year, H,V)=MODIStilename(filehdf)    
    
    in_dir=os.path.dirname(filehdf)    
    base=os.path.basename(filehdf)
    basename=os.path.splitext(base)[0]
    
    tempfolder=outfolder+"\\temp"+basename
    shutil.rmtree(tempfolder, ignore_errors=True)
    os.mkdir(tempfolder)
    
    filetif=tempfolder+"\\in" + basename + ".tif"
    filetxt=tempfolder+"\\in" + basename + ".txt"
    outputtxt=tempfolder+"\\out" + basename + ".txt"
    outputtif=outfolder+"\\d" + day+"y"+year+"H"+H+"V"+V + ".tif"
    fileband = filetif +"\\Band_"+bandnum
    bandtif=tempfolder+"\\in"+basename+"band"+bandnum+".tif"
    
    # Process: Extract Subdataset
    arcpy.ExtractSubDataset_management(filehdf, filetif, "0")
    
    ###
    #bandnum=str(1)
    
    #ModBldBand_1 = "S:\\particulates\\data_processing\\data\\MODIS_FIRE\\manual\\generated\\single\\Band"+bandnum+".tif"
    
    ## Process: Extract Subdataset
    #arcpy.ExtractSubDataset_management(filehdf, rasterstif, "0")
    
    ## Process: Copy Raster
    arcpy.CopyRaster_management(fileband, bandtif, "", "", "0", "NONE", "NONE", "8_BIT_UNSIGNED", "NONE", "NONE")    
    ###
    
    # Process: Raster to ASCII
    arcpy.RasterToASCII_conversion(fileband, filetxt)
    
    #Obtain corner coordinates
    (lly,llx)=MODIStilecorner(int(H), int(V)+1)
    (ury, urx)=MODIStilecorner(int(H)+1, int(V))
    (uly, ulx)=MODIStilecorner(int(H), int(V))


    ncols=1200
    cellsize=float((uly-lly)/ncols)
    print cellsize
    #uly='%d' % (uly)
    #ulx='%d' % (ulx)    
    #ury='%d' % (ury)
    #urx='%d' % (urx)
    #llx='%d' % (llx)
    #lly='%d' % (lly)    
    
    #print "Upper left y "+uly 
    #print "Lower left y "+lly     
    
    #Modify Raster
    with open(filetxt, mode='r') as inascii:
        with open(outputtxt, mode='w') as outascii:
            #Keep first two lines unchanged
            line= inascii.readline()
            outascii.write(line)
            
            print "Number of input columns " + str(ncols)
            print "Implies cell size "+str(cellsize)
            
            line= inascii.readline()
            outascii.write(line)        
    
            #Change xllcorner=-180 and yllcorner=-90
            line= inascii.readline()
            outascii.write(line[:14]+str(llx)+"\n")
            
            line= inascii.readline()
            outascii.write(line[:14]+str(lly)+"\n")
            
            #Change cellsize to keep proper extent
            line= inascii.readline()
            outascii.write(line[:14]+str(cellsize)+"\n")
            
            shutil.copyfileobj(inascii, outascii)    
            
    # Process: ASCII to Raster
    print "Attempting to write to "+outputtif
    
    arcpy.ASCIIToRaster_conversion(outputtxt, outputtif, "INTEGER")
    
    # Process: Define Projection
    arcpy.DefineProjection_management(outputtif, "GEOGCS['GCS_WGS_1984',DATUM['D_WGS_1984',SPHEROID['WGS_1984',6378137.0,298.257223563]],PRIMEM['Greenwich',0.0],UNIT['Degree',0.0174532925199433]]")

    shutil.rmtree(tempfolder)


# Local variables:
#filehdf = "S:\\particulates\\data_processing\\data\\MODIS_FIRE\\manual\\source\\single\\MOD14A1.A2000049.h00v08.006.2015041132347.hdf"

projection = "S:\\particulates\\data_processing\\data\\projections\\WGS 1984.prj"
outputfolder="S:\\particulates\\data_processing\\data\\MODIS_FIRE\\manual\\generated\\day"
inputfolder="S:\\particulates\\data_processing\\data\\MODIS_FIRE\\manual\\source\\day"
subdatanum="0"
bandnum="1"

#extractband inputs
filehdf= "S:\\particulates\\data_processing\\data\\MODIS_FIRE\\manual\\source\\single\\MOD14A1.A2000049.h00v08.006.2015041132347.hdf"


for filehdf in glob.glob(inputfolder+"\\*.hdf"):
    print "Working on " + str(filehdf)
    #hdf2tif(filehdf,outputfolder,projection)
    tilehdf2tif(filehdf, outputfolder, projection, subdatanum, bandnum)
    
