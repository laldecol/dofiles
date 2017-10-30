#delimit;
set tracedepth 1;
set trace on;
set more off;
pause on;

/*;
This .do file computes, for each country:

1. psi variables, one for each source type in Matt's box model
2. Transport matrices, in the same form as in LB's model
Created: October 26, 2017, by Lorenzo
Last modified: October 26, 2017, by Lorenzo
*/;

*Define set of years we want to process;
local years 2005;
local rho=100;
local lambda=3;
local vd=3; 
local k=10;

foreach year of local years{;
use "..\\..\\..\\data\\dtas\\country\\box_model_inputs`year'.dta", clear;

replace Fire`year'rural=1 if Fire`year'rural==0;
replace length_interior_border = 0 if country=="China Hong Kong Special Administrative Region";
replace flux_to_interior_rural = 0 if country=="China Hong Kong Special Administrative Region";
replace flux_to_interior_urban = 0 if country=="China Hong Kong Special Administrative Region";
replace flow_urban_rural = 0 if country=="China Hong Kong Special Administrative Region";
replace flow_rural_urban = 0 if country=="China Hong Kong Special Administrative Region";
replace wind_rural_urban = 0 if country=="China Hong Kong Special Administrative Region";
replace wind_urban_rural = 0 if country=="China Hong Kong Special Administrative Region";
replace wind_urban_world = 0 if country=="China Hong Kong Special Administrative Region";
replace wind_rural_world = 0 if country=="China Hong Kong Special Administrative Region";
replace Terra_avg_interior_urban = .6505333 if country=="China Hong Kong Special Administrative Region";
replace Terra_avg_interior_rural = .795 if country=="China Hong Kong Special Administrative Region";

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
*This line verified to match model;

replace A= `rho' * `lambda'* length_interior_border * wind_rural_urban/(Cr*Cs) if urban_sender_pixel_model==0;
		
gen psi_b=.;
gen psi_o=.;
gen psi_c=.;

***Gen psi_ vars for urban sender;
replace psi_o=	(Terra_avg_interior_urban-flux_from_world_urban/Cs)*(Cs/(`k'*Coal`year'+Oil`year')) if urban_sender_pixel_model==1;

replace psi_c=	`k'*psi_o if urban_sender_pixel_model==1;

replace psi_b=	(Terra_avg_interior_rural-
				A*(psi_c*Coal`year'+psi_o*Oil`year'+flux_from_world_urban)-flux_from_world_rural/Cr)*
				(Cr/Fire`year'rural) if urban_sender_pixel_model==1;
				
***Gen psi_ vars for rural sender;
replace psi_b=	(Cs*Terra_avg_interior_rural-flux_from_world_rural)/Fire`year'rural if urban_sender_pixel_model==0;

replace psi_o=	(Terra_avg_interior_urban-A*(psi_b*Fire`year'rural+flux_from_world_rural)-flux_from_world_urban/Cr)*
				(Cr/(`k'*Coal`year'+Oil`year')) if urban_sender_pixel_model==0;
				
replace psi_c=`k'*psi_o if urban_sender_pixel_model==0;


merge 1:1 gpw_v4_national_identifier_gri using "S:\particulates\calibration_v1\data\country_regions\country_lvl2005_calib1.dta", nogen;
order country gpw_v4_national_identifier_gri psi_b psi_o psi_c;
keep if calibration_sample_05;

label var psi_b "Particulates per unit fire";
label var psi_c "Particulates per carbon toe used";
label var psi_o "Particulates per oil toe used";

gen sender_eq_B_Coeff=.;
gen sender_eq_Rcoal_Coeff=.;
gen sender_eq_Roil_Coeff=.;
gen sender_eq_constant=.;

gen receiver_eq_B_Coeff=.;
gen receiver_eq_Rcoal_Coeff=.;
gen receiver_eq_Roil_Coeff=.;
gen receiver_eq_constant=.;

*Agricultural senders;
replace sender_eq_B_Coeff=psi_b/Cs if urban_sender_pixel_model==0;
replace sender_eq_Rcoal_Coeff=0 if urban_sender_pixel_model==0;
replace sender_eq_Roil_Coeff=0 if urban_sender_pixel_model==0;
replace sender_eq_constant=flux_from_world_rural/Cs if urban_sender_pixel_model==0;

replace receiver_eq_B_Coeff=A if urban_sender_pixel_model==0;
replace receiver_eq_Rcoal_Coeff=psi_c/Cr if urban_sender_pixel_model==0;
replace receiver_eq_Roil_Coeff=psi_o/Cr if urban_sender_pixel_model==0;
replace receiver_eq_constant=A*flux_from_world_rural+flux_from_world_urban/Cr if urban_sender_pixel_model==0;

*Urban senders;
replace sender_eq_B_Coeff=0 if urban_sender_pixel_model==1;
replace sender_eq_Rcoal_Coeff=psi_c/Cs if urban_sender_pixel_model==1;
replace sender_eq_Roil_Coeff=psi_o/Cs if urban_sender_pixel_model==1;
replace sender_eq_constant=flux_from_world_urban/Cs if urban_sender_pixel_model==1;

replace receiver_eq_B_Coeff=psi_b/Cr if urban_sender_pixel_model==1;
replace receiver_eq_Rcoal_Coeff=A*psi_c if urban_sender_pixel_model==1;
replace receiver_eq_Roil_Coeff=A*psi_o if urban_sender_pixel_model==1;
replace receiver_eq_constant=A*flux_from_world_urban+flux_from_world_rural/Cr if urban_sender_pixel_model==1;

drop length_interior_border length_urban_world_border length_rural_world_border 
Terra_avg_world_rural Terra_avg_world_urban flux_to_interior_rural uwnd_avg_interior_rural 
vwnd_avg_interior_rural flux_to_world_rural uwnd_avg_world_rural vwnd_avg_world_rural 
sending_area_rural flux_from_world_rural uwnd_avg_from_world_rural vwnd_avg_from_world_rural 
flux_to_interior_urban uwnd_avg_interior_urban vwnd_avg_interior_urban flux_to_world_urban 
uwnd_avg_world_urban vwnd_avg_world_urban sending_area_urban flux_from_world_urban 
uwnd_avg_from_world_urban vwnd_avg_from_world_urban vwnd_avg_from_world_urban 
flow_urban_world flow_rural_world flow_urban_rural flow_rural_urban flow_world_rural 
flow_world_urban wind_urban_world wind_rural_world wind_urban_rural wind_rural_urban 
wind_world_rural wind_world_urban urban_sender_region_model Cs Cr A y2005 y2016 
agshare2005 agshare2016 pop_rural2005 arearural pop_urban2005 areaurban 
rgdpe2005 rgdpo2005 countrypop2005 merge_WDISectoralOutput;

gen error_sender=.;
gen error_receiver=.;

replace error_sender=Terra_avg_interior_rural
					-sender_eq_B_Coeff*Fire`year'rural
					-sender_eq_Rcoal_Coeff*Coal`year'
					-sender_eq_Roil_Coeff*Oil`year'
					-sender_eq_constant if urban_sender_pixel_model==0;
replace error_receiver=Terra_avg_interior_urban
					-receiver_eq_B_Coeff*Fire`year'rural
					-receiver_eq_Rcoal_Coeff*Coal`year'
					-receiver_eq_Roil_Coeff*Oil`year'
					-receiver_eq_constant if urban_sender_pixel_model==0;

replace error_sender=Terra_avg_interior_urban
					-sender_eq_B_Coeff*Fire`year'rural
					-sender_eq_Rcoal_Coeff*Coal`year'
					-sender_eq_Roil_Coeff*Oil`year'
					-sender_eq_constant if urban_sender_pixel_model==1;
replace error_receiver=Terra_avg_interior_rural
					-receiver_eq_B_Coeff*Fire`year'rural
					-receiver_eq_Rcoal_Coeff*Coal`year'
					-receiver_eq_Roil_Coeff*Oil`year'
					-receiver_eq_constant if urban_sender_pixel_model==1;
};

save "..\\..\\..\\data\\dtas\\country\\box_model_calibration_v1_2005.dta", replace;
