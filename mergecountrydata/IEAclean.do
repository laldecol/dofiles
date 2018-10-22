#delimit;
pause on; 
set trace off;
set tracedepth 1;

***Import source files;
local ieafiles: dir "..\\..\\..\\data\\IEA\\source\\fuel_use" files "*.csv", respectcase;
local filecount=0;
local tempfs;
if 1==1{;
	foreach ieafile of local ieafiles{;
		
		import delimited "..\\..\\..\\data\\IEA\\source\\fuel_use/`ieafile'", varnames(2) rowrange(2) clear ;
		
		capture drop v*;
		*Name and create temporary files for merge;
		tempfile temp`filecount';
		local ++filecount;
		local tempfs `tempfs' temp`filecount';
		
		distinct country;
		

		
		*Keep list of sources variables;
		ds country time flow, not;
		local sourcelist `r(varlist)';
		
		*Clean flow names;
		replace flow=subinstr(flow,"/","",.);
		replace flow=subinstr(flow,"-","",.);

		*Fill in missing country and time data;
		replace country=country[_n-1] if country=="";
		replace time=time[_n-1] if time==.;
		
		destring time `sourcelist', ignore(. x c) replace;

		foreach sourcevar of local sourcelist{;
			dis "`sourcevar'";
			local newvarname=substr("`sourcevar'", 1, 25);
			
			dis "`newvarname'";
			rename `sourcevar' `newvarname';
			local label : var label `newvarname';
			rename `newvarname' source_`newvarname';
			
			gen units_`newvarname'="`label'";
			
			
			
		};
		

		replace flow="Tr_Main_Elec" if flow=="Main activity producer electricity plants (transf.)";
		replace flow="Tr_Auto_Elec" if flow=="Autoproducer electricity plants (transf.)";
		replace flow="Tr_Main_CHP" if flow=="Main activity producer CHP plants (transf.)";
		replace flow="Tr_Auto_CHP" if flow=="Autoproducer CHP plants (transf.)";
		replace flow="Tr_Main_Heat" if flow=="Main activity producer heat plants (transf.)";
		replace flow="Tr_Auto_Heat" if flow=="Autoproducer heat plants (transf.)";
		replace flow="Tr_Blast" if flow=="Blast furnaces (transf.)";
		replace flow="Tr_Coke" if flow=="Coke ovens (transf.)";
		
		
		save temp`filecount', replace;
	
	};
	
	use temp1, clear;
	
	*Keep list of using files to merge;
	local usings: list tempfs-temp1;
	dis "`usings'";
	clear;

	append using `tempfs';
	
	*Keep list of using files to merge;
	*local usings: list tempfs - master;
	
	*Merge all usings to master;
	
	reshape long source_ units_, i(country time flow)  j(source_name) string;
	reshape wide source_ units_, i(country time source_name) j(flow) string;
		
	replace source_name=subinstr(source_name,"kt","",.);
	replace source_name=subinstr(source_name,"tjnet","",.);
	replace source_name=subinstr(source_name,"tjne","",.);
	replace source_name=subinstr(source_name,"tjn","",.);
	replace source_name=subinstr(source_name,"tjgross","",.);
	replace source_name=subinstr(source_name,"tjgros","",.);
	replace source_name=subinstr(source_name,"tjgro","",.);
	replace source_name=subinstr(source_name,"tjgr","",.);
	replace source_name=subinstr(source_name,"tjg","",.);
	replace source_name=subinstr(source_name,"tj","",.);
	replace source_name="gasdieseloilexclbiofuels" if source_name=="gasdieseloilexclbiofuelsk";
	
	
	tempfile source_merged;
	save `source_merged';
};

if 1==1{;
	***Import conversion factors;
	local convfiles: dir "S:\\particulates\\data_processing\\data\\IEA\\source\\conversion_factors" files "*.csv", respectcase;
	local filecount=0;
	local tempcfs;
	local master temp1;

	foreach convfile of local convfiles{;
		
		import delimited "..\\..\\..\\data\\IEA\\source\\conversion_factors/`convfile'", varnames(2) rowrange(2) clear ;
		
		*Name and create temporary files for merge;
		tempfile tempcf`filecount';
		local ++filecount;
		local tempcfs `tempcfs' tempcf`filecount';
		capture drop v*;
		*Keep list of sources variables;
		ds country time flow unit, not;
		
		local sourcelist `r(varlist)';
		
		*Fill in missing country and time data;
		replace country=country[_n-1] if country=="";
		replace time=time[_n-1] if time==.;
		
		destring time `sourcelist', ignore(. x) replace;
		
		foreach sourcevar of local sourcelist{;
			dis "`sourcevar'";
			local newvarname=substr("`sourcevar'", 1, 25);
			dis "`newvarname'";
			rename `sourcevar' `newvarname';
			rename `newvarname' conv_`newvarname';
		};	

		replace flow="avg" if flow=="Average net calorific value";
		replace flow="production" if flow=="NCV of production";
		replace flow="other_sources" if flow=="NCV of other sources";
		replace flow="imports" if flow=="NCV of imports";
		replace flow="exports" if flow=="NCV of exports";
		replace flow="cokeovens" if flow=="NCV of coke ovens";
		replace flow="blast" if flow=="NCV of blast furnaces";
		replace flow="mapep" if flow=="NCV in main activity producer electricity plants";
		replace flow="aep" if flow=="NCV in autoproducer electricity plants";
		replace flow="ma_chp" if flow=="NCV in main activity CHP plants";
		replace flow="auto_chp" if flow=="NCV in autoproducer CHP plants";
		replace flow="mahp" if flow=="NCV in main activity heat plants";
		replace flow="ahp" if flow=="NCV in autoproducer heat plants";
		replace flow="industry" if flow=="NCV in industry";
		replace flow="other_use" if flow=="NCV for other uses";

		
		sort country time;
		save tempcf`filecount', replace;
	};

	*Keep list of using files to merge;
	*local usings: list tempfs - master;
	*dis "`usings'";
	clear;

	*Merge all usings to master;
	append using `tempcfs';
	
	reshape long conv_, i(unit country time flow)  j(source_name) string;
	reshape wide conv_, i(country time source_name) j(flow) string;
	
	tempfile conv_merged;
	save `conv_merged';
	
	merge 1:1 country time source_name using `source_merged', keep(match using);
	sort country time _merge source_name;
	order _merge country time source_name;

	bro if _merge==2;
	gen fuel_units=units_Energy;
	drop units*;

	save "S:\particulates\data_processing\data\IEA\generated/sources_conv_factors.dta", replace;
};

use "S:\particulates\data_processing\data\IEA\generated/sources_conv_factors.dta", clear;
