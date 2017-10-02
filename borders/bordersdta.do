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

use "..\\..\\..\\data\\dtas\\analyze_me.dta", clear;

*Check we're using correct ubergrid settings;
assert _N==`R'*`C';

sort uber_code;

local ubercodetest=uber_code[_N];
neighborsca `ubercodetest' `C' `R';
return list;

isborder gpw_v4_national_identifier_gri uber_code `C' `R' -9999;

*Preserve, then generate macros with neighbor codes for each region;
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
#delimit;
forvalues year=2000/2015{;

gen Nt`year'=max(vwnd_`year',0)*Terra`year'avg;
gen St`year'=max(-vwnd_`year',0)*Terra`year'avg;
gen Et`year'=max(uwnd_`year',0)*Terra`year'avg;
gen Wt`year'=max(-uwnd_`year',0)*Terra`year'avg;

};

restore;

save "S:\\particulates\\data_processing\\data\\boundaries\\manual\\borders.dta", replace;