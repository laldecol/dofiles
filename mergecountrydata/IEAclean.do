#delimit;
/*;
***This .do file:
1. Imports source IEA fuel use files
2. Appends fuel files together;
3. Imports conversion factor files;
4. Appends conversion factor files together;
5. Merges fuels and conversion factors at country-year-fuel level, with flows as variables, and saves output;

Created: Lorenzo, Oct 22 2018;
Last modified: Lorenzo, Oct 28 2018;
*/;


pause on; 
set trace off;
set tracedepth 1;


*1. Import source files;

	local ieafiles: dir "..\\..\\..\\data\\IEA\\source\\fuel_use" files "*.csv", respectcase;
	local filecount=0;
	local tempfs;

	foreach ieafile of local ieafiles{;
		
		import delimited "..\\..\\..\\data\\IEA\\source\\fuel_use/`ieafile'", varnames(2) rowrange(2) clear ;
		capture drop v*;
		
		*Declare locals and tempfiles for merge;
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
		
		*Rename to keep variables after reshape;
		replace flow="Tr_Main_Elec" if flow=="Main activity producer electricity plants (transf.)";
		replace flow="Tr_Auto_Elec" if flow=="Autoproducer electricity plants (transf.)";
		replace flow="Tr_Main_CHP" if flow=="Main activity producer CHP plants (transf.)";
		replace flow="Tr_Auto_CHP" if flow=="Autoproducer CHP plants (transf.)";
		replace flow="Tr_Main_Heat" if flow=="Main activity producer heat plants (transf.)";
		replace flow="Tr_Auto_Heat" if flow=="Autoproducer heat plants (transf.)";
		replace flow="Tr_Blast" if flow=="Blast furnaces (transf.)";
		replace flow="Tr_Coke" if flow=="Coke ovens (transf.)";
		replace flow="Tr_Coke" if flow=="Coke ovens (transf.)";
		replace flow="Electr_Output" if flow=="Electricity output (GWh)";
		
		replace flow="Electr_MA_Ele" if flow=="Electricity output (GWh)main activity producer electricity plants";
		replace flow="Electr_Auto_Ele" if flow=="Electricity output (GWh)autoproducer electricity plants";
		replace flow="Electr_MA_CHP" if flow=="Electricity output (GWh)main activity producer CHP plants";
		replace flow="Electr_Auto_CHP" if flow=="Electricity output (GWh)autoproducer CHP plants";
		replace flow="Heat_Output" if flow=="Heat output (TJ)";
		
		
		save temp`filecount', replace;

	};
	
*2. Append all fuel files together;
	
	use temp1, clear;
	
	*Keep list of using files to append;
	local usings: list tempfs-temp1;
	dis "`usings'";
	clear;

	append using `tempfs';
	
	foreach file of local tempfs{;
	capture rm `file';
	};
	
	*Reshape to country-time-fuel level;
	reshape long source_ units_, i(country time flow)  j(source_name) string;
	reshape wide source_ units_, i(country time source_name) j(flow) string;
		
	*Clean fuel names;
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
	
	*Save for merging;
	tempfile source_merged;
	save `source_merged';

*3. Imports conversion factor files;
	local convfiles: dir "../../../data/IEA/source/conversion_factors" files "*.csv", respectcase;
	local filecount=0;
	local tempcfs;
	local master temp1;

	foreach convfile of local convfiles{;
		
		import delimited "../../../data/IEA/source/conversion_factors/`convfile'", varnames(2) rowrange(2) clear ;
		
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

	*Append all conversion files together;
	clear;
	append using `tempcfs';
	
	foreach file of local tempcfs{;
	capture rm `file';
	};
	
	*Reshape to country-time-fuel level;
	reshape long conv_, i(unit country time flow)  j(source_name) string;
	reshape wide conv_, i(country time source_name) j(flow) string;
	
	tempfile conv_merged;
	save `conv_merged';
	
	*Merge IEA flows and conversion factors;
	merge 1:1 country time source_name using `source_merged', keep(match using);
	sort country time _merge source_name;
	order _merge country time source_name;

	bro if _merge==2;
	gen fuel_units=units_Energy;
	drop units*;

	save "../../../data/IEA/generated/sources_conv_factors.dta", replace;
