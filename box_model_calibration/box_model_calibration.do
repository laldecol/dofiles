#delimit;
set tracedepth 1;
set trace on;
set more off;

/*;
This .do file computes, for each country:

1. psi variables, one for each source type in Matt's box model
2. Transport matrices, in the same form as in LB's model
Created: October 26, 2017, by Lorenzo
Last modified: October 26, 2017, by Lorenzo
*/;

*Define set of years we want to process;
local years 2005;
local rho 100;
local lambda 3;
local vd .0072; 
local k 10;

foreach year of local years{;
use "..\\..\\..\\data\\dtas\\country\\box_model_inputs`year'.dta", clear;



tempvar Cs;
tempvar Cr;

gen Cs=.;
gen Cr=.;

replace 
Cs=	`rho'*
	(`vd'*sending_area_urban
	-`lambda'*length_urban_world_border*wind_urban_world
	-`lambda'*length_interior_border*wind_urban_rural) if urban_sender_pixel_model==1;
	
replace
Cs= `rho'*
	(`vd'*sending_area_rural
	-`lambda'*length_rural_world_border*wind_rural_world
	-`lambda'*length_interior_border*wind_rural_urban) if urban_sender_pixel_model==0;
	
replace 
Cr= `rho'*
	(`vd'*sending_area_rural
	-`lambda'*length_rural_world_border*wind_rural_world) if urban_sender_pixel_model==1;
	 
replace 
Cr= `rho'*
	(`vd'*sending_area_urban
	-`lambda'*length_urban_world_border*wind_urban_world) if urban_sender_pixel_model==0;

gen A=.;

replace A= `rho' * `lambda'* length_interior_border * wind_urban_rural/(Cr*Cs) if urban_sender_pixel_model==1;

replace A= `rho' * `lambda'* length_interior_border * wind_rural_urban/(Cr*Cs) if urban_sender_pixel_model==0;
		
gen psi_b=.;
gen psi_o=.;
gen psi_c=.;

***Gen psi_ vars for urban sender;
replace psi_o=	(Terra_avg_interior_urban-flux_from_world_urban/Cs)*
				(Cs/(`k'*Coal`year'+Oil`year')) if urban_sender_pixel_model==1;

replace psi_c=	`k'*psi_o if urban_sender_pixel_model==1;

replace psi_b=	(Terra_avg_interior_rural-
				A*(psi_c*Coal`year'+psi_o*Oil`year'+flux_from_world_urban)-flux_from_world_rural)*
				(Cr/Fire`year'rural) if urban_sender_pixel_model==1;

***Gen psi_ vars for rural sender;
replace psi_b=	(Cs*Terra_avg_interior_rural-flux_from_world_rural)/Fire`year'rural if urban_sender_pixel_model==0;

replace psi_o=	(Terra_avg_interior_urban-A*(psi_b*Fire`year'rural+flux_from_world_rural)-flux_from_world_urban/Cr)*
				(Cr/(`k'*Coal`year'+Oil`year')) if urban_sender_pixel_model==0;
				
replace psi_c=`k'*psi_o if urban_sender_pixel_model==0;
};

merge 1:1 gpw_v4_national_identifier_gri using "S:\particulates\calibration_v1\data\country_regions\country_lvl2005_calib1.dta";
order country gpw_v4_national_identifier_gri psi_b psi_o psi_c;
bro if calibration_sample_05;
