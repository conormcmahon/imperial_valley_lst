
# ******************************************
# For a list of MODIS files (Terra and Aqua, day and night)
# For each day of the year in the ~22-year data record
# Regress land surface temperature vs. year to track climtic trends
# Output is 4 * 366 files with 6 bands for the regression:
#    slope
#    intercept
#    r, correlation coefficient 
#    p-value
#    standard error
#    n, number of values used in regression (after cloud filters, etc.)

import numpy as np
import rasterio as rio
import rioxarray as rxr
import xarray as xa
import glob
import scipy

# User Parameters
data_directory = "D:/imperial_valley_ag_heat/modis_change_test/"

# Function to compute linear regression between residual values and years
#   Returns, for each pixel and day-of-year, in this order:
#      slope, intercept, r value, p-value, standard error, and number of good scenes
def residual_linregress(residual, years):
    # Mask out NaN values
    years = np.array(years).astype(float)
    mask = ~np.isnan(residual) & ~np.isnan(years)
    # If all data are masked (all NaN, no good observations in any year) then return 5 NaN values
    num_good_values = np.sum(mask)
    if(num_good_values < 2):
        return np.array([np.nan, np.nan, np.nan, np.nan, np.nan, num_good_values])
    # Wrapper around scipy linregress to use in apply_ufunc
    slope, intercept, r_value, p_value, std_err = scipy.stats.linregress(years[mask], residual[mask])
    return np.array([slope, intercept, r_value, p_value, std_err, num_good_values])

# Search parameters to find MODIS files in data_directory
#   Define list of search patterns for each combination of MODIS imagery
search_patterns = [data_directory + "lst_day_????_aqua_out_366_resid",          # Aqua Daytime
                   data_directory + "lst_night_????_aqua_out_366_resid",        # Aqua Nighttime
                   data_directory + "lst_day_????_out_366_resid",               # Terra Daytime
                   data_directory + "lst_night_????_out_366_resid"]             # Aqua Nighttime
output_names = ["_aqua_day_regression.tif",
                "_aqua_night_regression.tif",
                "_terra_day_regression.tif",
                "_terra_night_regression.tif"]

# ******* Run all regressions *******
# Iterate over 
for ind in range(0,4):
    # Get list of all files
    residual_filenames = glob.glob(search_patterns[ind])

    # Open one file to reference CRS and coordinates
    example_file = rxr.open_rasterio(residual_filenames[0])

    print("\nFirst, working on Terra Daytime imagery (10:30 AM)")
    print("  Found ", len(residual_filenames), "files.")

    # For each day-of-year, fit a linear regression predicting change in land surface temperature vs. year in the dataset
    for day in range(0,366): #366):
        print("\nBeginning to work on day of year ", day, " with pattern ", search_patterns[ind])
        
        all_years = []  
        year_names = []

        # Load a particular year's data
        for filename in residual_filenames:
            # Get year from filename
            file_basename = filename.split("\\")[-1]
            file_year = file_basename.split("_")[2]
            # Load raster data
            residual_img = rxr.open_rasterio(filename)[day,:,:]
            # Fill 0 values with NA
            residual_img.data[residual_img.data == 0] = np.nan
            # Add year as a coordinate for timeseries analysis
            residual_img.assign_coords(year = file_year)
            residual_img.expand_dims(dim="year")
            # Add the new data to the list
            all_years.append(residual_img.data) 
            year_names.append(file_year)
        
        # Stack data into an rioxarray
        all_years_stack = xa.DataArray(all_years, coords={'y':example_file['y'].values, 'x':example_file['x'].values, 'year':year_names}, dims=['year', 'y', 'x'])
        all_years_stack.rio.write_crs(example_file.rio.crs, inplace=True)
        
        # Apply a linear regression over 'year' dimension of input raster
        #   Code based on https://github.com/pydata/xarray/issues/1815#issuecomment-614216243
        one_year_mean = xa.apply_ufunc(residual_linregress, all_years_stack,
                        input_core_dims=[['year']],
                        output_core_dims=[["parameter"]],
                        kwargs={"years": year_names},
                        vectorize=True,
                        dask="parallelized",
                        output_dtypes=['float64'],
                        dask_gufunc_kwargs={"parameter": 6},
                        )
        # Transpose data to have bands first
        one_year_mean = one_year_mean.transpose('parameter','y','x')
        # Update band names
        one_year_mean.attrs['long_name'] = ['slope', 'intercept', 'r_value', 'p_value', 'std_err', 'number_good_scenes']
        # Update coordinate reference system
        one_year_mean.rio.write_crs(example_file.rio.crs, inplace=True)
        # Write raster to disk
        one_year_mean.rio.to_raster(data_directory + "doy_" + str(day).zfill(3) + output_names[ind]) 

        print("   Finished computing regression for day of year ", day)

