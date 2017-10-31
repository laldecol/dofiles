#delimit;
set tracedepth 1;
set trace on;
set more off;

/*;
This .do file:

1. Changes units in analyze_me_land.dta and analyze_me_mod5.dta into the km/ton/hr system;
2. Labels variables to make the normalizations explicit;
3. Saves output with a new name;

Affected variables are of three types:;
1.Wind;
2.Energy;

Created: October 27, 2017, by Lorenzo
Last modified: October 27, 2017, by Lorenzo
*/;
use "S:\particulates\data_processing\data\dtas\analyze_me_land.dta", clear;

*Wind variables: change units and label variables;
foreach windvar in uwnd_ vwnd_{;
forvalues year = 2000/2015{;
if "`windvar'"=="uwnd_"{;
*Change wind units from m/s to km/hr;
local direction "eastward";
};

if "`windvar'"=="vwnd_"{;
*Change wind units from m/s to km/hr;
local direction "northward";
};

replace `windvar'`year' = `windvar'`year'*3.6; 
label var `windvar'`year' "Average `direction' wind speed, km/hr";
};
};


*Energy variables: change units and label variables;

forvalues year = 2000/2015{;

*Change units from million tonnes of oil equivalent per year 
*to kilotonnes of oil equivalent per hour;

*1000ktoe in a mtoe;
*8760 hours in a year;

replace Coal`year'=Coal`year'/8.76;
replace Oil`year'=Oil`year'/8.76;
replace Gas`year'=Gas`year'/8.76;

label var Coal`year' "Coal energy consumption, ktoe/hr";
label var Oil`year' "Oil energy consumption, ktoe/hr";
label var Gas`year' "Gas energy consumption, ktoe/hr";

};

save "S:\particulates\data_processing\data\dtas\analyze_me_land_std_units.dta", replace;

/*;
Can keep Fire vars the same by reinterpreting the \psi^b;
Fire2000 Fire2001 Fire2002 Fire2003 Fire2004 Fire2005 Fire2006 Fire2007 Fire2008 Fire2009 Fire2010 Fire2011 Fire2012 Fire2013 Fire2014 Fire2015 ;
*/;
