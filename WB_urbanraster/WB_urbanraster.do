/*****************************************************************************
WB_urbanraster.do

This .do file creates an urban dummy ubergrid .dta, using the WB urbanization
rate data and GPW ubergrid rasters.

*Last modified: Oct 2 2017 la
*****************************************************************************/

* set up;
#delimit;
clear all;
cls;
set more off;
pause off;

use "S:\particulates\data_processing\data\dtas\analyze_me.dta";
levelsof country, local(countries);
*First, must generate the cutoff (either in proportions or total population);
foreach year in 2000 2005 2010 2015{;

dis "`country'" `year';

sort country projected_aggregated_gpw_`year';
by country: egen totalpop`year'=total(projected_aggregated_gpw_`year');
by country: gen runsum`year'=sum(projected_aggregated_gpw_`year'); 

gen urban_wb`year'=(runsum`year'*100/totalpop`year'>urbanshare`year');

};
