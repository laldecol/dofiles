***This .do file computes 
*Output dtas can be converted to ubergrid rasters using raster2dta
*Output rasters are dummy rasters for: international border NSEW & land-ocean borders,
#delimit;
program drop _all;

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

program define north;
args ubercode C;
return north=cond(`ubercode'>`C', `ubercode'-C , . );
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

local ubercodetest=v1[_N];
north `ubercodetest' `C';
local Ntest=r(north);

dis `Ntest';

pause;

*Eastern and western neighbor are easy for uber_code MOD C !=;
ubercode2rc v1 `C' test;
gen Nx=col;
gen Ny=.;
replace Ny=row-1 if row>1;

*Test whether rc2ubergrid and ubergrid2rc are inverses

rc2ubercode rowtest coltest `C' ubercode_test;

rc2ubercode Nx Ny `C' index;
*write a program that returns the ubercode given row and col, and vice versa;
