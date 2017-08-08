# ---------------------------------------------------------------------------
# aggregate_raster.py
# Description: This program adds n x n blocks of cells from rasters in a folder
# and saves the resulting raster.
# Please inform the factor of aggregation in line 63 (cellFactor)

#Created Nov 3 2016, by Lorenzo
#Last modified June 13 2017, by Marcel
# ---------------------------------------------------------------------------

import shutil, os, numpy, urllib

print('Now let`s download one file from a specific website')

## Create folder (if it does not exist) 
folder  = "S:\\particulates\\data_processing\\data\\CCMP\\source"
try: 
    os.mkdir(folder)
except Exception:
    pass

## Set url
urlpattern = 'ftp://ftp2.remss.com/ccmp/v02.0/Y'

## Set years, months
years = numpy.linspace(2000, 2015, num = 16)
months = numpy.linspace(1, 12, num = 12)
## Set destination

for year in years:
    x = int(year)
    year_folder = folder+"\\Y"+str(x)
    
    for month in months:
        y = int(month)
        if month>=10:
            url = urlpattern+str(x)+"/M" +str(y)+"/"+"CCMP_Wind_Analysis_"+str(x)+str(y)+"_V02.0_L3.5_RSS.nc"
            fullfilename = os.path.join(folder, "CCMP_Wind_Analysis_"+str(x)+"_"+str(y)+"_V02.0_L3.5_RSS.nc")
        else:
            url = urlpattern+str(x)+"/M0" +str(y)+"/"+"CCMP_Wind_Analysis_"+str(x)+"0"+str(y)+"_V02.0_L3.5_RSS.nc"
            fullfilename = os.path.join(folder, "CCMP_Wind_Analysis_"+str(x)+"_0"+str(y)+"_V02.0_L3.5_RSS.nc")
        print(url)            
        

        urllib.urlretrieve(url, fullfilename)
        
        
print("Donwloads ended.")