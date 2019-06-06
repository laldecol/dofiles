set trace on
pause on
set tracedepth 2
/*
IIASA_regions_to_country.do
This .do file reads country region dta files from IIASA and aggregates them 
into a single file per country year.

Created: 		Jun 4, 2017, by Lorenzo
Last modified: 	Jun 4, 2017, by Lorenzo
*/

local country_region_folder "S:/particulates/data_processing/data/IIASA/generated/country_region"
local country_region_subfolders:	dir "`country_region_folder'"	dir "*", respectcase

clear
foreach subfolder of local country_region_subfolders{
	local year_dtas : dir "`country_region_folder'/`subfolder'" file "*clean*.dta", respectcase
	foreach year_dta of local year_dtas{
		local file_str ="`country_region_folder'/"+"`subfolder'/"+"`year_dta'"
		dis "`file_str'"
		append using "`file_str'"
	}
}

split region, p(",")
gen country=strtrim(region1)
drop region*
*collapse to country year
*aggregate ag burning as Lint describes
*calculate country year level emission factor

*ag_burn is in Mt, ag_waste_burn_coeff in kt PM10/Mt

gen emiss_ag_waste=ag_burn*ag_waste_burn_coeff

 foreach v of var * {
	local l`v' : variable label `v'
	if `"`l`v''"' == "" {
		local l`v' "`v'"
	}
}
 
collapse (sum) en* emiss* ag_burn, by(year country)

foreach v of var * {
	label var `v' "`l`v''"
}

gen ag_waste_burn_coeff_avg=emiss_ag_waste/ag_burn
label var ag_waste_burn_coeff "Avg ag burning emiss coef, kt PM10/Mt, w by reg burning"

drop emiss_ag_waste

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

reshape wide en* emiss* ag* *coeff , i(country) j(year)

order *, alpha
order country

save "S:/particulates/data_processing/data/IIASA/generated/country/activity_emissions.dta", replace

reshape long
levelsof country, local(countries)

foreach country of local countries{

	local 	country_folder 	"S:/particulates/data_processing/data/IIASA/generated/country/`country'"
	capture mkdir 			"`country_folder'"
	
	foreach t of numlist 2000 2005 2010 2015 {
		
		local 	country_file	="`country_folder'/"+"`country'"+"iiasa_clean_"+"`t'"+".dta"
		
		preserve
		
		keep if year==`t' & country=="`country'"
		order 	year ///
				enbiomass encoal enelec engas enheat enhydrogen ennuc enoil enotheren enrenewables ensum ///
				country ///
				emissag emissbiomass emisscoal emisselec emissgas emissheat emisshydrogen emissindustrial ///
				emissnofuel emissnonexhaust emissnuc emissoil emissotheren emissrenewables emisssolvent emisssum ///
				ag_burn ag_waste_burn_coeff coal_coeff oil_coeff gas_coeff ag_emiss_noburn

		
		save	"`country_file'", replace
		
		restore
	}
}
			