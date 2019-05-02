# ---------------------------------------------------------------------------
# clean_scraped_GAINS.py
# Created on: 2019-5-2
# Description: This file cleans scraping output for ag burning and ag burning
# emission factors. It removes duplicates and moves files to match output from 
# particulates emissions and energy use.
# ---------------------------------------------------------------------------

import os, shutil, glob

source_folder_pattern='S:/particulates/data_processing/data/IIASA/GAINS/agricultural_burning/_region_/*.csv'
target_folder='S:/particulates/data_processing/data/IIASA\GAINS/agricultural_burning/'

regions=[]
regions.append('G20')
regions.append('EUN')
regions.append('ASN')
regions.append('ANN')

for region in regions:
    path=source_folder_pattern.replace('_region_', region)
    csv_list=glob.glob(path)
    
    for csv in csv_list:
        source_filename=os.path.basename(csv)
        target_file=target_folder+source_filename
        
        if os.path.isfile(target_file)==False:
            shutil.copy(csv, target_file)
        
        
        
    