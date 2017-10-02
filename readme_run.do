
/**********************************************
R E A D M E _ R U N. D O

This program serves as a driver and documentation 
for all the code in \\particulates;

last modified: Apr 30, 2017, by la
**********************************************/
* set up;
#delimit;
clear all;
cls;
set more off;

local python "C:\Python27\ArcGIS10.2\python.exe";

**********************************************************;
**   Step 1: Aggregate source GPW to use as ubergrid    **;
**********************************************************;
if 1==2{;
	cd aggregate_raster;
	shell `python' aggregate_raster.py;
	cd ..;
};

**********************************************************;
**   Step 2: Create extent and settings for rasters     **;
**********************************************************;
*2.1 Reprojects GPWv4 rasters, extracts extent and settings (as template for ubergrid);

if 1==2{;
	cd make_xy_extent;
	shell `python' make_xy_extent.py;
	cd ..;
	*Successfully ran make_xy_extent;
	};

*2.2 Saves ubergrid settings (boundary coordinates, cell sizes, row and col numbers)
*in a dta (data\projections\generated\settings.dta) for future reference.;

if 1==2{;
	cd settings2dta;
	do settings2dta.do;
	cd ..;
	*Successfully ran settings2dta.do;
	};

***************************************************************;
**    Step 3: Average daily AOD rasters into yearly ones     **;
***************************************************************;
*Averages all daily AOD files from the years set in daily2yearly.py into 
*yearly ones, by satellite. ;

if 1==2{;
	cd daily2yearlyAOD;
	shell `python' daily2yearlyAOD.py;
	cd ..;
	*Successfully ran daily2yearlyAOD.py;
	};


***************************************************************;
**    Step 4: Average monthly fire rasters into yearly ones     **;
***************************************************************;
*Averages all monthly fire files from the years set in monthly2yearlyFIRE.py into 
*yearly ones, by satellite. ;

if 1==2{;
	cd monthly2yearlyFIRE;
	shell `python' monthly2yearlyFIRE.py;
	cd ..;
	*Successfully ran monthly2yearlyFIRE.py;
	};

*************************************************;
**    Step 5: Transform rasters into ubergrid  **;
*************************************************;
*Takes all non-ubergrid rasters from the directories set in raster2ubergrid.py 
*and uses the settings from make_xy_extent.py to transform them into standard
*ubergrids. (This program depends on the projection.);

if 1==2{;
	cd raster2ubergrid;
	shell `python' raster2ubergrid.py;
	cd ..;
	*Successfully ran raster2ubergrid.py;
	};

**********************************************************************;
**    Step 5: Transform vector shapefiles into ubergrid rasters     **;
**********************************************************************;
*Takes all vector shapefiles from the directories set in polygon2ubergrid.py
*and turns them into ubergrids.;

if 1==2{;
	cd polygon2ubergrid;
	shell `python' polygon2ubergrid.py;
	cd ..;
	*Successfully ran polygon2ubergrid.py;
	};

***************************************************************;
** Step 6: Transform ubergrid raster files into ascii files  **;
***************************************************************;
*6.1 Takes all ubergrid rasters specified in raster2list.py and exports their
* data into .txt files. ;

if 1==2{;
	cd raster2list;
	shell `python' raster2list.py;
	cd ..;
	*Successfully ran raster2list.py;
	};
	
*6.2 Cleans gpw .txt filenames so they can be processed by stata.;
if 1==2{;
	cd gpwclean;
	shell `python' gpwclean.py;
	cd ..;
	*Successfully ran gpwclean.py;
	};

********************************************;
** Step 7: Import ascii tables to dta     **;
********************************************;
*Takes directory and filename pattern pairs,  imports corresponding .txt files
*into stata, and saves them as .dta;

if 1==2{;
	cd table2dta;
<<<<<<< HEAD
	
	*do table2dta.do "..\..\..\data\MODIS_AOD\generated\yearly\ubergrid\table" "*avg.txt";
	*do table2dta.do "..\..\..\data\GPW4\generated\projected\table" "*.txt";
	*do table2dta.do "..\..\..\data\GPW4\generated\gpw-v4-national-identifier-grid\ubergrid\table" "*.txt";
	*do table2dta.do "..\..\..\data\GPW4\generated\gpw-v4-data-quality-indicators-mean-administrative-unit-area\ubergrid\table" "*.txt";
	*do table2dta.do "..\..\..\data\MODIS_FIRE\generated\yearly\ubergrid\table" "*.txt";
	*do table2dta.do "..\..\..\data\CRU\generated\yearly\ubergrid\table" "*.txt";
	do table2dta.do "..\..\..\data\MODIS_LULC\generated\yearly\dummy\ubergrid\table" "*.txt";
=======
	/*;
	do table2dta.do "..\..\..\data\MODIS_AOD\generated\yearly\ubergrid\table" "*avg.txt";
	do table2dta.do "..\..\..\data\GPW4\generated\projected\table" "*.txt";
	do table2dta.do "..\..\..\data\GPW4\generated\gpw-v4-national-identifier-grid\ubergrid\table" "*.txt";
	do table2dta.do "..\..\..\data\GPW4\generated\gpw-v4-data-quality-indicators-mean-administrative-unit-area\ubergrid\table" "*.txt";
	do table2dta.do "..\..\..\data\MODIS_FIRE\generated\yearly\ubergrid\table" "*.txt";
	do table2dta.do "..\..\..\data\CRU\generated\yearly\ubergrid\table" "*.txt";
	*/;
	do table2dta.do "..\..\..\data\CCMP\generated\yearly\ubergrid\table" "*.txt";
>>>>>>> master
	cd ..;
	*Successfully ran table2dta.do;
	};

**************************;
** Step 8: Merge dtas   **;
**************************;
*Merges all .dta files from the specified directories together and saves them.;

if 1==1{;
	cd mergedtas;
	do mergedtas.do 7 "MODIS_AOD\generated\yearly\ubergrid\dtas"
	"GPW4\generated\projected\dtas"
	"GPW4\generated\gpw-v4-national-identifier-grid\ubergrid\dtas"
	"GPW4\generated\gpw-v4-data-quality-indicators-mean-administrative-unit-area\ubergrid\dtas"
	"MODIS_FIRE\generated\yearly\ubergrid\dtas"
	"CRU\generated\yearly\ubergrid\dtas"
<<<<<<< HEAD
	"MODIS_LULC\generated\yearly\dummy\ubergrid\dtas";
=======
	"CCMP\generated\yearly\ubergrid\dtas";
>>>>>>> master
	cd ..;
	*Successfully ran mergedtas.do;
	};

****************************************;
** Step 9: Merge country level data  **;
****************************************;
*Cleans and merges sources of country level data, preserving all pixels;
*BPclean defines a EU country and must be run last;

if 1==1{;
	cd mergecountrydata;
	do PWTclean.do;
	do urbanshareclean.do;
	do BPclean.do;
	cd ..;
	*Successfully ran do files
	in \mergecountrydata;
	};
 
