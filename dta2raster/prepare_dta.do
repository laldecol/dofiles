/**********************************************
dta2table.do
*********
/ * This program is used by dta2raster to prepare a dta file to be processed and 
transfored in a raster */
/* Created by Marcel, 6/22/2017 */


* set up;
#delimit;
set more off;
pause off;
clear;

local arg1 `1';
local arg2 `2';

display `"The dta file `arg2' will be processed."';
display `"Prepared dta files will be saved `arg1'/temporary_dtas"';

use "`arg2'";


* Change name to uber_code;
capture confirm variable v1;
if !_rc 
	{;
    rename v1 uber_code;  
	};

* Sort by uber_code;	
sort uber_code;

*Drop it, it is useless;
drop uber_code;

* Create folder to store temporary dtas;
cd "`arg1'\temporary_dtas";

foreach var of varlist *
	{;
	preserve;
	keep `var';
	save "`var'_ubergrid", replace;
	restore;
	};
	
	
	
exit, STATA clear;
	
	
	

