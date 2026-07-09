# ---------------------------------------------------------------------------
# ftp2rasterLULC_worker.py  [WORKER -- imports arcpy; called by propy.bat]
# Description: Reclassifies LULC raster for one year into 7 dummy rasters.
# Called by ftp2rasterLULC.py via propy.bat; NOT called by Stata directly.
#
# Created 2026-07-06 as part of py3/ArcGIS Pro refactor.
# Previous single-file version saved in _old/ftp2rasterLULC.py.
# ---------------------------------------------------------------------------

import sys, os
sys.path.append(os.path.abspath('..'))

import arcpy, logging, math, shutil, time
import mylibrary

arcpy.CheckOutExtension("spatial")
arcpy.env.overwriteOutput = True

def yearlyconverter(year):
    # Reclassifies the LULC raster for one year into 7 dummy rasters
    # (one per land cover class), then aggregates each to match the ubergrid.

    output_raster = "../../../data/MODIS_LULC/generated/yearly/" + year + ".tif"

    temp_folder = os.path.dirname(output_raster) + "/temp" + year

    shutil.rmtree(temp_folder, ignore_errors=True)
    os.mkdir(temp_folder)
    print("Reclassifying LULC raster for year %s." % year)

    settingsdict = mylibrary.ubergridsettings()
    ubercol = settingsdict["COLUMNCOUNT"]
    uberrow = settingsdict["ROWCOUNT"]

    # Remap rules: one string per dummy category (water, trees, pasture, barren, crop, urban, other).
    # See ftp2rasterLULC/LULC_classes.xlsx for category definitions.
    remap = ["0 1;1 6 0;7 0;8 0;8 11 0;12 0;13 0;14 0;15 0;16 0;16 255 0",
             "0 0;1 6 1;7 0;8 1;8 11 0;12 0;13 0;14 0;15 0;16 0;16 255 0",
             "0 0;1 6 0;7 1;8 0;8 11 1;12 0;13 5;14 0;15 0;16 0;16 255 0",
             "0 0;1 6 0;7 0;8 0;8 11 0;12 0;13 0;14 0;15 0;16 1;16 255 0",
             "0 0;1 6 0;7 0;8 0;8 11 0;12 1;13 0;14 1;15 0;16 0;16 255 0",
             "0 0;1 6 0;7 0;8 0;8 11 0;12 0;13 1;14 0;15 0;16 0;16 255 0",
             "0 0;1 6 0;7 0;8 0;8 11 0;12 0;13 0;14 0;15 1;16 0;16 255 1"]

    try:
        for dummyval in range(0, 7):
            print("Creating dummy raster for value %s" % str(dummyval))

            dummytif = temp_folder + "/dummy" + str(dummyval) + ".tif"

            arcpy.gp.Reclassify_sa(output_raster,
                                   "Value",
                                   remap[dummyval],
                                   dummytif,
                                   "DATA")

            # Compute aggregation factors from input vs. ubergrid dimensions.
            desc = arcpy.Describe(dummytif)
            inputrow = desc.height
            inputcol = desc.width

            rowfactor = math.floor(int(inputrow) / int(uberrow))
            colfactor = math.floor(int(inputcol) / int(ubercol))

            print(str(rowfactor), str(colfactor))

            aggtiff = (os.path.dirname(output_raster) + "/dummy/" +
                       year + "_dummy" + str(dummyval) + ".tif")
            print("Aggregating dummy raster by a factor of %s" % str(colfactor))
            arcpy.gp.Aggregate_sa(dummytif, aggtiff, colfactor, "SUM", "EXPAND", "DATA")

        print("Cleaning up year %s." % year)
        shutil.rmtree(temp_folder, ignore_errors=True)
        return True

    except Exception as e:
        tb = sys.exc_info()[2]
        print("An error occured on line %i" % tb.tb_lineno)
        print(str(e))
        return False

if __name__ == "__main__":
    # Entry point when called by propy.bat from the orchestrator.
    year = sys.argv[1]

    t0 = time.process_time()
    success = yearlyconverter(year)
    elapsed = time.process_time() - t0
    print("[%s] completed in %.1fs. success=%s" % (year, elapsed, str(success)))

    sys.exit(0 if success else 1)
