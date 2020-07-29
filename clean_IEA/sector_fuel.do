#delimit;
/*;
This .do file:

1. Imports standard conversion factor file, fuel group file, and IEA fuel use;
2. Converts IEA data to ktoe and aggregates by fuel group;
3. Cleans, labels, and saves at country-time-sector-fuel group level, for use in Lint's model;
4. Reshape to country year and merge into analyze_me;

Created: Lorenzo, Oct 22 2018;
Last modified: Lorenzo, Oct 28 2018;
*/;

capture log close;
log using sector_fuel.log, replace;
pause on; 
set trace off;
set tracedepth 1;

*1. Imports standard conversion factor file, fuel group file, and IEA fuel use;

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

*2. Converts IEA data to Mtoe and aggregates by fuel group;
	
	
	*keep if 	sector_=="Industry" |
				sector_=="Transport" |
				sector_=="Residential" | 
				sector_=="Commercial" |
				sector_=="Agricultureforestry" |
				sector_=="Fishing" |
				sector_=="Non-Specified" |
				sector_=="Energy" |
				sector_=="Transformation";
	
	*Merge conversion factors and convert consumption to ktoe;
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
	
	*Convert to MTOE;
	gen fuel_use_mtoe=source_*cf/1000000;
		
	*Merge fuel group variable;
	drop _merge;
	merge m:1 fuel_units using `groups';
	drop if country=="";
	*Collapse into year, country, sector, group variable in ktoe;
	collapse (sum) fuel_use_mtoe, by(country time sector_ fuel_group);
	tab sector_;

*3. Clean, label, and save at country-time-sector-fuel group level, for use in Lint's model;

	keep if 	sector_=="Industry" |
				sector_=="Transport" |
				sector_=="Residential" | 
				sector_=="Commercial" |
				sector_=="Agricultureforestry" |
				sector_=="Fishing" |
				sector_=="Non-Specified" |
				sector_=="Transformation" |
				sector_=="Energy" |
				sector_=="Electr_Auto_CHP" |
				sector_=="Electr_Auto_Ele" |
				sector_=="Electr_MA_CHP" |
				sector_=="Electr_MA_Ele" |
				sector_=="Electr_Output" |
				sector_=="Heat_Output" |
				sector_=="Tr_Auto_CHP" |
				sector_=="Tr_Auto_Elec" |
				sector_=="Tr_Auto_Heat" |
				sector_=="Tr_Main_CHP" |
				sector_=="Tr_Main_Elec" |
				sector_=="Tr_Main_Heat";
    
	
	replace sector_="Energy industry own use" if sector_=="Energy";
	replace sector_="Commercial and public services" if sector_=="Commercial";
	replace sector_="Electricity Output, Autoproducer CHP Plants" if sector_=="Electr_Auto_CHP";
	replace sector_="Electricity Output, Autoproducer Electricity Plants" if sector_=="Electr_Auto_Ele";
	replace sector_="Electricity Output, Main Activity CHP Plants" if sector_=="Electr_MA_CHP";
	replace sector_="Electricity Output, Main Activity Electricity Plants" if sector_=="Electr_MA_Ele";
	replace sector_="Electricity Output, Total" if sector_=="Electr_Output";
	replace sector_="Heat Output" if sector_=="Heat_Output";
	replace sector_="Transformation Inputs, Autoproducer CHP Plants" if sector_=="Tr_Auto_CHP";
	replace sector_="Transformation Inputs, Autoproducer Electricity Plants" if sector_=="Tr_Auto_Elec";
	replace sector_="Transformation Inputs, Autoproducer CHP Plants" if sector_=="Tr_Auto_Heat";
	replace sector_="Transformation Inputs, Main Activity CHP Plants" if sector_=="Tr_Main_CHP";
	replace sector_="Transformation Inputs, Electricity Plants" if sector_=="Tr_Main_Elec";
	replace sector_="Transformation Inputs, Heat Plants" if sector_=="Tr_Main_Heat";

	rename fuel_use_mtoe energy_consumption;

	label variable energy_consumption "Energy consumption by country, year, economic sector, and fuel group in mtoe";
	fillin country time sector_ fuel_group;
	replace energy_consumption=0 if _fillin;
	drop _fillin;
	save "../../../data/IEA/generated/energy_use/energy_use.dta", replace;

*4. Reshape to country year and merge into analyze_me;

	collapse (sum) energy_consumption, by(fuel_group time country);

	replace fuel_group="Oil_Shale" if fuel_group=="Oil Shale";
	
	reshape wide energy_consumption,i(country time) j(fuel_group) string;

	rename energy_consumptionCoal IEA_Coal;
	rename energy_consumptionOil IEA_Oil;
	gen IEA_Other=energy_consumptionGas+energy_consumptionOther;
	drop energy_consumption*;
	
	reshape wide IEA_*, i(country) j(time);
	
	*Label reshaped variables to keep track of units;
	#delimit;
	local fuel_types Coal Oil Other;
	set trace on;
	set tracedepth 2;
	foreach fuel_type of local fuel_types{;
		foreach energy_var of varlist IEA_`fuel_type'*{;
			label variable `energy_var' "`fuel_type' consumption in Mtoe from IEA";
		};
	};
	
	*using is GPW, master is IEA;
	*replace country=using if country==master;
	merge 1:1 country using "..\..\..\data\GPW4\source\gpw-v4-national-identifier-grid\idnames.dta", keepusing(gpw_v4_national_identifier_gri) nogen keep(match master);
	
	replace gpw_v4_national_identifier_gri=826 if country=="United Kingdom";
	replace gpw_v4_national_identifier_gri=840 if country=="United States";
	replace gpw_v4_national_identifier_gri=68 if country=="Plurinational State of Bolivia";
	replace gpw_v4_national_identifier_gri=862 if country=="Bolivarian Republic of Venezuela";
	replace gpw_v4_national_identifier_gri=531 if country=="Curaçao/Netherlands Antilles";
	replace gpw_v4_national_identifier_gri=384 if country=="Côte d'Ivoire";
	replace gpw_v4_national_identifier_gri=807 if country=="Former Yugoslav Republic of Macedonia";
	replace gpw_v4_national_identifier_gri=156 if country=="People's Republic of China";
	replace gpw_v4_national_identifier_gri=364 if country=="Islamic Republic of Iran";
	replace gpw_v4_national_identifier_gri=344 if country=="Hong Kong (China)";
	replace gpw_v4_national_identifier_gri=703 if country=="Slovak Republic";
	replace gpw_v4_national_identifier_gri=410 if country=="Korea";
	replace gpw_v4_national_identifier_gri=178 if country=="Republic of the Congo";
	
	drop if gpw_v4_national_identifier_gri==.;
	
	
	
	save "../../../data/IEA/generated/energy_use/country_level.dta", replace;
		
	use "..\\..\\..\\data\\dtas\\analyze_me.dta", clear;

	merge m:1 gpw_v4_national_identifier_gri using "../../../data/IEA/generated/energy_use/country_level.dta", nogen;
	
	drop if uber_code==.;
	
	*New merged data replaces old data, but keeps name;
	*This is bad practice, because user cannot know what the file is good for from name only;
	save "..\\..\\..\\data\\dtas\\analyze_me.dta", replace;

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

log close;
