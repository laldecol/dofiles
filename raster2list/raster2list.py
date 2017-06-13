#This program:
#1. Reads the raster settings generated by makexy_extent
#2. Converts rasters into ascii
#3. Converts ascii files into stata readable tables

import os, time, arcpy, glob, shutil, logging
from arcpy import env

def raster2list(outputraster):
    
    arcpy.env.overwriteOutput = True
    #Extract input directory and basename
    
    in_dir=os.path.dirname(outputraster)    
    base=os.path.basename(outputraster)
    basename=os.path.splitext(base)[0]
    
    # Local variables:
    outputascii = in_dir+"\\ascii" 
    outputtable = in_dir+"\\table" 
    
    #settingsdict={}
    #with open("..\\..\\data\\projections\generated\settings.txt", 'r') as settingfile:
        #templines=settingfile.readlines()
        #lines = [i.replace('\n','') for i in templines]
        #for linecounter in range(len(lines)):        
            #if linecounter % 2 ==0:
                #print linecounter
                #settingsdict[str(lines[linecounter])]=str(lines[linecounter+1])
    #print settingsdict
    
    #basename=os.path.basename(os.path.splitext(outputraster)[0])
    asciipath=outputascii + "\\" + basename + ".txt"
    arcpy.RasterToASCII_conversion(outputraster, asciipath )
    
    tablepath=outputtable + "\\" + basename + ".txt"
    
    t0=time.clock()
    i=0
    ubercount=1
    with open(asciipath, 'r') as asciifile, open(tablepath, mode='w') as table:
        twith1=time.clock()
        for line in asciifile:
            tlinefor1=time.clock()
            i+=1
            if i>=7:
                
                row=line.split()
                j=0
                #Problem: row has no columns. 
                for column in row:
                    #tcolumnfor1=time.clock()
                    #print "Writing column " + str(j) + " of line " + str(i) + " of file " + str(basename)
                    table.write(str(ubercount)+" "+str(column)+"\n")
                    j+=1
                    ubercount+=1
                    #tcolumnfor2=time.clock()
                    #print "Column took " + str(tcolumnfor2-tcolumnfor1) + "seconds."
                #print "column is " + str(j)
            tlinefor2=time.clock()
            #print "Line took " + str(tlinefor2-tlinefor1) + " seconds."
            #wait=raw_input("Check line times.")
        twith2=time.clock()
        #print "with took " + str(twith2-twith1) + " seconds."
    #print (i==int(settingsdict["ROWCOUNT"])+6)
    #print (j==int(settingsdict["COLUMNCOUNT"]))
    t1=time.clock()
    
    #print str((t1-t0)/60)
    #wait=raw_input("Check times (in minutes)")
    #print settingsdict

if __name__=="__main__":    

    logging.basicConfig(format='%(asctime)s %(message)s', filename='raster2list.log', filemode='w', level=logging.DEBUG)
    logging.info('Starting raster2list.py.')    
    
    #Set up directories    
    input_folderlist=[]
    pattern_list=[]
    rastercount=0

    #Test for unprojected GPW counts; remove and uncomment others for normal functioning
    #input_folderlist.append("..\\..\\data\\GPW4\\source\\gpw-v4-population-count-2000")
    #pathnamelist.append(input_folderlist[0]+"\\*.tif")
    
    #input_folderlist.append("..\\..\\data\\MODIS_AOD\\generated\\yearly\\ubergrid")
    #pattern_list.append("\\*avg.tif")
    
    #input_folderlist.append("..\\..\\data\\GPW4\\generated\\projected")
    #pattern_list.append("\\*20??.tif")
    
    ##"..\\..\\data\\GPW4\\source\\gpw-v4-national-identifier-grid"
    #input_folderlist.append("..\\..\\data\\GPW4\\generated\\gpw-v4-national-identifier-grid\\ubergrid")
    #pattern_list.append("\\*.tif")
    
    #input_folderlist.append("..\\..\\data\\GPW4\\generated\\gpw-v4-data-quality-indicators-mean-administrative-unit-area\\ubergrid")
    #pattern_list.append("\\*.tif")    
    
    #input_folderlist.append("..\\..\\data\\MODIS_FIRE\\generated\\yearly\\ubergrid")
    #pattern_list.append("\\*.tif")    
    
    input_folderlist.append("..\\..\\data\\CRU\\generated\\yearly\\ubergrid")
    pattern_list.append("\\*.tif")    

    print input_folderlist
    print pattern_list

    logging.info('Starting process...')    
    time0=time.clock()
    for index in range(len(input_folderlist)):
        
        input_folder=input_folderlist[index]
        pathname=input_folderlist[index]+pattern_list[index]
        
        ascii_folder=input_folder+"\\ascii"
        table_folder=input_folder+"\\table"
        
        shutil.rmtree(ascii_folder, ignore_errors=True)
        shutil.rmtree(table_folder, ignore_errors=True)
        os.mkdir(ascii_folder)
        os.mkdir(table_folder)
        
        for raster in glob.glob(pathname):
            t0=time.clock()
            raster2list(raster)
            rastercount+=1
            t1=time.clock()
            print "Raster " + str(raster) + " took " + str(t1-t0) + "seconds."
            #wait=raw_input("Press enter to continue.")
    
    time1=time.clock()
    
    logging.info('Processed %s rasters in %s minutes',str(rastercount),str((time1-time0)/60))
    logging.info('Done with raster2list.py.')