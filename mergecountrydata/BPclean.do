/*****************************************************************************
BPclean.do

This .do file imports data from BP's Statistical Review of World Energy 2016
into stata, cleans it, and merges it into the ubergrid database.

It also groups all states in the EU as a single country; for this reason this
.do file must run after all other country-level merges.

*Last modified: Jan 2 2017 la
*****************************************************************************/

* set up;
#delimit;
clear all;
cls;
set more off;
pause off;

*Define products, satellites, and years to process;
local products Oil Coal Gas;
local satellites "Terra";
local Terrayears 2000 2005 2010;

use "..\\..\\..\\data\\dtas\\analyze_me.dta", clear;

*Set the "parameters" of the import command for each product;
foreach product of local products{;
pause;
if "`product'"=="Oil"{;

local sheetname "Oil Consumption – Tonnes";
local endrange "BC112";
local lastvar "BC";
local removerows=10;
};

else if "`product'"=="Coal"{;
local sheetname "Coal Consumption -  Mtoe";
local endrange "BC112";
local lastvar "BC";
local removerows=11;
};

else if "`product'"=="Gas"{;
local sheetname "Gas Consumption – tonnes";
local endrange "BD114";
local lastvar "BD";
local removerows=11;
};
 
*Import the sheets and ranges that correspond to the product;
import excel "..\\..\\..\\data\BP\source\bp-statistical-review-of-world-energy-2016-workbook.xlsx",
 sheet("`sheetname'") cellrange(A3:`endrange') firstrow clear;

*Rename year variables to `product'`year' so stata can work with them;
foreach v of varlist B-AZ {;
   local x : variable label `v';
   rename `v' `product'`x';
   *label variable y`x' "`v'";
};

rename Milliontonnes country; // particular to the table structure

*Drop clutter variables and observations;
drop BA-`lastvar';
drop if country=="";

drop if strpos(country,"Total")>0;
drop if strpos(country,"Other")>0;
drop if country=="USSR";
drop `product'1965-`product'1999;

drop if _n>_N-`removerows';

*Clean values;
foreach variable of varlist `product'*{;
replace `variable'="0" if `variable'=="^";
};

destring `product'*, ignore("n/a") replace;

*Clean country names so that they match the GPW ones and can therefore merge;
replace country="Republic of Korea" if country=="South Korea";
replace country="United States of America" if country=="US";
replace country="China" if country=="People's Republic of China";
replace country="China Hong Kong Special Administrative Region"
 if country=="China Hong Kong SAR";
replace country="United Kingdom of Great Britain and Northern Ireland"
 if country=="United Kingdom";
replace country="Iran (Islamic Republic of)" if country=="Iran";
replace country="Trinidad and Tobago" if country=="Trinidad & Tobago";
replace country="Venezuela (Bolivarian Republic of)" if country=="Venezuela";
replace country="Viet Nam" if country=="Vietnam";

sort country;
save "..\\..\\..\\data\\BP\\generated/`product'Consumption.dta", replace;

use "..\\..\\..\\data\\dtas\\analyze_me.dta", clear;

sort country;

merge m:1 country using "..\\..\\..\\data\\BP\\generated/`product'Consumption.dta";
rename _merge merge`product';

*Saves version of dta with all country level variables and all pixels;
save "..\\..\\..\\data\\dtas\\analyze_me.dta",replace;

};
/*;
*Drops pixels with no country level data (including non-country pixels);
keep if country!="";
keep if mergeCoal==3 | mergeOil==3 | mergeGas==3;
*/;
*Groups all EU countries as country=EU;
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

*replace country="EU" if EU==1;

format %30s country;

save "..\\..\\..\\data\\dtas\\analyze_me.dta",replace;
