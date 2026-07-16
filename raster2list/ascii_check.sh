#!/bin/bash
# ascii_check.sh
# For every (ascii_file, table_file) pair produced by raster2list.py,
# extract the raster value at each of the 4 test-city positions from the
# ASCII file and from the table file, then compare them.
#
# City positions (1-indexed row and column in the ubergrid):
#   St. Petersburg : row 301, col 2525  -> ASCII line 307  -> uber_code 1,298,525
#   New York       : row 532, col 1272  -> ASCII line 538  -> uber_code 2,295,192
#   Tokyo          : row 592, col 3836  -> ASCII line 598  -> uber_code 2,556,956
#   Cape Town      : row 1428, col 2382 -> ASCII line 1434 -> uber_code 6,167,022
#
# Usage: bash ascii_check.sh
# Output: ascii_check_results.txt in the same directory

DATA="C:/workspace/data_processing/data"
OUT="C:/workspace/data_processing/dofiles_la/dofiles/raster2list/ascii_check_results.txt"
TMP="/tmp/ascii_check_$$"
mkdir -p "$TMP"

# --- worker function ---
# Each call processes one ascii/table pair and writes one result line.
check_pair() {
    local ascii_file="$1"
    local table_file="$2"
    local layer_tag="$3"     # short label, e.g. "CRU"
    local base="$4"          # filename without path, e.g. "tmp2010.txt"

    # Extract from ASCII: one pass, exit after the deepest city row (1434).
    read -r sp_asc ny_asc tk_asc ct_asc < <(awk '
        NR==307  { sp=$2525 }
        NR==538  { ny=$1272 }
        NR==598  { tk=$3836 }
        NR==1434 { ct=$2382; exit }
        END { printf "%s %s %s %s\n",
              (sp==""?"NA":sp), (ny==""?"NA":ny),
              (tk==""?"NA":tk), (ct==""?"NA":ct) }
    ' "$ascii_file")

    # Extract from table: one pass, exit after the deepest uber_code (6167022).
    read -r sp_tbl ny_tbl tk_tbl ct_tbl < <(awk '
        NR==1298525 { sp=$2 }
        NR==2295192 { ny=$2 }
        NR==2556956 { tk=$2 }
        NR==6167022 { ct=$2; exit }
        END { printf "%s %s %s %s\n",
              (sp==""?"NA":sp), (ny==""?"NA":ny),
              (tk==""?"NA":tk), (ct==""?"NA":ct) }
    ' "$table_file")

    # Compare all four cities
    if [ "$sp_asc" = "$sp_tbl" ] && [ "$ny_asc" = "$ny_tbl" ] && \
       [ "$tk_asc" = "$tk_tbl" ] && [ "$ct_asc" = "$ct_tbl" ]; then
        match="OK"
    else
        match="MISMATCH"
    fi

    # Write one result line (tab-separated) to a private temp file
    # to avoid write races between parallel workers.
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
        "$layer_tag" "$base" \
        "$sp_asc" "$ny_asc" "$tk_asc" "$ct_asc" \
        "$sp_tbl" "$ny_tbl" "$tk_tbl" "$ct_tbl" \
        "$match" > "$TMP/${layer_tag}__${base}.result"
}
export -f check_pair
export TMP

# --- layer directory pairs ---
declare -A LAYERS
LAYERS["MODIS_AOD"]="$DATA/MODIS_AOD/generated/yearly/ubergrid"
LAYERS["GPW_pop"]="$DATA/GPW4/generated/projected"
LAYERS["GPW_natID"]="$DATA/GPW4/generated/gpw-v4-national-identifier-grid/ubergrid"
LAYERS["GPW_qual"]="$DATA/GPW4/generated/gpw-v4-data-quality-indicators-mean-administrative-unit-area/ubergrid"
LAYERS["LULC"]="$DATA/MODIS_LULC/generated/yearly/dummy/ubergrid"
LAYERS["CRU"]="$DATA/CRU/generated/yearly/ubergrid"
LAYERS["boundaries"]="$DATA/boundaries/generated/ubergrid"

MAX_JOBS=8
job_count=0

for tag in "${!LAYERS[@]}"; do
    dir="${LAYERS[$tag]}"
    ascii_dir="$dir/ascii"
    table_dir="$dir/table"
    [ -d "$ascii_dir" ] || continue
    [ -d "$table_dir" ] || continue

    for ascii_file in "$ascii_dir"/*.txt; do
        [ -f "$ascii_file" ] || continue
        base=$(basename "$ascii_file")
        table_file="$table_dir/$base"
        [ -f "$table_file" ] || continue

        check_pair "$ascii_file" "$table_file" "$tag" "$base" &
        job_count=$(( job_count + 1 ))
        if (( job_count % MAX_JOBS == 0 )); then
            wait
        fi
    done
done
wait

# --- assemble output ---
{
    printf "ASCII vs TABLE cross-check -- all layers, all cities\n"
    printf "Run date: 2026-07-11\n"
    printf "Cities checked:\n"
    printf "  St. Petersburg  row 301 col 2525  uber_code 1298525  ASCII line 307\n"
    printf "  New York        row 532 col 1272  uber_code 2295192  ASCII line 538\n"
    printf "  Tokyo           row 592 col 3836  uber_code 2556956  ASCII line 598\n"
    printf "  Cape Town      row 1428 col 2382  uber_code 6167022  ASCII line 1434\n"
    printf "\n"
    printf "%-12s\t%-45s\t%-12s\t%-12s\t%-12s\t%-12s\t%-12s\t%-12s\t%-12s\t%-12s\t%s\n" \
        "LAYER" "FILE" \
        "StP_asc" "NYC_asc" "Tok_asc" "CPT_asc" \
        "StP_tbl" "NYC_tbl" "Tok_tbl" "CPT_tbl" \
        "MATCH"
    # Sort results by layer and filename for readability
    sort "$TMP"/*.result
} > "$OUT"

rm -rf "$TMP"
echo "Done. Results in: $OUT"
