# ---------------------------------------------------------------------------
# gpw_clearn.py
# This file renames some ubergrid table .txts so they fit stata's constraints:
# 1. GPW national identifier grid
# 2. GPW data quality
# 3. LULC dummy files

#Created 6/01/2017, by Lorenzo
#Last modified 6/15/2017, by Marcel
# ---------------------------------------------------------------------------


import glob, shutil, logging, os

def gpwclean(pathname):
    
    # Logging settings
    logging.info('Starting gpwclean.')
    
    
    tablecount=0
    
    #Identify directory and files within it
    print str(os.getcwd())
    print str(glob.glob(pathname))
    
    
    for table in glob.glob(pathname):
        #Identify where table is
        in_dir=os.path.dirname(table)
        print in_dir
        #Identify its name
        base=os.path.basename(table)
        print base
        #Replace previous dashes by underscores
        newbase=base.replace("-","_")
        print newbase
        logging.info("Dashes in table %s were replaced by underscores.", str(base))
        
        tablecount+=1
        # Move to its own new folder
        shutil.move(table, in_dir+"\\"+newbase)
        
    #for table in glob.glob(pathname):
        #print table
        #tabledest=table[:32]+"gpw"+table[-8:]
        #print tabledest
        #table=shutil.move(table, tabledest)
    
        
    logging.info('Renamed %s tables.', str(tablecount))
    logging.info('Done with gpwclean.py.')
    
def lulc_clean(pathname):
    
    # Logging settings
        logging.info('Starting lulc_clean')
        
        
        tablecount=0
        
        #Identify directory and files within it
        print str(os.getcwd())
        print str(glob.glob(pathname))
        
        
        for table in glob.glob(pathname):
            #Identify where table is
            in_dir=os.path.dirname(table)
            print in_dir
            #Identify its name
            base=os.path.basename(table)
            print base
            if base.find("LU")==-1:
                #Replace previous dashes by underscores
                newbase="LU"+base.replace("_","")
                print newbase
                logging.info("Removed underscores from %s, and added LU prefix.", str(base))
                
                tablecount+=1
                # Move to its own new folder
                shutil.move(table, in_dir+"\\"+newbase)
                
        #for table in glob.glob(pathname):
            #print table
            #tabledest=table[:32]+"gpw"+table[-8:]
            #print tabledest
            #table=shutil.move(table, tabledest)
        
            
        logging.info('Renamed %s tables.', str(tablecount))
        logging.info('Done with lulc_clean.')
    

if __name__=='__main__': 
    
    logging.basicConfig(format='%(asctime)s %(message)s', filename='clean_txt_names.log', filemode='w', level=logging.DEBUG)
    
    pathnames=[]
    pathnames.append("..\\..\\..\\data\\GPW4\\generated\\gpw-v4-national-identifier-grid\\ubergrid\\table\\*.txt")
    pathnames.append("..\\..\\..\\data\\GPW4\\generated\\gpw-v4-data-quality-indicators-mean-administrative-unit-area\\ubergrid\\table\\*.txt")
    
    for pathname in pathnames:
        gpwclean(pathname)
        
    lulc_clean('..\\..\\..\\data\\MODIS_LULC\\generated\\yearly\\dummy\\ubergrid\\table\\*.txt')
    
