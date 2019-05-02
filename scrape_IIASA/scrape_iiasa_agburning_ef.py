# -*- coding: utf-8 -*-
"""
This .py file downloads agriculture activity data from the GAINS model pages

Created by: Lorenzo, Apr 21 2019
Last modified: Lorenzo, Apr 29, 2019
"""

import os, time, shutil, glob, shutil

from random import randint
from selenium import webdriver
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import Select
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.common.action_chains import ActionChains

def courtesy_wait(min_s,max_s):
    wait=randint(min_s, max_s)
    print('Sleeping for ' + str(wait))
    time.sleep(wait)

fp = webdriver.FirefoxProfile()
fp.set_preference("browser.preferences.instantApply",True)
fp.set_preference("browser.helperApps.neverAsk.saveToDisk", "text/plain, application/octet-stream, application/binary, text/csv, application/csv, application/excel, text/comma-separated-values, text/xml, application/xml, application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
fp.set_preference("browser.helperApps.alwaysAsk.force",False)
fp.set_preference("browser.download.manager.showWhenStarting",False)
fp.set_preference("browser.download.folderList",2);
fp.set_preference("browser.download.dir","C:/Users/lorenzo/Documents/IIASA_emmission_factors/pm10_emissions");

wait_min=2
wait_max=4
wait_error=2
driver = webdriver.Firefox(firefox_profile=fp)

address_general='http://gains.iiasa.ac.at/gains/_region_/index.login?logout=1&switch_version=v0'

regions=[]
#Done
#regions.append('G20')
regions.append('EUN')
regions.append('ASN')
regions.append('ANN')

data_management_dir={'G20':'/html/body/div[3]/div[2]/div/div[2]/a[6]', \
                     'EUN':'/html/body/div[3]/div[2]/div/div[2]/a[8]', \
                     'ASN':'/html/body/div[3]/div[2]/div/div[2]/a[7]', \
                     'ANN':'/html/body/div[3]/div[2]/div/div[2]/a[6]'}

for region in regions:
    target_page=address_general.replace('_region_', region)
    driver.get(target_page)
    assert "No results found." not in driver.page_source
    username = driver.find_element_by_name('username')
    user="Lint291"
    #user="laldecol"
    username.send_keys(user)
    
    
    password = driver.find_element_by_name('password')
    password.send_keys("S7i7m7ie")
    #password.send_keys("KyfEkuYMF3vVeR")
    
    login_button=driver.find_element_by_xpath('/html/body/div[2]/div[2]/form/input[5]')
    login_button.click()
    
    clicked_advanced=False
    while clicked_advanced==False:
        try:
            print('Trying to click advanced model tab')
            advanced_button=driver.find_element_by_xpath('/html/body/div[2]/div[1]/div[5]/div[2]/a[2]')
            advanced_button.click()
            clicked_advanced=True
            courtesy_wait(wait_min, wait_max)
        except Exception as e:
            print(e)
            time.sleep(wait_error)
            
    clicked_data_management=False
    while clicked_data_management==False:
        try:
            print('Trying to click data management tab')
            activity_data=driver.find_element_by_xpath(data_management_dir[region])
            activity_data.click()
            clicked_data_management=True
            courtesy_wait(wait_min, wait_max)
        except Exception as e:
            print(e)
            time.sleep(wait_error)
    
    clicked_regional_parameters=False
    while clicked_regional_parameters==False:
        try:
            print('Trying to click regional parameters')
            regional_parameters=driver.find_element_by_xpath('/html/body/div[3]/div[3]/a[3]')
            regional_parameters.click()
            clicked_regional_parameters=True
            courtesy_wait(wait_min, wait_max)
        except Exception as e:
            print(e)
            time.sleep(wait_error)
    
    selected_scenario_type=False
    while selected_scenario_type==False:
        try:
            #scenario_dropdown=Select(driver.find_element_by_name('PD_scenario_group'))
            print('Trying to select scenario type')
            scenario_dropdown=Select(driver.find_element_by_xpath('/html/body/div[3]/div[4]/form/div[3]/select'))
            target_scenario='BASE_SCENARIOS'
            scenario_dropdown.select_by_visible_text(target_scenario)
            selected_scenario_type=True
        except Exception as e:
            print(e)
            time.sleep(wait_error)
    
    selected_emission_type=False
    while selected_emission_type==False:
        try:
#            emission_dropdown=Select(driver.find_element_by_name('PD_excel_regional'))
            print('Trying to select emission type')
            emission_dropdown=Select(driver.find_element_by_xpath('/html/body/div[3]/div[4]/form/div[8]/select'))
            target_emission='Emission parameters PM CO2'
            emission_dropdown.select_by_visible_text(target_emission)
            selected_emission_type=True
        except Exception as e:
            print(e)
            time.sleep(wait_error)
 
    got_country_list=False
    while got_country_list==False :
        try:
            print('Trying to select country list type')
            #region_dropdown=Select(driver.find_element_by_name('PD_region_scenario'))
            region_dropdown=Select(driver.find_element_by_xpath('/html/body/div[3]/div[4]/form/div[5]/select'))
            country_list=[str(option.text) for option in region_dropdown.options]
            got_country_list=True
        except Exception as e:
            print(e)
            time.sleep(wait_error)
                    
    error_count=0;

    #List files already downloaded
    out_dir='C:/Users/lorenzo/Documents/IIASA_emmission_factors/agricultural_burning_ef/'+region+'/'

    done_g20=glob.glob('C:/Users/lorenzo/Documents/IIASA_emmission_factors/agricultural_burning_ef/G20/*.csv')    
    done_eun=glob.glob('C:/Users/lorenzo/Documents/IIASA_emmission_factors/agricultural_burning_ef/EUN/*.csv')
    done_asn=glob.glob('C:/Users/lorenzo/Documents/IIASA_emmission_factors/agricultural_burning_ef/ASN/*.csv')    
    done_ann=glob.glob('C:/Users/lorenzo/Documents/IIASA_emmission_factors/agricultural_burning_ef/ANN/*.csv')    
    
    done_file_list=[done_g20, done_eun, done_asn, done_ann]
    done_countries=[]
    
    for done_files in done_file_list:
        for file in done_files:
            done_countries.append(os.path.splitext(os.path.basename(file))[0])
                
    print('Done countries:')
    print(done_countries)
    download_dir='C:/Users/lorenzo/Downloads/'
#    download_file='act_oth_AGR.csv'
#    download=download_dir+download_file
    
    #List files with known errors
    error_file=out_dir+region+'errors_agef.txt'

    with open(error_file,'r') as f:
        country_errors = list(f)
        
    print(country_errors)
    missing_countries=set(country_list)-set(done_countries)-set(country_errors)
    missing_countries=[x for x in missing_countries if x.find('Select')==-1]
    
    print(missing_countries)
    
    for country in missing_countries:
         
        destination=out_dir+country+'.csv'
        print(country)

        file_error=False
        
        #Check if drop down element is a country and its file hasn't been downloaded

        while str(country).find('Select')==-1 and os.path.isfile(destination)==False and file_error==False:
            print('Trying to get ' + country+ ' file.')
            
#            selected_region_dropdown=False
#            while selected_region_dropdown==False and error_count<5:
#                try:
#                    region_dropdown=Select(driver.find_element_by_id("PD_region"))
#                    region_dropdown.select_by_visible_text(country)
#                    selected_region_dropdown=True
#                except Exception as e:
#                    error_count+=1
#                    print (e)
#                    time.sleep(wait_error)
            selected_region_dropdown=False
            while selected_region_dropdown==False :
                try:
                    print('Trying to select region dropdown')
                    region_dropdown=Select(driver.find_element_by_xpath("//select[@name='PD_region_scenario']"))
                    region_dropdown.select_by_visible_text(country)
                    selected_region_dropdown=True
                except Exception as e:
                    print(e)
                    time.sleep(wait_error)
                            
            courtesy_wait(wait_min, wait_max)
            
            clicked_export=False
            while clicked_export==False:
                try:
                    print('Trying to click export button')
                    export_button=driver.find_element_by_id('linkExportData')
                    export_button.click()
                    clicked_export=True
                except Exception as e:
                    error_count+=1
                    print(e)
                    time.sleep(wait_error)

            while os.path.isfile(destination)==False and file_error==False:
            
                   
                courtesy_wait(wait_min, wait_max)
                
                
                while os.path.isfile(destination)==False:
                    
                    download_path_pattern=download_dir+'Emfac_PM_CO2_v2_ECLIPSE_V5a_CLE_base*.xlsx'
                    try:
                        print('Checking for downloaded file')
                        download_file=glob.glob(download_path_pattern)
                        assert len(download_file)==1
                        download=download_file[0]
                        shutil.move(download,destination)

                    except Exception as e: 
                        print(e)
                        time.sleep(5)
                        pass            
    
        print('Done')
        

#First test only on Argentina

#for option in region_dropdown.options:
#    print(option.text, option.get_attribute('value'))
#    if i>1:
#        region_dropdown.select_by_visible_text(option.text)
#        time.sleep(2)
#        show_button=driver.find_element_by_id("btnShow")
#        show_button.click()
#        time.sleep(60)
#        
#        export_menu=driver.find_element_by_xpath('/html/body/div[2]/div[1]/div/table/tbody/tr[2]/td[2]/div[1]/div[2]/a[2]/span/span[4]')
#        export_button=driver.find_element_by_xpath('/html/body/div[6]/div[2]/div[1]')
#        time.sleep(10)
#        
#    else:
#        pass
#    i=i+1
    
