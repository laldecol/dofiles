***This .do file takes an ubergrid country file and creates ubergrid border dtas
*Output dtas can be converted to ubergrid rasters using raster2dta
*Output rasters are dummy rasters for: international border NSEW & land-ocean borders,
#delimit;
program drop _all;

program define ubercode2rc;
args ubercode C stub;
gen col`stub'=mod(`ubercode',`C');
replace col`stub'=`C' if col`stub'==0;
gen row`stub'=(`ubercode'-col`stub')/`C'+1;
end;

program define rc2ubercode;
args row col C ubercodename;
gen ubercodename=.;
replace `ubercodename'=(`row'-1)*`C'+`col' if `row'!=. & `col'!=.;
end;

*For each uber_code, generate four variables: uber_code of northern, southern, western, and eastern neighbor.;
*Calculations:;
use "..\\..\\..\\data\projections\generated\settings.dta", clear;

*Define C,R as column and row totals in current ubergrid.;

local C=COLUMNCOUNT[1];
local R=ROWCOUNT[1];

use "..\\..\\..\\data\GPW4\generated\gpw-v4-national-identifier-grid\ubergrid\dtas\gpw_v4_national_identifier_gri.dta", clear;

*Check we're using correct ubergrid settings;
assert _N==`R'*`C';

*Eastern and western neighbor are easy for uber_code MOD C !=;
ubercode2rc v1 `C' test;
gen Nx=col;
gen Ny=.;
replace Ny=row-1 if row>1;

rc2ubercode Nx Ny `C' index;
*write a program that returns the ubercode given row and col, and vice versa;
