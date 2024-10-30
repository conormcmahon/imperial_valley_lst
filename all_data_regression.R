

# Quick test of whether we can get good relationships fitting ALL data together across days

library(terra)
library(tictoc)
library(tidyverse)
library(RobustLinearReg)

file_list <- list.files("D:/imperial_valley_ag_heat/modis_weekly_averages/", 
                        pattern = "lst_day.*aqua_out_366_resid_week_avg$", 
                        full.names = TRUE)


# Get list of years 
#    Split list of filenames by '_' character, then pick the one corresponding to year in our file naming scheme
#    Index will need to be manually changed for other filesystems
years <- unlist(lapply(strsplit(file_list, "_"), 
                       function(str_list){ 
                         return(str_list[[8]]) 
                       }))
years <- as.numeric(years)
data_width <- length(years)*52

# Load all imagery from target day of year into one raster
lst_imagery <- lapply(file_list, 
                      function(filename){
                        return(terra::rast(filename))                        
                      })
lst_imagery <- terra::rast(lst_imagery)
names(lst_imagery) <- paste("year_", 
                            unlist(lapply(years, function(year){return(rep(year,52))})), 
                            "_week_", 
                            rep(1:52, length(years)), 
                            sep="")

#target_coords <- rbind(c(-115.466, 33.103))
target_coords <- rbind(c(-115.562, 32.788))
target_point <- vect(target_coords, crs="+proj=longlat +datum=WGS84")

target_timeseries <- terra::extract(lst_imagery, target_point) %>%
  pivot_longer(2:(data_width+1), 
               names_to = "time_str",
               values_to = "lst") %>%
  mutate(year = as.numeric(substr(time_str,6,9)),
         week = as.numeric(substr(time_str,16,17))) %>%
  mutate(year_frac = year + week/52)

ggplot(target_timeseries) + 
  geom_point(aes(x=year_frac, y=lst)) + 
  scale_y_continuous(limits=c(-10,10))
Sys.sleep(2)
ggplot(target_timeseries %>% filter(week > 20, week < 40)) + 
  geom_point(aes(x=year_frac, y=lst)) + 
  scale_y_continuous(limits=c(-10,10))

target_timeseries <- target_timeseries %>%
  filter(lst > -15, lst < 15)

summary(lm(data=target_timeseries %>% filter(week > 20, week < 40), lst ~ year + week))


