*This .do file identifies ubergrid pixels that fall within a circle of radius r 
*and center (x0, y0), expressed in latitude terms. 

* set up;
#delimit;
set more off;
pause off;
clear;

use "..\\..\\..\\data\\projections\\generated\\settings.dta";

*read settings from settings.dta, save values in locals.;
foreach var of varlist _all{;
*in once;
local `var'=`var'[1];
};

*;
use "..\\..\\..\\data\\dtas\\analyze_me.dta";
keep uber_code;

*generate row and column numbers in the plate carree representation of the grid;
gen rowno=floor((uber_code-1)/`COLUMNCOUNT')+1;
gen colno=uber_code-`COLUMNCOUNT'*(rowno-1);

*generate coordinates of top left corner of each cell;
gen lon=`LEFT'+`CELLSIZEX'*(colno-1);
gen lat=`TOP'-`CELLSIZEY'*(rowno-1);

*define parameters for angular radius calculation;
local earthradius=6371;
local circleradius=100;
local lambda=360*`circleradius'/(2*c(pi)*`earthradius');

*semiminor axis is lambda;
*semimajor axis is sec(latitude)*lambda;

gen ellipses=((lon^2)*cos(lat*c(pi)/180)^2/`lambda'^2+(lat)^2/`lambda'^2<=1);
replace ellipses==1 if lon==0 & lat ==0;

forvalues latitudes = 5(10)75 {;
replace ellipses = 1 if (lon^2)*cos(lat*c(pi)/180)^2/`lambda'^2+(lat-`latitudes')^2/`lambda'^2<=1;
replace ellipses = 1 if lon==0 & lat=`latitudes'
}; 

save "..\\..\\..\\data\\dtas\\latitudecircles\\latitudecircles.dta", replace; 

