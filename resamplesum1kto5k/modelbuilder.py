# -*- coding: utf-8 -*-
# ---------------------------------------------------------------------------
# modelbuilder.py
# Created on: 2016-09-23 16:04:39.00000
#   (generated by ArcGIS/ModelBuilder)
# Description: 
# ---------------------------------------------------------------------------

# Import arcpy module
import arcpy

# Check out any necessary licenses
arcpy.CheckOutExtension("spatial")


# Local variables:
gpw_v4_population_count_2000_tif = "\\..\\..\\..\\data\\GPW4\\source\\gpw-v4-population-count-2000\\gpw-v4-population-count_2000.tif"
projected_gpw_v4_population_count_2000_tif = "\\..\\..\\..\\data\\GPW4\\generated\\projected_gpw-v4-population-count_2000.tif"
gpwagg2000 = "..\\..\\..\\data\\manual\\gpwagg2000"
gpwaggclp = "..\\..\\..\\data\\manual\\gpwaggclp"
gpwacproj = "S..\\..\\..\\data\\manual\\gpwacproj"

# Process: Aggregate
arcpy.gp.Aggregate_sa(gpw_v4_population_count_2000_tif, gpwagg2000, "5", "SUM", "EXPAND", "DATA")

# Process: Clip
arcpy.Clip_management(gpwagg2000, "-179.999988540844 -60.0080243043874 179.999861570054 85.0000000000092", gpwaggclp, projected_gpw_v4_population_count_2000_tif, "", "NONE", "MAINTAIN_EXTENT")

# Process: Project Raster
arcpy.ProjectRaster_management(gpwaggclp, gpwacproj, "PROJCS['World_Cylindrical_Equal_Area',GEOGCS['GCS_WGS_1984',DATUM['D_WGS_1984',SPHEROID['WGS_1984',6378137.0,298.257223563]],PRIMEM['Greenwich',0.0],UNIT['Degree',0.0174532925199433]],PROJECTION['Cylindrical_Equal_Area'],PARAMETER['False_Easting',0.0],PARAMETER['False_Northing',0.0],PARAMETER['Central_Meridian',0.0],PARAMETER['Standard_Parallel_1',0.0],UNIT['Meter',1.0]]", "NEAREST", projected_gpw_v4_population_count_2000_tif, "", "", "GEOGCS['GCS_WGS_1984',DATUM['D_WGS_1984',SPHEROID['WGS_1984',6378137.0,298.257223563]],PRIMEM['Greenwich',0.0],UNIT['Degree',0.0174532925199433]]")

