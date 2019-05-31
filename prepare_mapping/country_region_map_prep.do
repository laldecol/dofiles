#delimit;

/*;
This .do file:

Created: Lorenzo, Oct 23 2018;
Last modified: Lorenzo, Oct 28 2018;

1. 	Writes an ubergrid .dta with country-region level data.
	This .dta can be used as an input to dta2raster/dta2raster.py;

*/;


set more off; 
pause on;
clear;
set trace off;
set tracedepth 1;
capture program drop gen_wc_country;

program define gen_wc_country;
	gen wc_country=country;

	replace wc_country="Bolivia" if country=="Bolivia (Plurinational State of)";
	replace wc_country="Iran" if country=="Iran (Islamic Republic of)";
	replace wc_country="Falkland Islands" if country=="Falkland Islands (Malvinas)";
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
end;


*1. Writes an ubergrid .dta with country-region level data, to be used in dta2raster;

	local country_region_dta 	"../../../data/dtas/country_regions/flux/net_flows_into2010.dta";
	local mapping_vars			net_flows_into_by_area net_flow_into;
	
	*Prepare country region level file to merge with ubergrid;
	use `country_region_dta', clear ;
	
	gen urban_wb2010=1 if region=="urban";
	replace urban_wb2010=0 if region=="rural";
	gen_wc_country;
	gen ctry_reg=wc_country + string(urban_wb2010);
	keep 	gpw_v4_national_identifier_gri 
			urban_wb2010
			country
			region
			ctry_reg
			`mapping_vars';

	save "../../../data/mapping/country_region_lvl_vars/country_reg_join.dta", replace;	
	export delimited 	country	gpw_v4_national_identifier_gri	region ctry_reg 
						`mapping_vars'
						using "../../../data/mapping/country_region_lvl_vars/country_reg_join.csv", replace;
	
	*Merge country region with land pixel file;
	use "../../../data/dtas/analyze_me_land.dta", clear;
	
	merge m:1 gpw_v4_national_identifier_gri urban_wb2010 using "../../../data/mapping/country_region_lvl_vars/country_reg_join.dta", keep(match);
	keep uber_code `mapping_vars';
	
	tempfile uber_code_country_region;
	save `uber_code_country_region', replace;



	*Generate full ubergrid file to feed into dta2raster;

	use "../../../data/projections/generated/settings.dta", clear;
	
	*Define C,R as column and row totals in current ubergrid.;
	local C=COLUMNCOUNT[1];
	local R=ROWCOUNT[1];
	dis "Number of Columns: " `C';
	dis "Number of Rows: " `R';

	local Nobs=`C'*`R';
	clear;
	set obs `Nobs';
	gen uber_code=_n;
	merge 1:1 uber_code using `uber_code_country_region', nogen;
	recode `mapping_vars' (.=-9999);
	
	save "../../../data/dta2raster/dtas/country_region_flows.dta", replace;

	