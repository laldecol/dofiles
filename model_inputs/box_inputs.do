#delimit;
set trace on;
set tracedepth 1;
set more off;
pause on;
capture log close;
/*;
This .do file computes, for each country:

1. AOD flows from world into each country region;
2. World AOD, for the rural and urban region;
3. Length of the interior, urban-world, and rural-world border.
4. Length of the border over which transfers occur, for each region pair;
5. Average AOD in the urban and rural region;
6. Urban and rural area;

Created: October 22, 2017, by Lorenzo
Last modified: Feb 23, 2017, by Lorenzo
*/;

*Define set of years we want to process;
local years 2000 2001 2002 2003 2004 2005 2006 2007 2008 2009 2010 2011 2012 2013 2015;
local rho 10;
local h 3;
local k; 


*1.Compute flows from world for each country-region, looping over years;	
	foreach year of local years{;

		*First, load flux dtas. These have country neighbor pair as unit of observation;
		*One flux dta per year;
		use "..\\..\\..\\data\\dtas\\country_regions\\flux\\flux`year'.dta", clear;
		
		*These are total flows into neighbor_ from world and interior.;
		collapse (sum)
		transfer_ windborder_
		, by (neighbor_ interior_border);
		
		gen bordtype_str="";
		replace bordtype_str="interior" if interior_border==1;
		replace bordtype_str="world" if interior_border==0; 
		drop interior_border;

		rename transfer_ flux_from_;
		rename windborder_ windborder_from_;

		reshape wide flux_from windborder_from, i(neighbor_) j(bordtype_str) string;

		rename neighbor_ countryXregion_const;

		tempfile from_world`year';
		save `from_world`year'';

	};

*Again, load flux dtas. These have country neighbor pair as unit of observation;
*2-6. Compute World AOD, border length, mean AOD, and wind, for each country region;

foreach year of local years{;
	use "..\\..\\..\\data\\dtas\\country_regions\\flux\\flux`year'.dta", clear;

	*Keep total AOD for each neighbor country X region;
	*Receiver_Terra`year' is receiver's AOD;
	gen total_neighbor_AOD=receiver_Terra`year'_mean * receiver_Terra`year'_count;

	*transfer_ here is total transfer from own to world and interior;
	*We have kept neighbor region AOD;
	*Collapses to country region X interior/world level;
	*transfer_ here is total transfer from the region to interior and world;
	*windborder is the length of the border over which this transfer happens;
	collapse (sum) total_neighbor_AOD receiver_Terra`year'_count 
	length transfer_ windborder_
	, by (sending_countryXregion_const interior_border);

	gen bordtype_str="";
	replace bordtype_str="interior" if interior_border==1;
	replace bordtype_str="world" if interior_border==0; 
	rename sending_countryXregion_const countryXregion_const;
	
	*We will recover urban and rural AOD from neighbor's AOD & urban/rural status;
	*Terra_avg_ is interior neighbor's AOD in the next line's definition. obsolete as of Oct 31;
	gen Terra_avg_=total_neighbor_AOD/receiver_Terra`year'_count;
	
	drop total_neighbor_AOD receiver_Terra`year'_count interior_border;
	
	merge m:1 countryXregion_const using "..\\..\\..\\data\\dtas\\country\\country_codes_names`year'.dta", nogen;
	*Care should be taken here. in country_codes_names, neighbor_rgn means own region urban status.
	*This is bad notation but is correct for the computations, after Lint's comment on Oct 31;

	rename Terra`year'_count sending_Terra`year'_count;
	rename Terra`year'_mean sending_Terra`year'_mean;
	rename area sending_area;
	rename transfer_ flux_to_;
	rename windborder windborder_to_;
	
	*Terra_avg is own Terra ;
	reshape wide Terra_avg length windborder_to_ flux_to_, i(countryXregion_const) j(bordtype_str) string;
	
	merge 1:1 countryXregion_const using `from_world`year'', nogen;
	drop countryXregion_const neighbor_ uber_code;
	
	gen regtype_str="";
	*Terra_avg_interior_urban is the AOD average of own region, i.e. urban if own region (called neighbor_rgn_in data) is urban;
	*See above. neighbor_rgn is own urban status;
	drop if neighbor_rgn_==.;
	replace regtype_str="_urban" if neighbor_rgn_==1;
	replace regtype_str="_rural" if neighbor_rgn_==0;
	
	drop neighbor_rgn_;
	
	reshape wide lengthworld Terra_avg_world Terra_avg_interior lengthinterior 
	sending_Terra`year'_count sending_Terra`year'_mean sending_area
	flux_to_interior flux_to_world
	windborder_to_interior windborder_to_world
	flux_from_world windborder_from_world
	flux_from_interior windborder_from_interior	
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
	
	drop sending_Terra`year'_count_rural Terra_avg_interior_rural
	sending_Terra`year'_count_urban Terra_avg_interior_urban;
	
	rename sending_Terra`year'_mean_rural Terra_avg_interior_rural;
	rename sending_Terra`year'_mean_urban Terra_avg_interior_urban;
	
	*Label:;
	*Last part of name is origin region type;
	label var gpw_v4_national_identifier_gri "Country id";
	
	label var Terra_avg_world_rural "World AOD concentration for the rural area";
	label var Terra_avg_world_urban "World AOD concentration for the urban area";
	
	label var Terra_avg_interior_urban "Average AOD concentration in urban area, 2010 boundaries";
	label var Terra_avg_interior_rural "Average AOD concentration in rural area, 2010 boundaries";
	
	label var flux_to_interior_urban "Flow from urban to rural, computed using pixel-flow model, AOD units per hour";
	label var flux_to_interior_rural "Flow from rural to urban, computed using pixel-flow model, AOD units per hour";

	label var flux_from_interior_rural "Flow from world to rural, computed using pixel-flow model, AOD units per hour";
	label var flux_from_interior_urban "Flow from world to urban, computed using pixel-flow model, AOD units per hour";

	label var flux_from_world_rural "Flow from world to rural, computed using pixel-flow model, AOD units per hour";
	label var flux_from_world_urban "Flow from world to urban, computed using pixel-flow model, AOD units per hour";

	label var flux_to_world_urban "Flow from urban to world, computed using pixel-flow model, AOD units per hour";
	label var flux_to_world_rural "Flow from rural to world, computed using pixel-flow model, AOD units per hour";

	label var length_interior_border "Length of rural-urban border (km)";
	label var length_rural_world_border "Length of rural-world border (km)";
	label var length_urban_world_border "Length of urban-world border (km)";
	
	label var sending_area_urban "Area of urban region, 2010 boundaries, sq km";
	label var sending_area_rural "Area of rural region, 2010 boundaries, sq km"; 

	label var windborder_from_interior_rural "Length of urban-rural border where wind blows into rural, km";
	label var windborder_from_interior_urban "Length of urban-rural border where wind blows into urban, km";
	
	label var windborder_from_world_rural "Length of rural-world border where wind blows into rural, km";
	label var windborder_from_world_urban "Length of urban-world border where wind blows into urban, km";
	
	label var windborder_to_interior_rural "Length of urban-rural border where wind blows into urban, km";
	label var windborder_to_interior_urban "Length of urban-rural border where wind blows into rural, km";
	
	label var windborder_to_world_rural "Length of rural-world border where wind blows into world, km";
	label var windborder_to_world_urban "Length of urban-world border where wind blows into world, km";

	gen wind_urban_world=flux_to_world_urban/(`h'*`rho'* Terra_avg_interior_urban * windborder_to_world_urban);
	gen wind_rural_world=flux_to_world_rural/(`h'*`rho'* Terra_avg_interior_rural * windborder_to_world_rural);

	label var wind_urban_world "Average wind speed from urban to world, computed from flows & Matt's model, km/yr";
	label var wind_rural_world "Average wind speed from rural to world, computed from flows & Matt's model, km/yr";

	gen wind_urban_rural=flux_to_interior_urban/(`h'*`rho'* Terra_avg_interior_urban * windborder_to_interior_urban );
	gen wind_rural_urban=flux_to_interior_rural/(`h'*`rho'* Terra_avg_interior_rural * windborder_to_interior_rural );

	label var wind_urban_rural "Average wind speed from urban to rural, computed from flows & Matt's model, km/yr";
	label var wind_rural_urban "Average wind speed from rural to urban, computed from flows & Matt's model, km/yr";

	gen wind_world_rural=flux_from_world_rural/(`h'*`rho'* Terra_avg_world_rural * windborder_from_world_rural);
	gen wind_world_urban=flux_from_world_urban/(`h'*`rho'* Terra_avg_world_urban * windborder_from_world_urban);

	label var wind_world_rural "Average wind speed from world to rural, computed from flows & Matt's model, km/yr";
	label var wind_world_urban "Average wind speed from world to urban, computed from flows & Matt's model, km/yr";
	
	gen urban_sender_pixel_model=(flux_to_interior_rural<flux_to_interior_urban);
	label var urban_sender_pixel_model "Urban sender dummy, defined by net pixel-model flux";

	save "..\\..\\..\\data\\dtas\\country\\emission_factor_inputs_`year'.dta", replace;
	
	*For mod5 years, write country level file with urban and rural variables;
	if `year'==2000 | `year'==2005 | `year'==2010 | `year'==2015{;
		merge 1:1 gpw_v4_national_identifier_gri using "..\\..\\..\\data\\dtas\\country\\macro_model_inputs_`year'.dta", nogen;
		drop Terra`year'rural pop_rural`year' arearural Terra`year'urban pop_urban`year' areaurban
		rgdpe`year' rgdpo`year' countrypop`year';
		
		label data "Country level variables, including AOD flows and fuel consumption";

		save "..\\..\\..\\data\\dtas\\country\\box_model_inputs`year'.dta", replace;
	};
};
	