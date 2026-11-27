/*****************************************************************************
merge_country_data.do

This .do file merges all country level data to analyze_me_pixel.dta.

*Created		: Nov 26 2026 la
*Last modified	: Nov 26 2026 la

*****************************************************************************/

* set up;
#delimit;
clear all;
cls;
set more off;
pause off;

capture log close;
log using merge_country_data.log, replace;

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
save `wb_wide';

use "..\\..\\..\\data\dtas\analyze_me_pixel.dta", clear;

fmerge m:1 country  using "..\\..\\..\\data\PWT\generated\pwt90.dta", keep(match master) nogen;
assert missing(uber_code)==0;

fmerge m:1 country using "..\\..\\..\\data\World_Bank\generated\urbanshare.dta", keep(match master) nogen;
assert missing(uber_code)==0;

merge m:1 gpw_v4_national_identifier_gri using "../../../data/IEA/generated/energy_use/country_level.dta", nogen update replace;
drop if uber_code==.;

fmerge m:1 country  using "../../../data/IIASA/generated/country/activity_emissions.dta", keep(match master) nogen;
drop if uber_code==.;
assert missing(uber_code)==0;

fmerge m:1 country  using `wb_wide', keep(match master) nogen;
assert missing(uber_code)==0;

fmerge m:1 country using "..\\..\\..\\data\\BP\\generated/OilConsumption.dta", keep(match master) nogen;

fmerge m:1 country using "..\\..\\..\\data\\BP\\generated/CoalConsumption.dta", keep(match master) nogen;

fmerge m:1 country using "..\\..\\..\\data\\BP\\generated/GasConsumption.dta", keep(match master) nogen;

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


*New merged data replaces old data, but keeps name;

log close;
