#delimit;
pause on; 
set trace on;
set tracedepth 1;

use "S:\particulates\data_processing\data\IEA\generated/sources_conv_factors.dta", clear;
rename source_name fuel_type;
reshape long source_ ,i(country time fuel_type) j(sector_) string;
drop if source_==0 | source_==.;

order country time fuel_type sector_ source fuel_units;

*Create new unit variable, to be used in conversion;

*From https://www.iea.org/publications/freepublications/publication/statistics_manual.pdf;
gen TJ_to_MTOE	=.00002388; 
gen GWh_to_MTOE	=.000086;

local conv_factors conv_other_use conv_industry conv_aep conv_ahp conv_auto_chp 
					conv_avg conv_blast conv_cokeovens conv_exports conv_imports 
					conv_ma_chp conv_mahp conv_mapep conv_other_sources conv_production;

foreach conv_factor of local conv_factors{;
	replace `conv_factor'=. if `conv_factor'==0;
	*replace conversion factors for fuel types without data ;
	replace `conv_factor'=29.65*`MJkg_to_MTOEton' if fuel_units=="Anthracite (kt)";
	replace `conv_factor'=29.65*`GJt_to_MTOEton' if fuel_units=="Anthracite (kt)";
};

preserve;

collapse (mean) `conv_factors', by(fuel_units sector);

gen units="";
replace units="kt" if strpos(fuel_units, "(kt)")>0;
replace units="TJ" if strpos(fuel_units, "(TJ-gross)")>0 | strpos(fuel_units, "(TJ-net)")>0 | strpos(fuel_units, "(TJ)")>0 | strpos(fuel_units, "TJ-net)")>0;
replace units="GWh" if strpos(fuel_units, "(GWh)")>0;
replace units="TJ" if fuel_units=="Heat from chemical sources"  | fuel_units=="Heat output from non-specified combustible fuels";
replace units="GWh" if fuel_units=="Wind" |  fuel_units=="Nuclear" | fuel_units=="Electric boilers" |   fuel_units=="Hydro" | fuel_units=="Tide, wave and ocean" | fuel_units=="Solar photovoltaics" | fuel_units=="Heat pumps";
tab fuel_units if units=="";
drop if units=="";
tempfile conv_merge;
pause;


save `conv_merge';

restore;

*Must generate a list of which conversion factor each fuel sector has to match, and then merge using those as keys.;
drop `conv_factors' _merge;
merge m:1 fuel_units sector using `conv_merge';

/*;
capture drop coal_dummy;
local coalsources 	anthracite subbituminouscoal lignite charcoal  otherbituminouscoal
					peat peatproducts cokingcoal patentfuel cokeovencoke gascoke bkb coaltar;
				
local oilsources	bitumen crudeoil oilshaleandoilsands aviationgasoline 
					motorgasolineexclbiofuels biodiesels biogasoline otherkerosene
					otherliquidbiofuels gasolinetypejetfuel kerosenetypejetfuelexclbi
					otheroilproducts liquefiedpetroleumgaseslp
					fueloil refineryfeedstocks additivesblendingcomponen otherhydrocarbons 
					refinerygas  gasdieseloilexclbiofuels naphtha whitespiritsbp lubricants
					paraffinwaxes petroleumcoke;
				
local gassources	natgas ethane naturalgasliquids;

local fuel_types coal oil gas;
*Must assign a conversion factor to each of the following uses;



*kt to MTOE is complex because it depends on the fuel and the sector;
foreach 
gen kt_to_MTOE=.;

foreach fuel_type of local fuel_types{;
	
	gen `fuel_type'_dummy=0;

	foreach `fuel_type'_source of local `fuel_type'sources{;
		replace `fuel_type'_dummy=1 if source_name=="``fuel_type'_source'";
	};
};

*First must define world averages of emissions, to make sure there's something to merge always ;



					


*here must replace t_to_MTOE, by fuel and use;
*must generate a conversion factor for each activity, as follows:
*source_Energy source_Final source_Transformation;
foreach use in Agricultureforestry Commercial Fishing Nonspecified Residential Transport{;
	gen cf_`use'=conv_other_use if conv_other_use!=.;
	replace cf_`use'=mean_conv_other_use if conv_other_use==.;
};

gen cf_Industry=conv_industry if conv_industry!=.;
replace cf_Industry=mean_conv_industry if conv_industry==.;

