#delimit;
set trace on;
set more off;
pause on;
/*;
This .do file computes the country_region level variables we use in the models,
and reshapes into country level.
Output variables are country-region level unless otherwise stated.

1. Area
2. Average AOD (over pixels)
3. GDP (country level)
4. Population
5. Total Fires

Created: October 19, 2017, by Lorenzo
Last modified: January 15, 2019, by Lorenzo
*/;

local years 2000 2005 2010 2015;

foreach year of local years{;
	use "..\\..\\..\\data\\dtas\\analyze_me_land.dta", clear;

	*Use urbanization dummies to generate a region variable for each year;
		egen countryXregion`year'=group(country urban_wb`year'), label;
		gen region_str="";
		replace region_str="urban" if urban_wb`year'==1;
		replace region_str="rural" if urban_wb`year'==0;
		drop urban_wb`year';

	*Compute 1-5 above by collapsing into country X region level
		collapse (count) uber_code (firstnm) gpw_v4_national_identifier_gri 
		rgdpe`year' rgdpo`year' Oil`year' Coal`year' Gas`year' 
		urbanshare`year' countrypop`year'
		(mean) Terra`year' (sum) area Fire`year' gpwpop`year', by(countryXregion`year' country region_str);

		drop countryXregion`year';
		drop uber_code;
		drop if gpw_v4_national_identifier_gri==-9999;

	*Reshape into country-level, with separate urban and rural variables;
		reshape wide Terra`year' area Fire`year' gpwpop`year', i(country) j(region_str) string;

		gen pop_urban`year'= (urbanshare`year'/100)* countrypop`year';
		gen pop_rural`year'= (1-urbanshare`year'/100)* countrypop`year';
		drop gpwpop`year'rural;
		drop gpwpop`year'urban;

		order country gpw_v4_national_identifier_gri 
		Terra`year'rural pop_rural`year' arearural Fire`year'rural 
		Terra`year'urban pop_urban`year' areaurban Fire`year'urban 
		rgdpe`year' rgdpo`year' Oil`year' Coal`year' Gas`year' 
		urbanshare`year' countrypop`year';

		label var country "Country name";
		label var gpw_v4_national_identifier_gri "Country id";
		label var rgdpe`year' "Real `year' GDP, 2011 USD, Expenditure Side";
		label var rgdpo`year' "Real `year' GDP, 2011 USD, Output Side";
		label var Coal`year' "Coal, peat, and shale consumption (ktoe), `year'";
		label var Oil`year' "Oil products consumption (ktoe), `year'";
		label var Gas`year' "Natural gas consumption (ktoe), `year'";
		label var countrypop`year' "Total country population, `year'";
		label var Terra`year'rural "Mean AOD concentration in rural, `year'";
		label var Terra`year'urban "Mean AOD concentration in urban, `year'";
		label var arearural "Rural area, `year'";
		label var areaurban "Urban area, `year'";
		label var Fire`year'rural "Total fire pixel-days in rural, `year'";
		label var Fire`year'urban "Total fire pixel-days in urban, `year'";
		label var pop_rural`year' "Rural population, `year'";
		label var pop_urban`year' "Urban population, `year'";

	save "..\\..\\..\\data\\dtas\\country\\macro_model_inputs_`year'.dta", replace;

};
