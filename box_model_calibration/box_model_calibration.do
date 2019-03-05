#delimit;
set tracedepth 1;
set trace on;
set more off;
pause on;

/*;
This .do file is based on MT's note mass_balance6.pdf, from Jan 18, 2019

It takes as inputs:

1. Data from box_model_inputs.dta, in particular:
	a. wind, to and from world, by sender status
	b. wind from sender to receiver, as defined in the note
	c. border lengths
	d. AOD concentrations in sender and receiver
	e. Area of sending and receiving regions
	f. Mixing height lambda and AOD to PM10 conversion factor rho, parameters
2. Energy consumption shares, from Lint's calibration


It produces as outputs:

1. Estimated deposition velocities for sender and receiver
2. Region specific emission factors psi1
3. Region specific unobserved emissions psi0
4. Region-year residuals from the OLS regression

Created: October 26, 2017, by Lorenzo
Last modified: Feb 15, 2019, by Lorenzo
*/;

*Define set of years we want to process;
local years 2000 2001 2002 2003 2004 2005 2006 2007 2008 2009 2010 2011 2012 2013 2015;
local countries "China";
local rho=100;
local lambda=3;
local vd=3; 
local k=10;

local appendfiles;

foreach year of local years{;
local appendfiles `appendfiles' "..\\..\\..\\data\\dtas\\country\\emission_factor_inputs_`year'.dta";
};
clear;


append using `appendfiles',  generate(file);


/*;
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


pause;
					
save "..\\..\\..\\data\\dtas\\country\\box_model_calibration_v1_`year'.dta", replace;

					};
*/;
