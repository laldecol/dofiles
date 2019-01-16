#delimit;
set trace on;
set more off;
pause on;
clear;

/*;
This .do file writes the .dtas used to run regressions. 
The code that uses these files is in the particulates_analysis repository.

1. Country-year level flows
2. Country-year averages of pixel level variables

Created: October 22, 2017, by Lorenzo
Last modified: January 15, 2019, by Lorenzo
*/;

*1. Country-year level flows;
*Append and reshape box_model_inputs to merge them in as country-year-level to regression database.;

	append using "..\\..\\..\\data\\dtas\\country\\box_model_inputs2000.dta"
	"..\\..\\..\\data\\dtas\\country\\box_model_inputs2005.dta"
	"..\\..\\..\\data\\dtas\\country\\box_model_inputs2010.dta"
	"..\\..\\..\\data\\dtas\\country\\box_model_inputs2015.dta", gen(year);

	recode year (1=2000) (2=2005) (3=2010) (4=2015);

	drop length_interior_border length_urban_world_border sending_area_urban 
	length_rural_world_border Terra_avg_world_rural Terra_avg_world_urban 
	sending_area_rural
	flux_to_interior_rural flux_to_interior_urban
	flow_rural_urban flow_urban_rural
	uwnd_avg_interior_rural vwnd_avg_interior_rural 
	uwnd_avg_world_rural vwnd_avg_world_rural 
	uwnd_avg_from_world_rural vwnd_avg_from_world_rural 
	uwnd_avg_interior_urban vwnd_avg_interior_urban 
	uwnd_avg_world_urban vwnd_avg_world_urban 
	uwnd_avg_from_world_urban vwnd_avg_from_world_urban
	wind_urban_world wind_rural_world wind_urban_rural 
	wind_rural_urban wind_world_rural wind_world_urban
	urban_sender_pixel_model urban_sender_region_model
	Fire2000rural Fire2000urban Oil2000 Coal2000 Gas2000 urbanshare2000 
	Fire2005rural Fire2005urban Oil2005 Coal2005 Gas2005 urbanshare2005 
	Fire2010rural Fire2010urban Oil2010 Coal2010 Gas2010 urbanshare2010 
	Fire2015rural Fire2015urban Oil2015 Coal2015 Gas2015 urbanshare2015;

	gen flow_out_pixel_model =flux_to_world_rural 	+ flux_to_world_urban;
	gen flow_in_pixel_model  =flux_from_world_rural + flux_from_world_urban;

	label var flow_out_pixel_model "Flow out, pixel model";
	label var flow_in_pixel_model "Flow in, pixel model";

	gen flow_out_region_model=flow_urban_world		+ flow_rural_world ;
	gen flow_in_region_model =flow_world_rural		+ flow_world_urban;

	label var flow_out_region_model "Flow out, region model";
	label var flow_in_region_model "Flow in, region model";

	drop flux_to_world_rural flux_to_world_urban 
	flux_from_world_rural flux_from_world_urban
	flow_urban_world flow_rural_world
	flow_world_rural flow_world_urban;


	save "..\\..\\..\\data\\dtas\\country_year\\fluxes_merge_mod5.dta", replace;
  
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

save "..\\..\\..\\data\dtas\\country\\aux_dtas\\orderded_country_transfer`year'.dta", replace;

gen temp_sender=sender_country_name;
gen temp_receiver=neighbor_country_name;

replace sender_country_name=temp_receiver;
replace neighbor_country_name= temp_sender;

replace transfer_=-transfer_;

drop temp_receiver temp_sender;

save "..\\..\\..\\data\dtas\\country\\aux_dtas\\inverted_country_transfer`year'.dta", replace;

append using "..\\..\\..\\data\dtas\\country\\aux_dtas\\orderded_country_transfer`year'.dta";

save "..\\..\\..\\data\\dtas\\country\\regression_inputs_flux`year'.dta", replace;
	
};

*2. Country-year averages of pixel level variables

	use "..\\..\\..\\data\\dtas\analyze_me_land_mod5.dta", clear;
	*Generate country year averages of pixel level variables, to be used in regressions;
	collapse (mean) density_ctryyr=density urban_wb_ctryyr=urban_wb
	rgdpe Oil Coal Gas IEA_Coal IEA_Oil IEA_Other urbanshare countryGDPpc
	gpwpop
	water_ctryyr=water trees_ctryyr=trees pasture_ctryyr=pasture 
	barren_ctryyr=barren crops_ctryyr=crops 
	other_ctryyr=other
	Fire_ctryyr=Fire construction_ctryyr=construction5yr
	(sum)
	area_urban_ctryyr=area_urban
	area_ctryyr=area
	
	, by(country year);
	
	gen share_area_urban=area_urban_ctryyr/area_ctryyr;
	save "..\\..\\..\\data\\dtas\\country_year\\pixel_data_country_avgs.dta", replace;
