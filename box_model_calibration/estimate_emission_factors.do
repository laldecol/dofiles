#delimit;
set more off;
set trace off;
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
	
*Insheet Lint's regional energy consumption shares;
	use "..\..\..\..\data_processing_calibration\data\to_main\generated\energy_outputs_PANEL.dta", clear;
	drop res*;
	
	merge m:1 code using `code_id', nogen;
	
	rename (Ecu Epu Egu) (Ec_urban Ep_urban Eg_urban);
	rename (Ecr Epr Egr) (Ec_rural Ep_rural Eg_rural);
	
	reshape long Ec_ Ep_ Eg_, i(code country year) j(region) string;
	
	tempfile energy_cons;
	save `energy_cons';
	
*Insheet fires;
	use "../../../data/dtas/country/country_aggregates/country_aggregates.dta", clear;
	keep country Fire*;
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
 
 *Merge all input year tempfiles together;
	 use `flows_merge2000', clear;
	 
	 local merge_years 2001 2002 2003 2004 2005 2006 2007 2008 2009 2010 2011 2012 2013 2015;
	 
	 foreach merge_year of local merge_years{;
		merge 1:1 country gpw_v4_national_identifier_gri region using `flows_merge`merge_year'', nogen;
	 };
	 
	merge m:1 country using `country_agg', nogen;
	reshape long net_flow_into Xk sender_dummy_ Fire Terra_, i(country gpw_v4_national_identifier_gri region) j(year);

*Count years each region is a sender - our model assumes no switching;
	bysort country region: egen sender_freq=total(sender_dummy_) if !missing(sender_dummy_);


*Merge in energy consumption;
	merge 1:1 country region year using `energy_cons', nogen;
	keep if CalibrationError==0 & (sender_freq>=12 | sender_freq==0);
	gen region_sender=cond(sender_freq>=12,1,0,.);
*Define country sample: correct calibration and no swiching;
	levelsof country , local(regcountries);
	
	gen urban_dummy=cond(region=="urban",1,0,.);
	gen rural_dummy=cond(region=="rural",1,0,.);
	gen Xu=Xk*urban_dummy;
	gen Xa=Xk*rural_dummy;
	
	gen Ecu=Ec_*urban_dummy;
	gen Eca=Ec_*rural_dummy;
	
	gen Epu=Ep_*urban_dummy;
	gen Epa=Ep_*rural_dummy;
	
	gen Fra=Fire*rural_dummy;
	
	encode country, generate(country_code);
	encode region, generate(region_code);
	reg net_flow_into Xu Xa Ecu Eca Epu Epa Fra i.country_code#i.region_code ;
	
	local cfile_pooled "../../../data/dtas/country_regions/emission_factors/pooled_reg_emission_factors.dta";
	
	regsave _cons using `cfile_pooled', replace ci pval
			addvar(						
					v_ud,	_b[Xu],			_se[Xu],
					v_ad,	_b[Xa],			_se[Xa],
					
					psi_uc, -1*_b[Ecu],		_se[Ecu],
					psi_up, -1*_b[Epu],		_se[Epu],
					
					psi_ac, -1*_b[Eca],		_se[Eca],
					psi_ap, -1*_b[Epa],		_se[Epa],
					psi_af, -1*_b[Fra],		_se[Fra],
					
					);
					
	
	predict nu_ij, resid;
	
	use `cfile_pooled', clear;
	
	
*Prepare files to output coefficients;
/*;
	local cfile_sender "../../../data/dtas/country_regions/emission_factors/sender_emission_factors.dta";
	local cfile_receiver "../../../data/dtas/country_regions/emission_factors/receiver_emission_factors.dta";
	
	capture rm `cfile_sender';
	touch `cfile_sender', replace;

	capture rm `cfile_receiver';
	touch `cfile_receiver', replace;

foreach country of local regcountries{;
		
		preserve;
		
		*******************;
		*Sender regression*;
		*******************;
		
		keep if region_sender==1 & country=="`country'";
		
		*Check region is constant within country and sender status;
		sort region;
		assert region[1]==region[_N];
		
		*If urban is sender for country, save constant, coal, and oil 
		*coefficients in sender file;
		if region[1]=="urban"{;
		
			capture reg net_flow_into Xk Ec Ep;
			local rc=_rc;
			capture regsave _cons Xk Ec_ Ep_ using `cfile_sender', append ci pval
			addvar(	psi_s0,	-1*_b[_cons],	_se[_cons],
					psi_sc, -1*_b[Ec_],		_se[Ec_],
					psi_sp, -1*_b[Ep_],		_se[Ep_],
					v_sd,	_b[Xk],			_se[Xk],
					)
			addlabel(	country,	"`country'",
						rc, 		`rc',
						region, 	"urban"
					);
					

		};
		*If rural is sender for country, save constant, coal, and oil 
		*coefficients in sender file;
		
		else if region[1]=="rural"{;
			capture reg net_flow_into Xk Ec Ep Fire;
			local rc=_rc;
			capture regsave _cons Xk Ec_ Ep_ using `cfile_sender', append ci pval
			addvar(	psi_s0,	-1*_b[_cons], 	_se[_cons],
					psi_sc, -1*_b[Ec_],		_se[Ec_],
					psi_sp, -1*_b[Ep_],		_se[Ep_],
					psi_sf, -1*_b[Fire],	_se[Fire],
					v_sd,	_b[Xk],			_se[Xk],
					)
			addlabel(	country,	"`country'",
						rc, 		`rc',
						region, 	"rural"
					);
			
		};
			
		
		
		restore, preserve;;
		
		*********************;
		*Receiver regression*;
		*********************;
		
		keep if region_sender==0 & country=="`country'";
		
		*Check region is constant within country and sender status;
		sort region;
		assert region[1]==region[_N];
		
		*If urban is receiver for country, save constant, coal, and oil 
		*coefficients in sender file;
		if region[1]=="urban"{;
		
			capture reg net_flow_into Xk Ec Ep;
			local rc=_rc;
			capture regsave _cons Xk Ec_ Ep_ using `cfile_receiver', append ci pval
			addvar(	psi_r0,	-1*_b[_cons], 	_se[_cons],
					psi_rc, -1*_b[Ec_], 	_se[Ec_],
					psi_rp, -1*_b[Ep_],		_se[Ep_],
					v_rd,	_b[Xk],			_se[Xk],
					)
			addlabel(	country,	"`country'",
						rc, 		`rc',
						region, 	"urban"
					);
;
		};
					

		*If rural is receiver for country, save constant, coal, and oil 
		*coefficients in sender file;
		
		else if region[1]=="rural"{;
			capture reg net_flow_into Xk Ec Ep Fire;
			local rc=_rc;
			capture regsave _cons Xk Ec_ Ep_ using `cfile_receiver', append ci pval
			addvar(	psi_r0,	-1*_b[_cons],	_se[_cons],
					psi_rc, -1*_b[Ec_],		_se[Ec_],
					psi_rp, -1*_b[Ep_],		_se[Ep_],
					psi_rf, -1*_b[Fire],	_se[Fire],
					v_rd,	_b[Xk],			_se[Xk],
					)
			addlabel(	country,	"`country'",
						rc, 		`rc',
						region, 	"rural"
					);
		};
		restore;
			
		

};

local outfiles cfile_sender cfile_receiver;
foreach file of local outfiles{;
	use ``file'', clear;
	drop if var=="Xk" | var=="Ec_" | var=="Ep_" | var=="_cons" | N<=11;
	save ``file'', replace;
	label var 
};
*/;
log close;
