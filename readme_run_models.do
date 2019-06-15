/**********************************************
R E A D M E _ R U N. D O

This program serves as a driver and documentation 
for all the code in \\particulates;

last modified: Jan 9, 2019, by la
**********************************************/
* set up;
#delimit;
clear all;
cls;
set more off;

local python "C:\Python27\ArcGIS10.2\python.exe";

********************************************************************************;
** Step 2: Generate inputs for macro model, pollution model, and regressions  **;
********************************************************************************;
if 1==1{;
	cd model_inputs;
	do macro_inputs.do;
	do box_inputs.do;
	do reg_inputs.do;
	do calculate_net_flows.do;
	cd ..;
};

*****************************************************;
** Step 2: Calibrate economic and pollution model  **;
*****************************************************;

if 1==2{;
	cd ../../../data_processing_calibration/dofiles;
	do readme_run_calibration.do;
	cd ../../data_processing/dofiles_la/dofiles;
};

***************************;
** Step 3: Prepare maps  **;
***************************;

if 1==1{;
	cd prepare_mapping;
	do country_map_prep.do;
	do country_region_map_prep.do;
	shell $python country_region_map_join.py;
	cd ..;
};


