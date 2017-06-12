#Steps from scratch to .dta (correspond to scripts)
import sys, shutil, os, glob, time
sys.path.append("..\\raster2list")
from raster2list import raster2list
##AOD
#1. Turn daily AOD into yearly AOD. 2003-2014
#daily2yearlyAOD does this already

#2. Turn yearly AOD into ubergrid AOD for each year and satellite (24 total ubergrids)
#raster2ubergrid does this already


##GPW
#3. Turn GPW (already ubergrid) to ascii and then table (4 total ubergrids)
#raster2list does this already.


##Country borders
#1. Turn border shapefile into ubergrid.
#polygon2raster does this already.


##For all 
#2. Turn ubergrid into ascii and then table.
#raster2list does this already.

cwd=os.getcwd()
print str(cwd)
#pause=raw_input("Check current working path")

input_folderlist=[]
pathnamelist=[]

input_folderlist.append("..\\..\\data\\lor_manual\\tempdata")
pathnamelist.append(input_folderlist[0]+"\\*behr.tif")

print input_folderlist
print pathnamelist


for index in range(len(input_folderlist)):
    
    input_folder=input_folderlist[index]
    pathname=pathnamelist[index]
    
    ascii_folder=input_folder+"\\ascii"
    table_folder=input_folder+"\\table"
    
    shutil.rmtree(ascii_folder, ignore_errors=True)
    shutil.rmtree(table_folder, ignore_errors=True)
    os.mkdir(ascii_folder)
    os.mkdir(table_folder)
    
    for raster in glob.glob(pathname):
        t0=time.clock()
        raster2list(raster)
        t1=time.clock()
        print "Raster " + str(raster) + " took " + str(t1-t0) + "seconds."
        #wait=raw_input("Press enter to continue.")    
    



#3. Import table into stata and save as .dta
#must do this in stata


##Merging
#1. Merge all 29 tables and whittle down to size



