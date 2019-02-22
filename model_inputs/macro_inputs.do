#delimit;
set trace off;
set more off;
pause on;
capture log close;
/*;
This .do file computes the country_region level variables we use in the models,
and reshapes into country level. Its output is used by Lint's code and by the box
model files.

Output variables are country-region level unless otherwise stated.

1. Area
2. Average AOD (over pixels)
3. GDP (country level)
4. Population
5. Total Fires

Created: October 19, 2017, by Lorenzo
Last modified: January 15, 2019, by Lorenzo
*/;

local years 2000 2001 2002 2003 2004 2005 
			2006 2007 2008 2009 2010 2011
			2012 2013 2015;
			
log using macro_inputs.log, replace;

*Import oil price data;
	import excel "..\\..\\..\\data\BP\\source\\bp-statistical-review-of-world-energy-2016-workbook.xlsx", 
	sheet("Oil – Spot crude prices") clear;

	drop if _n<=6 | _n>=50;

	destring A, gen(year) ignore("-");
	destring B , gen(oilpr_dubai) ignore("-");
	destring C, gen(oilpr_brent) ignore("-");
	destring D, gen(oilpr_nigerian) ignore("-");
	destring E, gen(oilpr_wti) ignore("-");

	keep year oilpr*;

	label variable oilpr_dubai "Dubai oil spot price, dls/barrel";
	label variable oilpr_brent "Brent oil spot price, dls/barrel";
	label variable oilpr_nigerian "Nigerian Forcados oil spot price, dls/barrel";
	label variable oilpr_wti "West Texas Intermediate oil spot price, dls/barrel";

	keep year oilpr*;

	tempfile oil_price;
	save `oil_price';

*Import coal price data;
	import excel "..\\..\\..\\data\BP\\source\\bp-statistical-review-of-world-energy-2016-workbook.xlsx", 
	sheet("Coal - Prices") clear;

	drop if _n<=3 | _n>=33;

	destring A , gen(year);
	destring B , gen(coalpr_nweuro) ignore("-");
	destring C , gen(coalpr_usca) ignore("-");
	destring D , gen(coalpr_japc) ignore("-");
	destring E , gen(coalpr_japs) ignore("-");
	destring F , gen(coalpr_asia) ignore("-");

	keep year coalpr*;

	label variable coalpr_nweuro "Northwestern Europe coal marker price, dls/tonne" ;
	label variable coalpr_usca "US Central Appalachian coal spot price, dls/tonne" ;
	label variable coalpr_japc "Japan coking coal spot price, dls/tonne" ;
	label variable coalpr_japs "Japan steam coal spot price, dls/tonne" ;
	label variable coalpr_asia "Asian coal marker price, dls/tonne" ;


	tempfile coal_price;
	save `coal_price';

*Import gas price data;
	import excel "..\\..\\..\\data\BP\\source\\bp-statistical-review-of-world-energy-2016-workbook.xlsx", 
	sheet("Gas - Prices ") clear;

	drop if _n<=5 | _n>=38;

	destring A, gen(year);
	destring B, gen(lng_jpn) ignore("-");
	destring C, gen(lng_ger) ignore("-");
	destring D, gen(ng_her) ignore("-");
	destring E, gen(ng_ushh) ignore("-");
	destring F, gen(ng_can) ignore("-");

	keep year ng* lng*;

	label variable lng_jpn "Liquefied natural gas Japan cif price, dls/Mbtu";
	label variable lng_ger "Liquefied natural gas average German import cif price, dls/Mbtu";
	label variable ng_her "Natural gas UK Heren NBP index, dls/Mbtu";
	label variable ng_ushh "Natural gas US Henry Hub, dls/Mbtu";
	label variable ng_ca "Natural gas Canada price, dls/Mbtu";

	tempfile gas_price;
	save `gas_price';


foreach year of local years{;
	***Change to analyze_me_land_std units?;
	use "..\\..\\..\\data\\dtas\\analyze_me_land.dta", clear;

	*Use urbanization dummies to generate a region variable for each year;
		***countryXregion`year' is now generated in pixel_data_prep;
		
		egen countryXregion`year'=group(country urban_wb`year'), label;
		gen region_str="";
		replace region_str="urban" if urban_wb`year'==1;
		replace region_str="rural" if urban_wb`year'==0;
		drop urban_wb`year';

	*Compute 1-5 above by collapsing into country X region level;
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

	*Merge energy data;
		gen int year=`year';
		merge m:1 year using `oil_price', nogen keep(match);
		merge m:1 year using `coal_price', nogen keep(match);
		merge m:1 year using `gas_price', nogen keep(match);
			
	*Label output variables;
		label var country "Country name";
		label var gpw_v4_national_identifier_gri "Country id";
		label var rgdpe`year' "Real `year' GDP, 2011 USD, Expenditure Side";
		label var rgdpo`year' "Real `year' GDP, 2011 USD, Output Side";
		label var Coal`year' "Coal, peat, and shale consumption (mtoe), `year'";
		label var Oil`year' "Oil products consumption (mtoe), `year'";
		label var Gas`year' "Natural gas consumption (mtoe), `year'";
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

log close;
