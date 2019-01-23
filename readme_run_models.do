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

*Calculate variables to feed the models;
if 1==1{;
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
