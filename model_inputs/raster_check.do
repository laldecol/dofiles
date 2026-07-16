* raster_check.do
* Spot-checks analyze_me.dta (output of mergedtas.do) against values
* extracted directly from the ubergrid rasters at four test-city locations.
*
* The point is to verify the FULL pipeline: from ASCII raster -> table file ->
* table2dta.do -> mergedtas.do -> analyze_me.dta.  If any of those steps
* reorders, drops, or garbles values, this program will catch it.
*
* Four test cities (row/col in 4320x1740 ubergrid, top-to-bottom, left-to-right):
*   St. Petersburg  row 301  col 2525  uber_code 1,298,525
*   New York        row 532  col 1272  uber_code 2,295,192
*   Tokyo           row 592  col 3836  uber_code 2,556,956
*   Cape Town      row 1428  col 2382  uber_code 6,167,022
*
* Key transformation to remember:
*   AOD (Terra*) values: raster stored as AOD*1000 integers.
*   mergedtas.do line 105 replaces -9999 with missing (.) for all vars.
*   mergedtas.do lines 112-117 generate Terra2000 = Terra2000avg/1000,
*     then drop Terra2000avg. So expected values below are raster_value/1000.
*   All other variables: no transformation except -9999 -> missing.
*   Variable names truncated to 30 chars by table2dta.do.
*
* Written 2026-07-13 for spatial correspondence verification.

#delimit;
set more off;
clear all;
capture log close;

* --- Define helper program ---
* chk varname uber_code expected_value city_label
*   expected_value = . (dot) means "expect Stata missing".
*   Comparison is relative: abs(obs - exp) / max(abs(exp), 1) <= 1e-4.
*   Increments globals $ntest and $nfail.;

program define chk;
    args vname uc exp city;
    local tol = 1e-4;

    count if uber_code==`uc';
    if r(N)==0 {;
        di "  SKIP : [`city'] `vname' -- city not in dataset";
        exit;
    };

    quietly sum `vname' if uber_code==`uc';
    local obs = r(mean);

    * Both missing: pass;
    if missing(`obs') & missing(`exp') {;
        di "  PASS : [`city'] `vname' = . (missing as expected)";
        global ntest = $ntest + 1;
        exit;
    };

    * Expected non-missing but got missing;
    if missing(`obs') & !missing(`exp') {;
        di "  FAIL : [`city'] `vname' = . (missing); expected `exp'";
        global ntest = $ntest + 1;
        global nfail = $nfail + 1;
        exit;
    };

    * Expected missing but got non-missing;
    if !missing(`obs') & missing(`exp') {;
        di "  FAIL : [`city'] `vname' = `obs'; expected missing (.)";
        global ntest = $ntest + 1;
        global nfail = $nfail + 1;
        exit;
    };

    * Both non-missing: relative comparison;
    local rdiff = abs(`obs' - `exp') / max(abs(`exp'), 1);
    if `rdiff' <= `tol' {;
        di "  PASS : [`city'] `vname' = `obs' (expected `exp')";
    };
    else {;
        di "  FAIL : [`city'] `vname' = `obs'; expected `exp' (rdiff = `rdiff')";
        global nfail = $nfail + 1;
    };
    global ntest = $ntest + 1;
end;

* --- Setup ---
global ntest 0;
global nfail 0;

log using raster_check.log, text replace;

di "================================================================";
di "RASTER VS analyze_me.dta SPOT CHECK";
di "Run: $S_DATE $S_TIME";
di "================================================================";
di "Four test cities (uber_code):";
di "  St. Petersburg: 1298525   New York: 2295192";
di "  Tokyo:          2556956   Cape Town: 6167022";
di "AOD expected values = ASCII raster / 1000 (mergedtas.do line 115)";
di "-9999 in rasters -> Stata missing (mergedtas.do line 105)";
di "================================================================";

* --- Load data and restrict to 4 test cities ---;
use "..\..\..\data\dtas\analyze_me.dta", clear;

quietly count if inlist(uber_code, 1298525, 2295192, 2556956, 6167022);
if r(N) != 4 {;
    di "ERROR: expected 4 city observations in analyze_me.dta, found `r(N)'.";
    di "Check that mergedtas.do has run successfully.";
    log close;
    exit 1;
};
keep if inlist(uber_code, 1298525, 2295192, 2556956, 6167022);

* =======================================================
* 1. AOD: Terra2000 - Terra2015
*    Raster: Terra2000avg, Terra2005avg, Terra2010avg, Terra2015avg
*    DTA:    Terra2000, Terra2005, Terra2010, Terra2015  (= raster / 1000)
*    Source: MODIS_AOD/generated/yearly/ubergrid/ascii/terra20XXavg.txt
*    -9999 in raster -> missing in DTA (NYC Terra2000 was -9999 in raster)
* =======================================================;
di "";
di "--- 1. AOD: Terra2000 ---";
chk Terra2000 1298525  0.136175    "StP";
chk Terra2000 2295192  .           "NYC";   /* -9999 in raster */
chk Terra2000 2556956  0.1057818   "Tok";
chk Terra2000 6167022  0.09380769  "CPT";

di "";
di "--- 2. AOD: Terra2005 ---";
chk Terra2005 1298525  0.2414314   "StP";
chk Terra2005 2295192  0.1261      "NYC";
chk Terra2005 2556956  0.1604789   "Tok";
chk Terra2005 6167022  0.1364286   "CPT";

di "";
di "--- 3. AOD: Terra2010 ---";
chk Terra2010 1298525  0.4300476   "StP";
chk Terra2010 2295192  0.1197042   "NYC";
chk Terra2010 2556956  0.1206216   "Tok";
chk Terra2010 6167022  0.09467857  "CPT";

di "";
di "--- 4. AOD: Terra2015 ---";
chk Terra2015 1298525  0.2163056   "StP";
chk Terra2015 2295192  0.1456477   "NYC";
chk Terra2015 2556956  0.1292917   "Tok";
chk Terra2015 6167022  0.1321429   "CPT";

* =======================================================
* 2. GPW population
*    DTA variable names: aggregated_gpw_2000 etc. (no truncation)
*    No transformation: -9999 -> missing (but all 4 cities have real values)
*    Source: GPW4/generated/projected/ubergrid/table/aggregated_gpw_20XX.txt
* =======================================================;
di "";
di "--- 5. GPW population 2000 (aggregated_gpw_2000) ---";
chk aggregated_gpw_2000 1298525  391972.9  "StP";
chk aggregated_gpw_2000 2295192  348151.4  "NYC";
chk aggregated_gpw_2000 2556956  1017527   "Tok";
chk aggregated_gpw_2000 6167022  99356.27  "CPT";

di "";
di "--- 6. GPW population 2010 (aggregated_gpw_2010) ---";
chk aggregated_gpw_2010 1298525  415056.9  "StP";
chk aggregated_gpw_2010 2295192  360845.3  "NYC";
chk aggregated_gpw_2010 2556956  1113878   "Tok";
chk aggregated_gpw_2010 6167022  128425.6  "CPT";

* =======================================================
* 3. GPW national identifier
*    Full file name: gpw_v4_national_identifier_grid.txt (31 chars without .txt)
*    DTA variable:   gpw_v4_national_identifier_gri  (30-char truncation)
*    Integer country codes: these must match exactly for country-level merges
* =======================================================;
di "";
di "--- 7. GPW national identifier (gpw_v4_national_identifier_gri) ---";
chk gpw_v4_national_identifier_gri 1298525  643  "StP";
chk gpw_v4_national_identifier_gri 2295192  840  "NYC";
chk gpw_v4_national_identifier_gri 2556956  392  "Tok";
chk gpw_v4_national_identifier_gri 6167022  710  "CPT";

* =======================================================
* 4. GPW data quality
*    Full file name: gpw_v4_data_quality_indicators_mean_administrative_unit_area.txt
*    DTA variable:   gpw_v4_data_quality_indicators  (30-char truncation)
* =======================================================;
di "";
di "--- 8. GPW data quality (gpw_v4_data_quality_indicators) ---";
chk gpw_v4_data_quality_indicators 1298525  9.727518    "StP";
chk gpw_v4_data_quality_indicators 2295192  0.06710713  "NYC";
chk gpw_v4_data_quality_indicators 2556956  34.16035    "Tok";
chk gpw_v4_data_quality_indicators 6167022  4.267531    "CPT";

* =======================================================
* 5. CRU climate (2010)
*    No transformation: monthly values were averaged to annual in CRU pipeline.
*    tmp = mean temperature (degrees C): cld = cloud cover (%)
* =======================================================;
di "";
di "--- 9. CRU temperature 2010 (tmp2010) ---";
chk tmp2010 1298525  5.1       "StP";
chk tmp2010 2295192  12.79167  "NYC";
chk tmp2010 2556956  15.89167  "Tok";
chk tmp2010 6167022  17.18333  "CPT";

di "";
di "--- 10. CRU cloud cover 2010 (cld2010) ---";
chk cld2010 1298525  77.39167  "StP";
chk cld2010 2295192  63.25     "NYC";
chk cld2010 2556956  63.31667  "Tok";
chk cld2010 6167022  38.09167  "CPT";

* =======================================================
* 6. MODIS LULC 2001 (land use/land cover)
*    Values are pixel counts per 1/12-degree cell (max = 400 for 25m pixels).
*    dummy1 = trees: dummy0 = water/other.
*    StP has 306/400 tree pixels: NYC/Tokyo/CPT are water or non-tree pixels.
* =======================================================;
di "";
di "--- 11. LULC 2001 trees (LU2001dummy1) ---";
chk LU2001dummy1 1298525  306  "StP";
chk LU2001dummy1 2295192  0    "NYC";
chk LU2001dummy1 2556956  0    "Tok";
chk LU2001dummy1 6167022  0    "CPT";

di "";
di "--- 12. LULC 2001 water/other (LU2001dummy0) ---";
chk LU2001dummy0 1298525  0    "StP";
chk LU2001dummy0 2295192  400  "NYC";
chk LU2001dummy0 2556956  400  "Tok";
chk LU2001dummy0 6167022  400  "CPT";

* =======================================================
* SUMMARY
* =======================================================;
di "";
di "================================================================";
di "SUMMARY: $ntest tests run, $nfail failures";
if $nfail > 0 {;
    di "STATUS: FAIL -- see FAIL lines above";
};
else {;
    di "STATUS: PASS -- all raster values confirmed in analyze_me.dta";
};
di "================================================================";

log close;
