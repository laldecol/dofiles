***This .do file takes an ubergrid country file and creates ubergrid border dtas
*Output dtas can be converted to ubergrid rasters using raster2dta
*Output rasters are dummy rasters for: international border NSEW & land-ocean borders,
#delimit;

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
gen row=mod(v1,`C');
gen col=(v1-row)/`C';

capture assert max(row)
