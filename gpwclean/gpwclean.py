# ---------------------------------------------------------------------------
# gpw_clearn.py
# This file cleans up GPW table files so they can be imported into stata
# and saves the resulting raster.

#Created ??, by Lorenzo
#Last modified 6/15/2017, by Marcel
# ---------------------------------------------------------------------------


import glob, shutil, logging, os

def gpwclean(pathname):
    
    # Logging settings
    logging.basicConfig(format='%(asctime)s %(message)s', filename='gpwclean.log', filemode='w', level=logging.DEBUG)
    logging.info('Starting gpwclean.py.')
    
    
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

if __name__=='__main__': 
    pathnames=[]
    pathnames.append("..\\..\\..\\data\\GPW4\\generated\\gpw-v4-national-identifier-grid\\ubergrid\\table\\*.txt")
    pathnames.append("..\\..\\..\\data\\GPW4\\generated\\gpw-v4-data-quality-indicators-mean-administrative-unit-area\\ubergrid\\table\\*.txt")
    
    for pathname in pathnames:
        gpwclean(pathname)
        
    
