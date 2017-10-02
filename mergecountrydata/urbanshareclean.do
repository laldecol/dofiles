/*****************************************************************************
urbanshareclean.do

This .do file imports data from the World Bank's Urban Population (% of total)
sheet into stata, cleans it, and merges it into the ubergrid database.

*Last modified: Dec 31 2016 la
*****************************************************************************/

* set up;
#delimit;
clear all;
cls;
set more off;
pause off;

import excel "..\\..\\..\\data\World_Bank\source\urbanshare.xls",
sheet("Data") cellrange(A4:BI268) firstrow;

*Rename year variables as urbanshare`year' so that stata can work with them;
foreach v of varlist E-BH {;
   local x : variable label `v';
   rename `v' urbanshare`x';
   *label variable y`x' "`v'";
};

*Keep years for which we also have population data;
keep CountryName urbanshare2000 urbanshare2005 urbanshare2010 urbanshare2015;
rename CountryName country;

*Clean country names so that they match the GPW ones and can therefore merge;
replace country="Bahamas" if country =="Bahamas, The";

replace country=
"Bolivia (Plurinational State of)"
if country ==
"(Plurinational State of) Bolivia" | 
country== "Bolivia";

replace country=
"Cape Verde" 
if country ==
"Cabo Verde";

replace country=
"Democratic Republic of the Congo" 
if country ==
"Congo, Dem. Rep.";

replace country=
"Congo" 
if country ==
"Congo, Rep.";

replace country=
"Côte d'Ivoire" 
if country ==
"Cote d'Ivoire";

replace country=
"Curaçao" 
if country ==
"Curacao";

replace country=
"Egypt" 
if country ==
"Egypt, Arab Rep.";

replace country=
"Faeroe Islands"
if country == 
"Faroe Islands";

replace country=
"Gambia" 
if country ==
"Gambia, The";

replace country=
"China Hong Kong Special Administrative Region" 
if country ==
"Hong Kong SAR, China";

replace country=
"Iran (Islamic Republic of)" 
if country ==
"Iran, Islamic Rep.";

replace country=
"Democratic People's Republic of Korea" 
if country ==
"Korea, Dem. People’s Rep.";

replace country=
"Republic of Korea"
if country == 
"Korea, Rep.";

replace country=
"Kyrgyzstan" 
if country ==
"Kyrgyz Republic";

replace country=
"Lao People's Democratic Republic" 
if country ==
"Lao PDR";

replace country=
"China Macao Special Administrative Region" 
if country ==
"Macao SAR, China";

replace country=
"The former Yugoslav Republic of Macedonia" 
if country ==
"Macedonia, FYR";

replace country=
"Micronesia (Federated States of)" 
if country ==
"Micronesia, Fed. Sts.";

replace country=
"Republic of Moldova" 
if country ==
"Moldova";

replace country=
"Western Samoa" 
if country ==
"Samoa";

replace country=
"Slovakia" 
if country ==
"Slovak Republic";

replace country=
"Saint Kitts and Nevis" 
if country ==
"St. Kitts and Nevis";

replace country=
"Saint Lucia"
if country == 
"St. Lucia";

replace country=
"Saint-Martin (French part)" 
if country ==
"St. Martin (French part)";

replace country=
"Saint Vincent and the Grenadines" 
if country ==
"St. Vincent and the Grenadines";

replace country=
"United Republic of Tanzania" 
if country ==
"Tanzania";

replace country=
"United Kingdom of Great Britain and Northern Ireland" 
if country ==
"United Kingdom";

replace country=
"United States of America" 
if country ==
"United States";

replace country=
"Venezuela (Bolivarian Republic of)" 
if country ==
"Venezuela, RB";

replace country=
"Viet Nam" 
if country ==
"Vietnam";

replace country=
"United States Virgin Islands" 
if country ==
"Virgin Islands (U.S.)";

replace country=
"Yemen" 
if country ==
"Yemen, Rep.";

*drop variables corresponding to non-country geographical units;
foreach country in
"Arab World"
"Caribbean small states"
"Central Europe and the Baltics"
"Early-demographic dividend"
"East Asia & Pacific"
"East Asia & Pacific (IDA & IBRD countries)"
"East Asia & Pacific (excluding high income)"
"Euro area"
"Europe & Central Asia"
"Europe & Central Asia (IDA & IBRD countries)"
"Europe & Central Asia (excluding high income)"
"European Union"
"Fragile and conflict affected situations"
"Heavily indebted poor countries (HIPC)"
"High income"
"IBRD only"
"IDA & IBRD total"
"IDA blend"
"IDA only"
"IDA total"
"Late-demographic dividend"
"Latin America & Caribbean"
"Latin America & Caribbean (excluding high income)"
"Latin America & the Caribbean (IDA & IBRD countries)"
"Least developed countries: UN classification"
"Low & middle income"
"Low income"
"Lower middle income"
"Middle East & North Africa"
"Middle East & North Africa (IDA & IBRD countries)"
"Middle East & North Africa (excluding high income)"
"Middle income"
"North America"
"Not classified"
"OECD members"
"Other small states"
"Pacific island small states"
"Post-demographic dividend"
"Pre-demographic dividend"
"Small states"
"South Asia"
"South Asia (IDA & IBRD)"
"Sub-Saharan Africa"
"Sub-Saharan Africa (IDA & IBRD countries)"
"Sub-Saharan Africa (excluding high income)"
"Upper middle income"
"World"
{;
drop if country=="`country'";
};

save "..\\..\\..\\data\World_Bank\generated\urbanshare.dta", replace;

use "..\\..\\..\\data\dtas\analyze_me.dta", clear;

merge m:1 country using "..\\..\\..\\data\World_Bank\generated\urbanshare.dta";

drop if _merge==2;

drop _merge;

*New merged data replaces old data, but keeps name;
save "..\\..\\..\\data\dtas\analyze_me.dta", replace;
