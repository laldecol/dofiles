#delimit;
set trace on;
set more off;

/*;
This .do file computes, for each country:

1. World AOD, for the rural and urban region;
2. Length of the interior, urban-world, and rural-world border;
3. Average AOD in the urban and rural region;
4. Urban and rural area;
Created: October 22, 2017, by Lorenzo
Last modified: October 23, 2017, by Lorenzo
*/;

*Define set of years we want to process;
local years 2000 2005 2010 2015;

*First, load flux dtas. These have country neighbor pair as unit of observation;
foreach year of local years{;
use "..\\..\\..\\data\\dtas\\country_regions\\flux\\flux`year'.dta", clear;
*Keep total AOD for each neighbor country;

gen total_neighbor_AOD=receiver_Terra`year'_mean * receiver_Terra`year'_count;
gen total_neighbor_uwnd=uwnd_mean * uwnd_pixels;
gen total_neighbor_vwnd=vwnd_mean * vwnd_pixels;

collapse (sum) total_neighbor_AOD receiver_Terra`year'_count 
total_neighbor_uwnd uwnd_pixels total_neighbor_vwnd vwnd_pixels
length, by (sending_countryXregion`year' interior_border);

***Check if any direction of flow is reversed when computing flow from averages;
gen bordtype_str="";
replace bordtype_str="interior" if interior_border==1;
replace bordtype_str="world" if interior_border==0; 
rename sending_countryXregion`year' countryXregion`year';
gen Terra_avg_=total_neighbor_AOD/receiver_Terra`year'_count;
gen uwnd_avg=

merge m:1 countryXregion`year' using "..\\..\\..\\data\\dtas\\country\\country_codes_names`year'.dta";
rename Terra`year'_count sending_Terra`year'_count;
rename Terra`year'_mean sending_Terra`year'_mean;
rename area sending_area;
drop total_neighbor_AOD receiver_Terra`year'_count _merge interior_border;

reshape wide Terra_avg length, i(countryXregion`year') j(bordtype_str) string;

drop countryXregion`year' neighbor_ uber_code;

gen regtype_str="";
replace regtype_str="_urban" if neighbor_rgn_==1;
replace regtype_str="_rural" if neighbor_rgn_==0;
drop neighbor_rgn_;
reshape wide lengthworld Terra_avg_world Terra_avg_interior lengthinterior 
sending_Terra`year'_count sending_Terra`year'_mean sending_area, i(neighbor_country_name_) j(regtype_str) string;

drop lengthinterior_rural;
rename lengthinterior_urban length_interior_border;
rename lengthworld_rural length_rural_world_border;
rename lengthworld_urban length_urban_world_border;
rename neighbor_ctry_ gpw_v4_national_identifier_gri;
rename neighbor_country_name_ country;
order country gpw_v4_national_identifier_gri
Terra_avg_world_rural Terra_avg_world_urban
length_interior_border length_urban_world_border
length_rural_world_border
Terra_avg_interior_urban Terra_avg_interior_rural;
drop sending_Terra`year'_count_rural sending_Terra`year'_mean_rural 
sending_Terra`year'_count_urban sending_Terra`year'_mean_urban;

*Label:;
label var gpw_v4_national_identifier_gri "Country id";
label var Terra_avg_world_rural "World concentration for the rural area";
label var Terra_avg_world_urban "World concentration for the rural area";
label var length_interior_border "Length of rural-urban border";
label var length_urban_world_border "Length of urban-world border";
label var length_rural_world_border "Length of rural-world border";
label var Terra_avg_interior_urban "Average AOD concentration in urban area";
label var Terra_avg_interior_rural "Average AOD concentration in rural area";

save "..\\..\\..\\data\\dtas\\country\\box_model_inputs`year'.dta", replace;
};

