# Tracking runs for the revision

How to keep track of long jobs and checks across `dofiles`, `particulates_analysis`
and `data_processing_calibration`. Set up 2026-11-27.

## The pieces

1. **Referee point** (in `laldecol/ABT_main` only): one issue per point, titled
   with the comment number, e.g. `[R1 1(a)] ...`.
2. **Code task** (in the code repo): a change a referee point needs, filed as a
   sub-issue of the ABT_main point.
3. **Run / test log** (in the code repo): one per job you launch, with
   `Part of #N`. Fill it in at launch; when the job comes back, comment
   **Result vs expected** and **Next step**, then close it.
4. **Run manifest**: the script itself writes `run_manifest.txt` into its output
   folder with the git commit, uncommitted changes, inputs (size, date), and key
   numbers. `run_manifest_history.txt` keeps every finished run. If a manifest
   still says `status: running`, the job crashed or is still going.
5. **Project board** "Particulates Revision JEEA": auto-adds issues from all repos.

## Run manifest helpers

### Stata (`mylibrary/run_manifest.ado`)

Copy `run_manifest.ado` to your PERSONAL ado folder (type `sysdir` in Stata;
`settings_particulates.ado` is there too). Then, in any do-file:

```stata
#delimit ;
run_manifest start, outdir("../../output/FE") script("FE_regressions.do")
    inputs("../../data/main.dta") expected("Table 4 col 1 matches 2019 version")
    issue("laldecol/particulates_analysis#5");

* ... regressions ...

run_manifest finish, outputs("FE_table.tex") signature
    estimates keep(aod fire area);
```

`signature` records Stata's `datasignature` of the data in memory: if two runs
show the same signature, the data are identical. That is the quickest check that
the new arcpy pipeline reproduces the old data. Add `checksum` to `start` to
record a CRC for each input (slower for large files).

### Python (`mylibrary/run_manifest.py`)

Standard library only, no arcpy. Import it directly (not through the
`mylibrary` package, whose `__init__` imports arcpy):

```python
import sys
sys.path.append(r"S:\particulates\data_processing\dofiles_la\dofiles\mylibrary")
import run_manifest

with run_manifest.start(outdir, inputs=nc_files, expected="3 tifs",
                        issue="laldecol/dofiles#40") as m:
    ...  # the work; a crash is recorded as status: failed
    m.outputs += out_tifs
    m.stats["n_files"] = len(out_tifs)
```

Call it from the orchestrator (for example `van_donkelar.py`), not from each
worker, so there is one manifest per run.

### MATLAB (`data_processing_calibration/dofiles/matlab/functions/run_manifest.m`)

```matlab
run_manifest('../../out/IND2010', 'Inputs', {'inputs.mat'}, ...
    'Expected', 'Welfare loss about 3%', 'Stats', struct('welfare', w));
```

