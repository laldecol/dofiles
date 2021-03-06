
#delimit;
set more off; 
set matsize 4000;
pause on;
set emptycells drop;
capture log close;
clear;
set trace off;
set tracedepth 1;
/*;

This .do file processes analyze_me.dta to write all the pixel or pixel-year 
level files used by macro_inputs.do, box_inputs.do, reg_inputs.do, and 
prepare_mapping.do.


*********************************************
*****Preliminaries: only need to be run once.
*********************************************;

This .do does some preliminary processing, and needs to be run only once
for a given analyze_me.dta.;

I. Generate and relabel variables, and define sample;

0. 	Generate country-level total population before dropping pixels;

1. 	Drop pixels missing population, country, or AOD data, and save result as analyze_me_land.dta;

2. 	Generate population weighted GPW data quality, by country. 
	Tag high quality countries and calibration sample;

3. 	Rename population, land use, and climate variables. 
	Relabel 2104 vars as 2015, and 2001 as 2000;

4. Generate exposure, GDP per capita, and country pixel count variables;

5. 	Generate urban dummy, using WB urbanization rate and GPW population;


*/;

*Locals defined here help write down samples for regressions; 
*samplepixels determines the sample to be used;
*Keep all pixels with data for mod5 years;
local samplepixels "Terra2000!=. & Terra2005!=. & Terra2010!=. & Terra2015!=.
& gpwpop2000!=. & gpwpop2005!=. & gpwpop2010!=. & gpwpop2015!=.
& country!="" ";

/*;
& Coal2000!=. & Coal2005!=. & Coal2010!=. & Coal2015!=.
& Oil2000!=. & Oil2005!=. & Oil2010!=. & Oil2015!=.
& Gas2000!=. & Gas2005!=. & Gas2010!=. & Gas2015!=.";
*/;

log using pixel_data_prep.log, text replace;

*I. Generate and relabel variables, and define sample;
	use "..\\..\\..\\data\dtas\analyze_me.dta", clear;

	*0. Generate country-level total population before dropping any pixels;
	foreach year in 2000 2005 2010 2015{;
		bysort gpw_v4_national_identifier_gri: egen countrypop`year'=total(projected_aggregated_gpw_`year');
	};
	*0. END;
	
	*0.1 Interpolate linearly  to get population between years.;
	
	foreach year in 2000 2005 2010 2015{;
	
		if `year'!=2015{;
		
			local end_year=`year'+5;
			
			forvalues t=1/4{;
			
				local tyear=`year'+`t';
				gen countrypop`tyear'=countrypop`year'+`t'*(countrypop`end_year'-countrypop`year')/(5);
				
			};
		};
	};
	
	*1. Drop pixels missing population, country, or AOD data, and save result as analyze_me_land.dta;
	*How is this different from sample in samplepixels;
		keep if projected_aggregated_gpw_2000<. &
		projected_aggregated_gpw_2005<. &
		projected_aggregated_gpw_2010<. &
		projected_aggregated_gpw_2015<. &
		projected_aggregated_gpw_2000!=0 &
		projected_aggregated_gpw_2005!=0 &
		projected_aggregated_gpw_2010!=0 &
		projected_aggregated_gpw_2015!=0 &
		Terra2000!=. & Terra2010!=. &
		Terra2005!=. & Terra2015!=.;
	*1. END;

	*2. Generate population weighted GPW data quality, by country. 
	*Tag high quality countries and calibration sample;
		sort country;
		egen CTprojected_aggregated_gpw=total(projected_aggregated_gpw_2000), by(country);
		gen pwquality=projected_aggregated_gpw_2000*gpw_v4_data_quality_indicators/CTprojected_aggregated_gpw;

		preserve;
		collapse (sum) pwquality (count) uber_code, by(country gpw_v4_national_identifier_gri) fast;
		sort pwquality;

		gen gpw_qual_rank=_n;

		sum pwquality, detail;
		gen highqualGPW=(pwquality<=`r(p50)');
		
		save "..\\..\\..\\data\\dtas\\country\\gpw_quality\\country_data_quality.dta", replace;
		
		restore;

		merge m:1 country using "..\\..\\..\\data\\dtas\\country\\gpw_quality\\country_data_quality.dta", nogen;
		merge m:1 gpw_v4_national_identifier_gri using "..\\..\\..\\data\\dtas\\country_regions\\calibration_sample\\country_lvl2005_calib1.dta", keepusing(calibration_sample_05) nogen;	
	*2. END;

	*3.	Rename population, land use, and climate variables. 
	*Relabel 2104 vars as 2015, and 2001 as 2000;

		*Rename variables to fit stata's constraints;
		rename (projected_aggregated_gpw_2000 projected_aggregated_gpw_2005 
		projected_aggregated_gpw_2010 projected_aggregated_gpw_2015)
		(gpwpop2000 gpwpop2005 gpwpop2010 gpwpop2015);

		*Use climate & GDP from 2014 with population from 2015;
		
		rename (rgdpe2014 rgdpo2014) (rgdpe2015 rgdpo2015); 

		rename (cld2014 wet2014 tmp2014 frs2014 vap2014) (cld2015 wet2015 tmp2015 frs2015 vap2015);

		*Drop unused climate variables;
		drop dtr* pet* tmn* tmx*;


		*Relabel 2001 data as 2000;
		foreach LUvar of varlist LU*{;
			
			dis "`LUvar'";
			local year=substr("`LUvar'",3,4);
			dis `year';
			
			if "`year'"=="2001"{;
				local year="2000";
			};
			*END if;

			*Prepare land use varnames;
			local cat=substr("`LUvar'",-1,1);
			dis `cat';
			local newname="LU" + "`cat'" + "dummy"+ "`year'";
			rename `LUvar' `newname';

		};	
		*END foreach LUvar;
		
		*Rename land use variables;
		
		foreach year in 2000 2002 2003 2004 2005 2006 2007 2008 2009 2010 2011 2012{;
			rename LU0dummy`year' water`year';
			rename LU1dummy`year' trees`year';
			rename LU2dummy`year' pasture`year';
			rename LU3dummy`year' barren`year';
			rename LU4dummy`year' crops`year';
			rename LU5dummy`year' urban`year';
			rename LU6dummy`year' other`year';
			
			if `year'>2002{;
			local lag=`year'-1;
			};
			
			if `year'==2002{;
			local lag=2000;
			};
			
			
			
		};
		*END foreach year;

		rename (water2012 trees2012 pasture2012 barren2012 crops2012 urban2012 other2012 )
		(water2015 trees2015 pasture2015 barren2015 crops2015 urban2015 other2015 );
		
		
	*END 3.;
	
	*4. Generate exposure, GDP per capita, country pixel counts;
		foreach year in 2000 2005 2010 2015{;
			capture drop exposure`year';
			gen exposure`year'=Terra`year'*gpwpop`year';
		};
		*END foreach; 
	
		foreach year in 2000 2005 2010 2015{;
			gen countryGDPpc`year'=rgdpe`year'/countrypop`year';
		};
		*END foreach;

		bysort gpw_v4_national_identifier_gri: egen countrypixels=count(uber_code);


	*END 4.;

	*5. Generate urban dummies, using GPW-WB data, and WB city disks;
	
		levelsof country, local(countries);

		* 5.1 Interpolate pixel population for intermediate years;
		foreach year in 2000 2005 2010 2015{;
		
			if `year'!=2015{;
			
				local end_year=`year'+5;
				
				forvalues t=1/4{;
				
					local tyear=`year'+`t';
					gen gpwpop`tyear'=gpwpop`year'+`t'*(gpwpop`end_year'-gpwpop`year')/(5);
					
				};
			};
		};
		
		*5.2 Generate urban dummy from GPW-WB;
		*foreach year in 2000 2001 2002 2003 2004 2005 2006 2007 2008 2009 2010 2011 2012 2013 2015{;
		foreach year in 2000 2001 2002 2003 2004 2005 2006 2007 2008 2009 2010 2011 2012 2013 2014 2015{;

			dis "`country'" `year';
			*First, must generate the cutoff (either in proportions or total population);
			gsort country -gpwpop`year';
			by country: egen totalpop`year'=total(gpwpop`year');
			by country: gen runsum`year'=sum(gpwpop`year'); 
			
			gen urban_wb`year'=(runsum`year'*100/totalpop`year'<=urbanshare`year' & country!="");

			
		};
			
		gen urban_wb_constant=urban_wb2010;
		replace country="Sea, Inland Water, other Uninhabitable" if gpw_v4_national_identifier_gri==-9999 | country=="";
		recode gpw_v4_national_identifier_gri (-9999=446);

		egen countryXregion_const=group(country urban_wb2010), label;
		
		*END foreach;
		compress;
		tempfile analyze_me_land;
		save `analyze_me_land', replace;

		use `analyze_me_land', clear;
		keep uber_code urban_wb* city*disk country countryXregion_const;
		recode urban_wb* (.=-9999);
		
		*5.3 Clean city disk variable and generate dummy;	
		
		foreach diskvar of varlist city*disk{;
			replace `diskvar'=. if `diskvar'==0;
			gen dummy_`diskvar'=1 if `diskvar'>0 & !missing(`diskvar');
			replace dummy_`diskvar'=0 if `diskvar'==.;
			
		};
		
		compress;

		save "..\\..\\..\\data\\World_Bank\\generated\\urban_pixels.dta", replace;
		use `analyze_me_land', clear;
		merge 1:1 uber_code using "..\\..\\..\\data\\World_Bank\\generated\\urban_pixels.dta", nogen keepusing(urban_wb*);

		
		*Create country label for nonland;
		replace gpw_v4_national_identifier_gri=-9999 if gpw_v4_national_identifier_gri==.;
		replace country="Sea, Inland Water, other Uninhabitable" if gpw_v4_national_identifier_gri==-9999 | country=="";
		
		***Notice countryXregion`year' is actually fixed over time;

		save "..\\..\\..\\data\\dtas\\analyze_me_land.dta", replace;

	*END 5.;


log close;
