#delimit;
set trace on;
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

sort var constant_urban_sender coef;
by var constant_urban_sender (coef): gen sigma_order=_n;

sort var constant_urban_sender coef;
by var constant_urban_sender (coef): gen psi_order=_n;

local sigmavars sigma_c sigma_o sigma_f;
local psivars psi_c psi_o psi_f;

foreach sigmavar of local sigmavars{;
	
	cdfplot coef if var=="`sigmavar'", by(constant_urban_sender) title("`sigmavar' CDF, by sender region");
	graph export "../../../analysis/emission_factors/figures/sigma_estimates_`sigmavar'.png", replace ;
};

foreach psivar of local psivars{;

	cdfplot coef if var=="`psivar'", by(constant_urban_sender) title("`psivar' CDF, by sender region");
	graph export "../../../analysis/emission_factors/figures/psi_estimates_`psivar'.png", replace;
};

order country var coef constant_urban_sender constant_rural_sender;
sort country var coef constant_urban_sender constant_rural_sender;

save "../../../data/dtas/country_regions/emission_factors/restricted_shares_emissions.dta", replace;
