# ---------------------------------------------------------------------------
# EPA_AQS_worker.py  [WORKER -- imports arcpy; called by propy.bat]
# Description: Convert one year of EPA AQS PM2.5 station data to an
# uber_grid-aligned raster.
# Called by EPA_AQS.py via propy.bat; NOT called by Stata directly.
#
# Approach: Because station data and the uber_grid are both in WGS84, cell
# assignment is exact arithmetic (no projection or snapping needed).
#   1. Read CSV, filter for Parameter Code 88101 (FRM/FEM PM2.5).
#   2. Assign each station to its uber_grid cell by formula from settings.txt.
#   3. Average PM2.5 within each cell.
#   4. Write an ASCII grid (ESRI format).
#   5. arcpy: ASCIIToRaster -> DefineProjection (WGS84).
# No feature classes, GDB, PointToRaster, or spatial operations required.
#
# Arguments: csv_path  output_raster
#
# Created 2026-08-31.
# ---------------------------------------------------------------------------

import csv, datetime, os, sys, time

# Write a per-worker log before importing arcpy.
_pid = os.getpid()
os.makedirs("temp", exist_ok=True)
_logpath = "temp/worker_%d.log" % _pid

def _wlog(msg):
    line = datetime.datetime.now().strftime("%H:%M:%S") + " " + msg
    print(line, flush=True)
    with open(_logpath, "a") as f:
        f.write(line + "\n")

_wlog("Worker started (PID %d) -- about to import arcpy" % _pid)

import arcpy

_wlog("arcpy imported successfully")

# Give each worker its own scratch workspace.
_scratch = os.path.abspath("temp/scratch_%d" % _pid)
os.makedirs(_scratch, exist_ok=True)
arcpy.env.scratchWorkspace = _scratch
arcpy.env.workspace        = _scratch
arcpy.env.overwriteOutput  = True
arcpy.env.pyramid          = "NONE"
arcpy.env.rasterStatistics = "NONE"
_wlog("Scratch workspace: " + _scratch)


def read_ubergrid_settings():
    # Read settings.txt (same relative path used by rasters.py).
    # Returns a dict with keys: LEFT, RIGHT, TOP, BOTTOM, CELLSIZEX,
    # CELLSIZEY, COLUMNCOUNT, ROWCOUNT (all as raw strings).
    settings_path = "../../../data/projections/generated/settings.txt"
    d = {}
    with open(settings_path, 'r') as f:
        lines = [ln.rstrip('\n') for ln in f.readlines()]
    for i in range(0, len(lines) - 1, 2):
        d[lines[i].strip()] = lines[i + 1].strip()
    return d


def run_convert(csv_path, output_raster):
    # Assigns each PM2.5 station to an uber_grid cell and averages within cell.
    # Returns True on success, False on failure.
    try:
        _wlog("Reading uber_grid settings")
        s      = read_ubergrid_settings()
        LEFT   = float(s['LEFT'])
        TOP    = float(s['TOP'])
        CSIZE  = float(s['CELLSIZEX'])
        NCOLS  = int(s['COLUMNCOUNT'])
        NROWS  = int(s['ROWCOUNT'])
        _wlog("Grid: %d cols x %d rows, cell=%.8f, LEFT=%.1f TOP=%.1f" % (
              NCOLS, NROWS, CSIZE, LEFT, TOP))

        # --- Steps 1-3: read CSV, filter PM2.5 88101, assign cells, accumulate ---
        _wlog("Reading CSV: " + csv_path)
        cell_sums   = {}   # (row_idx, col_idx) -> sum of PM2.5 values
        cell_counts = {}   # (row_idx, col_idx) -> count of stations
        n_read = n_skipped_code = n_skipped_data = n_outside = 0

        with open(csv_path, 'r', newline='', encoding='utf-8', errors='replace') as f:
            reader = csv.DictReader(f)
            for row in reader:
                n_read += 1

                # Keep only Parameter Code 88101 (FRM/FEM PM2.5 primary standard).
                if row.get("Parameter Code", "").strip() != "88101":
                    n_skipped_code += 1
                    continue

                # Parse required numeric fields; skip if missing or non-numeric.
                try:
                    lat  = float(row["Latitude"])
                    lon  = float(row["Longitude"])
                    pm25 = float(row["Arithmetic Mean"])
                except (ValueError, KeyError):
                    n_skipped_data += 1
                    continue

                # Assign station to uber_grid cell by arithmetic.
                # col: 0-indexed west->east; rw: 0-indexed top->bottom.
                col = int((lon - LEFT) / CSIZE)
                rw  = int((TOP  - lat) / CSIZE)

                # Clamp stations exactly on the right or bottom boundary.
                col = min(col, NCOLS - 1)
                rw  = min(rw,  NROWS - 1)

                # Discard stations outside the grid extent.
                if col < 0 or col >= NCOLS or rw < 0 or rw >= NROWS:
                    n_outside += 1
                    continue

                key = (rw, col)
                cell_sums[key]   = cell_sums.get(key,   0.0) + pm25
                cell_counts[key] = cell_counts.get(key, 0)   + 1

        n_stations = sum(cell_counts.values())
        n_cells    = len(cell_counts)
        _wlog("Rows read: %d  Skipped (not 88101): %d  Skipped (bad data): %d"
              "  Outside extent: %d" % (n_read, n_skipped_code, n_skipped_data, n_outside))
        _wlog("Stations used: %d  Uber_grid cells occupied: %d" % (n_stations, n_cells))

        if n_cells == 0:
            raise RuntimeError(
                "No PM2.5 stations matched Parameter Code 88101 in: " + csv_path)

        # --- Step 4: write ASCII grid (top->bottom, left->right) ---
        asc_path = os.path.join(_scratch, "aqs_%d.asc" % _pid)
        NODATA = -9999
        _wlog("Writing ASCII raster (%d rows x %d cols): %s" % (NROWS, NCOLS, asc_path))

        with open(asc_path, 'w') as asc:
            # Header: YLLCORNER is the y coordinate of the bottom edge of the grid.
            asc.write("NCOLS %d\n"        % NCOLS)
            asc.write("NROWS %d\n"        % NROWS)
            asc.write("XLLCORNER %s\n"    % s['LEFT'])
            asc.write("YLLCORNER %s\n"    % s['BOTTOM'])
            asc.write("CELLSIZE %s\n"     % s['CELLSIZEX'])
            asc.write("NODATA_VALUE %d\n" % NODATA)

            # Data: one line per row, space-separated floats, top-to-bottom.
            for rw in range(NROWS):
                vals = []
                for col in range(NCOLS):
                    key = (rw, col)
                    if key in cell_sums:
                        vals.append("%.6f" % (cell_sums[key] / cell_counts[key]))
                    else:
                        vals.append("-9999")
                asc.write(" ".join(vals) + "\n")

        _wlog("ASCII raster written (%d bytes)" % os.path.getsize(asc_path))

        # --- Steps 5-6: convert ASCII to TIF and assign WGS84 projection ---
        out_dir = os.path.dirname(os.path.abspath(output_raster))
        os.makedirs(out_dir, exist_ok=True)

        _wlog("Converting ASCII to raster: " + output_raster)
        arcpy.ASCIIToRaster_conversion(asc_path, output_raster, "FLOAT")

        _wlog("Defining projection (WGS84 / EPSG:4326)")
        arcpy.management.DefineProjection(output_raster, arcpy.SpatialReference(4326))

        _wlog("Done: " + output_raster)
        return True

    except Exception as e:
        _wlog("ERROR: " + str(e))
        return False


if __name__ == "__main__":
    csv_path      = sys.argv[1]
    output_raster = sys.argv[2]

    t0 = time.process_time()
    success = run_convert(csv_path, output_raster)
    elapsed = time.process_time() - t0

    print("[%s] completed in %.1fs. success=%s" % (
        os.path.basename(output_raster), elapsed, str(success)))

    sys.exit(0 if success else 1)
