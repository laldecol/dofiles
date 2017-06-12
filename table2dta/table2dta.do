*This do file:
*1. Imports all delimited .txt in a folder into stata as .dtas
*2. Saves each separately in a folder ("dtas") in the same location as the input folder

* For future reference, this is probably better to do with STATTRANSFER. Other wise this looks good. MT 02/13/17

*Start up
#delimit;
clear all;
cls;
set more off;
pause on;

*Define the two arguments: directory that contains tables and .txt filename pattern.;
local inputdir `1';
local pattern `2';
local startdir : pwd;

*Set up output folder;
cd `inputdir';
shell RD /S /Q "..\dtas";
mkdir "..\dtas";

*Create local with all file names in input directory that match the pattern;
local txts : dir . files "`pattern'", respectcase;

*For each file in local, import to stata and save to \dtas.;
foreach txt of local txts{;
clear;

display "Started importing `txt'";
import delimited `txt', delimiter(space);

local basename = substr("`txt'",1,min(length("`txt'")-4,30));
display "Done importing `basename'";

rename v2 `basename';
compress;

save "..\dtas/`basename'.dta",replace;
};
cd `startdir';
