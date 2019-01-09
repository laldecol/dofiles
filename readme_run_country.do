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

*Prepare data for regressions, model, and maps;
if 1==2{;
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
	do box_inputs.do;
	do macro_inputs.do;
	do reg_inputs.do;
	cd ..;
};

if 1==1{;
	cd prepare_mapping;
	do prepare_mapping.do;
};
