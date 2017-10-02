import os, glob, shutil
#This file changes the names of LULC files so they can be added to stata
os.chdir("S:\\particulates\\data_processing\\data\\MODIS_LULC\\generated\\yearly\\dummy\\ubergrid\\table")
for filename in glob.glob("S:\\particulates\\data_processing\\data\\MODIS_LULC\\generated\\yearly\\dummy\\ubergrid\\table\\*.txt"):
    oldname=os.path.basename(filename)
    newname="LU"+oldname.replace("_","")
    shutil.move(oldname, newname)
    print newname
    
