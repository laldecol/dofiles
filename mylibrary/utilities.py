# ---------------------------------------------------------------------------
# utilities.py
# -------- #
# Description: This file holds some utilities for the particulates project

# created: June 5 2017 by Lorenzo
# last modified: June 5 2017 by Lorenzo
# ---------------------------------------------------------------------------

import ftplib, time

def ftp2disk(ftpaddress,serverpath,localfolder, pattern):
#downloads files from an ftp server to a local folder.

#Inputs:
    #ftpaddress: ftp server address e.g. 'ftp.glcf.umd.edu'
    #serverpath: path to folder with the files we want e.g. 'glcf/Global_LNDCVR/UMD_TILES/Version_5.1/2006.01.01'
    #localfolder: path to local folder. files download to that location.
    #pattern: program will only download files with this pattern in their names. can be an extension, e.g. '.tif.gz'
    
    #Open ftp connection and change directory
    ftp=ftplib.FTP(ftpaddress)
    ftp.login()
    ftp.cwd(serverpath)
    filelist=ftp.nlst()
    
    #Keep list of files that match pattern
    filelist=[filename for filename in filelist if pattern in filename ]
    print filelist
    
    #Download files
    for filename in filelist:
        localfile=localfolder+"\\"+filename
        attempts=0
        
        #Open file to hold data. Name is the same as in server.
        with open(localfile, 'wb') as file:
            
            #Try at most 20 times to download each file. 
            #Program sleeps for a few seconds after each failed attempt to wait for server
            while attempts<20:
                try:
                    attempts+=1
                    ftp.retrbinary('RETR '+ filename, file.write)
                    #If above line runs fine, set attempts to 20 to stop loop
                    attempts=20
                except:
                    print "Trouble downloading "+filename
                    print "Attempt # "+ str(attempts+1)
                    time.sleep(10)
    ftp.quit()
