#delimit;
set trace on;
set tracedepth 1;
pause on;
capture program drop _all;
/*;
This .do:

1. Constructs the database needed to estimate emission factors.
2. Estimates the emisson factors.
3. Saves emission factors to disk for analysis and further manipulation;
*/;

**1.1. Reshape each emission_factor_inputs`year'.dta into country-region level;
**1.2. Append all country-region files together;
**1.3. Merge in country-year level energy consumption data;

program nleq8;
	version 15;
	syntax varlist(min=4 max=5) if, at(name);
	local pred_inflow : word 1 of `varlist';
	local Xk : word 2 of `varlist';
	local Oil: word 3 of `varlist';
	local Coal: word 4 of `varlist';
	local Fire: word 5 of `varlist';
	// Retrieve parameters out of at matrix;
	tempname 	sigma_c 	sigma_o 	sigma_f
				psi_c 		psi_o 		psi_f
				vd_s 		vd_r
				c_s 		c_r;

	*We estimate a transformation of the parameter, so that it is restricted to 
	*a certain range;
	
	*invlogit returns values in (0,1);
	scalar `sigma_c' = invlogit(`at'[1, 1]);
	scalar `sigma_o' = invlogit(`at'[1, 2]);
	scalar `sigma_f' = invlogit(`at'[1, 3]);
	
	*exp returns values in (0, inf);
	scalar `psi_c'	 = exp(`at'[1, 4]);
	scalar `psi_o'	 = exp(`at'[1, 5]);
	scalar `psi_f'	 = exp(`at'[1, 6]);
	scalar `vd_s'	 = exp(`at'[1, 7]);
	scalar `vd_r'	 = exp(`at'[1, 8]);
	scalar `c_s'	 = `at'[1, 9];
	scalar `c_r'	 = `at'[1, 10];

	// Fill in dependent variable;
	replace `pred_inflow' = -`vd_s'*`Xk'
							+`sigma_c'*`psi_c'*`Coal'
							+`sigma_o'*`psi_o'*`Oil'
							+`sigma_f'*`psi_f'*`Fire'
							+`c_s'
							`if' & sender_dummy_==1;
	
	replace `pred_inflow' = -`vd_r'*`Xk'
							+(1-`sigma_c')*`psi_c'*`Coal'
							+(1-`sigma_o')*`psi_o'*`Oil'
							+(1-`sigma_f')	*`psi_f'*`Fire'
							+`c_r'
							`if' & sender_dummy_==0;
end;



local rho 10;
local h 1000;

local years 2000 2001 2002 2003 2004 2005 2006 2007 2008 2009 2010 2011 2012 2013 2015;

foreach year of local years{;
	use "S:\particulates\data_processing\data\dtas\country\emission_factor_inputs_`year'.dta", clear;
	
	keep 
	country gpw_v4_national_identifier_gri 
	flux_to_interior_rural flux_to_world_rural flux_from_world_rural
	flux_to_interior_urban flux_to_world_urban flux_from_world_urban
	Terra_avg_interior_rural sending_area_rural  
	Terra_avg_interior_urban sending_area_urban  
	urban_sender_pixel_model;
	
	drop if gpw_v4_national_identifier_gri==-9999;

	*Generate reshapeable sender status;
	gen sender_dummy_rural=(1-urban_sender_pixel_model);
	gen sender_dummy_urban=urban_sender_pixel_model;
	drop urban_sender_pixel_model;

	*Suppose urban_sender_pixel_model==1.;
	*Recall gen urban_sender_pixel_model=(flux_to_interior_rural<flux_to_interior_urban);
	*Then net flows are calculated as:;
	
	*Flows are in AOD units per hour. Want to convert into kg of PM10/ year;
	gen net_flow_into_urban=24*365*`rho'*
	(flux_from_world_urban-flux_to_world_urban-flux_to_interior_urban+flux_to_interior_rural);
	label var net_flow_into_urban "Flow into urban region, in kg of PM10 per year ";
	
	gen net_flow_into_rural=24*365*`rho'*
	(flux_from_world_rural-flux_to_world_rural-flux_to_interior_rural+flux_to_interior_urban);
	label var net_flow_into_rural "Flow into rural region, in kg of PM10 per year";

	drop
	flux_from_world_urban flux_to_world_urban 
	flux_from_world_rural flux_to_world_rural 
	flux_to_interior_rural flux_to_interior_urban;

	rename Terra_avg_interior_rural Terra_rural;
	rename Terra_avg_interior_urban Terra_urban;
	rename sending_area_rural area_rural;
	rename sending_area_urban area_urban;

	reshape long net_flow_into_ Terra_ area_ sender_dummy_,
	 i(country gpw_v4_national_identifier_gri ) j(region) string;

	rename net_flow_into net_flow_into`year';
	rename Terra_ Terra_`year';
	rename area_ area_`year';
	rename sender_dummy_ sender_dummy_`year';
	 
	gen Xk`year'=-area_*Terra_*`rho';

	tempfile flows_merge`year';
	save `flows_merge`year'', replace;
};
 
 use `flows_merge2000', clear;
 local merge_years 2001 2002 2003 2004 2005 2006 2007 2008 2009 2010 2011 2012 2013 2015;
 foreach merge_year of local merge_years{;
 merge 1:1 country gpw_v4_national_identifier_gri region using `flows_merge`merge_year'', nogen;
 };
 
 save "../../../data/dtas/country_regions/flux/net_flows_into.dta", replace;
 
local products Oil Coal;
foreach product of local products{;

	merge m:1 country using "../../../data/BP/generated/`product'Consumption.dta", keepusing(`product'*) nogen keep(match);
	
};

merge m:1 country using "../../../data/dtas/country/country_aggregates/country_aggregates.dta", nogen keepusing(Fire*) keep(match);

reshape long Oil Coal Fire net_flow_into Terra_ area_ sender_dummy_ Xk, i(country gpw_v4_national_identifier_gri region) j(year);
drop if year==2014;
***Check and label units;

*Notice sending region switches from rural to urban in some years for some countries;
bysort country : tab sender_dummy region;
bysort country region: egen sender_freq=total(sender_dummy_) if !missing(sender_dummy_);

gen constant_sender=(sender_freq==15 | sender_freq==0) if !missing(sender_dummy_);
gen constant_urban_sender= ((sender_freq==15 & region=="urban") | (sender_freq==0 & region=="rural")) if !missing(sender_dummy_);
gen constant_rural_sender= ((sender_freq==15 & region=="rural") | (sender_freq==0 & region=="urban")) if !missing(sender_dummy_);

save "../../../data/dtas/country_year/emission_factor_inputs.dta", replace;

pause;
preserve;
collapse (firstnm) constant_urban_sender constant_rural_sender if constant_sender==1, by(country gpw_v4_national_identifier_gri);
tempfile constant_senders;
save `constant_senders';
restore;


levelsof gpw_v4_national_identifier_gri if constant_sender==1, local(countries);
local ncountries : word count `countries';

local parms_urban Xk Oil Coal Fire;
local parms_rural Xk Oil Coal Fire;

local nparms_urban: word count `parms_urban';
local nparms_rural: word count `parms_rural';

matrix Urban = J(1,`nparms_urban'+2,.);
matrix Rural = J(1,`nparms_rural'+2,.);

matrix colname Urban =  gpw_v4_national_identifier_gri `parms_urban' constant;
matrix colname Rural =  gpw_v4_national_identifier_gri `parms_rural' constant;
local rownames_urban first;
local rownames_rural first;

capture rm "../../../data/dtas/country_regions/emission_factors/all_emission_factors.dta";
touch "../../../data/dtas/country_regions/emission_factors/all_emission_factors.dta";

foreach country of local countries{;

	dis "`country'";
	tab country if gpw_v4_national_identifier_gri==`country';
	*reg net_flow_into `parms_urban' if gpw_v4_national_identifier_gri==`country'; 
	*capture noisily reg net_flow_into `parms_urban' if gpw_v4_national_identifier_gri==`country' & region=="urban";
	capture noisily nl eq8 @ net_flow_into `parms_urban' if gpw_v4_national_identifier_gri==`country', 
	parameters(
 	sigma_c 	sigma_o 	sigma_f
	psi_c 		psi_o 		psi_f
	vd_s 		vd_r
	c_s 		c_r
	)
	initial(
	sigma_c 0	sigma_o 0	sigma_f 0
	psi_c 10	psi_o 10	psi_f 10
	vd_s 5		vd_r 5
	c_s 0 		c_r 0)
	;
	
	*capture noisily nl (net_flow_into = exp({ln_pOil})*Oil  +exp({ln_pCoal})*Coal + exp({ln_pFire})*Fire-exp({ln_Vd})*Xk + {c}) if gpw_v4_national_identifier_gri==`country' & region=="urban", 
	nolog variables(Oil Coal Fire Xk);
	
	if _rc==0{;
		
		capture regsave _cons using "../../../data/dtas/country_regions/emission_factors/all_emission_factors.dta", ci append
		addlabel(gpw_v4_national_identifier_gri, `country');
		*matrix beta_urban=(`country', e(b));
		*matrix Urban=Urban\beta_urban;
		*local rownames_urban `rownames_urban' `country';
	};
	capture ereturn clear;
};
local regions urban rural;

*Plot coefficients as estimated;
/*;
foreach region of local regions {;
	foreach parm of local parms_`region'{;
		use "../../../data/dtas/country_regions/emission_factors/`region'_emission_factors.dta", clear;
		sort var coef;
		by var (coef): gen order=_n;
		twoway line ci_lower coef ci_upper order if var=="`parm'" & order>3 & order<55, ti("`parm' emission coefficients in `region'");
		graph export "../../../analysis/emission_factors/figures/`region'_emission_estimates_`parm'.png", replace;
	};
};
*/;
*Clean regression output;

use "../../../data/dtas/country_regions/emission_factors/all_emission_factors.dta", clear;
merge m:1 gpw_v4_national_identifier_gri using "../../../data/dtas/country/emission_factor_inputs_2000.dta", nogen keepusing(country);
merge m:1 gpw_v4_national_identifier_gri using `constant_senders', nogen keep(match);
save "../../../data/dtas/country_regions/emission_factors/all_emission_factors.dta", replace;

/*;foreach region of local regions{;
	
	
	pause;
	gen double temp_coef=exp(coef);
	drop coef;
	rename temp_coef coef;
	
	replace var=subinstr(var, "ln_p", "",.);
	replace var=subinstr(var, "ln_", "",.);
	replace var=subinstr(var, ":_cons", "",.);
	
	foreach var of varlist coef stderr ci_lower ci_upper N r2{;
		rename `var' `region'_`var';
	};
	save "../../../data/dtas/country_regions/emission_factors/`region'_emission_factors.dta", replace;
};
use "../../../data/dtas/country_regions/emission_factors/rural_emission_factors.dta", clear;
merge 1:1 gpw_v4_national_identifier_gri var using "../../../data/dtas/country_regions/emission_factors/urban_emission_factors.dta", nogen;
merge m:1 gpw_v4_national_identifier_gri using `constant_senders', nogen keep(match);

save "../../../data/dtas/country_regions/emission_factors/all_emission_factors.dta", replace;
*/;

*Use estimated aggregate emission factors to back out regional consumption shares and overall emission shares;
