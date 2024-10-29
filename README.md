# Imperial Valley - Land Surface Temperature MODIS Investiation

Interrogating long-term change and spatial patterns of Land Surface Temperature in Imperial Valley, CA using MODIS satellite imagery.

Currently, takes list of annual files with 366 bands (one for each day of year) containing residuals away from long-term mean land surface temperature for each pixel and day. Computes linear regressions between temperature residual and year to look for long-term trends.

Run lst_residual_patterns.py first, which runs the regressions. Then lst_residual_aggregation.py builds the regression data into an easier format with one file for each sensor and time of day. 
