#delimit;
*This .do file;
local years 2000;

*Use urbanization dummies to generate a region variable for each year;
foreach year of local years{;
use "..\\..\\..\\data\\dtas\\analyze_me_land.dta", clear;

*Create country label for nonland;
replace gpw_v4_national_identifier_gri=-9999 if gpw_v4_national_identifier_gri==.;
replace country="Sea, Inland Water, other Uninhabitable" if gpw_v4_national_identifier_gri==-9999;

egen countryXregion`year'=group(country urban_wb`year'), label;
gen region_str="";
replace region_str="urban" if urban_wb`year'==1;
replace region_str="rural" if urban_wb`year'==0;

pause;

collapse (count) uber_code (firstnm) gpw_v4_national_identifier_gri 
rgdpe`year' rgdpo`year' Oil`year' Coal`year' Gas`year' 
countryGDPpc`year' urban_wb`year' countrypop`year'
(mean) Terra`year' (sum) area, by(countryXregion`year' country region_str);

drop countryXregion`year';
drop uber_code;
reshape wide Terra`year' area, i(country) j(region_str) string;

save "S:\\particulates\\data_processing\\data\\dtas\\country_regions\\country_lvl`year'.dta", replace;

};

