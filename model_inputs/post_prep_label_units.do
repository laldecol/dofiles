#delimit;
set tracedepth 1;
set trace on;
set more off;
capture log close;
log using post_prep_label_units.log, replace;
/*;
This .do file:

1. Changes units in analyze_me_land.dta and analyze_me_mod5.dta into the km/ton/yr system;
2. Labels variables to make the normalizations explicit;
3. Saves output with a new name;

Affected variables are:;
1.Wind;
2.Energy;

Created: October 27, 2017, by Lorenzo
Last modified: October 27, 2017, by Lorenzo
*/;
use "..\\..\\..\\data\dtas\analyze_me_land.dta", clear;

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
label var `windvar'`year' "Average `direction' wind speed, km/hr";
};
};


*Energy variables: change units and label variables;

forvalues year = 2000/2015{;

*Change units from million tonnes of oil equivalent per year 
*to tonnes of oil equivalent per year;

*1000ktoe in a mtoe;
*8760 hours in a year;

replace Coal`year'=Coal`year'*1000000;
replace Oil`year'=Oil`year'*1000000;
replace Gas`year'=Gas`year'*1000000;

replace IEA_Coal`year'=IEA_Coal`year'*1000;
replace IEA_Oil`year'=IEA_Oil`year'*1000;
replace IEA_Other`year'=IEA_Other`year'*1000;

label var Coal`year' "Coal energy consumption, toe/yr";
label var Oil`year' "Oil energy consumption, toe/yr";
label var Gas`year' "Gas energy consumption, toe/yr";

label var IEA_Coal`year' "IEA Coal energy consumption, toe/yr";
label var IEA_Oil`year' "IEA Oil energy consumption, toe/yr";
label var IEA_Other`year' "IEA Other energy consumption, toe/yr";

};

save "..\\..\\..\\data\\dtas\analyze_me_land_std_units.dta", replace;

/*;
Can keep Fire vars the same by reinterpreting the \psi^b;
Fire2000 Fire2001 Fire2002 Fire2003 Fire2004 Fire2005 Fire2006 Fire2007 Fire2008 Fire2009 Fire2010 Fire2011 Fire2012 Fire2013 Fire2014 Fire2015 ;
*/;
log close;
