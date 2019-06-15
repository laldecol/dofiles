
#delimit;
set more off; 
set matsize 4000;
pause on;
set emptycells drop;
capture log close;
clear;
set trace on;
set tracedepth 3;
/*;

This .do file processes analyze_me.dta & analyze_me_land.dta to write all the pixel or pixel-year 
level files used by macro_inputs.do, box_inputs.do, reg_inputs.do, and
prepare_mapping.do.

Created by Lorenzo from code previously in pixel_data_prep;
Last modified: 21 Feb 2019, by Lorenzo;

*II. Choose samples, and save separate .dtas for each;
*/;
log using save_samples.log, text replace;

*END I.;
	
*II. Choose samples, save separate .dtas for each, and calculate country year and country level means and totals;

**Reshape to create two .dtas: one for all years and one for mod5years, for the 
*sample specified in local samplepixels;

*Keep defined sample and save two reshaped files:;
*all_pooled contains all years, and mod5 contains only mod5 years;
*Locals defined here help write down samples for regressions; 
*samplepixels determines the sample to be used;
*Keep all pixels with data for mod5 years;
local samplepixels "Terra2000!=. & Terra2005!=. & Terra2010!=. & Terra2015!=.
& gpwpop2000!=. & gpwpop2005!=. & gpwpop2010!=. & gpwpop2015!=.
& country!="" ";

local reshape_vars 
Terra gpwpop Fire
water trees pasture barren crops urban other urban_wb 
cld wet vap tmp frs pre 
Oil Coal Gas
IEA_Coal IEA_Oil IEA_Other
urbanshare 
rgdpe rgdpo countrypop countryGDPpc vwnd_ uwnd_
ag_burn ag_emiss_noburn ag_waste_burn_coeff_avg coal_coeff emissag emissbiomass
emisscoal emisselec emissgas emissheat emisshydrogen emissindustrial
emissnofuel emissnonexhaust emissnuc emissoil emissotheren emissrenewables
emisssolvent emisssum enbiomass encoal enelec engas enheat enhydrogen
ennuc enoil enotheren enrenewables ensum gas_coeff oil_coeff 
vAGREMPL vAGRTOTL vINDEMPL vINDMANF vINDTOTL vSRVEMPL vSRVTOTL;

local keep_vars 
uber_code country countryXregion_const calibration_sample_05
gpw_v4_national_identifier_gri gpw_v4_data_quality_indicators
area;
*Keep only analysis variables;

	use "..\\..\\..\\data\\dtas\\analyze_me_land.dta", clear;

	foreach reshape_var of local reshape_vars{;
	local abbrev_name `reshape_var'*;
	unab more_keepvars : `abbrev_name';
	local keep_vars `keep_vars' `more_keepvars';
};

	keep `keep_vars';
	keep if `samplepixels';

	save "..\\..\\..\\data\\dtas\pixel_sample.dta", replace;

	*All countries pooled;
	reshape long `reshape_vars',
	 i(uber_code country area) j(year);
	
	*generate interval variables;
	gen fiveyearint=.;
	replace fiveyearint=1 if year>=2000 & year<=2005;
	replace fiveyearint=2 if year>2005 & year<=2010;
	replace fiveyearint=3 if year>2010 & year<=2015;
	drop if gpw_v4_nat==-9999;
	compress;
	save "..\\..\\..\\data\\dtas\analyze_me_land_allpooled.dta", replace;

	*Collapse to country level to keep country means and totals;
	
	use "..\\..\\..\\data\\dtas\\analyze_me_land.dta";
	
	drop if country=="" | gpw_v4_national_identifier_gri==.;
	drop if gpw_v4_national_identifier_gri==-9999;
	
	collapse (mean) Terra* cld* vap* wet* pre*
	(sum) Fire* gpwpop* area 
	(firstnm) Oil* Coal* Gas* IEA* highqualGPW rgdpo2010
	ag_burn* ag_emiss_noburn* ag_waste_burn_coeff_avg* coal_coeff* emissag* emissbiomass*
	emisscoal* emisselec* emissgas* emissheat* emisshydrogen* emissindustrial*
	emissnofuel* emissnonexhaust* emissnuc* emissoil* emissotheren* emissrenewables*
	emisssolvent* emisssum* enbiomass* encoal* enelec* engas* enheat* enhydrogen*
	ennuc* enoil* enotheren* enrenewables* ensum* gas_coeff* oil_coeff*
	vAGREMPL* vAGRTOTL* vINDEMPL* vINDMANF* vINDTOTL* vSRVEMPL* vSRVTOTL*
	rgdpe2010, by(gpw_v4_national_identifier_gri country);
	
	sum rgdpe2010, detail;
	gen hic=cond(rgdpe2010>=`r(p50)', 1, 0, .) if rgdpe2010!=.;
		
	isid country;
	isid gpw_v4_national_identifier_gri;
	save "../../../data/dtas/country/country_aggregates/country_aggregates.dta", replace;
	
	*Using mod5 years, save country year level averages of pixel level data;
	use "..\\..\\..\\data\\dtas\analyze_me_land_allpooled.dta", clear;
	***Keep modulo 5 years;
	keep if year==2000 | year==2005 | year==2010 | year==2015;

	*gen landshare to adjust density;
	gen landshare=(400-water)/400;
	gen density=gpwpop/(area*landshare);
	gen area_urban=urban_wb*area;
	save "..\\..\\..\\data\\dtas\analyze_me_land_mod5.dta", replace;

	*Flux sample;
	#delimit;
	use "..\\..\\..\\data\\dtas\\analyze_me.dta", clear;
	keep uber_code Terra* gpw_v4_national_identifier_gri area vwnd* uwnd*;
	merge 1:1 uber_code using "..\\..\\..\\data\\World_Bank\\generated\\urban_pixels.dta", nogen;
	replace country="Sea, Inland Water, other Uninhabitable" if gpw_v4_national_identifier_gri==-9999 | country=="";
	recode gpw_v4_national_identifier_gri (-9999=446);

	save "..\\..\\..\\data\\dtas\\analyze_me_flux.dta", replace;
*END II.;
log close;
