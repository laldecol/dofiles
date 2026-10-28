# ---------------------------------------------------------------------------
# diagnose_nc.py
# Prints variable and dimension names from the Van Donkelaar NetCDF files.
# Run with the particulatespy environment from the van_donkelar/ directory:
#   python diagnose_nc.py
# ---------------------------------------------------------------------------

import os, sys

source_dir = "../../../data/VanDonkelar_annual/source"
nc_files = sorted(f for f in os.listdir(source_dir) if f.endswith('.nc'))
if not nc_files:
    print("No .nc files found in " + source_dir)
    sys.exit(1)

# Try with the first file only -- all three have the same structure.
nc_path = os.path.join(source_dir, nc_files[0])
print("Inspecting: " + nc_path)
print()

# Method 1: netCDF4 package (usually available in ArcGIS Pro conda env)
try:
    import netCDF4
    ds = netCDF4.Dataset(nc_path)
    print("=== netCDF4 ===")
    print("Dimensions:")
    for name, dim in ds.dimensions.items():
        print("  %s  (size %d)" % (name, len(dim)))
    print("Variables:")
    for name, var in ds.variables.items():
        print("  %s  shape=%s  dims=%s" % (name, var.shape, var.dimensions))
    ds.close()
    sys.exit(0)
except ImportError:
    print("netCDF4 not available, trying scipy...")

# Method 2: scipy (also often available)
try:
    from scipy.io import netcdf_file
    ds = netcdf_file(nc_path, 'r', mmap=False)
    print("=== scipy ===")
    print("Dimensions:", list(ds.dimensions.keys()))
    print("Variables:")
    for name, var in ds.variables.items():
        print("  %s  shape=%s  dims=%s" % (name, var.shape, var.dimensions))
    ds.close()
    sys.exit(0)
except ImportError:
    print("scipy not available, trying arcpy probe...")

# Method 3: probe arcpy MakeNetCDFRasterLayer with common alternatives
import arcpy

candidates = [
    ("PM25",   "lon",       "lat"),
    ("PM25",   "longitude", "latitude"),
    ("PM25",   "LON",       "LAT"),
    ("GWRPM25","lon",       "lat"),
    ("GWRPM25","longitude", "latitude"),
    ("PM2.5",  "lon",       "lat"),
    ("PM2.5",  "longitude", "latitude"),
]

print("=== arcpy probe (trying common variable/dimension combinations) ===")
for var, xdim, ydim in candidates:
    try:
        arcpy.md.MakeNetCDFRasterLayer(nc_path, var, xdim, ydim, "probe_layer")
        print("SUCCESS: variable=%r  x_dimension=%r  y_dimension=%r" % (var, xdim, ydim))
        arcpy.management.Delete("probe_layer")
        break
    except Exception as e:
        print("FAIL:    variable=%r  x=%r  y=%r  -- %s" % (var, xdim, ydim, str(e).splitlines()[0]))
