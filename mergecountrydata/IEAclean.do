#delimit;
pause on; 
use "S:\particulates\data_processing\data\IEA\source\coal.dta", clear;
rename var1 country;
rename var2 year;
rename product flow;

drop if _n==1;
drop if flow=="Energy industry own use";
replace country=country[_n-1] if country=="";
replace year=year[_n-1] if year=="";

destring year anthracitekt cokingcoalkt otherbituminouscoalkt subbituminouscoalkt 
lignitekt cokeovencokekt coaltarkt peatkt peatproductskt oilshaleandoilsandskt, 
ignore(.) replace;

sort country year flow;
drop flow;
by country year: gen concept=_n;

reshape wide anthracitekt cokingcoalkt otherbituminouscoalkt subbituminouscoalkt 
lignitekt cokeovencokekt coaltarkt peatkt peatproductskt oilshaleandoilsandskt
, i(year country) j(concept);

tempfile IEAcoal;
save `IEAcoal';

use "S:\\particulates\\data_processing\\data\\BP\\generated\\CoalConsumption.dta";
reshape long Coal, i(country) j(year);

merge 1:m year country using `IEAcoal', nogen;
replace Coal=Coal*1000;
reg Coal anthracitekt1 cokingcoalkt1 otherbituminouscoalkt1 subbituminouscoalkt1 lignitekt1 cokeovencokekt1 coaltarkt1 peatkt1 peatproductskt1 oilshaleandoilsandskt1 anthracitekt2 cokingcoalkt2 otherbituminouscoalkt2 subbituminouscoalkt2 lignitekt2 cokeovencokekt2 coaltarkt2 peatkt2 peatproductskt2 oilshaleandoilsandskt2;
