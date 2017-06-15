# ---------------------------------------------------------------------------
# gridhdf2tif.py
# -------- #
# Run time: ~5 hours per year
#
# Description: This script converts all .hdf files in a folder to .tifs
#
# created: Feb 21, 2017 by la
# last modified: Mar 29, 2017 by la
# ---------------------------------------------------------------------------

# Import modules
import arcpy, shutil, os, glob, subprocess, time, logging
from functools import partial
from multiprocessing import Pool

def MODIStilename(filename): 
    #This function takes a MODIS tile file and extracts day, year, and tile information from its name
    namevars= filename.split(".")
    
    year=namevars[1][1:5]
    day=namevars[1][5:]
    H=namevars[2][1:3]
    V=namevars[2][4:]    
    
    return [day, year, H, V]

def writeheader(filehdf,outfolder):
    #This function runs an hdf file through hegtool.exe to create a header file, and saves it to the output location.
    cwd=os.getcwd()
    hegtool= "C:\\HEGtools2\\HEG\\HEG_Win\\bin\\hegtool -s "
    os.chdir(outfolder)
    try:
        retcode=subprocess.call(hegtool+filehdf, shell=False)
    except:
        print "Problems with" +  filehdf
    finally:
        print "Return code from hegtool call: "+str(retcode) 
        [day, year, H, V]=MODIStilename(filehdf)
        
    os.chdir(cwd)
    
    return(retcode)
    
def headercoords(fileheader):
    #This function reads the bounding coordinates and number of bands from a grid header file.
    with open(fileheader, mode='rb') as header:
        lslice=header.readlines()[22:50]
        ulcorner=lslice[0].split("=")
        lrcorner=lslice[6].split("=")
        numbands=lslice[26].split("=")[1][0]
        
        print "Upper left corner coords: "+ulcorner[1]
        print "Lower right corner coords: "+lrcorner[1]
        print "Numbands "+numbands
        
    return (ulcorner, lrcorner, numbands)

def grid2tif(filehdf,outfolder):
    #This function converts an hdf file to .tif, using default extent and pixel size, and a geographical projection.
    #All bands within the .hdf file are processed and returned as separate .tifs.
        
    resampletool="C:\\HEGtools2\\HEG\\HEG_Win\\bin\\resample.exe -P "
    
    #Use MODIStilename to name output cleanly
    [day, year, H, V]=MODIStilename(filehdf)
    outname="D"+day+"_Y"+year+"_H"+H+"_V"+V
    
    #Separate temporary folders keep processes tidy
    tempfolder=outfolder+"\\temp"+outname
    fileheader=tempfolder+"\\HegHdr.hdr"
    os.mkdir(tempfolder)
    
    retcode=writeheader(filehdf, tempfolder)
    if retcode==0:
        [ulcorner,lrcorner,numbands]=headercoords(fileheader)
        correctbands=0
        print str(ulcorner)
        print str(lrcorner)
    
        #Name the parameter file that HEG will process
        fileprm=tempfolder+"\\"+outname+"Band"+numbands+".prm"
    
        #One .prm per band
        for bandnum in [str(x+1) for x in range(int(numbands)) ]:
        
            print "Working on file "+outname
            print "Band"+bandnum
        
            f = open(fileprm, 'wb')
            f.write('\n')
            f.write('NUM_RUNS = 1\n')
            f.write('\n')
            f.write('BEGIN\n')
            f.write('INPUT_FILENAME = ')
            f.write(filehdf)
            f.write('\n')
            f.write('OBJECT_NAME = MODIS_Grid_Daily_Fire|\n')
            f.write('FIELD_NAME = FireMask\n')
            
            #Band numbers correspond to days
            f.write('BAND_NUMBER = '+bandnum+'\n')
            f.write('SPATIAL_SUBSET_UL_CORNER = ( '+ulcorner[1][:-3]+' )')
            f.write('\n')
            f.write('SPATIAL_SUBSET_LR_CORNER = ( '+lrcorner[1][:-3]+' )')
            f.write('\n')
            f.write('RESAMPLING_TYPE = NN')
            f.write('\n')
            f.write('OUTPUT_PROJECTION_TYPE = GEO')
            f.write('\n')
            f.write('OUTPUT_PROJECTION_PARAMETERS = ( 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0  ) ')
            f.write('\n')
            
            #Output pixel size is given in seconds("). 30"=.00833 degrees~1km along undistorted parallel
            f.write('OUTPUT_PIXEL_SIZE = 30.000047779492313\n')
            f.write('OUTPUT_FILENAME = ')
            f.write(outfolder+"\\"+outname+'_B'+bandnum+'.tif')
            f.write('\n')
            f.write('OUTPUT_TYPE = GEO\n')
            f.write('END\n')
            f.write('\n')
            f.close()
            
            #Print return code from resample call
            retcode=subprocess.call(resampletool+fileprm, stderr=open(os.devnull, 'wb'), stdout=open(os.devnull, 'wb'))
            print "Return code for resample.exe call: "+str(retcode)
            
            if retcode==0:
                correctbands+=1
        
        if correctbands == int(numbands):
            shutil.rmtree(tempfolder, ignore_errors=True) 
    
    else:
        print "Problems with " + filehdf
        
if __name__=='__main__':  
    
    #Name general inputs
    resampletool="C:\\HEGtools2\\HEG\\HEG_Win\\bin\\resample.exe -P "
    projection="..\\..\\..\\data\\projections\\WGS 1984.prj"
    
    #Fix years
    startyear=2000
    endyear=2015
    years=[ str(x) for x in range(startyear, endyear+1)]
    print years
    
    #Set up logging
    logging.basicConfig(format='%(asctime)s %(message)s', filename='gridhdf2tif.log', filemode='w', level=logging.DEBUG)
    logging.info('Starting gridhdf2tif.py.')
    logging.info('Processing files from %s  to %s .' , str(startyear), str(endyear) )
    
    #Set up pooling:
    nw=20
    
    #Set up metrics
    tothdfs=0
    totbands=0
    t0=time.clock()
    
    for year in years:

        logging.info('Started processing %s .' , str(year))  
                
        #Name input and output folders
        infolder="..\\..\\..\\data\\MODIS_FIRE\\source\\tiles\\" + year
        outfolder="..\\..\\..\\data\\MODIS_FIRE\\generated\\daily\\" + year    
        
        #Set up output folder
        shutil.rmtree(outfolder, ignore_errors=True) 
        os.mkdir(outfolder)

        #Set up folder for unprocessed hdfs
        unprocessed=infolder+"\\unprocessed"
        shutil.rmtree(unprocessed, ignore_errors=True) 
        os.mkdir(unprocessed)
        
        #Create list of hdfs to process
        hdfs=glob.glob(infolder+"\\*.hdf")
        tothdfs=tothdfs+len(hdfs)
        
        #Process all hdfs through partialgrid2tif.py
        partialgrid2tif=partial(grid2tif,outfolder=outfolder)
        pool=Pool(processes=nw)
        results=pool.map(partialgrid2tif, hdfs)
        
        #Clean up pooling
        pool.close
        pool.join
    
        #Gather hdfs that didn't process correctly:
        problems=[x[-18:] for x in glob.glob("..\\..\\..\\data\\MODIS_FIRE\\generated\\daily\\"+str(year)+"\\temp*")]

        logging.info('The following %s of the total %s hdfs ran into trouble.' ,str(len(problems)), str(len(hdfs)))  
        logging.info(' %s .' ,str(problems))        
        
        #List all problematic hdfs and set them apart        
        problemlist=infolder+"\\"+year+"problemlist.txt"

        with open(problemlist, mode='w') as f:
            for problem in problems:

                #Get tile info from file name
                day=problem[1:4]
                yr=problem [6:10]
                h=problem[12:14]
                v=problem[16:18]
                
                #Move problem source file and record its name
                try:
                    filename=glob.glob("..\\..\\..\\data\\MODIS_FIRE\\source\\tiles\\"+year+"\\*"+ year+day+"."+"h"+h+"v"+v+"*.hdf")[0]
                    f.write("%s\n" % filename)
                    shutil.copy(filename, unprocessed+"\\"+str(os.path.basename(filename)))
                except:
                    pass
                
        #Remove HEGTool's big log files
        try:
            cwd=os.getcwd()
            os.remove(cwd+"\\resample.log")       
        except OSError:
            pass
        
        try:
            os.remove("C:\\HEGtools2\\HEG\\HEG_Win\\TOOLKIT_MTD\\runtime\\LogStatus")
        except OSError:
            pass
        
        #Write a file listing all input hdfs, and delete them
        hdflist=infolder+"\\"+year+"hdflist.txt"
        
        with open(hdflist, mode='w') as f:
            for hdf in hdfs:
                f.write("%s\n" % hdf)
                os.remove(hdf)
        
        #Create list of generated tifs
        tifs=glob.glob(outfolder+"\\*.tif")
        totbands=totbands+len(tifs)
        logging.info('Done processing %s .' , str(year))  
    
    t1=time.clock()
    logging.info(' %s total bands processed correctly.' ,str(totbands))  
    logging.info('Processed %s .hdf files in %s minutes.' ,str(tothdfs), str((t1-t0)/60) )