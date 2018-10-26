***This .do file prepares data to be mapped***;

#delimit;
set more off; 

pause on;

clear;

set trace on;
set tracedepth 1;

use "S:\particulates\data_processing/data/dtas/country/country_aggregates/country_aggregates.dta", clear;
tempfile gpw_countries;
drop if missing(gpw_v4_national_identifier_gri);
isid country gpw_v4_national_identifier_gri;
*collapse (count) Terra2000, by(country gpw_v4_national_identifier_gri);
gen wc_country=country;

***replace wc_country=master if country==using;
replace wc_country="Bolivia" if country=="Bolivia (Plurinational State of)";
replace wc_country="Iran" if country=="Iran (Islamic Republic of)";
replace wc_country="Falkland Islands" if country=="Falkland Islands (Malvinas)";
replace wc_country="Faroe Islands" if country=="Faeroe Islands";
replace wc_country="Micronesia" if country=="Micronesia (Federated States of)";
replace wc_country="Sint Maarten" if country=="Sint Maarten (Dutch part)";
replace wc_country="Venezuela" if country=="Venezuela (Bolivarian Republic of)";
replace wc_country="Vietnam" if country=="Viet Nam";
replace wc_country="United Kingdom" if country=="United Kingdom of Great Britain and Northern Ireland";
replace wc_country="United States" if country=="United States of America";
replace wc_country="United States Minor Outlying Islands" if country=="Puerto Rico" | country=="United States Virgin Islands" | country=="American Samoa" | country=="Guam" | country=="Northern Mariana Islands";
replace wc_country="Syria" if country=="Syrian Arab Republic";
replace wc_country="The Former Yugoslav Republic of Macedonia" if country=="The former Yugoslav Republic of Macedonia";
replace wc_country="Palestinian Territory" if country=="State of Palestine";
replace wc_country="Laos" if country=="Lao People's Democratic Republic";
replace wc_country="Moldova" if country=="Republic of Moldova";
replace wc_country="South Korea" if country=="Republic of Korea";
replace wc_country="North Korea" if country=="Democratic People's Republic of Korea";
replace wc_country="Tanzania" if country=="United Republic of Tanzania";
replace wc_country="Samoa" if country=="Western Samoa";
replace wc_country="Curacao" if country=="Curaçao";


save `gpw_countries';

import delimited "S:\particulates\data_processing\data\mapping\world_countries_2011_list\country_list.csv", clear encoding(UTF8);
tempfile wc_countries;
rename country wc_country;
collapse (count) land_rank, by(wc_country);

save `wc_countries';

merge 1:m wc_country using `gpw_countries';

replace highqualGPW=0 if highqualGPW==.;

gen has_BP_data=1 if !missing(	Oil2000, Oil2001, Oil2002, Oil2003, Oil2004, Oil2005,
								Oil2006, Oil2007, Oil2008, Oil2009, Oil2010, Oil2011,
								Oil2012, Oil2013, Oil2014, Oil2015, 
								Coal2000, Coal2001, Coal2002, Coal2003, Coal2004, Coal2005,
								Coal2006, Coal2007, Coal2008, Coal2009, Coal2010, Coal2011,
								Coal2012, Coal2013, Coal2014, Coal2015, 
								Gas2000, Gas2001,	Gas2002, Gas2003, Gas2004, Gas2005,
								Gas2006, Gas2007, Gas2008, Gas2009, Gas2010, Gas2011,
								Gas2012, Gas2013, Gas2014, Gas2015);
								
gen has_IEA_data=1 if !missing(	IEA_Oil2000, IEA_Oil2001, IEA_Oil2002, IEA_Oil2003, IEA_Oil2004, IEA_Oil2005,
								IEA_Oil2006, IEA_Oil2007, IEA_Oil2008, IEA_Oil2009, IEA_Oil2010, IEA_Oil2011,
								IEA_Oil2012, IEA_Oil2013, IEA_Oil2014, IEA_Oil2015, 
								IEA_Coal2000, IEA_Coal2001, IEA_Coal2002, IEA_Coal2003, IEA_Coal2004, IEA_Coal2005,
								IEA_Coal2006, IEA_Coal2007, IEA_Coal2008, IEA_Coal2009, IEA_Coal2010, IEA_Coal2011,
								IEA_Coal2012, IEA_Coal2013, IEA_Coal2014, IEA_Coal2015, 
								IEA_Other2000, IEA_Other2001,	IEA_Other2002, IEA_Other2003, IEA_Other2004, IEA_Other2005,
								IEA_Other2006, IEA_Other2007, IEA_Other2008, IEA_Other2009, IEA_Other2010, IEA_Other2011,
								IEA_Other2012, IEA_Other2013, IEA_Other2014, IEA_Other2015);


local fuel_types Oil Coal Other;
local years 2000 2001 2002 2003 2004 2005 2006 2007 2008 2009 2010 2011 2012 2013 2014 2015;
foreach fuel_type of local fuel_types{;
foreach year of local years{;
local fuel_str=substr("`fuel_type'",1,4);
local year_str=substr("`year'",3,2);
rename IEA_`fuel_type'`year' `fuel_str'`year_str'IEA;
};
};
replace has_BP_data=0 if has_BP_data==.;
replace has_IEA_data=0 if has_IEA_data==.;

forvalues year=2000/2015{;
	local year_str=substr("`year'",3,2);
	gen CoalKm2`year'=Coal`year_str'IEA/area;
};

keep if _merge!=2;
replace country="Non GPW Territory" if country=="";
drop _merge;
export delimited "../../../data/mapping/country_lvl_vars/country_lvl_vars_join.csv", replace;

*Label territories we cannot find in the gpw country list as such;

/*
Territory List;
Most of the following will have no data, so can safely be dropped;

*New Zealand;
Tokelau	master only (1)

*Australia;
Christmas Island	master only (1)
Cocos Islands	master only (1)
Heard Island and McDonald Islands	master only (1)

*France;
French Southern Territories	master only (1)
Guadeloupe	using only (2)
Martinique	using only (2)
New Caledonia	using only (2)
Saint Pierre and Miquelon	using only (2)
Wallis and Futuna Islands	using only (2)
French Guiana	using only (2)
French Polynesia	using only (2)

*Norway
Bouvet Island	master only
Svalbard and Jan Mayen Islands	using only (2)

*Finland
�land Islands	using only (2)

*UK
Gibraltar	master only (1)
South Georgia	master only (1)
British Indian Ocean Territory	master only (1)

*China
China Hong Kong Special Administrative Region	using only (2)
China Macao Special Administrative Region	using only (2)

*Netherlands;
Bonaire Saint Eustatius and Saba	using only (2)

*Own countries
Tuvalu	master only (1)
Monaco	master only (1)
Singapore	master only (1)
Holy See	master only (1)
Kosovo	using only (2)
Western Sahara	using only (2)
Mayotte	using only (2)
Niue	using only (2)
Taiwan	using only (2)

*/;
*The following is at the country year region level.;
*If we merge it into an ubergrid file, and keep the id and flow variables, we can use dta2raster to export into a net flow raster that varies at the country region level, for each year. 
#delimit;

use "S:\particulates\data_processing\data\dtas\country_regions/flux/net_flows_into.dta", clear ;
gen urban_wb2010=1 if region=="urban";
replace urban_wb2010=0 if region=="rural";
tempfile country_regionvars;
save `country_regionvars', replace;


use "../../../data/dtas/analyze_me_land.dta", clear;
merge m:1 gpw_v4_national_identifier_gri urban_wb2010 using `country_regionvars', keep(match);
keep uber_code net_flow_into* ;
tempfile uber_code_country_region;

save `uber_code_country_region', replace;

*Create dta to map urban region, high quality GPW countries, and model sample;
use "..\\..\\..\\data\\projections\\generated\\settings.dta", clear;

*Define C,R as column and row totals in current ubergrid.;
local C=COLUMNCOUNT[1];
local R=ROWCOUNT[1];
dis "Number of Columns: " `C';
dis "Number of Rows: " `R';

local Nobs=`C'*`R';
clear;
set obs `Nobs';
gen uber_code=_n;
merge 1:1 uber_code using `uber_code_country_region', nogen;
recode net_flow_into* (.=-9999);
save "../../../data/dta2raster/dtas/country_region_flows.dta", replace;


