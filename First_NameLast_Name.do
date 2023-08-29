*Task 1: Estimation
use "hh_Stata12", clear
* Rename hsize to hhsize
rename hsize hhsize 
* Label the variable cluster as "Cluster"
label variable cluster "Cluster" 
* Arrange the cluster variable between the variables strata and hhsize
order strata cluster hhsize 

*1.1 How many households are there?
count 
*1.2 What is the average household size (without using sampling weights)?
mean hhsize

*1.3 What is the average household size when using sampling weights?
svyset [pweight = weight], psu(cluster) strata(strata)
svy: mean hhsize
di "Average household size (with sampling weights): " r(mean)

*1.4 What is the standard error of this estimate?
svy: mean hhsize
di "Standard error: " r(se)

*1.5 What is the average household size when considering the sampling weights and the stratification of the sampling methodology?
svy: mean hhsize, subpop(strata)
di "Average household size (with sampling weights and stratification): " r(mean)

*1.6 What is the standard error of this estimate?
svy: mean hhsize, subpop(strata)
di "Standard error: " r(se)

save "hh_Stata12.dta", replace

* Task 2: Outlier Correction
use hhitem_Stata12.dta, clear
* Convert consumption to USD 
replace xfood = xfood/6 

*2.1: What is the single largest value for consumption of any one item by any household?
summarize xfood
display r(max)


*2.2: Calculate the standard deviation across all consumption values and report how many consumption values are beyond 2 standard deviations of the mean.
* calculate summary statistics for the variable xfood
sum xfood   
* save the standard deviation in a local macro called sd
local sd = r(sd)   
* save the mean in a local macro called mean
local mean = r(mean)  
* generate a new variable called sd_upper which is 2 standard deviations above the mean
gen sd_upper = `mean' + 2*`sd'  
* generate a new variable called sd_lower which is 2 standard deviations below the mean
gen sd_lower = `mean' - 2*`sd'
* count the number of consumption values that are beyond 2 standard deviations of the mean
count if xfood > sd_upper | xfood < sd_lower   

*item-specific standard deviation and mean of consumption in a new variables.
bysort foodid: summarize xfood, detail
generate xsd = r(sd)
generate xmean = r(mean)

*2.3: How many records have consumption values beyond 2 times the item-specific standard deviations of the item-specific mean. 
bysort foodid: replace xfood = . if (xfood > (xmean + 2*xsd)) | (xfood < (xmean - 2*xsd))

* Aggregate consumption per household at the food category level
tostring foodid, generate(foodid1) 
*convert the foodid variable to a string variable, which should allow you to use the substr function without encountering the "type mismatch" error.
generate food_category = substr(foodid1, 1, 1)
collapse (sum) xfood, by(hhid food_category)

* Find the largest consumption across households and food categories
bysort hhid: summarize xfood, detail
bysort food_category: summarize xfood, detail
save "hhitem_Stata12.dta", replace

* Task 3 Democratic Food Shares Wrong

* Calculate total consumption per household
bysort hhid: egen xtotal = total(xfood)

*3.1: Report the household id of the household with largest consumption:
gsort -xtotal
list hhid xtotal in 1

gen xshare = xfood / xtotal

* Merge household weights onto the consumption dataset
merge 1:1 hhid using "hh_Stata12.dta"

* Calculate weighted means of xshare by food item
collapse (mean) xshare [pweight=weight], by(foodid)

* Normalize xshare by dividing by the sum of all xshare values
gen norm_factor = sum(xshare)
replace xshare = xshare / norm_factor


*Task 4: Democratic Food Shares Correct

*4.1: Reload the consumption data and report the number of rows in the dataset.
use hhitem_Stata12.dta, clear
count

*4.2: Reorganize the data so that you have the item-specific consumption in columns (called xfoodFOODID) with one row per household.

encode food_category, generate(category)
reshape wide xfood, i(hhid) j(category)

*4.3: Report the mean consumption of item 101 across households (don't consider sampling weights)
egen mean_consumption_item101 = mean(xfood101)

* Iterate over xfood variables and replace missing values with 0s
local i
forval i = 101/999 {
    replace xfood`i' = 0 if missing(xfood`i')
}

* Reorganize the dataset
reshape long xfood, i(hhid) j(food_category)
rename xfood consumption_corrected
drop if food_category == .
drop if missing(consumption_corrected)

*4.4: Report the number of rows in the dataset.
count

* Now, follow the previous steps from Task 3 to create the shares, add the sampling weights to the dataset and aggregate across households.
merge m:1 hhid using "hh_Stata12.dta"

collapse (mean) xshare [pweight=weight], by(foodid)

*4.5: Report the sum over all food shares.
egen sum_xshare = total(xshare)
display "Sum over all food shares: " sum_xshare

* Add the table from Task 3 to compare the 'wrong' and 'correct' methods
merge m:1 foodid using "food_shares_wrong.dta"

*4.6: Report the mean absolute difference between both methods.
gen abs_diff = abs(xshare - xshare_wrong)
egen mean_abs_diff = mean(abs_diff)
display "Mean absolute difference between methods: " mean_abs_diff

* Visualize the difference
twoway bar mean_abs_diff foodid, title("Differences") xtitle("Food Item") ytitle("Mean Absolute Difference")
graph export "differences.png", replace

