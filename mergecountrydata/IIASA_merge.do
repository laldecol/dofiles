/*****************************************************************************
urbanshareclean.do

This .do file merges IIASA emissions and activity data into analyze_me_land.dta

*Last modified: Dec 31 2016 la
*****************************************************************************/

* set up;
#delimit;
clear all;
cls;
set more off;
pause off;

capture log close;
log using IIASA_merge.log, replace;

use "..\\..\\..\\data\\dtas\\temp\\analyze_me.dta", clear;

merge m:1 country  using "../../../data/IIASA/generated/country/activity_emissions.dta", keep(match master) nogen;
assert missing(uber_code)==0;

*New merged data replaces old data, but keeps name;
capture mkdir "..\\..\\..\\data\dtas\temp";
save "..\\..\\..\\data\dtas\temp\analyze_me.dta", replace;
log close;
