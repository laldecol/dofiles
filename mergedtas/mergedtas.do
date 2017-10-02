*This do file:
*1. Merges all ubergrid dtas in the input folders
*2. Saves the resulting dta to data\dtas
*3. Generates some basic variables, such as latitude, longitude, and area

*Inputs should be directory locations starting from /data

*Start up
#delimit;
clear all;
cls;
set more off;
pause off;
set type double;

**Store Current Directory/;
local dofiledir : pwd;
dis "`dofiledir'";

** Change Directory/;
cd "..\\..\\..\\data";

***************;
*Define locals*;
***************;

**Path to data/;
local datadir : pwd;
dis "`datadir'";

**lists with directories and dtas to merge;
local argnum = `1'+1;
local dirlist;
local dtalist;

forvalues i=2/`argnum'{;
local dirlist `dirlist' ``i'';
};

**Settings: number of columns and rows, cellsizes, extent;
use "projections\\generated\\settings.dta";

*read settings from settings.dta, save values in locals.;
foreach var of varlist _all{;
local `var'=`var'[1];
};

*Radius of the earth in km;
local earthradius=6371;

*Compute number of observations to merge;
local obsno = `COLUMNCOUNT'*`ROWCOUNT';

clear;

****************;
**Merge .dtas **;
****************;

*Generate empty database and ubercode variable;
set obs  `obsno';
gen long v1=_n;

*Look in each directory in the input list, get a list with all .dtas in it, and
*merge each into database;
foreach dir of local dirlist{;
cd "`datadir'";
dis "`dir'";
local dtalist: dir "`datadir'/`dir'" files "*.dta", respectcase;
cd "`dir'";

foreach element of local dtalist{;
dis "`element'";
merge 1:1 v1 using "`element'", nogen;
};

};

cd "`datadir'";

rename v1 uber_code;

*Replace mising values as .;
foreach var of varlist gpw*{;
dis `var';
replace `var'=. if `var'==-9999;
};

merge m:1 gpw_v4_national_identifier_gri using "GPW4\source\gpw-v4-national-identifier-grid\idnames.dta";
drop if _merge==2;
drop _merge;

ds, has(type numeric);
foreach var of varlist `r(varlist)' {;
  replace `var' = .  if `var'==-9999;
};

****************************;
**Generate basic variables**;
****************************;

*Generate exposure for available years;
forvalues year=2000(5)2010{;
gen exposure`year' = Terra`year'avg * projected_aggregated_gpw_`year';
};

**generate latitude and longitude of cell's top left corner;

*first generate row and column numbers in the plate carree representation of the grid;
gen rowno=floor((uber_code-1)/`COLUMNCOUNT')+1;
gen colno=uber_code-`COLUMNCOUNT'*(rowno-1);

*use the above and cell size to generate coordinates of top left corner of each cell, in degrees;
gen lon=`LEFT'+`CELLSIZEX'*(colno-1);
gen lat=`TOP'-`CELLSIZEY'*(rowno-1);

*approximate area of each cell as that of a trapezoid (latitude in degrees);
*northern base length=b=(cellsizex/360)2pi*radius*cos(latitude);
*southern base length=B=(cellsizex/360)2pi*radius*cos(latitude-cellsizey);
*height=h=(cellsizey/360)2pi*radius;
*area ~= (b+B)*h/2;

gen area=(cos(lat*c(pi)/180)+cos((lat+`CELLSIZEY')*c(pi)/180))*2*(c(pi)*`CELLSIZEX'*`earthradius'/360)^2;

save "dtas\analyze_me.dta", replace;

** Back to original folder/;
cd "`dofiledir'";
