#delimit;
pause on; 
set trace on;
set tracedepth 1;

use "S:\particulates\data_processing\data\IEA\generated/sources_conv_factors.dta", clear;
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


foreach fuel_type of local fuel_types{;
	
	gen `fuel_type'_dummy=0;

	foreach `fuel_type'_source of local `fuel_type'sources{;
		replace `fuel_type'_dummy=1 if source_name=="``fuel_type'_source'";
	};
};

*First must define world averages of emissions, to make sure there's something to merge always ;

local conv_factors conv_other_use conv_industry conv_aep conv_ahp conv_auto_chp 
					conv_avg conv_blast conv_cokeovens conv_exports conv_imports 
					conv_ma_chp conv_mahp conv_mapep conv_other_sources conv_production;

foreach conv_factor of local conv_factors{;
	bysort source_name: egen mean_`conv_factor'=mean(`conv_factor');
};


*source_Energy source_Final source_Transformation;
foreach use in Agricultureforestry Commercial Fishing Nonspecified Residential Transport{;
	gen cf_`use'=conv_other_use if conv_other_use!=.;
	replace cf_`use'=mean_conv_other_use if conv_other_use==.;
};

gen cf_Industry=conv_industry if conv_industry!=.;
replace cf_Industry=mean_conv_industry if conv_industry==.;

