#delimit;
set trace on;
set more off;
*obsolete as of 23/10/2017. Look at bordersdta.do
/*;
This .do file computes, for each country:

1. Mean wind speed and direction;

Created: October 23, 2017, by Lorenzo
Last modified: October 24, 2017, by Lorenzo
*/;

*Define set of years we want to process;
local years 2000 2005 2010 2015;

*Must create a neighbor world and neighbor interior dummy here.;
for year of local years{;

collapse (count) vwnd_pixels=vwnd_ uwnd_pixels=uwnd_ (mean) vwnd_mean=vwnd_ uwnd_mean=uwnd_ , by( countryXregion`year' neighbor_);
merge m:1 countryXregion`year' using "..\\..\\..\\data\\dtas\\country\\country_codes_names`year'.dta", nogen;
rename neighbor_country_name_ own_country_name;
rename neighbor_ctry_ own_country;
rename neighbor_rgn_ own_region;
rename countryXregion`year' own_countryXregion`year';

merge m:1 neighbor_ using "..\\..\\..\\data\\dtas\country\\country_codes_names`year'.dta", nogen;
drop countryXregion`year';
gen interior_border=(sender_country_name==neighbor_country_name);

save "..\\..\\..\\data\\dtas\\country_regions\\wind\\wind`year'.dta", replace;

};
restore;
