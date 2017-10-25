#delimit;
set trace on;
set more off;

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
local rho 100;
local h 1000;
local k; 

*0.
*First, load flux dtas. These have country neighbor pair as unit of observation;
foreach year of local years{;
use "..\\..\\..\\data\\dtas\\country_regions\\flux\\flux`year'.dta", clear;
gen total_neighbor_uwnd=uwnd_mean * uwnd_pixels;
gen total_neighbor_vwnd=vwnd_mean * vwnd_pixels;

collapse (sum)
total_neighbor_uwnd uwnd_pixels total_neighbor_vwnd vwnd_pixels
, by (neighbor_ interior_border);

*These are average wind flowing into neighbor_ from world and interior.;
gen uwnd_avg_=total_neighbor_uwnd/uwnd_pixels;
gen vwnd_avg_=total_neighbor_vwnd/vwnd_pixels;

gen bordtype_str="";
replace bordtype_str="interior" if interior_border==1;
replace bordtype_str="world" if interior_border==0; 
drop interior_border total_neighbor_uwnd uwnd_pixels total_neighbor_vwnd vwnd_pixels;

reshape wide uwnd_avg_ vwnd_avg_, i(neighbor_) j(bordtype_str) string;
drop vwnd_avg_interior uwnd_avg_interior;

rename vwnd_avg_world vwnd_avg_from_world;
rename uwnd_avg_world uwnd_avg_from_world;
rename neighbor_ countryXregion`year';

save "..\\..\\..\\data\\dtas\\country_regions\\wind\\wind_from_world`year'.dta", replace;

};


*Again, load flux dtas. These have country neighbor pair as unit of observation;
foreach year of local years{;
use "..\\..\\..\\data\\dtas\\country_regions\\flux\\flux`year'.dta", clear;
*Keep total AOD for each neighbor country;

gen total_neighbor_AOD=receiver_Terra`year'_mean * receiver_Terra`year'_count;
gen total_neighbor_uwnd=uwnd_mean * uwnd_pixels;
gen total_neighbor_vwnd=vwnd_mean * vwnd_pixels;

collapse (sum) total_neighbor_AOD receiver_Terra`year'_count 
total_neighbor_uwnd uwnd_pixels total_neighbor_vwnd vwnd_pixels
length, by (sending_countryXregion`year' interior_border);

gen bordtype_str="";
replace bordtype_str="interior" if interior_border==1;
replace bordtype_str="world" if interior_border==0; 
rename sending_countryXregion`year' countryXregion`year';

gen Terra_avg_=total_neighbor_AOD/receiver_Terra`year'_count;
gen uwnd_avg_=total_neighbor_uwnd/uwnd_pixels;
gen vwnd_avg_=total_neighbor_vwnd/vwnd_pixels;

merge m:1 countryXregion`year' using "..\\..\\..\\data\\dtas\\country\\country_codes_names`year'.dta";

rename Terra`year'_count sending_Terra`year'_count;
rename Terra`year'_mean sending_Terra`year'_mean;
rename area sending_area;

drop total_neighbor_AOD receiver_Terra`year'_count _merge interior_border
total_neighbor_uwnd uwnd_pixels total_neighbor_vwnd vwnd_pixels;

reshape wide Terra_avg length uwnd_avg_ vwnd_avg_, i(countryXregion`year') j(bordtype_str) string;
merge 1:1 countryXregion`year' using "..\\..\\..\\data\\dtas\\country_regions\\wind\\wind_from_world`year'.dta", nogen;

drop countryXregion`year' neighbor_ uber_code;

gen regtype_str="";
replace regtype_str="_urban" if neighbor_rgn_==1;
replace regtype_str="_rural" if neighbor_rgn_==0;
drop neighbor_rgn_;

reshape wide lengthworld Terra_avg_world Terra_avg_interior lengthinterior 
sending_Terra`year'_count sending_Terra`year'_mean sending_area
uwnd_avg_interior uwnd_avg_world
vwnd_avg_interior vwnd_avg_world
uwnd_avg_from_world vwnd_avg_from_world
, i(neighbor_country_name_) j(regtype_str) string;

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
*Last part of name is origin region type;
label var gpw_v4_national_identifier_gri "Country id";

label var Terra_avg_world_rural "World concentration for the rural area";
label var Terra_avg_world_urban "World concentration for the urban area";

label var Terra_avg_interior_urban "Average AOD concentration in urban area";
label var Terra_avg_interior_rural "Average AOD concentration in rural area";

label var length_interior_border "Length of rural-urban border (km)";
label var length_urban_world_border "Length of urban-world border (km)";
label var length_rural_world_border "Length of rural-world border (km)";

label var uwnd_avg_interior_urban "Average eastward wind speed (m/s) from urban to rural";
label var uwnd_avg_interior_rural "Average eastward wind speed (m/s) from rural to urban";

label var uwnd_avg_world_urban "Average eastward wind speed (m/s) from urban to world";
label var uwnd_avg_world_rural "Average eastward wind speed (m/s) from rural to world";

label var vwnd_avg_interior_urban "Average northward wind speed (m/s) from urban to rural";
label var vwnd_avg_interior_rural "Average northward wind speed (m/s) from rural to urban";

label var vwnd_avg_world_urban "Average northward wind speed (m/s) from urban to world";
label var vwnd_avg_world_rural "Average northward wind speed (m/s) from rural to world";

label var uwnd_avg_from_world_urban "Average eastward wind speed (m/s) from world to urban";
label var uwnd_avg_from_world_rural "Average eastward wind speed (m/s) from world to rural";

label var vwnd_avg_from_world_urban "Average northward wind speed (m/s) from world to urban";
label var vwnd_avg_from_world_rural "Average northward wind speed (m/s) from world to rural";

label var sending_area_rural "Area of rural region"; 
label var sending_area_urban "Area of urban region";

gen flow_urban_world=`h'*`rho'* Terra_avg_interior_urban * length_urban_world_border *1000 * (abs(uwnd_avg_world_urban)+abs(vwnd_avg_world_urban));
gen flow_rural_world=`h'*`rho'* Terra_avg_interior_rural * length_rural_world_border *1000 * (abs(uwnd_avg_world_rural)+abs(vwnd_avg_world_rural)) ;

gen flow_urban_rural=`h'*`rho'* Terra_avg_interior_urban * length_interior_border *1000 * (abs(uwnd_avg_interior_urban)+abs(vwnd_avg_interior_urban));
gen flow_rural_urban=`h'*`rho'* Terra_avg_interior_rural * length_interior_border *1000 * (abs(uwnd_avg_interior_rural)+abs(vwnd_avg_interior_rural));

gen flow_world_rural=`h'*`rho'* Terra_avg_world_rural * length_rural_world_border *1000 * (abs(uwnd_avg_from_world_rural)+abs(vwnd_avg_from_world_rural));
gen flow_world_urban=`h'*`rho'* Terra_avg_world_urban * length_urban_world_border *1000 * (abs(uwnd_avg_from_world_urban)+abs(vwnd_avg_from_world_urban));

label var flow_urban_world "Flow from urban to world, computed as in Matt's model";
label var flow_rural_world "Flow from rural to world, computed as in Matt's model";

label var flow_urban_rural "Flow from urban to rural, computed as in Matt's model";
label var flow_rural_urban "Flow from rural to urban, computed as in Matt's model";

label var flow_world_rural "Flow from world to rural, computed as in Matt's model";
label var flow_world_urban "Flow from world to urban, computed as in Matt's model";

merge 1:1 gpw_v4_national_identifier_gri using "..\\..\\..\\data\\dtas\\country\\macro_model_inputs_`year'.dta", nogen;

drop Terra`year'rural pop_rural`year' arearural Terra`year'urban pop_urban`year' areaurban
rgdpe`year' rgdpo`year' urbanshare`year' countrypop`year';

save "..\\..\\..\\data\\dtas\\country\\box_model_inputs`year'.dta", replace;

};

