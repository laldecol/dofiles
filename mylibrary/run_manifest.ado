*! run_manifest 1.0  2026-11-27
/*
R U N _ M A N I F E S T . A D O

Writes a plain-text "run manifest" next to a do-file's outputs, so that days
later you can tell which code, inputs and data produced them.

Install: copy this file to your PERSONAL ado folder (type -sysdir- in Stata to
see where it is; settings_particulates.ado lives there too), or run
    adopath + "S:\particulates\data_processing\dofiles_la\dofiles\mylibrary"

Usage (works with #delimit ; as well):

    run_manifest start, outdir("../../../data/regressions/output")
        script("FE_regressions.do")
        inputs("../../../data/main.dta" "../../../data/countries.dta")
        expected("Table 4 col 1 coef on AOD about 0.12, N about 1.3m")
        issue("laldecol/particulates_analysis#5");

    ... the work ...

    run_manifest finish, outputs("table4.tex" "table4.csv")
        stats(aod pop) signature
        estimates keep(aod fire area);

  start options
    outdir()    required. Folder where the manifest is written.
    script()    name of the do-file (Stata cannot see it by itself).
    inputs()    files or folders read. Each gets its size; add -checksum- to
                also record a CRC (reads the whole file, slower for big files).
    expected()  what you expect the run to produce.
    issue()     GitHub issue this run belongs to, e.g. laldecol/dofiles#40.
    note()      anything else.

  finish options
    outputs()   files written (paths relative to the current folder are fine).
    stats()     numeric variables of the data in memory: N, mean, sd, min, max.
    signature   records -datasignature- of the data in memory; two runs with
                the same signature have identical data.
    estimates   records e(cmd), e(N), e(r2) of the last estimation, plus
                _b and _se for the variables in keep().
    status()    defaults to ok. Use e.g. status(failed) yourself if needed.
    note()      appended to the note.

  Files written in outdir:
    run_manifest.txt          latest run; written at start with status: running
                              and rewritten at finish. If it still says running,
                              the run crashed or is still going.
    run_manifest_history.txt  every finished run appended, newest last.

  One start/finish pair at a time: a sub-do-file that calls -run_manifest start-
  replaces the open manifest of the do-file that called it.

Created 2026-11-27.
*/

program define run_manifest
	version 14
	gettoken sub 0 : 0, parse(" ,")
	if "`sub'" == "start" {
		rm_start `0'
	}
	else if "`sub'" == "finish" {
		rm_finish `0'
	}
	else {
		di as err "run_manifest: type -run_manifest start, outdir(...)- or -run_manifest finish-"
		exit 198
	}
end

program define rm_start
	version 14
	syntax , OUTdir(string) [SCRipt(string) INPuts(string asis) EXPected(string) ///
		ISSUE(string) NOTE(string) CHECKsum]

	* Absolute path of outdir; create it if needed
	local here "`c(pwd)'"
	capture mkdir "`outdir'"
	quietly cd "`outdir'"
	local outabs "`c(pwd)'"
	quietly cd "`here'"

	global RM_outdir   `"`outabs'"'
	global RM_started  "`c(current_date)' `c(current_time)'"
	global RM_t0       = clock("`c(current_date)' `c(current_time)'", "DMYhms")
	global RM_script   `"`script'"'
	global RM_pwd      `"`here'"'
	global RM_expected `"`expected'"'
	global RM_issue    `"`issue'"'
	global RM_note     `"`note'"'

	* Git: try the git command, fall back to reading .git files
	mata: st_local("repo", rm_findrepo(st_local("here")))
	local commit "unknown"
	local branch "unknown"
	local dirty  "unknown"
	if `"`repo'"' == "" {
		local repo "(not in a git repo)"
	}
	else {
		tempfile g1 g2 g3
		capture quietly shell git -C "`repo'" rev-parse HEAD > "`g1'" 2>&1
		mata: st_local("commit", rm_firstline(st_local("g1")))
		if strlen(`"`commit'"') == 40 & !strpos(`"`commit'"', " ") {
			capture quietly shell git -C "`repo'" rev-parse --abbrev-ref HEAD > "`g2'" 2>&1
			mata: st_local("branch", rm_firstline(st_local("g2")))
			capture quietly shell git -C "`repo'" status --porcelain --untracked-files=no > "`g3'" 2>&1
			mata: st_local("dirty", rm_dirty(st_local("g3")))
		}
		else {
			mata: rm_readhead(st_local("repo"))
			local dirty "unknown (git command not available)"
		}
	}
	global RM_repo   `"`repo'"'
	global RM_commit `"`commit'"'
	global RM_branch `"`branch'"'
	global RM_dirty  `"`dirty'"'

	* Describe inputs
	global RM_ninputs 0
	local i 0
	foreach f of local inputs {
		local ++i
		mata: st_local("desc", rm_describe(st_local("f")))
		if "`checksum'" != "" {
			capture confirm file "`f'"
			if !_rc {
				quietly checksum "`f'"
				local desc `"`desc' | crc `r(checksum)'"'
			}
		}
		global RM_input`i' `"`desc'"'
	}
	global RM_ninputs `i'
	global RM_noutputs 0

	rm_write, status(running)
	di as txt "run_manifest: started, writing to " as res `"$RM_outdir/run_manifest.txt"'
end

program define rm_finish
	version 14
	syntax , [OUTputs(string asis) STATS(varlist numeric) SIGnature ESTimates ///
		KEEP(string) NOTE(string) STATUS(string)]

	if `"$RM_outdir"' == "" {
		di as err "run_manifest finish: no open manifest; call -run_manifest start- first"
		exit 198
	}
	if "`status'" == "" local status "ok"
	if `"`note'"' != "" {
		if `"$RM_note"' != "" global RM_note `"$RM_note | `note'"'
		else global RM_note `"`note'"'
	}

	local i 0
	foreach f of local outputs {
		local ++i
		mata: st_local("desc", rm_describe(st_local("f")))
		global RM_output`i' `"`desc'"'
	}
	global RM_noutputs `i'

	* Stats lines
	local nstats 0
	local ++nstats
	local stat`nstats' "data in memory: `c(N)' obs, `c(k)' vars, last file used: `c(filename)'"
	if "`signature'" != "" {
		quietly datasignature
		local ++nstats
		local stat`nstats' "datasignature: `r(datasignature)'"
	}
	foreach v of local stats {
		quietly summarize `v'
		local ++nstats
		local stat`nstats' : di "`v': N=" r(N) " mean=" %12.6g r(mean) " sd=" %12.6g r(sd) " min=" %12.6g r(min) " max=" %12.6g r(max)
	}
	if "`estimates'" != "" {
		if "`e(cmd)'" == "" {
			local ++nstats
			local stat`nstats' "estimates: none in memory"
		}
		else {
			local ++nstats
			local stat`nstats' : di "estimates: `e(cmd)' N=" e(N) " r2=" %9.6f e(r2) " r2_a=" %9.6f e(r2_a)
			local ++nstats
			local stat`nstats' `"cmdline: `e(cmdline)'"'
			foreach v of local keep {
				capture local b = _b[`v']
				if _rc {
					local ++nstats
					local stat`nstats' "_b[`v']: not in model"
					continue
				}
				local se = _se[`v']
				local ++nstats
				local stat`nstats' : di "_b[`v']=" %12.6g `b' " se=" %12.6g `se'
			}
		}
	}
	global RM_nstats `nstats'
	forvalues j = 1/`nstats' {
		global RM_stat`j' `"`stat`j''"'
	}

	rm_write, status(`status') final
	di as txt "run_manifest: finished (`status'), see " as res `"$RM_outdir/run_manifest.txt"'
	global RM_outdir ""
end

program define rm_write
	version 14
	syntax , status(string) [final]

	tempname fh
	tempfile tf
	file open `fh' using "`tf'", write text replace
	file write `fh' "==============================================================================" _n
	file write `fh' "RUN MANIFEST" _n
	file write `fh' "status:      `status'" _n
	file write `fh' "started:     $RM_started" _n
	if "`final'" != "" {
		local t1 = clock("`c(current_date)' `c(current_time)'", "DMYhms")
		local mins : di %9.1f (`t1' - $RM_t0) / 60000
		file write `fh' "finished:    `c(current_date)' `c(current_time)'  (`=strtrim("`mins'")' min)" _n
	}
	file write `fh' `"script:      $RM_script"' _n
	file write `fh' `"run from:    $RM_pwd"' _n
	file write `fh' `"issue:       $RM_issue"' _n
	file write `fh' `"git repo:    $RM_repo"' _n
	file write `fh' `"git commit:  $RM_commit"' _n
	file write `fh' `"git branch:  $RM_branch"' _n
	file write `fh' `"uncommitted: $RM_dirty"' _n
	local host ""
	capture local host "`c(hostname)'"
	file write `fh' "machine:     `host' / `c(username)' / `c(os)' `c(machine_type)'" _n
	file write `fh' "stata:       `c(stata_version)' `c(flavor)'" _n
	file write `fh' `"expected:    $RM_expected"' _n
	if `"$RM_note"' != "" file write `fh' `"note:        $RM_note"' _n
	file write `fh' "inputs:" _n
	if $RM_ninputs == 0 file write `fh' "  -" _n
	forvalues i = 1/$RM_ninputs {
		file write `fh' `"  ${RM_input`i'}"' _n
	}
	file write `fh' "outputs:" _n
	if $RM_noutputs == 0 file write `fh' "  -" _n
	forvalues i = 1/$RM_noutputs {
		file write `fh' `"  ${RM_output`i'}"' _n
	}
	if "`final'" != "" {
		file write `fh' "stats:" _n
		forvalues i = 1/$RM_nstats {
			file write `fh' `"  ${RM_stat`i'}"' _n
		}
	}
	file write `fh' "" _n
	file close `fh'

	copy "`tf'" `"$RM_outdir/run_manifest.txt"', replace
	if "`final'" != "" {
		mata: rm_append(st_local("tf"), st_global("RM_outdir") + "/run_manifest_history.txt")
	}
end

version 14
capture mata mata drop rm_findrepo() rm_firstline() rm_dirty() rm_readhead() rm_describe() rm_append()
mata:

string scalar rm_findrepo(string scalar start)
{
	string scalar d, p1, p2
	d = subinstr(start, "\", "/")
	while (d != "") {
		if (direxists(d + "/.git")) return(d)
		pathsplit(d, p1, p2)
		if (p1 == d | p2 == "") return("")
		d = p1
	}
	return("")
}

string scalar rm_firstline(string scalar f)
{
	string colvector x
	if (!fileexists(f)) return("")
	x = cat(f)
	if (rows(x) == 0) return("")
	return(strtrim(x[1]))
}

string scalar rm_dirty(string scalar f)
{
	string colvector x
	string scalar s
	real scalar i, n
	if (!fileexists(f)) return("unknown")
	x = cat(f)
	n = 0
	s = ""
	for (i = 1; i <= rows(x); i++) {
		if (strtrim(x[i]) != "") {
			n++
			if (n <= 20) s = s + (n > 1 ? "; " : "") + strtrim(x[i])
		}
	}
	if (n == 0) return("no")
	return("YES: " + s + (n > 20 ? " ..." : ""))
}

void rm_readhead(string scalar repo)
{
	string scalar h, ref, f
	string colvector x
	real scalar i
	h = rm_firstline(repo + "/.git/HEAD")
	if (substr(h, 1, 4) != "ref:") {
		st_local("commit", h)
		st_local("branch", "(detached)")
		return
	}
	ref = strtrim(substr(h, 5, .))
	st_local("branch", subinstr(ref, "refs/heads/", ""))
	f = repo + "/.git/" + ref
	if (fileexists(f)) {
		st_local("commit", rm_firstline(f))
		return
	}
	f = repo + "/.git/packed-refs"
	if (fileexists(f)) {
		x = cat(f)
		for (i = 1; i <= rows(x); i++) {
			if (substr(x[i], 1, 1) != "#" & strtrim(substr(x[i], 42, .)) == ref) {
				st_local("commit", substr(x[i], 1, 40))
				return
			}
		}
	}
	st_local("commit", "unknown")
}

string scalar rm_describe(string scalar f)
{
	real scalar fh, n
	if (direxists(f)) return(f + " | folder")
	if (!fileexists(f)) return(f + " | MISSING")
	fh = fopen(f, "r")
	fseek(fh, 0, 1)
	n = ftell(fh)
	fclose(fh)
	return(f + " | " + strtrim(sprintf("%20.0fc", n)) + " bytes")
}

void rm_append(string scalar src, string scalar dest)
{
	string colvector x
	real scalar fh, i
	x = cat(src)
	fh = fopen(dest, "a")
	for (i = 1; i <= rows(x); i++) fput(fh, x[i])
	fclose(fh)
}

end
