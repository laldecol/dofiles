#delimit;
pause on; 
set trace off;
set tracedepth 1;

***Import source files;
local ieafiles: dir "..\\..\\..\\data\\IEA\\source" files "IEA_energy_data*.csv", respectcase;
local filecount=0;
local tempfs;
local master temp1;

foreach ieafile of local ieafiles{;
	
	import delimited "..\\..\\..\\data\\IEA\\source/`ieafile'", varnames(2) rowrange(2) clear ;
	
	capture drop v*;
	*Name and create temporary files for merge;
	tempfile temp`filecount';
	local ++filecount;
	local tempfs `tempfs' temp`filecount';
	
	*Keep list of sources variables;
	ds country time flow, not;
	local sourcelist `r(varlist)';
	
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
	
	save temp`filecount', replace;
};

*Keep list of using files to merge;
local usings: list tempfs - master;
dis "`usings'";
clear;

*Merge all usings to master;
use temp1;
foreach using of local usings{;
merge 1:1 country time source_name using `using', nogen;
};
tempfile source_merged;
save `source_merged';

***Import conversion factors;
local convfiles: dir "S:\\particulates\\data_processing\\data\\IEA\\source\\conversion_factors" files "*.csv", respectcase;
local filecount=0;
local tempfs;
local master temp1;

foreach convfile of local convfiles{;
	
	import delimited "..\\..\\..\\data\\IEA\\source\\conversion_factors/`convfile'", varnames(2) rowrange(2) clear ;
	
	*Name and create temporary files for merge;
	tempfile temp`filecount';
	local ++filecount;
	local tempfs `tempfs' temp`filecount';
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
	
	reshape long conv_, i(unit country time flow)  j(source_name) string;
	reshape wide conv_, i(country time source_name) j(flow) string;
	
	sort country time;
	save temp`filecount', replace;
	*in this data, gas diesel oils are called gasdieseloilexclbiofuels;
};

*Keep list of using files to merge;
local usings: list tempfs - master;
dis "`usings'";
clear;

*Merge all usings to master;
use temp1;
foreach using of local usings{;
	merge 1:1 country time source_name using `using', nogen;
};

tempfile conv_merged;
save `conv_merged';
pause;
merge 1:1 country time source_name using `source_merged';

egen fuel_consumption=rowtotal(source_Energy source_Final source_Transformation);
drop source_Energy source_Final source_Transformation;

sort country time _merge source_name fuel_consumption;
order _merge country time source_name fuel_consumption;
drop if fuel_consumption==0;

bro if _merge==2;
gen fuel_units=units_Energy;
drop units_*;

local coalvars anthracite bkb charcoal coaltar otherbituminouscoal subbituminouscoal;
local oilvars bitumen crudeoil oilshaleandoilsands;
local gasvars ;

/*;
additivesblendingcomponen
         aviationgasoline
               biodiesels
              biogasoline
             cokeovencoke
               cokingcoal
                   ethane
                  fueloil
                  gascoke
 gasdieseloilexclbiofuels
      gasolinetypejetfuel
kerosenetypejetfuelexclbi
                  lignite
liquefiedpetroleumgaseslp
               lubricants
motorgasolineexclbiofuels
                  naphtha
        naturalgasliquids
        otherhydrocarbons
            otherkerosene
      otherliquidbiofuels
         otheroilproducts
            paraffinwaxes
               patentfuel
                     peat
             peatproducts
            petroleumcoke
       refineryfeedstocks
              refinerygas
           whitespiritsbp
*/;

. 

/**;
use "S:\particulates\data_processing\data\IEA\source\coal.dta", clear;
rename var1 country;
rename var2 year;
rename product flow;

drop if _n==1;
replace country=country[_n-1] if country=="";
replace year=year[_n-1] if year=="";



destring year anthracitekt cokingcoalkt otherbituminouscoalkt subbituminouscoalkt 
lignitekt cokeovencokekt coaltarkt peatkt peatproductskt oilshaleandoilsandskt, 
ignore(.) replace;

keep if year>=2000;

sort country year flow;
drop flow;
by country year: gen concept=_n;

reshape wide anthracitekt cokingcoalkt otherbituminouscoalkt subbituminouscoalkt 
lignitekt cokeovencokekt coaltarkt peatkt peatproductskt oilshaleandoilsandskt
, i(year country) j(concept);

tempfile IEAcoal;

replace country="United States of America" if country=="United States";
replace country="China" if country=="People's Republic of China";
replace country="China Hong Kong Special Administrative Region" if country=="Hong Kong (China)";
replace country="Republic of Korea" if country=="Korea";
replace country="United Kingdom of Great Britain and Northern Ireland" if country=="United Kingdom";


save `IEAcoal';

use "S:\\particulates\\data_processing\\data\\BP\\generated\\CoalConsumption.dta";
reshape long Coal, i(country) j(year);

merge 1:m year country using `IEAcoal';
replace Coal=Coal*1000;

tab country if _merge==1;
tab country if _merge==2;

reg Coal anthracitekt1 cokingcoalkt1 otherbituminouscoalkt1 subbituminouscoalkt1 lignitekt1 cokeovencokekt1 coaltarkt1 peatkt1 peatproductskt1 oilshaleandoilsandskt1 anthracitekt2 cokingcoalkt2 otherbituminouscoalkt2 subbituminouscoalkt2 lignitekt2 cokeovencokekt2 coaltarkt2 peatkt2 peatproductskt2 oilshaleandoilsandskt2;

egen IEAtotalcoal=rowtotal(anthracitekt* cokingcoalkt* otherbituminouscoalkt* subbituminouscoalkt* lignitekt* cokeovencokekt* coaltarkt* peatkt* peatproductskt* oilshaleandoilsandskt*);

scatter (Coal IEAtotalcoal) || function y = x, range(Coal);
**/;
