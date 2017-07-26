***This .do file takes an ubergrid country file and creates ubergrid border dtas
*Output dtas can be converted to ubergrid rasters using raster2dta
*Output rasters are dummy rasters for: international border NSEW & land-ocean borders,
#delimit;
use "S:\particulates\data_processing\data\boundaries\generated\ubergrid\dtas\world_countries_2011.dta", clear;
*For each uber_code, generate four variables: uber_code of northern, southern, western, and eastern neighbor.;
*Calculations:
*Define C,R as column and row totals in current ubergrid. Can be read from data\projections\generated\settings.dta;
*Eastern and western neighbor are easy for uber_code MOD C !=
