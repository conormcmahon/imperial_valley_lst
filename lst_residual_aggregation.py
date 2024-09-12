

# ******************************************
# Run after lst_residual_patterns.py
# Takes output regression data from that function, stacks them into single-file formats
# For each of MODIS Terra / Aqua, and Night / Day, creates 8 files:
#   slope
#   intercept
#   r, correlation coefficient
#   p-value
#   standard error
#   n, number of values used in the regression (after cloud masking, etc.)
#   slope, but masked to cases where p-value < 0.05
#   r, but masked to cases where p-value < 0.05
# Each file has 366 bands, which correspond to one day-of-year
# Values in that band show regression outputs for that day and sensor
# Result is 4 * 7 = 28 files

# Import required libraries
import numpy as np
import rasterio as rio
import rioxarray as rxr
import xarray as xa
import glob
import scipy

# Set output directory and file name search parameters for input files
output_directory = "D:/imperial_valley_ag_heat/modis/"
output_names = ["_aqua_day_regression.tif",
                "_aqua_night_regression.tif",
                "_terra_day_regression.tif",
                "_terra_night_regression.tif"]

# Now, aggregate all output files into one file for visualization
for output_name in output_names:
    # Get all files which match the pattern, in the specified directory
    regression_filenames = glob.glob(output_directory + "doy_???" + output_name)

    print("\nBeginning to work on group " + output_name)

    # Open file
    example_image = rxr.open_rasterio(regression_filenames[0])

    # Initialize output raster lists
    all_slopes = []  
    all_intercepts = []  
    all_r_sqd = []  
    all_p_value = []
    all_std_err_counts = []    
    all_day_counts = []  
    doys = []

    # Load a particular day of year's data
    for filename in regression_filenames:
        print("  Loading file " + filename)
        # Get day of year from filename
        file_basename = filename.split("\\")[-1]
        file_doy = file_basename.split("_")[1]
        # Load raster data
        residual_img = rxr.open_rasterio(filename)
        # Add day of year as a coordinate for timeseries analysis
        residual_img.assign_coords(doy = file_doy)
        residual_img.expand_dims(dim="doy")
        # Add the new data to the list
        all_slopes.append(residual_img.data[0,:,:]) 
        all_intercepts.append(residual_img.data[1,:,:]) 
        all_r.append(residual_img.data[2,:,:]) 
        all_p_value.append(residual_img.data[3,:,:]) 
        all_std_err_counts.append(residual_img.data[4,:,:]) 
        all_day_counts.append(residual_img.data[5,:,:]) 
        doys.append(file_doy)
    
    # Stack data into an rioxarray and export
    #    Slope
    all_slopes_stack = xa.DataArray(all_slopes, coords={'y':example_image['y'].values, 'x':example_image['x'].values, 'doy':doys}, dims=['doy', 'y', 'x'])
    all_slopes_stack.rio.write_crs(example_image.rio.crs, inplace=True)
    all_slopes_stack.rio.to_raster(output_directory + "slope" + output_name) 
    #    Intercept
    all_intercepts_stack = xa.DataArray(all_intercepts, coords={'y':example_image['y'].values, 'x':example_image['x'].values, 'doy':doys}, dims=['doy', 'y', 'x'])
    all_intercepts_stack.rio.write_crs(example_image.rio.crs, inplace=True)
    all_intercepts_stack.rio.to_raster(output_directory + "intercept" + output_name) 
    #    R_squared
    all_r_stack = xa.DataArray(all_r, coords={'y':example_image['y'].values, 'x':example_image['x'].values, 'doy':doys}, dims=['doy', 'y', 'x'])
    all_r_stack.rio.write_crs(example_image.rio.crs, inplace=True)
    all_r_stack.rio.to_raster(output_directory + "r" + output_name) 
    #    p-value
    all_p_value_stack = xa.DataArray(all_p_value, coords={'y':example_image['y'].values, 'x':example_image['x'].values, 'doy':doys}, dims=['doy', 'y', 'x'])
    all_p_value_stack.rio.write_crs(example_image.rio.crs, inplace=True)
    all_p_value_stack.rio.to_raster(output_directory + "p_value" + output_name) 
    #    Number of Good Scenes
    all_std_err_counts_stack = xa.DataArray(all_std_err_counts, coords={'y':example_image['y'].values, 'x':example_image['x'].values, 'doy':doys}, dims=['doy', 'y', 'x'])
    all_std_err_counts_stack.rio.write_crs(example_image.rio.crs, inplace=True)
    all_std_err_counts_stack.rio.to_raster(output_directory + "std_err" + output_name) 
    #    Number of Good Scenes
    all_day_counts_stack = xa.DataArray(all_day_counts, coords={'y':example_image['y'].values, 'x':example_image['x'].values, 'doy':doys}, dims=['doy', 'y', 'x'])
    all_day_counts_stack.rio.write_crs(example_image.rio.crs, inplace=True)
    all_day_counts_stack.rio.to_raster(output_directory + "day_counts" + output_name) 

    # Make a new copy of data which is masked based on p < 0.05 significance 
    #    Slope
    all_slopes_significant = all_slopes_stack
    all_slopes_significant.data[all_p_value_stack.data > 0.05] = np.nan
    all_slopes_significant.rio.to_raster(output_directory + "slope_significant" + output_name) 
    #    R^2
    all_r_significant = all_r_sqd_stack
    all_r_significant.data[all_p_value_stack.data > 0.05] = np.nan
    all_r_significant.rio.to_raster(output_directory + "r_significant" + output_name) 