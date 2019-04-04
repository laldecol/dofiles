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
	
	keep country Fire* IEA_Coal* IEA_Oil* rgdpe2010;
	reshape long Fire IEA_Coal IEA_Oil, i(country) j(year);
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
		
		local ts_vars net_flow_into_urban net_flow_into_rural
		Terra_urban Terra_rural
		Terra_avg_world_rural Terra_avg_world_urban
		area_urban area_rural 
		sender_dummy_urban sender_dummy_rural
		flux_to_world_rural flux_from_world_rural 
		flux_to_world_urban flux_from_world_urban;
		
		keep country gpw_v4
		`ts_vars';
		
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
	
	gen flux_to_world_country	=	flux_to_world_rural		+	flux_to_world_urban;
	gen flux_from_world_country	= 	flux_from_world_urban	+ 	flux_from_world_rural;
	gen net_flow_into_country	=	flux_from_world_country	-	flux_to_world_country;
	gen X_c						=	AOD_country * `rho' * area_country;
		
	*Sender and receiver regression, by country;
	
	local countries 
	`"
	"Bangladesh" "Brazil" "China" "Germany"  
	"Indonesia" "Russian Federation" "United States of America"
	"';
	capture log close regs;
	log using ef_regs.log, replace name(regs);
	
	dis "Pooled country years";
	reg net_flow_into_country X_c Fire IEA_Coal IEA_Oil;
	
	foreach country of local countries{;
		dis "Sample: `country'";
		reg net_flow_into_country X_c Fire IEA_Coal IEA_Oil	if country=="`country'";	
	};
	
	dis "Fixed Effect regression, high income countries";
	reg net_flow_into_country X_c Fire IEA_Coal IEA_Oil	i.gpw_v4_national_id if hic;	
	
	dis "Fixed Effect regression, low income countries";
	reg net_flow_into_country X_c Fire IEA_Coal IEA_Oil	i.gpw_v4_national_id if !hic;	
	
	log close regs;
	*Receiver regression;
	/*;
	local cfile_pooled "../../../data/dtas/country_regions/emission_factors/pooled_reg_ef.dta";
	regsave Xu using `cfile_pooled', replace ci pval
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
	
	reg net_flow_into Xu Xa c.Ecu#i.hic c.Eca#i.hic c.Epu#i.hic c.Epa#i.hic c.Fra#i.hic i.country_code#i.region_code ,  nocons ;
	
	local cfile_pooled_bi "../../../data/dtas/country_regions/emission_factors/pooled_reg_ef_by_income.dta";
	regsave Xu using `cfile_pooled_bi', replace ci pval
			addvar(						
					v_ud,	_b[Xu],			_se[Xu],
					v_ad,	_b[Xa],			_se[Xa],
					
					psi_uc_l, -1*_b[0b.hic#c.Ecu],		_se[0b.hic#c.Ecu],
					psi_up_l, -1*_b[0b.hic#c.Epu],		_se[0b.hic#c.Epu],
					
					psi_ac_l, -1*_b[0b.hic#c.Eca],		_se[0b.hic#c.Eca],
					psi_ap_l, -1*_b[0b.hic#c.Epa],		_se[0b.hic#c.Epa],
					psi_af_l, -1*_b[0b.hic#c.Fra],		_se[0b.hic#c.Fra],

					psi_uc_h, -1*_b[1.hic#c.Ecu],		_se[1.hic#c.Ecu],
					psi_up_h, -1*_b[1.hic#c.Epu],		_se[1.hic#c.Epu],
					
					psi_ac_h, -1*_b[1.hic#c.Eca],		_se[1.hic#c.Eca],
					psi_ap_h, -1*_b[1.hic#c.Epa],		_se[1.hic#c.Epa],
					psi_af_h, -1*_b[1.hic#c.Fra],		_se[1.hic#c.Fra],
					
					);
					
	predict nu_ij_bi, resid;
	save "../../../data/dtas/country_regions/emission_factors/residuals.dta", replace;
	
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
*/;
log close;
