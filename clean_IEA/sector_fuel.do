#delimit;
pause on; 
set trace on;
set tracedepth 1;

*Import standard conversion factor file;
	import excel "../../../data/IEA/source/conversion_factors/standard/standard_cf.xls", sheet("conversion_factors")
	firstrow clear;
	rename IEA_NAME fuel_units;
	drop if fuel_units=="";
	tempfile cf;
	save `cf';

*Import fuel group file;
	import excel "../../../data/IEA/source/fuel_groups/fuel_groups.xlsx", sheet("Sheet1")
	firstrow clear;
	tempfile groups;
	save `groups';
	
*Import fuel use data;
	use "S:\particulates\data_processing\data\IEA\generated/sources_conv_factors.dta", clear;
	rename source_name fuel_type;
	reshape long source_ ,i(country time fuel_type) j(sector_) string;
	drop if source_==0 | source_==.;
	drop conv*;

	order country time fuel_type sector_ source fuel_units;

	gen units="";
	replace units="kt" if strpos(fuel_units, "(kt)")>0;
	replace units="TJ" if strpos(fuel_units, "(TJ-gross)")>0 | strpos(fuel_units, "(TJ-net)")>0 | strpos(fuel_units, "(TJ)")>0 | strpos(fuel_units, "TJ-net)")>0;
	replace units="GWh" if strpos(fuel_units, "(GWh)")>0;
	replace units="TJ" if fuel_units=="Heat from chemical sources"  | fuel_units=="Heat output from non-specified combustible fuels";
	replace units="GWh" if fuel_units=="Wind" |  fuel_units=="Nuclear" | fuel_units=="Electric boilers" |   fuel_units=="Hydro" | fuel_units=="Tide, wave and ocean" | fuel_units=="Solar photovoltaics" | fuel_units=="Heat pumps";
	tab fuel_units if units=="";
	drop if units=="";
	tempfile conv_merge;

	local toe_per_TJ 23.8845897;
	local toe_per_GWh 85.9845227859;
	local MJkg_per_TJkt 1;

*Merge and convert consumption to ktoe;
	merge m:1 fuel_units using `cf', keepusing(cf cf_units) nogen;

	*Standardize conversion rates to match fuel units;
	replace cf=cf*`toe_per_TJ' 					if cf_units=="TJ/kt";
	replace cf_units="toe/kt"					if cf_units=="TJ/kt";

	replace cf=cf*`toe_per_TJ'*`MJkg_per_TJkt' 	if cf_units=="MJ/kg";
	replace cf_units="toe/kt"					if cf_units=="MJ/kg";

	replace cf=`toe_per_GWh' 					if units=="GWh";
	replace cf_units="toe/GWh"					if cf_units=="MJ/kg";

	replace cf=`toe_per_TJ' 					if units=="TJ";
	replace cf_units="toe/TJ"					if units=="TJ";

	gen fuel_use_ktoe=source_*cf/1000;

*Merge fuel group variable;
	drop _merge;
	merge m:1 fuel_units using `groups';
	drop if country=="";
	
*Collapse into year, country, sector, group variable in ktoe;


collapse (sum) source_, by(country time sector_ fuel_group);
tab sector_;
keep if 	sector_=="Industry" |
			sector_=="Transport" |
			sector_=="Residential" | 
			sector_=="Commercial" |
			sector_=="Agricultureforestry" |
			sector_=="Fishing" |
			sector_=="Non-Specified" |
			sector_=="Transformation" |
			sector_=="Energy";
			
replace sector_="Energy industry own use" if sector_=="Energy";
replace sector_="Commercial and public services" if sector_=="Commercial";
			
rename source_ energy_consumption;

label variable energy_consumption "Energy consumption by country, year, economic sector, and fuel group in ktoe";
fillin country time sector_ fuel_group;
replace energy_consumption=0 if _fillin;
drop _fillin;

save "../../../data/IEA/generated/energy_use/energy_use.dta", replace;
/*;
The IEA reports fuel consumption by the following sectors:
Final Consumtpion
	Industry
	Transport
	Residential
	Commercial/Public Service
	Agriculture/forestry
	Fishing
	Non-Specified
*/;

