/**********************************************
dta2table.do
*********
make maps for particulates draft.

la September 19, 2016, based on: 
UFD_maps2.do
mt  October 2015
	updated July 27th, 2014 
	
****This file must be called with arguments. 
*First argument is the name of the dta from which
values for map will be read from. Should be in folder data\\dta2raster\\
*Second argument is number of variables that user wants
to map.
*The third set of arguments is the list of variables
that we want to export into .txt to map.


use 
do dta2table.do "..\\dtas\\analyze_me.dta" 4 Aqua2004avg Terra2004avg gpw2000 world_countries_2011
to run;
**********************************************/

* set up;
#delimit;
set more off;
pause off;
clear;

*location for python;
local python "C:\Python27\ArcGIS10.2\python";
*Location of data directory;
local datadir "..\\..\\data\\dta2raster";
local dodir : pwd;

*for debugging is "..\..\data\dtas\analyze_me.dta";
local dta "`1'";
capture log close;
quietly log using dta2table ,text replace;

local argnum = `2'+2;
local varlist;

forvalues i=3/`argnum'{;
local varlist `varlist' ``i'';
};

dis "`varlist'";
dis "`dta'";

/**********************************************************************
 (1) Setup directory tree for generated files, ubergrid copies, and STATA
	 temporary files. Copy Ubergrid files, one for each variable.
**********************************************************************/;
*at this point of the program the current directory is dofiles\\dta2raster;

*dta local is "..\dtas\analyze_me.dta";
*datadir is "data\dta2raster" ;

cd `datadir';
shell rmdir "temp" /q /s;
shell rmdir "maps" /q /s;
shell rmdir "workspaces" /q /s;
mkdir "temp";
mkdir "maps";
mkdir "workspaces";

foreach var of local varlist
	{;
	shell rmdir "workspaces/`var'" /q /s;
	mkdir "workspaces/`var'";
*	copy  "${ddir}/ubergrid/source/ubergrid2011.img"
*	  "temp/ubergrid4`var'.img", replace;
	};

*get stata ubergrid data;
use `dta';
keep uber_code `varlist';

ds, has(type numeric);
foreach var of varlist `r(varlist)' {;
  replace `var' =-9999  if `var'==.;
};


sort uber_code;
compress;
save temp,replace;

foreach var of local varlist
	{;
	use temp,clear;
	sort uber_code;
	keep `var';
	compress;
	save "temp/`var'.dta", replace;
	dis "temp/`var'.dta" "temp/ready2map_`var'.txt";
	pause;
	shell st "temp/`var'.dta" "temp/ready2map_`var'.txt" /y;
	erase temp/`var'.dta;
	};
erase temp.dta;

*convert STATA lists to Raster files
*****************************************************************/;
cd `dodir';
pause;
display "`python' table2raster.py `varlist'";
shell `python' table2raster.py `varlist';
log close;
