# -*- coding: utf-8 -*-
"""
Spyder Editor

This is a temporary script file.
"""

import os, time, shutil, glob

from random import randint
from selenium import webdriver
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import Select
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.common.action_chains import ActionChains

fp = webdriver.FirefoxProfile()
fp.set_preference("browser.preferences.instantApply",True)
fp.set_preference("browser.helperApps.neverAsk.saveToDisk", "text/plain, application/octet-stream, application/binary, text/csv, application/csv, application/excel, text/comma-separated-values, text/xml, application/xml")
fp.set_preference("browser.helperApps.alwaysAsk.force",False)
fp.set_preference("browser.download.manager.showWhenStarting",False)
fp.set_preference("browser.download.folderList",2);
fp.set_preference("browser.download.dir","C:/Users/lorenzo/Documents/IIASA_emmission_factors/pm10_emissions");

def courtesy_wait(min_s,max_s):
    wait=randint(min_s, max_s)
    print('Sleeping for ' + str(wait))
    time.sleep(wait)
    
wait_min=2
wait_max=3

address_general='http://gains.iiasa.ac.at/gains/_region_/index.login?logout=1&switch_version=v0'

regions=[]
#Done regions are commented out
#regions.append('G20')
regions.append('EUN')
regions.append('ASN')
regions.append('ANN')

#x
#

for region in regions:
    target_page=address_general.replace('_region_', region)

    driver = webdriver.Firefox(firefox_profile=fp)
    driver.get(target_page)
    assert "No results found." not in driver.page_source
    username = driver.find_element_by_name('username')
#    username.send_keys("Lint291")
    username.send_keys("laldecol")
    
    password = driver.find_element_by_name('password')
#    password.send_keys("S7i7m7ie")
    password.send_keys("KyfEkuYMF3vVeR")
    
    login_button=driver.find_element_by_xpath('/html/body/div[2]/div[2]/form/input[5]')
    login_button.click()
    
    clicked_advanced=False
    
    while clicked_advanced==False:
        try:
            advanced_button=driver.find_element_by_xpath('/html/body/div[2]/div[1]/div[5]/div[2]/a[2]')
            advanced_button.click()
            clicked_advanced=True
        except Exception as e:
            print(e)
            time.sleep(1)
            
    clicked_emissions=False
    while clicked_emissions==False:
        try:
            emissions_button=driver.find_element_by_xpath('/html/body/div[3]/div[2]/div/div[2]/a[3]')
            #EUR:/html/body/div[3]/div[2]/div/div[2]/a[3]
            #ASN:/html/body/div[3]/div[2]/div/div[2]/a[3]
            #ANN:/html/body/div[3]/div[2]/div/div[2]/a[3]
            
            emissions_button.click()
            clicked_emissions=True
        except Exception as e:
            print(e)
            time.sleep(1)
            
    clicked_emission_dropdown=False
    while clicked_emission_dropdown==False:
        try:
            emissions_dropdown=Select(driver.find_element_by_xpath('/html/body/div[3]/div[3]/div[2]/div/select'))
            
            #ASN:/html/body/div[3]/div[3]/div[2]/div/select
            emissions_dropdown.select_by_visible_text("PM")
            clicked_emission_dropdown=True
        except Exception as e:
            print (e)
            time.sleep(1)
            
    clicked_key_fuels_button=False            
    while clicked_key_fuels_button==False:
        try:
            key_fuels_activities_button=driver.find_element_by_xpath('/html/body/div[3]/div[3]/a[3]')
            key_fuels_activities_button.click()
            clicked_key_fuels_button=True
        except Exception as e:
            print(e)
            time.sleep(1)
    
    clicked_results=False
    while clicked_results==False:
        try:
            results_icon=driver.find_element_by_xpath('/html/body/div[3]/div[4]/form/section/div/ul/li')
            results_icon.click()
            clicked_results=True
        except Exception as e:
            print (e)
            time.sleep(1)
        
    time.sleep(5)
    
    main_window=driver.window_handles[0]
    new_window=driver.window_handles[1]
    
    driver.switch_to.window(new_window)
    
    selected_scenario_dropdown=False
    while selected_scenario_dropdown==False:
        try:
            scenario_dropdown=Select(driver.find_element_by_id("PD_scenario_group"))  
            target_scenario='BASE_SCENARIOS'
            scenario_dropdown.select_by_visible_text(target_scenario)
            selected_scenario_dropdown=True
        except Exception as e:
            print(e)

            time.sleep(1)
        
    selected_fraction_dropdown=False
    while selected_fraction_dropdown==False:
        try:
            fraction_dropdown=Select(driver.find_element_by_id("fractionList"))
            target_fraction="PM_10"
            fraction_dropdown.select_by_visible_text(target_fraction)
            selected_fraction_dropdown=True
        except Exception as e:
            print(e)
            time.sleep(1)
            
    selected_region_dropdown=False
    while selected_region_dropdown==False:
        try:        
            region_dropdown=Select(driver.find_element_by_id("PD_region"))
            country_list=[str(option.text) for option in region_dropdown.options]
            selected_region_dropdown=True
        except Exception as e:
            print(e)
            time.sleep(1)
            
    error_count=0;

    #List files already downloaded
    out_dir='C:/Users/lorenzo/Documents/IIASA_emmission_factors/pm10_emissions/'
    error_file=out_dir+'errors_PM_emissions.txt'

    done_all=glob.glob('C:/Users/lorenzo/Documents/IIASA_emmission_factors/pm10_emissions/*.csv')    
    
    done_countries=[os.path.splitext(os.path.basename(file))[0] for file in done_all]
    
    print('Done countries:')
    print(done_countries)

    with open(error_file,'r') as f:
        country_errors = list(f)
        
    print(country_errors)
    missing_countries=set(country_list)-set(done_countries)-set(country_errors)
    missing_countries=[x for x in missing_countries if x.find('Select')==-1]
    
    print(missing_countries)
        
    for country in missing_countries:
        
        destination=out_dir+country+'.csv'
        print(country)
        
        #Check if drop down element is a country and its file hasn't been downloaded
        while str(country).find('Select')==-1 and os.path.isfile(destination)==False:
            print('Trying to get ' + country+ ' file.')
            selected_scenario_dropdown=False
            while selected_scenario_dropdown==False :
                try:
                    scenario_dropdown=Select(driver.find_element_by_id("PD_scenario_group"))  
                    target_scenario='BASE_SCENARIOS'
                    scenario_dropdown.select_by_visible_text(target_scenario)
                    selected_scenario_dropdown=True

                except Exception as e:
                    print(e)
                    time.sleep(1)
            
            courtesy_wait(wait_min, wait_max)

                
            selected_fraction_dropdown=False
            while selected_fraction_dropdown==False :
                try:
                    fraction_dropdown=Select(driver.find_element_by_id("fractionList"))
                    target_fraction="PM_10"
                    fraction_dropdown.select_by_visible_text(target_fraction)
                    selected_fraction_dropdown=True

                except Exception as e:
                    print(e)
                    time.sleep(1)
            courtesy_wait(wait_min, wait_max)

            selected_region_dropdown=False
            while selected_region_dropdown==False :
                try:        
                    region_dropdown=Select(driver.find_element_by_id("PD_region"))
                    region_dropdown.select_by_visible_text(country)

                    selected_region_dropdown=True

                except Exception as e:
                    print(e)
                    time.sleep(1)
                                
            show_button=driver.find_element_by_id("btnShow")
            
            show_button.click()            
            courtesy_wait(wait_min, wait_max)

            tab_visible=False
            while tab_visible==False :
                try:
                    data_tab=driver.find_element_by_xpath('/html/body/div[2]/div[3]/div/div[5]/div[1]/div[3]/ul/li[2]/a')
                    data_tab.click()
                    tab_visible=True

                except:
                    time.sleep(2)
                    pass
            courtesy_wait(wait_min, wait_max)

            
            could_download=False
            error_count=0;
    
            while could_download==False and error_count<5:
            
                try:
                    print('Trying to hover.')
                    export_button=driver.find_element_by_xpath('/html/body/div[2]/div[1]/div/table/tbody/tr[2]/td[2]/div[1]/div[2]/a[2]/span/span[3]')
                    hover = ActionChains(driver).move_to_element(export_button)
                    hover.perform()

                    print('Trying to click csv button.')
                    csv_button=driver.find_element_by_xpath('/html/body/div[6]/div[2]/div[1]')
                    driver.execute_script("arguments[0].scrollIntoView();", csv_button)
                    csv_button.click()
                    could_download=True

                except Exception as e: 
                    print(e)
                    time.sleep(1)
                    error_count+=1
                    pass
                
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
                        time.sleep(1)
                        pass
                    
                
            download='C:/Users/lorenzo/Downloads/emiss_keyfuel.csv'   
            download_wait=0
            while os.path.isfile(download)==False and download_wait<10:
                time.sleep(1)
                download_wait+=1
            
            try:
                shutil.move(download,destination)
            except:
                pass
    
        print('Done')
    
    driver.close()
    driver.switch_to.window(main_window)
    driver.close()
    

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
    
