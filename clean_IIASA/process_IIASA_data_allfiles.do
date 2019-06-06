
/*
process_IIASA_data_allfiles.do
This .do file reads raw country region files from IIASA, processes them, 
and writes them as clean country region year level dtas.

Output includes country level emission factors by emitting activity.

It reads:
1. PM emissions data
2. Energy use data
3. Agricultural burning data
4. Agricultural emission factors

Created: 		May 17, 2019, by Lint
Last modified: 	Jun 4, 2017, by Lorenzo
*/

*****************************
*** Processing IIASA Data ***
*****************************
set trace on
set tracedepth 3
clear
pause on
set more off

*****************************************
*** Program 1: Insheet Emissions Data ***
*****************************************

capture program drop insheet_emissions
program define insheet_emissions
	local import_file	= "S:/particulates/data_processing/data/IIASA/source/pm10_emissions" + "/" +`0' +".csv"
	import delimited using "`import_file'", rowr(9:27) colr(1:7)  clear

	gen region =  `0'

	rename v1 ktPM
	rename v2 y1990
	rename v3 y1995
	rename v4 y2000
	rename v5 y2005
	rename v6 y2010
	rename v7 y2015

	drop if _n==1

	reshape long y, i(ktPM) j(year)

	rename y emiss

	gen cat = ""
	replace cat = "coal" if regexm(kt,"Coal")==1
	replace cat = "gas" if regexm(kt,"Natural gas")==1
	replace cat = "biomass" if regexm(kt,"Biomass")==1
	replace cat = "hydrogen" if regexm(kt,"Hydrogen")==1
	replace cat = "otheren" if regexm(kt,"Other energy")==1
	replace cat = "nuc" if regexm(kt,"Nuclear")==1
	replace cat = "heat" if regexm(kt,"Heat")==1
	replace cat = "solvent" if regexm(kt,"Solvent")==1
	replace cat = "nofuel" if regexm(kt,"No fuel")==1
	replace cat = "ag" if regexm(kt,"Agriculture")==1
	drop if regexm(kt,"Macro parameters")==1
	drop if regexm(kt,"Other sources")==1
	replace cat = "industrial" if regexm(kt,"Industrial")==1
	replace cat = "sum" if regexm(kt,"Sum")==1
	replace cat = "elec" if regexm(kt,"Electricity")==1
	replace cat = "oil" if regexm(kt,"Liquid")==1
	replace cat = "renewables" if regexm(kt,"Renewables")==1
	replace cat = "nonexhaust" if regexm(kt,"Non-exhaust")==1

	replace emiss = "" if emiss=="n.a"
	destring emiss, replace
	*graph pie emiss if year==2010 & cat!="sum", over(cat) plabel(_all name) title("Est. PM10 Emissions")

	reshape wide emiss ktPM, i(year) j(cat) string

	drop ktPM*

	sort year
	
	local out_dir  ="S:/particulates/data_processing/data/IIASA/generated/country_region/"+`0'
	local file = "`out_dir'"+"/"+`0'+"emiss.dta"
	
	save "`file'", replace	

end

******************************************
*** Program 2: Insheet Energy Use Data ***
******************************************

capture program drop insheet_energy_use
program define insheet_energy_use
	local import_file="S:/particulates/data_processing/data/IIASA/source/energy_use/"+`0'+".csv"

	import delimited using "`import_file'", rowr(9:20) colr(1:7)  clear

	gen region = `0'

	rename v1 PJ
	rename v2 e1990
	rename v3 e1995
	rename v4 e2000
	rename v5 e2005
	rename v6 e2010
	rename v7 e2015
			
	drop if _n==1
			
	reshape long e, i(PJ) j(year)

	rename e en

	gen cat = ""
	replace cat = "coal" if regexm(PJ,"Coal")==1
	replace cat = "gas" if regexm(PJ,"Natural gas")==1
	replace cat = "biomass" if regexm(PJ,"Biomass")==1
	replace cat = "hydrogen" if regexm(PJ,"Hydrogen")==1
	replace cat = "otheren" if regexm(PJ,"Other energy")==1
	replace cat = "nuc" if regexm(PJ,"Nuclear")==1
	replace cat = "heat" if regexm(PJ,"Heat")==1
	replace cat = "sum" if regexm(PJ,"Sum")==1
	replace cat = "elec" if regexm(PJ,"Electricity")==1
	replace cat = "oil" if regexm(PJ,"Liquid")==1
	replace cat = "renewables" if regexm(PJ,"Renewables")==1
	tab cat, m
	*Note: Electricity is often negative - must be exports

	replace en = "" if en=="n.a"
	destring en, replace

	reshape wide en PJ, i(year) j(cat) string

	drop PJ*

	duplicates drop
	
	local out_dir  ="S:/particulates/data_processing/data/IIASA/generated/country_region/"+`0'
	local file = "`out_dir'"+"/"+`0'+"energy.dta"
	
	save "`file'", replace	

end

*********************************
**Program 3: Insheet Ag burning** 
*********************************

capture program drop insheet_agburning
program insheet_agburning
	local import_file="S:/particulates/data_processing/data/IIASA/source/agricultural_burning/"+`0'+".csv"

	import delimited using "`import_file'", rowr(9:18) colr(1:9)  clear
	gen region = `0'

	rename v2 sector
	rename v3 unit 
	rename v4 e1990
	rename v5 e1995
	rename v6 e2000
	rename v7 e2005
	rename v8 e2010
	rename v9 e2015
	drop v1
	
	keep if sector=="Agricultural waste burning"
	
	ds e*, has(type string)
	local estr_list `r(varlist)'
	
	foreach evar of local estr_list{
		replace `evar' = "" if `evar'=="n.a"
	}
	
	destring e*, replace

	reshape long e, i(sector) j(year)

	rename e ag_burn
	label var ag_burn "Agricultural waste burning, MT"

	keep region year ag_burn
	sort year

	*** Save ***
	************
	local out_dir  ="S:/particulates/data_processing/data/IIASA/generated/country_region/"+`0'
	local file = "`out_dir'"+"/"+`0'+"agburning.dta"
	
	save "`file'", replace	
	
end

************************************
**Program 4: Insheet Ag burning ef**
************************************
capture program drop insheet_agburning_ef
program define insheet_agburning_ef

	local import_file="S:/particulates/data_processing/data/IIASA/source/agricultural_burning_ef/"+`0'+".csv"

	import excel using "`import_file'", clear first cellrange(A4:K45) sheet("PMfac_nonen") 
	*Note: Excel import does not recognize PM10 coefficients since they are a formula in the spreadsheet -> Recreate!
	drop PM_10 PM_TSP
	gen PM_10 = PM_2_5 + PM_COA

	keep if Sector=="WASTE_AGR"
	rename PM_10 ag_waste_burn_coeff
	tab ActivityUnit
	label var ag_waste "Ag waste burning emissions coefficient, kt PM10/Mt"
	keep ag_waste
	duplicates drop
	gen region = `0'

	*** Save ***
	************
	
	local out_dir  ="S:/particulates/data_processing/data/IIASA/generated/country_region/"+`0'
	local file = "`out_dir'"+"/"+`0'+"agburning_ef.dta"
	
	save "`file'", replace	
end

************
************

local dir_emissions 	"S:\particulates\data_processing\data\IIASA\source\pm10_emissions"
local dir_energy_use 	"S:\particulates\data_processing\data\IIASA\source\energy_use"
local dir_ag_burning 	"S:\particulates\data_processing\data\IIASA\source\agricultural_burning"
local dir_ag_burning_ef "S:\particulates\data_processing\data\IIASA\source\agricultural_burning_ef"

local country_list:			dir "`dir_emissions'" 		file "*", respectcase

foreach country_file of local country_list{
	local country_name=subinstr("`country_file'", ".csv", "",.)
	
	local file_emissions: 		dir "`dir_emissions'" 		file "`country_name'*.csv", respectcase
	local file_energy_use: 		dir "`dir_energy_use'" 		file "`country_name'*.csv", respectcase
	local file_ag_burning: 		dir "`dir_ag_burning'" 		file "`country_name'*.csv", respectcase
	local file_ag_burning_ef: 	dir "`dir_ag_burning_ef'" 	file "`country_name'*.csv", respectcase
	
	local error_tag =0
	foreach ftype in emissions energy_use ag_burning ag_burning_ef{
		capture{
			local check_file="`dir_`ftype''"+"/"+`file_`ftype''
			confirm file "`check_file'"
			}
		if _rc>0{
			dis "`ftype' file missing for `country_name'"
		}
		local error_tag=`error_tag'+_rc	
}
	if `error_tag'==0{
		dis "`country_name' files all OK"
		local out_dir  ="S:/particulates/data_processing/data/IIASA/generated/country_region/"+"`country_name'"

		capture mkdir "`out_dir'"

		insheet_emissions 		"`country_name'" 
		insheet_energy_use 	"`country_name'"
		insheet_agburning 		"`country_name'"
		insheet_agburning_ef	"`country_name'"
		
		local file_emiss = 		"`out_dir'/"+"`country_name'emiss.dta"
		local file_energy= 		"`out_dir'/"+"`country_name'energy.dta"
		local file_agburning=	"`out_dir'/"+"`country_name'agburning.dta"
		local file_agburning_ef="`out_dir'/"+"`country_name'agburning_ef.dta"
		
		use "`file_emiss'", clear
		merge 1:1 year using "`file_energy'", nogen
		merge 1:1 year using "`file_agburning'", nogen
		append using "`file_agburning_ef'"
		sum ag_waste_burn_coeff
		local temp = r(mean)
		replace ag_waste_burn_coeff = `temp' if mi(ag_waste_burn_coeff)
		drop if mi(year)
		***** Compute Coefficients ****
		********************************

		*Coal Coeff:
		gen coal_coeff = emisscoal/encoal	
		label var coal_coeff "kt per PJ"
		tabulate year, sum(coal)

		*Oil Coeff:
		gen oil_coeff = emissoil/enoil	
		label var oil_coeff "kt per PJ"
		tabulate year, sum(oil)
			
		*Gas coeff - just to check:
		gen gas_coeff = emissgas/engas	
		label var gas_coeff "kt per PJ"
		tabulate year, sum(gas)	/*de minimis, good!*/

		*Biomass we add - let's start with agriclture!
		*Agriculture we (i) subtract burning and (ii) divide by ag output
		*Industrial we divide by industry output
		*Non-exhaust we divide by services output

		gen ag_emiss_noburn = emissag-(ag_waste*ag_burn)+emissbiomass
		label var ag_emiss_noburn "Ag emissions - waste burning + biomass, kt"
		
		**Save separately for each year
		drop if year<2000

		foreach t of numlist 2000 2005 2010 2015 {
			preserve
			keep if year==`t'
			levelsof region, local(name)
			local name2 = r(levels)
			local file2 = "S:/particulates/data_processing/data/IIASA/generated/country_region/"+`name2'+"/"+`name2'+"iiasa_clean_"+"`t'"+".dta"
			sort year
			order year ///
			enbiomass encoal enelec engas enheat enhydrogen ennuc enoil enotheren enrenewables ensum ///
			region ///
			emissag emissbiomass emisscoal emisselec emissgas emissheat emisshydrogen emissindustrial ///
			emissnofuel emissnonexhaust emissnuc emissoil emissotheren emissrenewables emisssolvent emisssum ///
			ag_burn ag_waste_burn_coeff coal_coeff oil_coeff gas_coeff ag_emiss_noburn
			save "`file2'", replace	
			restore
		}

	}
	
	if `error_tag'>0{
		dis "Some `country_name' files missing"
	}
}




*******************************************
*** EXTRAPOlATE LINEARLY BETWEEN YEARS? ***
*******************************************
/*
tsset year
tsfill

*For our purposes:
drop if year<2000

*Extrapolate linearly:
*/


**************************************
**********		SAVE	 *************
**************************************


	