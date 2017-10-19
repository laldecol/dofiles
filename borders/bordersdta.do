***This .do file computes 
*Output dtas can be converted to ubergrid rasters using raster2dta
#delimit;
program drop _all;
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

*For each uber_code, generate four variables: uber_code of northern, southern, western, and eastern neighbor.;
*Calculations:;
use "..\\..\\..\\data\projections\generated\settings.dta", clear;

*Define C,R as column and row totals in current ubergrid.;

local C=COLUMNCOUNT[1];
local R=ROWCOUNT[1];
dis "Number of Columns: " `C';
dis "Number of Rows: " `R';


*Use urbanization dummies to generate a region variable for each year;
foreach year in 2000 2005 2010 2015{;
use "..\\..\\..\\data\\dtas\\analyze_me_land.dta", clear;

*Check we're using correct ubergrid settings;
assert _N==`R'*`C';

*Create country label for nonland;
replace gpw_v4_national_identifier_gri=-9999 if gpw_v4_national_identifier_gri==.;
replace country="Sea, Inland Water, other Uninhabitable" if gpw_v4_national_identifier_gri==-9999;

egen countryXregion`year'=group(country urban_wb`year'), label;
preserve;

collapse (count) uber_code (firstnm) country gpw_v4_national_identifier_gri urban_wb`year', by(countryXregion`year');

*Generate copy of id variable, for future merge;
gen neighbor_=countryXregion`year';

rename gpw_v4_national_identifier_gri neighbor_ctry_;
rename country neighbor_country_name_;
rename urban_wb`year' neighbor_rgn_;

*Order identical id vars first;
order countryXregion`year' neighbor_;

save "S:\particulates\data_processing\data\dtas\country_codes_names`year'.dta", replace;

restore;

*Generate region variables, per year;

*Should generate sea/water "country";
*Two ways to do it: use missing values in gpw_national_identifier_grid or in borders;

/*;
local ubercodetest=uber_code[_N];
neighborsca `ubercodetest' `C' `R';
return list;
*/;
sort uber_code;
isborder countryXregion`year' uber_code `C' `R' .;

*Preserve, then generate macros with neighbor codes for each region;
/*;
preserve;

keep uber_code* gpw_v4_national_identifier_gri isborder_* neighbor_*;

reshape long isborder_ neighbor_, i(uber_code) j(cardir) string;

collapse (count) uber_code, by ( gpw_v4_national_identifier_gri neighbor_);
#delimit;
levelsof gpw_v4_national_identifier_gri, local(countrycodes);

foreach countrycode of local countrycodes{;

levelsof neighbor_ if gpw_v4_national_identifier_gri==`countrycode', local(neighbors`countrycode');
*Next two lines remove own country code from list. Can be generalized to remove
*other codes too (e.g. international borders if looking at urban to rural);
local own `countrycode';
local neighbors`countrycode': list neighbors`countrycode' - own;
foreach neighbor of local neighbors`countrycode'{;
dis `neighbor';

};
};

*Restore analyze_me.dta with neighbor macros in place;
*N's neighbors are stored in macro neighborsN;

restore;
*/;
*forvalues year=2000(5)2015{;

gen Nt`year'=max(vwnd_`year',0)*Terra`year';
gen St`year'=max(-vwnd_`year',0)*Terra`year';
gen Et`year'=max(uwnd_`year',0)*Terra`year';
gen Wt`year'=max(-uwnd_`year',0)*Terra`year';

keep uber_code isborder_* country gpw_v4_national_identifier_gri countryXregion`year'
neighbor_* Nt* St* Et* Wt* area Terra*;

keep if isborder_N | isborder_S | isborder_E | isborder_W;

*This reshape might be unnecesary now, since regions change with time;
*reshape long Nt St Et Wt Terra, i(uber_code) j(year);

rename (Nt`year' St`year' Et`year' Wt`year') (transfer_N transfer_S transfer_E transfer_W);
reshape long isborder_ neighbor_ transfer_, i(uber_code) j(dir) string;

*Generate length of pixel as sqrt(area);
gen length=sqrt(area);

*merge m:1 neighbor_ using "S:\particulates\data_processing\data\dtas\country_codes_names`year'.dta";
*gen interior_border=(country==neighbor_country_name);

*Here, after reshaped but before collapse, I merge in the country and region variables to neighbor_;
*Then use those to define the receiving countryxregion as world or interior, i.e. interior=(emitting country == receiving country)
*This way I can collapse by country x region of origin and the world/interior variables, to get fluxes over the right regions.;

collapse (count) isborder_ (sum) length transfer_ if isborder_, by( countryXregion`year' neighbor_);

label variable isborder_ "Number of border pixels used in computations";
label variable length "Approximate length of border (km)";
label variable transfer_ "Flux from countryXregion to interior or world (depends on interior_border)";

merge m:1 countryXregion`year' using "S:\particulates\data_processing\data\dtas\country_codes_names`year'.dta";
rename neighbor_country_name_ sender_country_name;
rename neighbor_ctry_ sender_country;
rename neighbor_rgn_ sender_region;

pause;

label variable countryXregion`year' "Sender Region";
label variable neighbor_ "Receiver Region";

*Now must define sending & receiving, netting both interior transfers;

save "S:\\particulates\\data_processing\\data\\boundaries\\manual\\flux`year'.dta", replace;
pause;
};
