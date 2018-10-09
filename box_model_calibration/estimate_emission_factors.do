#delimit;
set trace off;
set tracedepth 1;
pause on;
/*;
This .do:

1. Constructs the database needed to estimate emission factors.
2. Estimates the emisson factors.
3. Saves emission factors to disk for analysis and further manipulation;
*/;

**1.1. Reshape each emission_factor_inputs`year'.dta into country-region level;
**1.2. Append all country-region files together;
**1.3. Merge in country-year level energy consumption data;

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
 
local products Oil Coal;
foreach product of local products{;

	merge m:1 country using "../../../data/BP/generated/`product'Consumption.dta", keepusing(`product'*) nogen keep(match);
	
};

merge m:1 country using "../../../data/dtas/country/country_aggregates/country_aggregates.dta", nogen keepusing(Fire*) keep(match);

reshape long Oil Coal Fire net_flow_into Terra_ area_ sender_dummy_ Xk, i(country gpw_v4_national_identifier_gri region) j(year);
***Check and label units;

*Notice sending region switches from rural to urban in some years for some countries;
bysort country : tab sender_dummy region;
bysort country region: egen sender_freq=total(sender_dummy_) if !missing(sender_dummy_);

gen constant_sender=(sender_freq==15 | sender_freq==0) if !missing(sender_dummy_);
gen constant_urban_sender= ((sender_freq==15 & region=="urban") | (sender_freq==0 & region=="rural")) if !missing(sender_dummy_);
gen constant_rural_sender= ((sender_freq==15 & region=="rural") | (sender_freq==0 & region=="urban")) if !missing(sender_dummy_);

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

capture rm "../../../data/dtas/country_regions/emission_factors/urban_emission_factors.dta";
touch "../../../data/dtas/country_regions/emission_factors/urban_emission_factors.dta", replace;

capture rm "../../../data/dtas/country_regions/emission_factors/rural_emission_factors.dta";
touch "../../../data/dtas/country_regions/emission_factors/rural_emission_factors.dta", replace;

pause;
foreach country of local countries{;

	dis "`country'";
	
	capture noisily reg net_flow_into `parms_urban' if gpw_v4_national_identifier_gri==`country' & region=="urban";
	
	if _rc==0{;
		
		capture regsave `parms_urban' using "../../../data/dtas/country_regions/emission_factors/urban_emission_factors.dta", ci append
		addlabel(gpw_v4_national_identifier_gri, `country');
		*matrix beta_urban=(`country', e(b));
		*matrix Urban=Urban\beta_urban;
		*local rownames_urban `rownames_urban' `country';
	};
	capture ereturn clear;
	
	dis "`country'";
	capture noisily reg net_flow_into `parms_rural' if gpw_v4_national_identifier_gri==`country' & region=="rural";
	if _rc==0{;
		capture regsave `parms_rural' using "../../../data/dtas/country_regions/emission_factors/rural_emission_factors.dta", ci append
		addlabel(gpw_v4_national_identifier_gri, `country', );
		*matrix beta_rural=(`country', e(b));
		*matrix Rural=Rural\beta_rural;
		*local rownames_rural `rownames_rural' `country';
	};
	capture ereturn clear;
	
};

local regions urban rural;

*Plot coefficients as estimated;

foreach region of local regions {;
	foreach parm of local parms_`region'{;
		use "../../../data/dtas/country_regions/emission_factors/`region'_emission_factors.dta", clear;
		sort var coef;
		by var (coef): gen order=_n;
		twoway line ci_lower coef ci_upper order if var=="`parm'" & order>3 & order<55, ti("`parm' emission coefficients in `region'");
		graph export "../../../analysis/emission_factors/figures/`region'_emission_estimates_`parm'.png", replace;
	};
};

*Clean regression output;
foreach region of local regions{;
	
	use "../../../data/dtas/country_regions/emission_factors/`region'_emission_factors.dta", clear;
	merge m:1 gpw_v4_national_identifier_gri using "../../../data/dtas/country/emission_factor_inputs_2000.dta", nogen keepusing(country);
	
	foreach var of varlist coef stderr ci_lower ci_upper N r2{;
		rename `var' `region'_`var';
	};
	save "../../../data/dtas/country_regions/emission_factors/`region'_emission_factors.dta", replace;
};

*Use estimated aggregate emission factors to back out regional consumption shares and overall emission shares;

use "../../../data/dtas/country_regions/emission_factors/rural_emission_factors.dta", clear;
merge 1:1 gpw_v4_national_identifier_gri var using "../../../data/dtas/country_regions/emission_factors/urban_emission_factors.dta", nogen;
merge m:1 gpw_v4_national_identifier_gri using `constant_senders', nogen keep(match);

gen coef_source=urban_coef*constant_urban_sender+rural_coef*constant_rural_sender if !missing(constant_urban_sender, constant_rural_sender) & (var=="Coal" | var=="Oil" | var=="Fire");
gen coef_receiv=rural_coef*constant_urban_sender+urban_coef*constant_rural_sender if !missing(constant_urban_sender, constant_rural_sender) & (var=="Coal" | var=="Oil" | var=="Fire");

gen sigma=coef_source/(coef_source+coef_receiv);
gen psi=sigma*coef_source;

local sigmavars Coal Oil Fire;

sort var sigma;
by var (sigma): gen sigma_order=_n;

sort var psi;
by var (psi): gen psi_order=_n;

foreach sigmavar of local sigmavars{;
	sort var sigma;
	twoway line sigma sigma_order if var=="`sigmavar'", ti("`sigmavar' share in sending region") by(constant_urban_sender) yline(0 1)  caption("Horizontal lines at sigma=0 and sigma=1");
	graph export "../../../analysis/emission_factors/figures/sigma_estimates_`sigmavar'.png", replace;
	
	sort var psi;
	twoway line psi psi_order if var=="`sigmavar'" & psi_order>3 & psi_order<31, ti("`sigmavar' PM10 emissions , kg per unit") by(constant_urban_sender) yline(0);
	graph export "../../../analysis/emission_factors/figures/psi_estimates_`sigmavar'.png", replace;

};
