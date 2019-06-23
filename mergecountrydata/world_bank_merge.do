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
pause on;

program clean_country_names;
*in WB1 but not merging
/*
*WB1;
code	country
CHI	Channel Islands
*analyze_me;
country
Guernsey
Jersey

*wb
CUW	Cura�ao
*analyze_me
Cura�ao

*wb
CIV	C�te d'Ivoire
*analyze_me
C�te d'Ivoire

*wb
PRK	Korea, Dem. People�s Rep.
*analyze_me
country
Democratic People's Republic of Korea
*/;
end;

capture log close;
log using world_bank_merge.log, replace;

use "../../../../data_processing_calibration/data/world_bank/generated/WB1clean.dta", clear;
local stubs vAGREMPL vAGRTOTL vINDEMPL vINDMANF vINDTOTL vSRVEMPL vSRVTOTL;
// Looping over stems to capture variable labels;
foreach s of local stubs {;
	local `s'label = "`: variable label `s''";
	dis "``s'label'";
};

reshape wide `stubs',i(country) j(year);

// Looping over stems again to reinstate labels;
foreach stub of local stubs{;
	foreach var of varlist `stub'* {;
		label variable `var' "``stub'label'";

	};
};
tempfile wb_wide;
pause;
save `wb_wide';

use "..\\..\\..\\data\\dtas\\temp\\analyze_me.dta", clear;

merge m:1 country  using `wb_wide', keep(match master) nogen;
assert missing(uber_code)==0;

*New merged data replaces old data, but keeps name;
capture mkdir "..\\..\\..\\data\dtas\temp";
save "..\\..\\..\\data\dtas\temp\analyze_me.dta", replace;
log close;
