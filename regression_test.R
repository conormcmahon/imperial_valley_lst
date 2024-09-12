
library(terra)

file_list <- list.files("D:/imperial_valley_ag_heat/modis_change_test/", 
                        pattern = "lst_day.*aqua_out_366_resid$", 
                        full.names = TRUE)

# target day of year
doy_target <- 240

# Get list of years 
#    Split list of filenames by '_' character, then pick the one corresponding to year in our file naming scheme
#    Index will need to be manually changed for other filesystems
years <- unlist(lapply(strsplit(file_list, "_"), 
                      function(str_list){ 
                        return(str_list[[8]]) 
                      }))
years <- as.numeric(years)

# Load all imagery from target day of year into one raster
lst_imagery <- lapply(file_list, 
                      function(filename){
                        return(terra::rast(filename, lyrs=doy_target))                        
                      })
lst_imagery <- terra::rast(lst_imagery)
names(lst_imagery) <- paste("year_", years, sep="")

# Apply a linear regression function
rasterLinreg <- function(y_values, x_values)
{
  # For our raster, NA or 0 are invalid
  mask <- (is.na(x_values) | (x_values==0)) | (is.na(y_values) | (y_values==0))
  
  if(sum(!mask) < 2)
    return(c(NA,NA,NA,NA,sum(!mask)))
  
  lin_mod <- lm(y_values[!mask] ~ x_values[!mask])
  
  return(c(summary(lin_mod)$coefficients[2,1],
           summary(lin_mod)$coefficients[1,1],
           summary(lin_mod)$adj.r.squared,
           summary(lin_mod)$coefficients[2,4],
           sum(!mask)))
}

tic()
test <- terra::app(lst_imagery, rasterLinreg, y_values=years)
timer_results <- toc()
