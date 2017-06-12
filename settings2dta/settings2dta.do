*settings2dta.do
*This .do reads settings.txt (written when generating ubergrid) and saves its
*contents as a .dta with parameters names as variables and values as the single
*observation's values. This format allows easy access of ubergrid parameters from
*stata. 

* set up;
#delimit;
set more off;
pause off;
clear;

import delimited "..\\..\\data\projections\\generated\\settings.txt", clear;

forvalues obs = 1(1)16{;

if mod(`obs',2)==1{;
local variable=v1[`obs'];
gen `variable'=v1[`obs'+1];

};

};
drop v1;
drop if _n>1;
destring, replace;

save "..\\..\\data\projections\\generated\\settings.dta", replace;
