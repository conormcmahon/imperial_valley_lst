
library(tidyverse)
library(janitor)
library(terra)

# Station Cutoff Requirement
station_requirement <- 10


# Load existing data from Dexter and Riley

all_data <- read_csv("D:/imperial_valley_ag_heat/air_temperature_model/modis_sept_version_predicted.csv") %>% 
  mutate(year = as.numeric(substr(date, 1,4)),
         month = as.numeric(substr(date, 6,7)),
         day = as.numeric(substr(date, 9,10)))
dates <- sort(unique(all_data$date))
# Function which gets the correlation (r) between two variables after removing the NA values
getRSqdWithoutNA <- function(x, y)
{
  # Check where each input vector is finite
  valid_x <- !is.na(x)
  valid_y <- !is.na(y)
  valid_both <- (valid_x * valid_y) == 1
  # If too few values are finite and good, return a NA
  if(sum(valid_both) < 3)
    return(NA)
  # Otherwise, get correlation between good values
  return(cor(x[which(valid_both)], y[which(valid_both)]))
}

# Function which gets the correlation (r) between two variables after removing the NA values
getSlopeWithoutNA <- function(x, y)
{
  # Check where each input vector is finite
  valid_x <- !is.na(x)
  valid_y <- !is.na(y)
  valid_both <- (valid_x * valid_y) == 1
  # If too few values are finite and good, return a NA
  if(sum(valid_both) < 3)
    return(NA)
  # Otherwise, get correlation between good values
  linmod <- lm(y[valid_both] ~ x[valid_both])
  return(summary(linmod)$coefficients[2,1])
}
# Function which gets the significance level (p) between two variables after removing the NA values
getpValueWithoutNA <- function(x, y)
{
  # Check where each input vector is finite
  valid_x <- !is.na(x)
  valid_y <- !is.na(y)
  valid_both <- (valid_x * valid_y) == 1
  # If too few values are finite and good, return a NA
  if(sum(valid_both) < 3)
    return(NA)
  # Otherwise, get p.value between good values
  linmod <- lm(y[valid_both] ~ x[valid_both])
  return(summary(linmod)$coefficients[2,4])
}

# Test correlation between MODIS LST and air temperature within a day/time pairing at stations
daily_summary <- all_data %>%
  group_by(date, time, sat) %>%
  summarize(count = sum((!is.na(air))*(!is.na(predicted_air))),
            correlation = getRSqdWithoutNA(predicted_air, air),
            slope = getSlopeWithoutNA(predicted_air, air),
            p.value = getpValueWithoutNA(predicted_air, air),
            rmse = sqrt(mean(error**2)),
            bias = mean(error),
            season = season[1],
            year = mean(year),
            month = mean(month),
            day = mean(day))
# Summary of Summaries
satellite_summary <- daily_summary %>%
  filter(count >= station_requirement) %>%
  group_by(time, sat) %>% 
  summarize(mean_corr = mean(correlation, na.rm=TRUE),
            std_corr = sd(correlation, na.rm=TRUE),
            mean_slope = mean(slope, na.rm=TRUE),
            std_slope = sd(slope, na.rm=TRUE),
            median_p.value = median(p.value, na.rm=TRUE),
            significant_05 = sum(p.value <= 0.05, na.rm=TRUE) / sum(!is.na(p.value)),
            significant_10 = sum(p.value <= 0.10, na.rm=TRUE) / sum(!is.na(p.value)),
            rmse_mean = mean(rmse, na.rm=TRUE),
            corr_frac_valid = sum(!is.na(correlation))/length(correlation))
satellite_summary_seasonal <- daily_summary %>%
  filter(count >= station_requirement) %>%
  group_by(time, sat, season) %>% 
  summarize(mean_corr = mean(correlation, na.rm=TRUE),
            std_corr = sd(correlation, na.rm=TRUE),
            mean_slope = mean(slope, na.rm=TRUE),
            std_slope = sd(slope, na.rm=TRUE),
            median_p.value = median(p.value, na.rm=TRUE),
            significant_05 = sum(p.value <= 0.05, na.rm=TRUE) / sum(!is.na(p.value)),
            significant_10 = sum(p.value <= 0.10, na.rm=TRUE) / sum(!is.na(p.value)),
            rmse_mean = mean(rmse, na.rm=TRUE),
            corr_frac_valid = sum(!is.na(correlation))/length(correlation))
satellite_summary_seasonal %>%
  mutate(season = factor(season, levels=c('winter','spring','summer','fall')),
         sat = factor(sat, levels=c('terra', 'aqua'))) %>%
  arrange(time, sat, season) %>%
  select(time, sat, season, mean_corr, mean_slope, significant_05)

# Seasonal Variation in Correlation by Satellite
ggplot(satellite_summary_seasonal) + 
  geom_line(aes(x=factor(season, levels=c('winter','spring','summer','fall')), 
                y=mean_corr,
                group=paste(sat, time),
                col=paste(sat, time)), size=1) + 
  geom_hline(yintercept=0, linetype="dashed") + 
  scale_y_continuous(limits=c(0,1), expand=c(0,0)) + 
  theme_bw() + 
  xlab("Season") + 
  ylab("Correlation") + 
  ggtitle("Correlation Between Predicted and Measured Air Temperature - Average Daily Values")


# Overall Variation in Correlation by Satellite, in summer
season_choice <- "spring"
ggplot() + 
  geom_histogram(data=daily_summary %>% filter(season==season_choice),
                 aes(x=correlation), alpha=0.5) + 
  geom_vline(data=satellite_summary_seasonal %>% filter(season==season_choice), 
             aes(xintercept=mean_corr)) + 
  geom_vline(data=satellite_summary_seasonal %>% filter(season==season_choice), 
             aes(xintercept=mean_corr+std_corr), linetype="dashed") + 
  geom_vline(data=satellite_summary_seasonal %>% filter(season==season_choice), 
             aes(xintercept=mean_corr-std_corr), linetype="dashed") + 
  facet_wrap(~time+sat) + 
  scale_x_continuous(limits=c(-1,1), expand=c(0,0)) +
  scale_y_continuous(expand=c(0,0)) + 
  theme_bw() +
  xlab("Correlation") + 
  ylab("Frequency") + 
  ggtitle('Springtime Correlations - Predicted vs. Actual Air Temperature')




