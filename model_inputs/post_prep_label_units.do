#delimit;
set tracedepth 1;
set trace off;
set more off;
capture log close;
log using post_prep_label_units.log, replace;
/*;
This .do file:

1. Changes units in analyze_me_land.dta and analyze_me_mod5.dta into the km/Mtoe/yr system;
2. Labels variables to make the normalizations explicit;
3. Saves output with a new name;

Affected variables are:;
1.Wind;
2.Energy;

Created: October 27, 2017, by Lorenzo
Last modified: October 27, 2017, by Lorenzo
*/;
use "..\\..\\..\\data\dtas\analyze_me_land.dta", clear;

*Climate variables;
foreach pre_var of varlist pre*{;
	label var `pre_var' "Mean monthly precipitation, mm";
};

*Wind variables: change units and label variables;
foreach windvar in uwnd_ vwnd_{;
forvalues year = 2000/2015{;
if "`windvar'"=="uwnd_"{;
*Change wind units from m/s to km/yr;
local direction "eastward";
};

if "`windvar'"=="vwnd_"{;
*Change wind units from m/s to km/yr;
local direction "northward";
};
*31536000 seconds in a year, 1000m in a km;
replace `windvar'`year' = `windvar'`year'*31536; 
label var `windvar'`year' "Average `direction' wind speed, km/yr";
};
};


*Energy variables: keep Mtoe units and label variables;

forvalues year = 2000/2015{;


replace Coal`year'=Coal`year';
replace Oil`year'=Oil`year';
replace Gas`year'=Gas`year';

replace IEA_Coal`year'=IEA_Coal`year';
replace IEA_Oil`year'=IEA_Oil`year';
replace IEA_Other`year'=IEA_Other`year';

label var Coal`year' "BP Coal energy consumption, Mtoe/yr";
label var Oil`year' "BP Oil energy consumption, Mtoe/yr";
label var Gas`year' "BP Gas energy consumption, Mtoe/yr";

label var IEA_Coal`year' "IEA Coal energy consumption, Mtoe/yr";
label var IEA_Oil`year' "IEA Oil energy consumption, Mtoe/yr";
label var IEA_Other`year' "IEA Other energy consumption, Mtoe/yr";

};

save "..\\..\\..\\data\\dtas\analyze_me_land_std_units.dta", replace;

use "..\\..\\..\\data\\dtas\\analyze_me_flux.dta", clear;

*Wind variables: change units and label variables;
foreach windvar in uwnd_ vwnd_{;
forvalues year = 2000/2015{;
if "`windvar'"=="uwnd_"{;

*Change wind units from m/s to km/yr;
local direction "eastward";
};

if "`windvar'"=="vwnd_"{;

*Change wind units from m/s to km/yr;
local direction "northward";
};

*31536000 seconds in a year, 1000m in a km;
replace `windvar'`year' = `windvar'`year'*31536; 
label var `windvar'`year' "Average `direction' wind speed, km/yr";
};
};

save "..\\..\\..\\data\\dtas\analyze_me_flux_std_units.dta", replace;


log close;
