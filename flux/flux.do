***This .do file computes AOD transfers between regions, given wind, AOD, and region information.
*It assumes a pixel-level input .dta, where pixels are indexed by the variable 'uber_code';
*It also takes as given a settings file that describes the dimensions of the reference rasters.;
*Output dtas can be converted to ubergrid rasters using raster2dta

*Created by: Lorenzo 
*

#delimit;
program drop _all;
capture log close;
pause on;
set more off;
set trace on;

*ubercode2rc generates variables with row and column coordinates for all cells in
*an ubergrid.
*Inputs:
*ubercode: An ubercode variable, that identifies the position of a cell in space
*C: The number of columns in the underlying ubergrid
*stub: The stub name of the row and column variables to be created;
program define ubercode2rc;
args ubercode C stub;
gen col`stub'=mod(`ubercode',`C');
replace col`stub'=`C' if col`stub'==0;
gen row`stub'=(`ubercode'-col`stub')/`C'+1;
end;

*rc2ubercode generates ubercode variable into row and column coordinates in an
*ubergrid.
*Inputs:
*row: The row coordinate of a cell in an ubergrid
*col: The column coordinate of a cell in an ubergrid
*C: The number of columns in the underlying ubergrid
*ubercodename: The name of the ubercode variable to be generated;
program define rc2ubercode;
args row col C ubercodename;
gen `ubercodename'=.;
replace `ubercodename'=(`row'-1)*`C'+`col' if `row'!=. & `col'!=.;
end;

program define neighborsca, rclass;
args ubercode C R;
return scalar north=cond(`ubercode'>`C', `ubercode'-`C' , . );
return scalar south=cond(`ubercode'<=`C'*`R'-`C', `ubercode'+`C' , . );
return scalar east=cond(mod(`ubercode',`C')==0, `ubercode'-`C'+1 , `ubercode'+ 1 );
return scalar west=cond(mod(`ubercode',`C')==1, `ubercode'+`C'-1 , `ubercode'- 1 );
end; 

program define neighborvar;
args ubercodevar C R;
gen `ubercodevar'_north=cond(`ubercodevar'>`C', `ubercodevar'-`C' , . );
gen `ubercodevar'_south=cond(`ubercodevar'<=`C'*`R'-`C', `ubercodevar'+`C' , . );
gen `ubercodevar'_east=cond(mod(`ubercodevar',`C')==0, `ubercodevar'-`C'+1 , `ubercodevar'+ 1 );
gen `ubercodevar'_west=cond(mod(`ubercodevar',`C')==1, `ubercodevar'+`C'-1 , `ubercodevar'- 1 );
end; 

program define isborder;
args bordervar ubercodevar C R ignorevals;

sort `ubercodevar';

neighborvar `ubercodevar' `C' `R';

gen isborder_N=(`bordervar'!=`bordervar'[`ubercodevar'_north] & `bordervar'!=. & `bordervar'!=`ignorevals' & 
`bordervar'[`ubercodevar'_north]!=`ignorevals' & `bordervar'[`ubercodevar'_north]!=. );

gen isborder_S=(`bordervar'!=`bordervar'[`ubercodevar'_south]  & `bordervar'!=. & `bordervar'!=`ignorevals' &
 `bordervar'[`ubercodevar'_south]!=`ignorevals' & `bordervar'[`ubercodevar'_south]!=.);
 
gen isborder_E=(`bordervar'!=`bordervar'[`ubercodevar'_east]  & `bordervar'!=. & `bordervar'!=`ignorevals' &
 `bordervar'[`ubercodevar'_east]!=`ignorevals' & `bordervar'[`ubercodevar'_east]!=.);
 
gen isborder_W=(`bordervar'!=`bordervar'[`ubercodevar'_west]  & `bordervar'!=. & `bordervar'!=`ignorevals' &
 `bordervar'[`ubercodevar'_west]!=`ignorevals' & `bordervar'[`ubercodevar'_west]!=.);

gen neighbor_N=`bordervar'[`ubercodevar'_north];

gen neighbor_S=`bordervar'[`ubercodevar'_south];

gen neighbor_E=`bordervar'[`ubercodevar'_east];

gen neighbor_W=`bordervar'[`ubercodevar'_west];

*drop `ubercodevar'_*;
end;

log using flux, replace;


*For each uber_code, generate four variables: uber_code of northern, southern, western, and eastern neighbor.;
*Calculations:;
use "..\\..\\..\\data\projections\generated\settings.dta", clear;

*Define C,R as column and row totals in current ubergrid.;

local C=COLUMNCOUNT[1];
local R=ROWCOUNT[1];
dis "Number of Columns: " `C';
dis "Number of Rows: " `R';

local years 2000 2001 2002 2003 2004 2005 2006 2007 2008 2009 2010 2011 2012 2013 2015;

*Use urbanization dummies to generate a region variable for each year;
foreach year of local years{;
use "..\\..\\..\\data\\dtas\\analyze_me_land_std_units.dta", clear;

*Check we're using correct ubergrid settings;
assert _N==`R'*`C';

*Create country label for nonland;
replace gpw_v4_national_identifier_gri=-9999 if gpw_v4_national_identifier_gri==.;
replace country="Sea, Inland Water, other Uninhabitable" if gpw_v4_national_identifier_gri==-9999;

egen countryXregion`year'=group(country urban_wb2010), label;

preserve;

collapse (count) uber_code Terra`year'_count=Terra`year' (firstnm) gpw_v4_national_identifier_gri
(mean) Terra`year'_mean=Terra`year' (sum) area, by(countryXregion`year' country urban_wb2010);

*Generate copy of id variable, for future merge;
gen neighbor_=countryXregion`year';

rename gpw_v4_national_identifier_gri neighbor_ctry_;
rename country neighbor_country_name_;
rename urban_wb2010 neighbor_rgn_;

*Order identical id vars first;
order countryXregion`year' neighbor_;

save "..\\..\\..\\data\\dtas\\country\\country_codes_names`year'.dta", replace;

restore;

***Generate Mean winds;

sort uber_code;
isborder countryXregion`year' uber_code `C' `R' .;

gen Nt`year'=max(vwnd_`year',0)*Terra`year';
gen St`year'=max(-vwnd_`year',0)*Terra`year';
gen Et`year'=max(uwnd_`year',0)*Terra`year';
gen Wt`year'=max(-uwnd_`year',0)*Terra`year';

gen Nw`year'=max(vwnd_`year',0);
gen Sw`year'=max(-vwnd_`year',0);
gen Ew`year'=max(uwnd_`year',0);
gen Ww`year'=max(-uwnd_`year',0);

keep uber_code isborder_* country gpw_v4_national_identifier_gri countryXregion`year'
neighbor_* Nt* St* Et* Wt* Nw* Sw* Ew* Ww*
area Terra`year' vwnd_`year' uwnd_`year';

keep if isborder_N | isborder_S | isborder_E | isborder_W;

rename (Nt`year' St`year' Et`year' Wt`year') (transfer_N transfer_S transfer_E transfer_W);
rename (Nw`year' Sw`year' Ew`year' Ww`year') (wind_N wind_S wind_E wind_W);

reshape long isborder_ neighbor_ transfer_ wind_, i(uber_code) j(dir) string;

*Generate length of pixel as sqrt(area);
gen length=sqrt(area);

*merge m:1 neighbor_ using "S:\particulates\data_processing\data\dtas\country_codes_names`year'.dta";
*;

collapse (count) isborder_ vwnd_pixels=vwnd_ uwnd_pixels=uwnd_ (sum) length transfer_ (mean) vwnd_mean=vwnd_ uwnd_mean=uwnd_ if isborder_, by( countryXregion`year' neighbor_);

label variable isborder_ "Number of border pixels used in computations";
label variable length "Approximate length of border (km)";
label variable transfer_ "Flux from countryXregion to interior or world (depends on interior_border), in AOD units per hr";

merge m:1 countryXregion`year' using "..\\..\\..\\data\\dtas\\country\\country_codes_names`year'.dta", nogen;
rename Terra`year'_mean sender_Terra`year'_mean;
rename Terra`year'_count sender_Terra`year'_count;

rename neighbor_country_name_ sender_country_name;
rename neighbor_ctry_ sender_country;
rename neighbor_rgn_ sender_region;
rename countryXregion`year' sending_countryXregion`year';

***Check Terra variables: count and average. Rename them to keep track of them after
* later merge;

merge m:1 neighbor_ using "..\\..\\..\\data\\dtas\country\\country_codes_names`year'.dta", nogen;
drop countryXregion`year';

rename Terra`year'_mean receiver_Terra`year'_mean;
rename Terra`year'_count receiver_Terra`year'_count;

*Now have all pairs of sender and receiver regions, with their countries and ruban status ;

label variable sending_countryXregion`year' "Sender Region";
label variable neighbor_ "Receiver Region";

*Now must define sending & receiving, netting both interior transfers;
gen interior_border=(sender_country_name==neighbor_country_name);

save "..\\..\\..\\data\\dtas\\country_regions\\flux\\flux`year'.dta", replace;

label var vwnd_mean "Average Northward Wind Speed (km/h)";
label var uwnd_mean "Average Eastward Wind Speed (km/h)";
label var sender_Terra`year'_mean "Average AOD in sender region, AOD units";
label var receiver_Terra`year'_mean "Average AOD in receiver region, AOD units";

};
log close;
