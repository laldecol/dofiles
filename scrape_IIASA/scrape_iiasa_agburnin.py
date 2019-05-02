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
fp.set_preference("browser.helperApps.neverAsk.saveToDisk", "text/plain, application/octet-stream, application/binary, text/csv, application/csv, application/excel, text/comma-separated-values, text/xml, application/xml")
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
#regions.append('EUN')
#regions.append('ASN')
regions.append('ANN')



for region in regions:
    target_page=address_general.replace('_region_', region)
    driver.get(target_page)
    assert "No results found." not in driver.page_source
    username = driver.find_element_by_name('username')
    user="Lint291"
#    user="laldecol"
    username.send_keys(user)
    
    
    password = driver.find_element_by_name('password')
    password.send_keys("S7i7m7ie")
#    password.send_keys("KyfEkuYMF3vVeR")
    
    login_button=driver.find_element_by_xpath('/html/body/div[2]/div[2]/form/input[5]')
    login_button.click()
    
    clicked_advanced=False
    while clicked_advanced==False:
        try:
            advanced_button=driver.find_element_by_xpath('/html/body/div[2]/div[1]/div[5]/div[2]/a[2]')
            advanced_button.click()
            clicked_advanced=True
            courtesy_wait(wait_min, wait_max)
        except Exception as e:
            print(e)
            time.sleep(wait_error)
    ###
    clicked_activity=False
    while clicked_activity==False:
        try:
            activity_data=driver.find_element_by_xpath('/html/body/div[3]/div[2]/div/div[2]/a[1]')
            activity_data.click()
            clicked_activity=True
            courtesy_wait(wait_min, wait_max)
        except Exception as e:
            print(e)
            time.sleep(wait_error)
    
    clicked_activity_dropdown=False
    while clicked_activity_dropdown==False:
        try:
            activity_dropdown=Select(driver.find_element_by_xpath('/html/body/div[3]/div[3]/div[2]/div/select'))
            activity_dropdown.select_by_visible_text("Agriculture")    
            clicked_activity_dropdown=True
            courtesy_wait(wait_min, wait_max)
        except Exception as e:
            print(e)
            time.sleep(wait_error)
    
    clicked_other_activity=False
    while clicked_other_activity==False:
        try:
            other_activity_data=driver.find_element_by_xpath('/html/body/div[3]/div[3]/a[5]')
            other_activity_data.click()
            clicked_other_activity=True
            courtesy_wait(wait_min, wait_max)
        except Exception as e:
            print(e)
            time.sleep(wait_error)
            
    clicked_results=False
    while clicked_results==False:
        try:
            results_icon=driver.find_element_by_xpath('/html/body/div[3]/div[4]/form/section/div/ul/li')
            results_icon.click()
            clicked_results=True
            courtesy_wait(wait_min, wait_max)
        except Exception as e:
            print(e)
            time.sleep(wait_error)
                        
       
    main_window=driver.window_handles[0]
    new_window=driver.window_handles[1]
    driver.switch_to.window(new_window)
    timeout_error=False

    error_count=0;

    selected_scenario=False
    while selected_scenario==False and error_count<5:
        try:
            scenario_dropdown=Select(driver.find_element_by_id("PD_scenario_group"))  
            target_scenario='BASE_SCENARIOS'
            scenario_dropdown.select_by_visible_text(target_scenario)
            selected_scenario=True
        except Exception as e:
            error_count+=1
            print(e)
            time.sleep(wait_error)
    
    got_country_list=False
    while got_country_list==False and error_count<5:
        try:
            region_dropdown=Select(driver.find_element_by_id("PD_region"))
            country_list=[str(option.text) for option in region_dropdown.options]
            got_country_list=True
        except Exception as e:
            error_count+=1
            print(e)
            time.sleep(wait_error)
        
    #List files already downloaded
    out_dir='C:/Users/lorenzo/Documents/IIASA_emmission_factors/agricultural_burning/'+region+'/'

    done_g20=glob.glob('C:/Users/lorenzo/Documents/IIASA_emmission_factors/agricultural_burning/G20/*.csv')    
    done_eun=glob.glob('C:/Users/lorenzo/Documents/IIASA_emmission_factors/agricultural_burning/EUN/*.csv')
    done_asn=glob.glob('C:/Users/lorenzo/Documents/IIASA_emmission_factors/agricultural_burning/ASN/*.csv')    
    done_ann=glob.glob('C:/Users/lorenzo/Documents/IIASA_emmission_factors/agricultural_burning/ANN/*.csv')    
    
    done_file_list=[done_g20, done_eun, done_asn, done_ann]
    done_countries=[]
    
    for done_files in done_file_list:
        for file in done_files:
            done_countries.append(os.path.splitext(os.path.basename(file))[0])
             
    download_dir='C:/Users/lorenzo/Downloads/'
    download_file='act_oth_AGR.csv'
    download=download_dir+download_file
    
    #List files with known errors
    error_file=out_dir+region+'errors_agburning.txt'

    with open(error_file,'r') as f:
        country_errors = list(f)
        
    print('Country list')
    print(country_list)

    print('Done countries:')
    print(done_countries)
    
    print('Country errors:')
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
            
            selected_region_dropdown=False
            while selected_region_dropdown==False and error_count<5:
                try:
                    region_dropdown=Select(driver.find_element_by_id("PD_region"))
                    region_dropdown.select_by_visible_text(country)
                    selected_region_dropdown=True
                except Exception as e:
                    error_count+=1
                    print (e)
                    time.sleep(wait_error)
            
            courtesy_wait(wait_min, wait_max)
            selected_scenario=False
            while selected_scenario==False and error_count<5:
                try:
                    scenario_dropdown=Select(driver.find_element_by_id("PD_scenario_group"))  
                    target_scenario='BASE_SCENARIOS'
                    scenario_dropdown.select_by_visible_text(target_scenario)
                    selected_scenario=True
                except Exception as e:
                    error_count+=1
                    print(e)
                    time.sleep(wait_error)
                    

            courtesy_wait(wait_min, wait_max)
            
            clicked_show=False
            while clicked_show==False and error_count<5:
                try:
                    show_button=driver.find_element_by_id("btnShow")
                    show_button.click()            
                    clicked_show=True
                except Exception as e:
                    error_count+=1
                    print(e)
                    time.sleep(wait_error)
            
            courtesy_wait(wait_min, wait_max)
            
            ##Check whether ag has data tab;
            tab_visible=False
            while tab_visible==False and error_count<5:
                try:
                    data_tab=driver.find_element_by_xpath('/html/body/div[2]/div[3]/div/div[5]/div[1]/div[3]/ul/li[1]/a')
                    data_tab.click()
                    tab_visible=True
                except:
                    error_count+=1
                    time.sleep(wait_error)
                    pass
                
            courtesy_wait(wait_min, wait_max)
                       

#            shutil.rmtree(download, ignore_errors=True)
            error_count=0

            while os.path.isfile(download)==False and error_count<5 and file_error==False:
            
                   
                courtesy_wait(wait_min, wait_max)
                
                clicked_csv_button=False
                while clicked_csv_button==False and error_count<5:

                    try:
                        print('Trying to hover.')
                        export_button=driver.find_element_by_xpath('/html/body/div[2]/div[1]/div/table/tbody/tr[2]/td[2]/div[1]/div[2]/a[2]/span/span[3]')
                        hover = ActionChains(driver).move_to_element(export_button)
                        hover.perform()

                        print('Trying to click csv button.')
                        csv_button=driver.find_element_by_xpath('/html/body/div[6]/div[2]')
                        driver.execute_script("arguments[0].scrollIntoView();", csv_button)
                        csv_button.click()
                        clicked_csv_button=True
                        
                        download_wait=0
                        
                        while os.path.isfile(download)==False and download_wait<10:
                            time.sleep(wait_error)
                            download_wait+=1
                
                    except Exception as e: 
                        print(e)
                        time.sleep(wait_error)
                        error_count+=1
                        pass
                    
                if clicked_csv_button==True and  os.path.isfile(download)==False:
                    file_error=True
                    
                    with open( error_file,'a') as error_list:
                            error_list.write(str(country))
            
                 
            if error_count>=5:
                
                driver.close()
                driver.switch_to_window(main_window)
                
                  
                switched_window=False
                while switched_window==False:
                    try:
                        print('Trying to click results icon')
                        results_icon=driver.find_element_by_xpath('/html/body/div[3]/div[4]/form/section/div/ul/li')
                        results_icon.click()
                        new_window=driver.window_handles[1]
                        driver.switch_to.window(new_window)
                        switched_window=True
                    except:
                        time.sleep(wait_error)
                        pass
                    
                
            
            try:
                shutil.move(download,destination)
            except:
                print('Could not rename downloaded file for ' + str(country))
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
    
