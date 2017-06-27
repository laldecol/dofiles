* set up;
#delimit;
clear all;
cls;
set more off;

cd S:\particulates\data_processing\dofiles\IEAclean;
local python "C:\Python27\ArcGIS10.2\python.exe";

import excel "S:\particulates\data_processing\data\IEA\source\IEA_HeadlineEnergyData_2016.xlsx", sheet("TimeSeries_1971-2015") cellrange(A2:BD5897) firstrow clear;

foreach v of varlist G-AX {;
   local x : variable label `v';
   rename `v' y`x';
   *label variable y`x' "`v'";
};

keep if Flow =="Total final consumption (ktoe)";
keep if Product == "Coal, peat and oil shale" | Product == "Oil products" | Product == "Natural gas";

replace Country="Republic of Korea" if Country=="Korea";
replace Country="United States of America" if Country=="United States";
replace Country="China" if Country=="People's Republic of China";
replace Country="Slovakia" if Country=="Slovak Republic";
replace Country="United Kingdom of Great Britain and Northern Ireland"
 if Country=="United Kingdom";

foreach product in "Coal, peat and oil shale" "Oil products" "Natural gas"{;
preserve;
keep if Product=="`product'";
local name=subinstr("`product'",",","",.);
local name=subinstr("`name'"," ","",.);
rename Country country;

save `"..\\..\\..\\data\\IEA\\generated/`name'.dta"', replace;

use "..\..\\..\\data\\dtas\\analyze_me.dta", clear;
merge m:1 country using `"..\\..\\data\\IEA\\generated/`name'.dta"';
save "..\\..\\..\\data\\dtas\\analyze_me.dta",replace;

restore;
};

keep if country!="";
keep if _merge==3 | _merge==1;

gen popweights=.;
gen pwquality=.;
gen EU=.;

replace EU=1 if country=="Austria" |
country=="Belgium" |
country=="Bulgaria" |
country=="Croatia" |
country=="Cyprus" |
country=="Czech Republic" |
country=="Denmark" |
country=="Estonia" |
country=="Finland" |
country=="France" |
country=="Germany" |
country=="Greece" |
country=="Hungary" |
country=="Ireland" |
country=="Italy" |
country=="Latvia" |
country=="Lithuania" |
country=="Luxembourg" |
country=="Malta" |
country=="Netherlands" |
country=="Poland" |
country=="Portugal" |
country=="Romania" |
country=="Slovakia" |
country=="Slovenia" |
country=="Spain" |
country=="Sweden" |
country=="United Kingdom of Great Britain and Northern Ireland"
;

egen countrycode=group(country);
sum countrycode;
forvalues i=1/`r(max)' {;
tab country if countrycode==`i';
sum projected_aggregated_gpw_2010 if countrycode==`i';
replace popweights=projected_aggregated_gpw_2010/(r(N)*r(mean)) if countrycode==`i';
replace pwquality=popweights*gpw_v4_data_quality_indicators;
};

collapse (sum) pwquality (mean) _merge (mean) EU (count) Terra2010count=Terra2010avg countrycount=pwquality, by(country);
gen CoverageTerra2010= Terra2010count/ countrycount
;
gsort -_merge -EU pwquality -CoverageTerra2010
;
order country _merge EU pwquality CoverageTerra2010
;



clear;




