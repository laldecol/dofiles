/*****************************************************************************
urbanshareclean.do

This .do file imports income data from the Penn World Tables v9
into stata, cleans it, and merges it into the ubergrid database.

*Last modified: Dec 31 2016 la
*****************************************************************************/

* set up;
#delimit;
clear all;
cls;
set more off;
pause off;

capture log close;
log using PWTClean.log;
*Import and keep only the years and variables we work with;
import excel "..\\..\\..\\data\PWT\source\pwt90.xlsx",
 sheet("Data") firstrow clear;
keep country rgdpe rgdpo year;
keep if year == 2000 | year == 2005 | year == 2010 | year ==2014;

*Change unit of observation from countryXyear to country, for merging purposes;
reshape wide rgdpe rgdpo, i (country) j(year);

*Clean country names so that they match the GPW ones and can therefore merge;
replace country="Cape Verde" if country=="Cabo Verde";
replace country="China Hong Kong Special Administrative Region" if country=="China, Hong Kong SAR"; 
replace country="China Macao Special Administrative Region" if country=="China, Macao SAR"; 
replace country="Democratic Republic of the Congo" if country=="D.R. of the Congo";
replace country="Lao People's Democratic Republic" if country=="Lao People's DR";
replace country="Saint Vincent and the Grenadines" if country=="St. Vincent and the Grenadines";
replace country="Sudan" if country=="Sudan (Former)";
replace country="The former Yugoslav Republic of Macedonia" if country=="TFYR of Macedonia";
replace country="United Republic of Tanzania" if country=="U.R. of Tanzania: Mainland";
replace country="United Kingdom of Great Britain and Northern Ireland" if country=="United Kingdom";
replace country="United States of America" if country=="United States";

save "..\\..\\..\\data\PWT\generated\pwt90.dta", replace;

clear;

use "..\\..\\..\\data\dtas\analyze_me_pixel.dta", clear;

merge m:1 country  using "..\\..\\..\\data\PWT\generated\pwt90.dta";

drop _merge;

*New merged data replaces old data, but keeps name;
capture mkdir "..\\..\\..\\data\dtas\temp";
save "..\\..\\..\\data\dtas\temp\analyze_me.dta", replace;
log close;
