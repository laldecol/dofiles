# ---------------------------------------------------------------------------
# resamplesum1kto5k.py
# -------- #
# Run time: <1 min per raster
#
# 
# Description: Takes a 1k raster and returns a 5k raster with cell
# values approximately equal to the sum of the contained 1k cell values.
# created: September 23 2016 by la
# last modified: April 25 2017 by la
# ---------------------------------------------------------------------------

# Import arcpy module
import arcpy, shutil, os, glob, time, logging

# Check out any necessary licenses
arcpy.CheckOutExtension("spatial")
arcpy.env.overwriteOutput = True

def resamplesum(inputraster, outfolder):
    
    #Extract input directory and basename
    base=os.path.basename(inputraster)
    out_name=os.path.splitext(base)[0]    
    tempfolder=outfolder+"\\temp"

    #Set up directories    
    #shutil.rmtree(tempfolder, ignore_errors=True)
    #os.mkdir(tempfolder)
    
    #Set file names
    #aggraster = tempfolder+"\\"+out_name+"agg.tif"
    aggraster = outfolder+"\\"+out_name+".tif"
    
    # Aggregate groups of 25 1k cells together by summing their values.
    arcpy.gp.Aggregate_sa(inputraster, aggraster, "5", "SUM", "EXPAND", "DATA")
    
    # Process: Project Raster
    #arcpy.Resample_management(aggraster, projraster, "5000 5000", "NEAREST")
    
    #Clean existing files
    #shutil.rmtree(tempfolder, ignore_errors=True)

if __name__=='__main__':
    # Local variables:
    #ubergrid_ref = "..\\..\\data\\GPW4\\generated\\projected\\projected_aggregated_gpw_2000.tif"
    #projection = "..\\..\\data\\projections\\WGS 1984.prj"
    outfolder="..\\..\\data\\MODIS_FIRE\\generated\\yearly"
    #inputraster="S:\\particulates\\data_processing\\data\\MODIS_FIRE\\generated\\yearly\\1k\\Fire2000.tif"
    #shutil.rmtree("..\\..\\data\\GPW4\\generated\\ubergrid", ignore_errors=True)
    #os.mkdir("..\\..\\data\\GPW4\\generated\\ubergrid")
    infolderpattern="..\\..\\data\\MODIS_FIRE\\generated\\yearly\\1k\\*.tif"
    
    #Set up logging
    logging.basicConfig(format='%(asctime)s %(message)s', filename='resamplesum1kto5k.log', filemode='w', level=logging.DEBUG)
    logging.info('Starting resamplesum1kto5k.py')
       
       
    t0=time.clock()
    for raster in glob.glob(infolderpattern):    
        resamplesum(raster, outfolder)
        print "Done aggregating " + raster
    t1=time.clock()
    
    logging.info('Done processing files of the form %s', infolderpattern)
    logging.info('Done with resamplesum1kto5k.py')
    logging.info('Aggregated %s rasters in %s minutes.', len(glob.glob(infolderpattern)), str((t1-t0)/60))
    
    
    