#This file cleans up GPW table files so they can be imported into stata

import glob, shutil, logging, os

def gpwclean(pathname):
    logging.basicConfig(format='%(asctime)s %(message)s', filename='gpwclean.log', filemode='w', level=logging.DEBUG)
    logging.info('Starting gpwclean.py.')
    tablecount=0
    print str(os.getcwd())
    print str(glob.glob(pathname))
    
    for table in glob.glob(pathname):
        in_dir=os.path.dirname(table)
        print in_dir
        base=os.path.basename(table)
        print base
        newbase=base.replace("-","_")
        print newbase
        tablecount+=1
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
        
    
