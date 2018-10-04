#delimit;
pause on; 

local ieafiles: dir "..\\..\\..\\data\\IEA\\source" files "IEA_energy_data*.csv", respectcase;
local filecount=0;
local tempfs;
local master temp1;

foreach ieafile of local ieafiles{;
	
	import delimited "..\\..\\..\\data\\IEA\\source/`ieafile'", varnames(2) rowrange(2) clear ;
	
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
	
	destring time `sourcelist', ignore(.) replace;
	
	sort country time flow;
	save temp`filecount', replace;
};

*Keep list of using files to merge;
local usings: list tempfs - master;
dis "`usings'";
clear;

*Merge all usings to master;
use temp1;
foreach using of local usings{;
merge 1:1 country time flow using `using', nogen;
};

local coalvars ;
local oilvars ;
local gasvars ;

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
