#delimit;
set trace off;
set tracedepth 1;
pause on;
capture program drop _all;
set more on;
/*;
This .do:

1. Constructs the database needed to estimate emission factors.
2. Estimates the emisson factors.
3. Saves emission factors to disk for analysis and further manipulation;
*/;

**1.1. Reshape each emission_factor_inputs`year'.dta into country-region level;
**1.2. Append all country-region files together;
**1.3. Merge in country-year level energy consumption data;
capture log close;
log using estimate_emission_factors.log, replace;
local rho 10;
local h 3;
local years 2000 2001 2002 2003 2004 2005 2006 2007 2008 2009 2010 2011 2012 2013 2015;

*Get country code id from Lint's file;
	use "..\..\..\..\data_processing_calibration\data\world_bank\generated\WB1clean.dta", clear;
	collapse (firstnm) country, by(code);
	tempfile code_id;
	save `code_id';
	
*Insheet Lint's regional energy consumption shares;
	use "..\..\..\..\data_processing_calibration\data\to_main\generated\energy_outputs_PANEL.dta", clear;
	drop res*;
	
	merge m:1 code using `code_id', nogen;
	
	rename (Ecu Epu Egu) (Ec_urban Ep_urban Eg_urban);
	rename (Ecr Epr Egr) (Ec_rural Ep_rural Eg_rural);
	
	reshape long Ec_ Ep_ Eg_, i(code country year) j(region) string;
	
	tempfile energy_cons;
	save `energy_cons';
	
foreach year of local years{;
	use "..\\..\\..\\data\\dtas\\country\\emission_factor_inputs_`year'.dta", clear;
	
	drop if gpw_v4_national_identifier_gri==-9999;

	*Generate reshapeable sender status;
	gen sender_dummy_rural=(1-urban_sender_pixel_model);
	gen sender_dummy_urban=urban_sender_pixel_model;
	drop urban_sender_pixel_model;

	*Flows are in AOD units per hour. Want to convert into Mt of PM10/ year;
	gen net_flow_into_urban=`rho'*
	(flux_from_world_urban-flux_to_world_urban-flux_to_interior_urban+flux_to_interior_rural)/1000000000;
	label var net_flow_into_urban "Flow into urban region, in Mt of PM10 per year ";
	
	gen net_flow_into_rural=`rho'*
	(flux_from_world_rural-flux_to_world_rural-flux_to_interior_rural+flux_to_interior_urban)/1000000000;
	label var net_flow_into_rural "Flow into rural region, in Mt of PM10 per year";

	rename Terra_avg_interior_rural Terra_rural;
	rename Terra_avg_interior_urban Terra_urban;
	rename sending_area_rural area_rural;
	rename sending_area_urban area_urban;

	keep country gpw_v4
	net_flow_into_urban net_flow_into_rural
	Terra_urban Terra_rural
	area_urban area_rural 
	sender_dummy_urban sender_dummy_rural;
	
	reshape long net_flow_into_ Terra_ area_ sender_dummy_,
	 i(country gpw_v4_national_identifier_gri ) j(region) string;

	rename net_flow_into net_flow_into`year';
	rename Terra_ Terra_`year';
	rename area_ area_`year';
	rename sender_dummy_ sender_dummy_`year';
	 
	gen Xk`year'=area_*Terra_*`rho';

	tempfile flows_merge`year';
	save `flows_merge`year'', replace;
};
 
 use `flows_merge2000', clear;
 local merge_years 2001 2002 2003 2004 2005 2006 2007 2008 2009 2010 2011 2012 2013 2015;
 foreach merge_year of local merge_years{;
 merge 1:1 country gpw_v4_national_identifier_gri region using `flows_merge`merge_year'', nogen;
 };
 
reshape long net_flow_into Xk sender_dummy_, i(country gpw_v4_national_identifier_gri region) j(year);

*Notice sending region switches from rural to urban in some years for some countries;
bysort country region: egen sender_freq=total(sender_dummy_) if !missing(sender_dummy_);

*Reshape to country year region level;

*Merge in energy consumption;
merge 1:1 country region year using `energy_cons', nogen;
keep if CalibrationError==0;
save "../../../data/dtas/country_year/emission_factor_inputs.dta", replace;
bysort country region: reg net_flow_into Xk Ec_ Ep_ Eg_;

log close;
