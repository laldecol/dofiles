***This .do file computes AOD transfers between regions, given wind, AOD, and region information.
*It assumes a pixel-level input .dta, where pixels are indexed by the variable 'uber_code';
*It also takes as given a settings file that describes the dimensions of the reference rasters.;
*Output dtas can be converted to ubergrid rasters using raster2dta

*Created by: Lorenzo, October 2017;
*Last modified: Lorenzo, October 2017;

#delimit;
program drop _all;
capture log close;
pause on;
set more off;
set trace off;

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

*rc2ubercode generates an ubercode variable from row and column coordinates in an
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
*This program generates the ubercode for each cell's four neighbors;
args ubercodevar C R;
gen `ubercodevar'_north=cond(`ubercodevar'>`C', `ubercodevar'-`C' , . );
gen `ubercodevar'_south=cond(`ubercodevar'<=`C'*`R'-`C', `ubercodevar'+`C' , . );
gen `ubercodevar'_east=cond(mod(`ubercodevar',`C')==0, `ubercodevar'-`C'+1 , `ubercodevar'+ 1 );
gen `ubercodevar'_west=cond(mod(`ubercodevar',`C')==1, `ubercodevar'+`C'-1 , `ubercodevar'- 1 );
end; 

program define isborder;
/*;
This program takes:
	bordervar: categorical variable with region ids, the borders pixels of which we want to
	identify;
	ubercodevar: integer variable with pixel identifier. Assumed to be numbered from 0 on,
	from left to right and top to bottom as in ubergrid files;
	C: number of columns in ubergrid
	R: number of rows in ubergrid
	
Returns:
	Four dummy isborder_X variables, which identify pixels that border a region in cardinal
	direction X=N,S,E,W.
	Four categorical neighbor_X variables, which hold the id of the pixel's neighbor in cardinal
	direction X=N,S,E,W.
*/;

args bordervar ubercodevar C R ignorevals;

sort `ubercodevar';

neighborvar `ubercodevar' `C' `R';

/*;
isborder_X is equal to 1 if the pixel is at the border between two nonmissing regions,
in direction X, and 0 otherwise;
*/;
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

log using flux.log, replace;

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
use "..\\..\\..\\data\\dtas\\analyze_me_flux_std_units.dta", clear;

*Check we're using correct ubergrid settings;
*assert _N==`R'*`C';

preserve;

collapse (count) uber_code Terra`year'_count=Terra`year' (firstnm) gpw_v4_national_identifier_gri
(mean) Terra`year'_mean=Terra`year' (sum) area, by(countryXregion_const country urban_wb2010);

*Generate copy of id variable, for future merge;
gen neighbor_=countryXregion_const;

rename gpw_v4_national_identifier_gri neighbor_ctry_;
rename country neighbor_country_name_;
rename urban_wb2010 neighbor_rgn_;

*Order identical id vars first;
order countryXregion_const neighbor_;

save "..\\..\\..\\data\\dtas\\country\\country_codes_names`year'.dta", replace;

restore;

sort uber_code;
isborder countryXregion_const uber_code `C' `R' .;
keep if isborder_N | isborder_S | isborder_E | isborder_W;

*Generate length of pixel as sqrt(area);
gen length=sqrt(area);

*transfer_X are the flow from each cell to each of its neighbors;
*Notice only one of Nt & St are nonzero - same for Et & Wt;
gen transfer_N=max(vwnd_`year',0)*Terra`year';
gen transfer_S=max(-vwnd_`year',0)*Terra`year';
gen transfer_E=max(uwnd_`year',0)*Terra`year';
gen transfer_W=max(-uwnd_`year',0)*Terra`year';


*windborder_X are wind border lengths: they measure the borders over which transfers happen;
*If AOD is transferred north from a given pixel, Nwb equals the pixel length - zero otherwise;
gen windborder_N=cond(vwnd_`year'>=0,1,0,.)*length;
gen windborder_S=cond(vwnd_`year'<0,1,0,.)*length;
gen windborder_E=cond(uwnd_`year'>=0,1,0,.)*length;
gen windborder_W=cond(uwnd_`year'<0,1,0,.)*length;

keep uber_code isborder_* country gpw_v4_national_identifier_gri countryXregion_const
neighbor_* transfer_* windborder_*
length area
Terra`year';

reshape long isborder_ neighbor_ transfer_ windborder_, i(uber_code) j(dir) string;

collapse (count) isborder_ (sum) windborder_ length transfer_ if isborder_, by( countryXregion_const neighbor_);

label variable isborder_ 	"Number of border pixels used in computations";
label variable length 		"Approximate length of border (km)";
label variable transfer_ 	"Flux from countryXregion to interior or world (depends on interior_border), in AOD units per yr";
label variable windborder_ 	"Length of border over which sender AOD flows into receiver";

merge m:1 countryXregion_const using "..\\..\\..\\data\\dtas\\country\\country_codes_names`year'.dta", nogen;
rename Terra`year'_mean sender_Terra`year'_mean;
rename Terra`year'_count sender_Terra`year'_count;

rename neighbor_country_name_ sender_country_name;
rename neighbor_ctry_ sender_country;
rename neighbor_rgn_ sender_region;
rename countryXregion_const sending_countryXregion_const;

*Check Terra variables: count and average. Rename them to keep track of them after
*later merge;

merge m:1 neighbor_ using "..\\..\\..\\data\\dtas\country\\country_codes_names`year'.dta", nogen;
drop countryXregion_const;

rename Terra`year'_mean receiver_Terra`year'_mean;
rename Terra`year'_count receiver_Terra`year'_count;

*Now have all pairs of sender and receiver regions, with their countries and urban status;
label variable sending_countryXregion_const "Sender Region";
label variable neighbor_ 					"Receiver Region";

*Now must define sending & receiving, netting both interior transfers;
gen interior_border=(sender_country_name==neighbor_country_name);

label var sender_Terra`year'_mean "Average AOD in sender region, AOD units";
label var receiver_Terra`year'_mean "Average AOD in receiver region, AOD units";
label data "AOD transfer between sender and receiver country-regions, year `year'";

save "..\\..\\..\\data\\dtas\\country_regions\\flux\\flux`year'.dta", replace;

};
log close;
