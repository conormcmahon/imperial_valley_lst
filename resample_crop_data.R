
# Resample crop data up to the resolution of MODIS

library(terra)

# Load crop data
crops <- terra::rast("D:/imperial_valley_ag_heat/crops/CDL_datasets/CDS_coarse_imperial_valley.tif", lyrs=10:26)
# For some reason, my version of Proj can't find epsg:5070 - so use a manual definition: 
crs(crops) <- "+proj=aea +lat_0=23 +lon_0=-96 +lat_1=29.5 +lat_2=45.5 +x_0=0 +y_0=0 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs +type=crs"

# Load an example MODIS LST scene
MODIS <- terra::rast("D:/imperial_valley_ag_heat/modis_weekly_averages/doy_000_aqua_day_regression_week_avg.tif", lyrs=1)

# Get raster with fraction of each MODIS pixel in a target class at the finer resolution of the crop mask
getCropFraction <- function(index, target_class, secondary_class=0)
{
  # Mask to pixels which are in either of two target classes
  masked_area = (crops[[index]]==target_class)+(crops[[index]]==secondary_class)
  # Aggregate up to MODIS scale, taking average of binary mask
  reprojected = terra::project(masked_area, MODIS, method="average")
  # Trim to remove NA values around edges and return 
  return(trim(reprojected))
}

# Crop fields area (either as row crops or fallow fields)
crop_fields_area <- terra::rast(lapply(1:dim(crops)[[3]],
                            getCropFraction, 
                            target_class=1, secondary_class=3))
writeRaster(crop_fields_area, "D:/imperial_valley_ag_heat/crops/CDL_datasets/crop_field_areas_annual.tif", overwrite=TRUE)

# Cropped area (either as row crops or fallow fields)
cropped_area <- terra::rast(lapply(1:dim(crops)[[3]],
                                   getCropFraction, 
                                   target_class=1, secondary_class=-1))
writeRaster(cropped_area, "D:/imperial_valley_ag_heat/crops/CDL_datasets/crop_areas_annual.tif", overwrite=TRUE)

# Orchard area 
orchard_area <- terra::rast(lapply(1:dim(crops)[[3]],
                                   getCropFraction, 
                                   target_class=2, secondary_class=-1))
writeRaster(orchard_area, "D:/imperial_valley_ag_heat/crops/CDL_datasets/orchard_areas_annual.tif", overwrite=TRUE)

# Any agriculture area 
agricultural_area <- orchard_area + crop_fields_area
writeRaster(agricultural_area, "D:/imperial_valley_ag_heat/crops/CDL_datasets/agriculture_areas_annual.tif", overwrite=TRUE)

# Urban area 
urban_area <- terra::rast(lapply(1:dim(crops)[[3]],
                                   getCropFraction, 
                                   target_class=4, secondary_class=-1))
writeRaster(urban_area, "D:/imperial_valley_ag_heat/crops/CDL_datasets/urban_areas_annual.tif", overwrite=TRUE)

# Natural area 
natural_area <- terra::rast(lapply(1:dim(crops)[[3]],
                                   getCropFraction, 
                                   target_class=5, secondary_class=-1))
writeRaster(natural_area, "D:/imperial_valley_ag_heat/crops/CDL_datasets/natural_areas_annual.tif", overwrite=TRUE)

# Water area 
water_area <- terra::rast(lapply(1:dim(crops)[[3]],
                                 getCropFraction, 
                                 target_class=6, secondary_class=-1))
writeRaster(water_area, "D:/imperial_valley_ag_heat/crops/CDL_datasets/water_areas_annual.tif", overwrite=TRUE)


# Get average frational area in each class over the whole period
average_classes <- c(sum(cropped_area)/dim(crops)[[3]],
                     sum(orchard_area)/dim(crops)[[3]],
                     sum(crop_fields_area-cropped_area)/dim(crops)[[3]],
                     sum(urban_area)/dim(crops)[[3]],
                     sum(natural_area)/dim(crops)[[3]],
                     sum(water_area)/dim(crops)[[3]])
names(average_classes) <- c("crop", "orchard", "fallow", "urban", "natural", "water")
writeRaster(average_classes, "D:/imperial_valley_ag_heat/crops/CDL_datasets/class_averages.tif", overwrite=TRUE)


# Get maps of sites which were usually one class
mostly_crops <- (average_classes[[1]]+average_classes[[3]]) > 0.8
mostly_orchards <- average_classes[[2]] > 0.8
mostly_ag <- mostly_crops + mostly_orchards
mostly_urban <- average_classes[[4]] > 0.8
terra::writeRaster(mostly_crops, "D:/imperial_valley_ag_heat/crops/CDL_datasets/usually_crops.tif", overwrite=TRUE)
terra::writeRaster(mostly_crops, "D:/imperial_valley_ag_heat/crops/CDL_datasets/usually_crops_envi", filetype="ENVI", overwrite=TRUE)
terra::writeRaster(mostly_orchards, "D:/imperial_valley_ag_heat/crops/CDL_datasets/usually_orchard.tif", overwrite=TRUE)
terra::writeRaster(mostly_orchards, "D:/imperial_valley_ag_heat/crops/CDL_datasets/usually_orchard_envi", filetype="ENVI", overwrite=TRUE)
terra::writeRaster(mostly_ag, "D:/imperial_valley_ag_heat/crops/CDL_datasets/usually_ag.tif", overwrite=TRUE)
terra::writeRaster(mostly_ag, "D:/imperial_valley_ag_heat/crops/CDL_datasets/usually_ag_envi", filetype="ENVI", overwrite=TRUE)
terra::writeRaster(mostly_urban, "D:/imperial_valley_ag_heat/crops/CDL_datasets/usually_urban.tif", overwrite=TRUE)
terra::writeRaster(mostly_urban, "D:/imperial_valley_ag_heat/crops/CDL_datasets/usually_urban_envi", filetype="ENVI", overwrite=TRUE)


