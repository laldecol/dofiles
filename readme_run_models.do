/**********************************************
R E A D M E _ R U N. D O

This program serves as a driver and documentation 
for all the prep and model estimation in \\particulates.
It is mostly model dependent;

last modified: May 23, 2019, by Lorenzo
**********************************************/
* set up;
#delimit;
clear all;
cls;
set more off;


*Calculate variables to feed the models;
if 1==1{;
	cd model_inputs;
	do macro_inputs.do;
	do box_inputs.do;
	do reg_inputs.do;
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
