#delimit;
set trace off;
set tracedepth 1;
pause off;

/*;
This .do uses parameters estimated in estimate_emission_factors.do to

1. Show plots of estimated coefficients;

*/;

use "../../../data/dtas/country_regions/emission_factors/all_emission_factors.dta", clear;
format country %45s;
 
replace var=subinstr(var,":_cons","",.);
replace coef=invlogit(coef) if var=="sigma_c" | var=="sigma_o" | var=="sigma_f";
replace coef=exp(coef) if var=="psi_c" | var=="psi_o" | var=="psi_f";

local sigmavars Coal Oil Fire;

sort var constant_urban_sender sigma;
by var constant_urban_sender (sigma): gen sigma_order=_n;

sort var constant_urban_sender psi;
by var constant_urban_sender (psi): gen psi_order=_n;


foreach sigmavar of local sigmavars{;
	
	sort var constant_urban_sender sigma;
	twoway line sigma sigma_order if var=="`sigmavar'", ti("`sigmavar' share in sending region") by(constant_urban_sender) yline(0 1)  caption("Horizontal lines at sigma=0 and sigma=1");
	graph export "../../../analysis/emission_factors/figures/sigma_estimates_`sigmavar'.png", replace;
	
	sort var constant_urban_sender psi;
	twoway line psi psi_order if var=="`sigmavar'", ti("`sigmavar' PM10 emissions , kg per unit") by(constant_urban_sender) yline(0);
	graph export "../../../analysis/emission_factors/figures/psi_estimates_`sigmavar'.png", replace;

};

order country var rural_coef urban_coef;
sort country var rural_coef urban_coef;
