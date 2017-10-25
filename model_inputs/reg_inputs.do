#delimit;
set trace on;
set more off;
pause on;

/*;
This .do file computes, for each country:

0. World wind, for the rural and urban region;
1. World AOD, for the rural and urban region;
2. Length of the interior, urban-world, and rural-world border;
3. Average AOD in the urban and rural region;
4. Urban and rural area;
Created: October 22, 2017, by Lorenzo
Last modified: October 25, 2017, by Lorenzo
*/;

*Define set of years we want to process;
local years 2000 2005 2010 2015;
foreach year of local years{;

use "..\\..\\..\\data\\dtas\\country_regions\\flux\\flux`year'.dta", clear;

collapse (sum) transfer_, by(sender_country_name neighbor_country_name_);

gen switch=.;
drop if sender_country_name==neighbor_country_name_;
replace switch=0 if sender_country_name<neighbor_country_name;
replace switch=1 if sender_country_name>neighbor_country_name;

gen temp_sender=""; 
gen temp_receiver="";

replace temp_sender=sender_country_name if !switch;
replace temp_receiver=neighbor_country_name if !switch;

replace temp_sender=neighbor_country_name if switch; 
replace temp_receiver=sender_country_name if switch;

replace transfer_=-transfer_ if switch;

replace sender_country_name=temp_sender;
replace neighbor_country_name= temp_receiver;

drop temp_receiver temp_sender;

collapse (sum) transfer_, by(sender_country_name neighbor_country_name_);

save "S:\\particulates\\data_processing\\data\dtas\\country\\aux_dtas\\orderded_country_transfer`year'.dta", replace;

gen temp_sender=sender_country_name;
gen temp_receiver=neighbor_country_name;

replace sender_country_name=temp_receiver;
replace neighbor_country_name= temp_sender;

replace transfer_=-transfer_;

drop temp_receiver temp_sender;

save "S:\\particulates\\data_processing\\data\dtas\\country\\aux_dtas\\inverted_country_transfer`year'.dta", replace;

append using "S:\\particulates\\data_processing\\data\dtas\\country\\aux_dtas\\orderded_country_transfer`year'.dta";

save "S:\\particulates\\data_processing\\data\\dtas\\country\\regression_inputs_flux`year'.dta", replace;
	
};
