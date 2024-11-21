

# QC Documentation in Table 5 here: https://lpdaac.usgs.gov/documents/624/MOD15_User_Guide_V6.pdf
#   bit 0: 0-> good quality, 1-> other quality
#   bit 1: 0-> Terra, 1-> Aqua
#   bit 2: 0-> detectors mostly fine, 1-> some dead detectors
#   bit 3-4: 0-> clear, 1-> significant clouds, 2-> mixed clouds, 3-> cloud state undefined, assumed clear
#   bit 5-7:
# For our use case, keep only cases where bits 5-7 have value = 000 (main method succeeded)
maskFromQC <- function(img)
{
  # Function to get values in bits 5-7
  bit57 <- function(x){bitwShiftR(bitwAnd(x, 2^5+2^6+2^7), 5)}
  # Apply function -> generates image ranging from 0 to 8 for values of bits 5-7
  SCF_QC <- terra::app(img, bit57)
  # Filter to only cases where main algorithm succeeded (0-value)
  return(SCF_QC == 0)
}
# Cloud State 
cloudState <- function(img)
{
  # Function to get values in bits 3-4
  bit34 <- function(x){bitwShiftR(bitwAnd(x, 2^3+2^4), 3)}
  # Apply function -> generates image ranging from 0 to 8 for values of bits 5-7
  cloud_state <- terra::app(img, bit34)
  # Filter to only cases where main algorithm succeeded (0-value)
  return(cloud_state)
}


crop_mask <- terra::rast("D:/imperial_valley_ag_heat/crops/CDL_datasets/usually_ag.tif")
crop_mask[is.na(crop_mask)] <- 0
urban_mask <- terra::rast("D:/imperial_valley_ag_heat/crops/CDL_datasets/usually_urban.tif")
urban_mask[is.na(urban_mask)] <- 0

aqua_day_slopes_rast <- terra::rast("D:/imperial_valley_ag_heat/modis_weekly_averages/slope_significant_aqua_day_regression_week_avg.tif")
aqua_day_slopes_rast <- crop(aqua_day_slopes_rast, crop_mask)

aqua_day_slopes_df <- as.data.frame(values(c(aqua_day_slopes_rast,
                                             crop_mask,
                                             urban_mask)))
names(aqua_day_slopes_df) <- c(paste("week_", 1:52, sep=""),
                               "crop",
                               "urban")

aqua_day_crops <- aqua_day_slopes_df %>% filter(crop==1)
aqua_day_urban <- aqua_day_slopes_df %>% filter(urban==1)

# Pivot to a 'longer' format where week is a variable and each week is a different observation
aqua_day_slopes_longer <- aqua_day_slopes_df %>% 
  pivot_longer(1:52, 
               names_to = "week_str",
               values_to = "slope") %>%
  mutate(week = as.numeric(substr(week_str, 6, 7))) %>%
  dplyr::select(-week_str) %>%
  mutate(class = c("crop", "urban", "natural")[3-2*crop-urban])

# Get average significant trend in urban and crop pixels in each week 
aqua_day_summaries <- aqua_day_slopes_longer %>% 
  group_by(class, week) %>% 
  summarize(mean_slope = mean(slope, na.rm=TRUE), 
            sd_slope = sd(slope, na.rm=TRUE), 
            frac_sig = sum(!is.na(slope))/n())

# Plot mean trends
ggplot(aqua_day_summaries %>% filter(class!="natural")) + 
  geom_line(aes(x=week, y=mean_slope)) + 
  geom_line(aes(x=week, y=mean_slope-sd_slope), col="gray") + 
  geom_line(aes(x=week, y=mean_slope+sd_slope), col="gray") + 
  facet_wrap(~class) + 
  theme_bw() + 
  geom_hline(yintercept = 0) + 
  xlab("Week") + 
  ylab("Mean Slope") 

Plot fraction of pixels with trends
ggplot(aqua_day_summaries %>% filter(class!="natural")) + 
  geom_line(aes(x=week, y=frac_sig)) + 
  facet_wrap(~class) + 
  theme_bw() + 
  geom_hline(yintercept = 0) + 
  xlab("Week") + 
  ylab("Mean Slope") 


