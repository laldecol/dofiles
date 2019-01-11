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

**************************************************;
** Step 1: Import and merge country level data  **;
**************************************************;
*Cleans and merges sources of country level data, preserving all pixels;
*BPclean defines a EU country and must be run last;

if 1==2{;

	cd mergecountrydata;
	
	*Penn World Tables GDP data;
	do PWTclean.do;
	
	*World bank urban shares;
	do urbanshareclean.do;
	
	*IEA energy consumption, including breakdown by fuel and sector;
	do IEAclean.do;
	cd "../clean_IEA";
	do sector_fuel.do;
	
	*BP energy consumption data;
	cd "../mergecountrydata";
	do BPclean.do;
	cd ..;
	
	*Successfully ran do files
	in \mergecountrydata;
	};

***************************************************;
** Step 2: Prepare regressions and calibration  **;
***************************************************;
************;

if 1==1{;
	cd model_inputs;
	do data_prep.do;
	do post_prep_label_units.do;
	cd ..;
};

*Compute flux between regions using a pixel-level box model;
if 1==2{;
	cd flux;
	do flux.do;
	cd ..;
};

*Calculate variables to feed the models;
if 1==2{;
	cd model_inputs;
	do macro_inputs.do;
	do box_inputs.do;
	do reg_inputs.do;
	cd ..;
};

**********************************;
** Step 2: Calibrate box model  **;
**********************************;

if 1==2{;
	cd box_model_calibration;
	do box_model_calibration;
	cd ..;
};

***************************************;
** Step 2: Calibrate economic model  **;
***************************************;
****Lint's code goes here;

if 1==2{;
	cd Lints_code_dir;
	do Lints_code.do;
};
