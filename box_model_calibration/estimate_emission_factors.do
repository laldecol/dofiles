#delimit;
set more off;
set trace off;
set tracedepth 1;
pause on;
capture program drop _all;
/*;
This .do:

1. Constructs the database needed to estimate emission factors.

*/;

**1.1. Reshape each emission_factor_inputs`year'.dta into country-region level;
**1.2. Append all country-region files together;
**1.3. Merge in country-year-region level energy consumption data from Lint's module;

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
	
*Get region codes from Lint;
	use "..\..\..\..\data_processing\data\regions\source\rice_regions.dta", clear;
	
	rename countrycode code;
	tempfile regions;
	save `regions';
	
*Insheet Lint's regional energy consumption shares;
	use "..\..\..\..\data_processing_calibration\data\to_main\generated\energy_outputs_PANEL.dta", clear;
	drop res*;
	
	merge m:1 code using `code_id', nogen;
	
	rename (Ecu Epu Egu) (Ec_urban Ep_urban Eg_urban);
	rename (Eca Epa Ega) (Ec_rural Ep_rural Eg_rural);
	*reshape long Ec_ Ep_ Eg_, i(code country year) j(region) string;
	
	*This is at the country year level, with regions in separate variables suffixed _urban and _rural;
	tempfile energy_cons;
	save `energy_cons';
	
*Insheet fires;
	use "../../../data/dtas/country/country_aggregates/country_aggregates.dta", clear;
	
	keep country Fire* IEA_Coal* IEA_Oil* cld* vap* wet* rgdpe2010;
	reshape long Fire IEA_Coal IEA_Oil cld vap wet
	, i(country) j(year);
	tempfile country_agg;
	save `country_agg';
	
*Insheet all emission input years and save as tempfiles;
	foreach year of local years{;
		use "..\\..\\..\\data\\dtas\\country\\emission_factor_inputs_`year'.dta", clear;
		
		drop if gpw_v4_national_identifier_gri==-9999;

		*Generate reshapeable sender status;
		gen sender_dummy_rural=(1-urban_sender_pixel_model);
		gen sender_dummy_urban=urban_sender_pixel_model;
		drop urban_sender_pixel_model;

		*Flows are in AOD units per hour up to here. 
		*Convert into Mt of PM10/ year;
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
		
		local ts_vars net_flow_into_urban net_flow_into_rural
		Terra_urban Terra_rural
		Terra_avg_world_rural Terra_avg_world_urban
		area_urban area_rural 
		sender_dummy_urban sender_dummy_rural
		flux_to_world_rural flux_from_world_rural 
		flux_to_world_urban flux_from_world_urban;
		
		keep country gpw_v4
		`ts_vars';
		
		preserve;
		
		reshape long 
		net_flow_into Terra Terra_avg_world area sender_dummy flux_to_world flux_from_world,
		i (country gpw_v4_national_identifier_gri ) j(region) string;
		
		replace region="urban" if region=="_urban";
		replace region="rural" if region=="_rural";
		
		gen net_flows_into_by_area=net_flow_into/area;
		label var net_flows_into_by_area "Flow into rural region, in Mt of PM10 per year per sq km";
		
		save "..\\..\\..\\data\\dtas\\country_regions\\flux\\net_flows_into`year'.dta", replace;
		restore;
		foreach ts_var of local ts_vars{;
			rename `ts_var' `ts_var'`year';
		};	
		*Correct shape but need to keep world AOD too. ;
		reshape long `ts_vars',
		 i(country gpw_v4_national_identifier_gri ) j(year);

		tempfile flows_merge`year';
		save `flows_merge`year'', replace;
	};
 
 *Merge all input year tempfiles together;
	 use `flows_merge2000', clear;
	 
	 local merge_years 2001 2002 2003 2004 2005 2006 2007 2008 2009 2010 2011 2012 2013 2015;
	 
	 foreach merge_year of local merge_years{;
		append using `flows_merge`merge_year'';
	 };

	 *Count years each region is a sender - our model assumes no switching;
	bysort country : egen sender_freq_urban=total(sender_dummy_urban) if !missing(sender_dummy_urban);

	 ***This is now at the country year level, with regions as separate variables;
	merge m:1 country year using `country_agg', nogen;
	sum rgdpe2010, detail;
	gen hic=cond(rgdp>=`r(p50)',1,0,.) if rgdp!=.;

*Merge in energy consumption;
	merge 1:1 country year using `energy_cons', nogen;
	keep if CalibrationError==0 & (sender_freq_urban>=12 | sender_freq_urban<=2);

*Define country sample: correct calibration and no swiching;
	*keep if CalibrationError==0 & (sender_freq_urban>=12 | sender_freq_urban<=2);

*Merge in region ids;	
	merge m:1 code using `regions', nogen;

*Define country sample: correct calibration and no switching;
	levelsof country , local(regcountries);
	
	encode country, generate(country_code);
	

	
	gen 	AOD_sender=			Terra_urban 			if sender_dummy_urban==1;
	replace AOD_sender=			Terra_rural 			if sender_dummy_urban==0;
	
	gen 	AOD_world_sender=	Terra_avg_world_urban 	if sender_dummy_urban==1;
	replace AOD_world_sender= 	Terra_avg_world_rural 	if sender_dummy_urban==0;
	
	gen 	Ec_sender=			Ec_urban				if sender_dummy_urban==1;
	replace	Ec_sender=			Ec_rural				if sender_dummy_urban==0;
	
	gen 	Ep_sender=			Ep_urban				if sender_dummy_urban==1;
	replace	Ep_sender=			Ep_rural				if sender_dummy_urban==0;
	
	gen 	Fr_sender=			0						if sender_dummy_urban==1;
	replace	Fr_sender=			Fire					if sender_dummy_urban==0;
	
	gen 	AOD_receiver=		Terra_urban 			if sender_dummy_urban==0;
	replace AOD_receiver=		Terra_rural 			if sender_dummy_urban==1;
	
	gen 	AOD_world_receiver=	Terra_avg_world_urban 	if sender_dummy_urban==0;
	replace AOD_world_receiver=	Terra_avg_world_rural 	if sender_dummy_urban==1;
	
	gen 	Ec_receiver=		Ec_urban				if sender_dummy_urban==0;
	replace	Ec_receiver=		Ec_rural				if sender_dummy_urban==1;
	
	gen 	Ep_receiver=		Ep_urban				if sender_dummy_urban==0;
	replace	Ep_receiver=		Ep_rural				if sender_dummy_urban==1;
	
	gen 	Fr_receiver=		0						if sender_dummy_urban==0;
	replace	Fr_receiver=		Fire					if sender_dummy_urban==1;
	
	
*Generate country level variables for one box model estimatio
*This section follows Matt's one box model note
*and Lint's one box model estimation note  from March , 2019;
	
	gen area_country=area_rural + area_urban;
	gen AOD_country=(	Terra_rural*area_rural	+	Terra_urban*area_urban)/area_country;
	
	gen flux_to_world_country	=	(flux_to_world_rural		+	flux_to_world_urban)*`rho'/1000000000;
	gen flux_from_world_country	= 	(flux_from_world_urban	+ 	flux_from_world_rural)*`rho'/1000000000;
	gen net_flow_into_country	=	(flux_from_world_country	-	flux_to_world_country);
	gen X_c						=	AOD_country * `rho' * area_country;
	
	label var Terra_avg_world_rural "World AOD concentration for the rural area";
	label var Terra_avg_world_urban "World AOD concentration for the urban area";
	label var flux_to_world_urban 	"Gross flow from urban to world, computed using pixel-flow model, AOD units per year";
	label var flux_to_world_rural 	"Gross flow from rural to world, computed using pixel-flow model, AOD units per year";
	label var flux_from_world_rural "Gross flow from world to rural, computed using pixel-flow model, AOD units per year";
	label var flux_from_world_urban "Gross flow from world to urban, computed using pixel-flow model, AOD units per year";
	label var Terra_rural 			"AOD concentration in rural region";
	label var Terra_urban			"AOD concentration in urban region";
	label var area_rural 			"Rural area, sq km";
	label var area_urban			"Urban area, sq km";
	label var sender_dummy_rural	"Dummy for rural sender";
	label var sender_dummy_urban 	"Dummy for urban sender";
	label var net_flow_into_rural 	"Flow into rural region, in Mt of PM10 per year";
	label var net_flow_into_urban 	"Flow into urban region, in Mt of PM10 per year ";
	label var sender_freq_urban 	"Number of years country is an urban sender" ;
	label var cld 					"Cloud cover";
	label var vap 					"Vapor pressure";
	label var wet 					"Rain days";
	label var Fire					"Fire pixels";
	
	label var AOD_sender 			"AOD concentration in sender region";
	label var AOD_world_sender 		"World AOD concentration in sender region";
	label var Ec_sender 			"Coal consumption in sender region, ktoe, from Lint's model";
	label var Ep_sender 			"Oil consumption in sender region, ktoe, from Lint's model";
	label var Fr_sender 			"Fire pixels in sender region";
	label var AOD_receiver 			"AOD concentration in receiver region";
	label var AOD_world_receiver 	"World AOD concentration in receiver region";
	label var Ec_receiver 			"Coal consumption in receiver region, ktoe, from Lint's model";
	label var Ep_receiver 			"Oil consumption in receiver region, ktoe, from Lint's model";
	label var Fr_receiver 			"Fire pixels in receiver region";
	label var area_country 			"Total country area, sq km";
	label var AOD_country 			"Average AOD in country";
	label var flux_to_world_country "Gross flow from country to world, Mt of PM10 per year";
	label var flux_from_world_country "Gross flow from world to country, Mt of PM10 per year";
	label var net_flow_into_country "Net flow into country, Mt of PM10 per year";
	label var X_c					"Area times rho times country AOD - coefficient, as in eq 5 of Lint's note";
	
	drop if country=="" | year==.;
	sort country year;
	save "../../../data/dtas/country_year/one_box_model_inputs.dta", replace;

log close;
