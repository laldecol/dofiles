***This .do file prepares data to be mapped***;

#delimit;
set more off; 

pause on;

clear;

set trace off;
set tracedepth 1;

use "S:\particulates\data_processing\data\dtas\country_year\pixel_data_country_avgs.dta", clear;
tempfile gpw_countries;

collapse (count) year, by(country);
gen wc_country=country;

***replace wc_country=master if country==using;
replace wc_country="Bolivia" if country=="Bolivia (Plurinational State of)";
replace wc_country="Iran" if country=="Iran (Islamic Republic of)";
replace wc_country="Falkland Islands" if country=="Falkland Islands (Malvinas)";

/*;
replace wc_country="Iran" if country=="Iran (Islamic Republic of)";
CÃ´te d'Ivoire	master only (1)
C�te d'Ivoire	using only (2)

Curacao	master only (1)
Cura�ao	using only (2)

RÃ©union	master only (1)
R�union	using only (2)
*/;

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

collapse (count) land_rank, by(country);
rename country wc_country;
save `wc_countries';

merge 1:m wc_country using `gpw_countries';
drop if _merge==2;

*Label territories we cannot find in the gpw country list as such;
gen nongpw_territory=1 if _merge==1;
replace nongpw_territory=0 if _merge==3;

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
