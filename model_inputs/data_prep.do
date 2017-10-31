***This .do file prepares data for tables from 10k analyze_me.dta;

#delimit;
set more off; 
set matsize 4000;
pause on;
set emptycells drop;
capture log close;
clear;
/*;

*********************************************
*****Preliminaries: only need to be run once.
*********************************************;

*This section does some preliminary processing, and needs to be run only once
*for a given analyze_me.dta.;

*I. Generate and relabel some variables.;

1. Saves a land-only version of analyze_me.dta, under analyze_me_land.dta;
2. Generates a population weighted measure of GPW data quality, by country, and 
tags high quality countries in variable highqualGPW;
3. Renames population, land use, and climate variables to ease manipulation, including
relabeling 2104 vars as 2015 vars, and 2001 as 2000;
4. Generates exposure variables for 2000 - 2015;
5. Defines an urbanized dummy in terms of MODIS urban cover
*/;

*Locals defined here help write down samples for regressions; 
*samplepixels determines the sample to be used;
*Keep all pixels with data for mod5 years;
local samplepixels "Terra2000!=. & Terra2005!=. & Terra2010!=. & Terra2015!=. 
& gpwpop2000!=. & gpwpop2005!=. & gpwpop2010!=. & gpwpop2015!=.";

/*;
& Coal2000!=. & Coal2005!=. & Coal2010!=. & Coal2015!=.
& Oil2000!=. & Oil2005!=. & Oil2010!=. & Oil2015!=.
& Gas2000!=. & Gas2005!=. & Gas2010!=. & Gas2015!=.";
*/;

if 1==1{;
	*Keep country total population before dropping any pixels;
	use "S:\particulates\data_processing\data\dtas\analyze_me.dta", clear;
	foreach year in 2000 2005 2010 2015{;
	bysort gpw_v4_national_identifier_gri: egen countrypop`year'=total(projected_aggregated_gpw_`year');
	};
	
*1. Saves a land-only version of analyze_me.dta, under analyze_me_land.dta;
if 1==1{;
	keep if projected_aggregated_gpw_2000<. &
	projected_aggregated_gpw_2000!=0 &
	projected_aggregated_gpw_2005!=0 &
	projected_aggregated_gpw_2010!=0 &
	projected_aggregated_gpw_2015!=0 &
	Terra2000!=. & Terra2010!=. &
	Terra2005!=. & Terra2014!=.;
};

*2. Generates a population weighted measure of GPW data quality, by country, and 
*tags those countries in variable highqualGPW;
if 1==1{;
	sort country;
	egen CTprojected_aggregated_gpw=total(projected_aggregated_gpw_2000), by(country);
	gen pwquality=projected_aggregated_gpw_2000*gpw_v4_data_quality_indicators/CTprojected_aggregated_gpw;

	preserve;
	collapse (sum) pwquality (count) uber_code, by(country) fast;
	sort pwquality;

	gen gpw_qual_rank=_n;

	sum pwquality, detail;
	gen highqualGPW=(pwquality<=`r(p50)');
	
	save "S:\\particulates\\data_processing\\analysis\\AODvariation10k\\temp_data\\country_data_quality.dta", replace;

	restore;

	merge m:1 country using "S:\\particulates\\data_processing\\analysis\\AODvariation10k\\temp_data\\country_data_quality.dta", nogen;
	merge m:1 gpw_v4_national_identifier_gri using "S:\particulates\calibration_v1\data\country_regions\country_lvl2005_calib1.dta", keepusing(calibration_sample_05) nogen;
	
};

*3. Rename and drop variables for convenience;
if 1==1{;
	*Rename variables to fit stata's constraints;
	rename (projected_aggregated_gpw_2000 projected_aggregated_gpw_2005 
	projected_aggregated_gpw_2010 projected_aggregated_gpw_2015)
	(gpwpop2000 gpwpop2005 gpwpop2010 gpwpop2015);

	*Use AOD & climate from 2014 with population from 2015;
	rename Terra2014avg Terra2015avg;

	rename (rgdpe2014 rgdpo2014) (rgdpe2015 rgdpo2015); 

	rename (cld2014 wet2014 tmp2014 frs2014 vap2014) (cld2015 wet2015 tmp2015 frs2015 vap2015);

	*Drop unused climate variables;
	drop dtr* pet* tmn* tmx*;

	*Rename and rescale AOD variables;
foreach Terravar of varlist Terra*{;
	local newname=substr("`Terravar'", 1,9);
	dis `newname';
	gen `newname'=`Terravar'/1000 ;
	drop `Terravar';
};

*Relabel 2001 data as 2000;
foreach LUvar of varlist LU*{;
	
	dis "`LUvar'";
	local year=substr("`LUvar'",3,4);
	dis `year';
	
	if "`year'"=="2001"{;
		local year="2000";
	};

	*Rename land use variables;
	local cat=substr("`LUvar'",-1,1);
	dis `cat';
	local newname="LU" + "`cat'" + "dummy"+ "`year'";
	rename `LUvar' `newname';
};

foreach year in 2000 2002 2003 2004 2005 2006 2007 2008 2009 2010 2011 2012{;
	rename LU0dummy`year' water`year';
	rename LU1dummy`year' trees`year';
	rename LU2dummy`year' pasture`year';
	rename LU3dummy`year' barren`year';
	rename LU4dummy`year' crops`year';
	rename LU5dummy`year' urban`year';
	rename LU6dummy`year' other`year';
};

rename (water2012 trees2012 pasture2012 barren2012 crops2012 urban2012 other2012)
(water2015 trees2015 pasture2015 barren2015 crops2015 urban2015 other2015);
};
*4. Generate exposure and per capita variables for 2000-2015;
if 1==1{;
foreach year in 2000 2005 2010 2015{;
capture drop exposure`year';
gen exposure`year'=Terra`year'*gpwpop`year';
};

foreach year in 2000 2005 2010 2015{;
gen countryGDPpc`year'=rgdpe`year'/countrypop`year';
};

bysort gpw_v4_national_identifier_gri: egen countrypixels=count(uber_code);

compress;
};
*Generate urban dummies, using MODIS and GPW-WB data.;
/*;
*5.1 Generate urban dummy from MODIS;

local K=100;
matrix R2=J(`K',1,.);

forvalues k=1/`K'{;
local cutoff=400*`k'/`K';
capture drop urbandummy;
gen urbandummy2000=(urban2000>=`cutoff');
reg Terra2000avg urbandummy2000 if urban2000>0;
matrix R2[`k',1]=`e(r2)';
};

svmat R2,names(rsq);
gen urbanpixels=_n*400/`K';
twoway line rsq urbanpixels if !missing(rsq);
drop urbandummy2000;

sum rsq;
local maxrsq=`r(max)';
dis `maxrsq';
sort rsq;

*local urbancutoff=urbanpixels[`K'];
local urbancutoff=20;

foreach year in 2000 2002 2003 2004 2005 2006 2007 2008 2009 2010 2011 2015{;
gen urbandummy`reg Terra2000avg urban_wb2000 if urban2000>0;
year'=(urban`year'>=`urbancutoff');
};
*/;

save "S:\\particulates\\data_processing\\data\\dtas\\analyze_me_land.dta", replace;

*5.2 Generate urban dummy from GPW-WB;
use "S:\particulates\data_processing\data\dtas\analyze_me.dta";
levelsof country, local(countries);
*First, must generate the cutoff (either in proportions or total population);
foreach year in 2000 2005 2010 2015{;

dis "`country'" `year';

gsort country -projected_aggregated_gpw_`year';
by country: egen totalpop`year'=total(projected_aggregated_gpw_`year');
by country: gen runsum`year'=sum(projected_aggregated_gpw_`year'); 

gen urban_wb`year'=(runsum`year'*100/totalpop`year'<=urbanshare`year' & country!="");

*Find what's making missing countries be 1's;
};
keep uber_code urban_wb*;
recode urban_wb* (.=-9999);

save "S:\\particulates\\data_processing\\data\\World_Bank\\generated\\urban_pixels.dta", replace;

use "S:\\particulates\\data_processing\\data\\dtas\\analyze_me_land.dta", clear;

merge 1:1 uber_code using "S:\\particulates\\data_processing\\data\\World_Bank\\generated\\urban_pixels.dta", nogen;

save "S:\\particulates\\data_processing\\data\\dtas\\analyze_me_land.dta", replace;

***Diagnostic;
reg Terra2000 urban_wb2000 if urban2000>0;
reg Terra2000 urban_wb2000;

use "S:\\particulates\\data_processing\\data\\projections\\generated\\settings.dta", clear;

*Define C,R as column and row totals in current ubergrid.;

local C=COLUMNCOUNT[1];
local R=ROWCOUNT[1];
dis "Number of Columns: " `C';
dis "Number of Rows: " `R';

dis `maxrsq';
dis "cutoff " `urbancutoff';

use "S:\\particulates\\data_processing\\data\\dtas\\analyze_me_land.dta", clear;

gen modelsample=.;
replace modelsample=1 if `samplepixels';
keep uber_code urban_wb2000 highqualGPW modelsample;

save "S:\\particulates\\data_processing\\data\\dta2raster\\temp\\merge_me.dta", replace;
clear;

local Nobs=`C'*`R';

set obs `Nobs';
gen uber_code=_n;
merge 1:1 uber_code using "S:\\particulates\\data_processing\\data\\dta2raster\\temp\\merge_me.dta", nogen;
recode highqualGPW urban_wb2000 modelsample (.=-9999);
save "S:\\particulates\\data_processing\\data\\dta2raster\\dtas\\urban_dummy_maps.dta", replace;

**End diagnostic;

use "S:\\particulates\\data_processing\\data\\dtas\\analyze_me_land.dta", clear;

keep uber_code gpwpop2000 gpwpop2010 country urbanshare2000 urbanshare2010
gpw_qual_rank urban_wb2000 urban_wb2010;

reshape long gpwpop urbanshare urban_wb, i(uber_code country gpw_qual_rank) j(year);

*Compute urbanization rates under our variable and merge them in to compare to WB;
preserve;

restore;
collapse (firstnm) gpw_qual_rank urbanshare (sum) gpwpop (count) uber_code, by(country year urban_wb);
bysort country year: egen ctrypop=total(gpwpop);
gen region_share=gpwpop*100/ctrypop;
save "S:\\particulates\\data_processing\\analysis\\AODvariation10k\\by_country\\urban_dummy_GPW_descriptives.dta", replace;


};

*II. Choose samples and save separate .dtas for each;

**Reshape to create two .dtas: one for all years and one for mod5years, for the 
*sample specified in the local var sample;


*Keep defined sample and save two reshaped files:;
*all_pooled contains all years, and mod5 contains only mod5 years;
if 1==1{;
use "S:\particulates\data_processing\data\dtas\analyze_me_land.dta", clear;

keep if `samplepixels';

compress;

save "S:\particulates\data_processing\data\dtas\pixel_sample.dta", replace;

*All countries pooled;
reshape long Terra Fire Data gpwpop water trees pasture barren crops urban other urban_wb 
cld wet vap tmp frs Oil Coal Gas urbanshare 
rgdpe rgdpo countrypop countryGDPpc vwnd_ uwnd_,
 i(uber_code country area) j(year);
 
*generate interval variables;
gen fiveyearint=.;
replace fiveyearint=1 if year>=2000 & year<=2005;
replace fiveyearint=2 if year>2005 & year<=2010;
replace fiveyearint=3 if year>2010 & year<=2015;

compress;
save "S:\particulates\data_processing\data\dtas\analyze_me_land_allpooled.dta", replace;

***Keep modulo 5 years;
keep if year==2000 | year==2005 | year==2010 | year==2015;

*gen landshare to adjust density;
gen landshare=(400-water)/400;
gen density=gpwpop/(area*landshare);

save "S:\particulates\data_processing\data\dtas\analyze_me_land_mod5.dta", replace;
};

log using reglog, text replace;


