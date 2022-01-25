********************
*** INTRODUCTION ***
********************
/* 
This .do-file creates a .dta with current and historical income group, IDA, and FCV classifications 
for each of the 218 economies the World Bank's operates with, from 1988 to 2021. 
1988 is the first year with income classification data.
Created by: Daniel Gerszon Mahler
*/

******************
*** DIRECTOTRY ***
******************
// Daniel
if (lower("`c(username)'") == "wb514665") {
	cd "C:\Users\WB514665\OneDrive - WBG\PovcalNet\GitHub\Class"
}

***************************************
*** HISTORICAL/CURRENT INCOME GROUP ***
***************************************
import excel "InputData/OGHIST.xlsx", sheet("Historical classifications") cellrange(A1:F7617) firstrow clear
rename wb_code code
rename country economy
rename publicationyear year
keep code economy income_group year
// Creating income classifications for countries that didn't exist
// Giving Kosovo Serbia's income classification before it became a separate country
*br if inlist(code,"SRB","XKX")
gen SRB = income_group if code=="SRB"
gsort year -SRB
replace SRB = SRB[_n-1] if missing(SRB)
replace income_group = SRB if code=="XKX" & missing(income_group)
drop SRB
// Giving Serbia, Montenegro, and Kosovo Yugoslavia's income classification before they become separate countries
*br if inlist(code,"YUG","SRB","MNE","XKX")
gen YUG = income_group if code=="YUG"
gsort year -YUG
replace YUG = YUG[_n-1] if missing(YUG)
replace income_group = YUG if inlist(code,"MNE","SRB","XKX") & missing(income_group)
drop YUG
drop if code=="YUG"
// Giving all Yugoslavian countries Yugoslavia's income classification before they became separate countries
*br if inlist(code,"YUGf","HRV","SVN","MKD","BIH","SRB","MNE","XKX")
gen YUGf = income_group if code=="YUGf"
gsort year -YUGf
replace YUGf = YUGf[_n-1] if missing(YUGf)
replace income_group = YUGf if inlist(code,"HRV","SVN","MKD","BIH","SRB","MNE","XKX") & missing(income_group)
drop YUGf
drop if code=="YUGf"
// Giving Czeck and Slovakia Czeckoslovakia's income classification before they became separate countries
*br if inlist(code,"CSK","CZE","SVK")
gen CSK = income_group if code=="CSK"
gsort year -CSK
replace CSK = CSK[_n-1] if missing(CSK)
replace income_group = CSK if inlist(code,"CZE","SVK") & missing(income_group)
drop CSK
drop if code=="CSK"
// Dropping three economies that are not among the WB's 218 economies
drop if inlist(code,"MYT","ANT","SUN")
// Now 218 economies
distinct code
if r(ndistinct)!=218 {
disp in red "There is an error somewhere -- you do not have 218 distinct economies"
}
rename income_group incgroup_historical
// Assume income group carries backwards when missing
gsort code -year
bysort code: replace incgroup_historical = incgroup_historical[_n-1] if missing(incgroup_historical) & year>=1988
// Assume income group carries forwards when missing. Only applies to Venezuela 2021
bysort code (year): replace incgroup_historical = incgroup_historical[_n-1] if missing(incgroup_historical) & year>=1988
label var incgroup_historical "Income group - historically"
label var code "Country code"
label var year "Year"
save "OutputData/CLASS.dta", replace

******************************************
*** FY2000-FY2019 IDA AND FCV CATEGORY ***
******************************************
import excel "InputData/IDA-FCV.xlsx", sheet("Sheet1") firstrow clear
drop unique iso2 N SS PSW SUF Refugees Country RegionCode eligibility_sincefy12
replace year = year - 1 // Such that FY19 classification applies to 2018
rename CountryCode code
replace code="XKX" if code=="KSV"
replace code="TLS" if code=="TMP"
replace code="ROU" if code=="ROM"
replace code="COD" if code=="ZAR"
merge 1:1 code year using "OutputData/CLASS.dta", nogen
sort code year

// FCV
rename FCSFCV fcv_historical
label var fcv_historical "FCV status - historically"
replace   fcv_historical = "N"   if inrange(year,1999,2018) & missing(fcv_historical)
replace   fcv_historical = "No"  if fcv_historical=="N"
replace   fcv_historical = "Yes" if fcv_historical=="Y"
	
// IDA historical
rename eligibility ida_historical
label var ida_historical "Lending group - historically"
replace   ida_historical = "Rest of the world" if ida_historical=="other"
replace   ida_historical = "Blend"             if ida_historical=="BLEND"
*tab year ida_hist,m
replace ida_historical = "Rest of the world" if missing(ida_historical) & inrange(year,1999,2018)
save "OutputData/CLASS.dta", replace


**********************************
*** FY2020-FY2021 IDA CATEGORY ***
**********************************
foreach year in 2020 2021 {
import excel "InputData/CLASS_FY`year'.xls", sheet("List of economies") cellrange(C5:H224) firstrow clear
drop if _n==1
drop X Incomegroup
rename Code code
rename Lendingcat ida_historical`year'
rename Region region
rename Economy economy
replace ida = "Rest of the world" if ida==".."
tempfile `year'
save     ``year''
}
use    `2020', clear
merge   1:1 code using `2021', nogen
reshape long ida_historical, i(economy code region) j(year)
replace year = year-1  // Such that FY19 classification applies to 2018
merge   1:1 code year using "OutputData/CLASS.dta", update replace nogen
sort    code year
save    "OutputData/CLASS.dta", replace

***************************
*** FY2022 IDA CATEGORY ***
***************************
import excel "InputData/CLASS_FY2022.xlsx", sheet("List of economies") firstrow clear
drop Other Incomegroup
drop if missing(Region)
rename Code code
rename Lendingcat ida_historical
rename Region region
rename Economy economy
replace ida = "Rest of the world" if missing(ida)
gen year = 2021
merge 1:1 code year using "OutputData/CLASS.dta",  replace update nogen
save    "OutputData/CLASS.dta", replace

******************
*** FCV FY2020 ***
******************
bysort code (year): replace fcv_historical = fcv_historical[_n-1] if year==2019
// Making the changes from the FY19 list
replace fcv_historical = "No"  if year==2019 & inlist(code,"CIV","DJI","MOZ","TGO")       
replace fcv_historical = "Yes" if year==2019 & inlist(code,"BFA","CMR","NER","NGA","VEN") 
save "OutputData/CLASS.dta", replace

******************
*** FCV FY2021 ***
******************
bysort code (year): replace fcv_historical = fcv_historical[_n-1] if year==2020
// Making the changes from the FY19 list
replace fcv_historical = "Yes" if year==2020 & inlist(code,"MOZ","LAO") & year==2020
save "OutputData/CLASS.dta", replace

******************
*** FCV FY2022 ***
******************
bysort code (year): replace fcv_historical = fcv_historical[_n-1] if year==2021
// Making the changes from the FY19 list
replace fcv_historical = "No"  if year==2021 & inlist(code,"GMB","LAO","LBR")       
replace fcv_historical = "Yes" if year==2021 & inlist(code,"ARM","AZE","ETH")
save "OutputData/CLASS.dta", replace

*******************************
*** ADDING POVCALNET REGION ***
*******************************
pcn master, load(countrylist)
keep   countrycode wbregioncode
rename countrycode code
rename wbregioncode region_povcalnet
merge  1:m code using "OutputData/CLASS.dta", nogen
save "OutputData/CLASS.dta", replace

****************************
*** ADDING SSA SUBREGION ***
****************************
use "InputData/SSAregions.dta", clear
drop countryname
rename countrycode code
rename regioncode region_SSA
lab var region_SSA "SSA subregion"
merge 1:m code using "OutputData/CLASS.dta", nogen
save "OutputData/CLASS.dta", replace

*********************************
*** FORMATTING AND FINALIZING ***
*********************************
isid code year
// Create current category variables
qui sum year
foreach type in incgroup ida fcv {
gen `type'_current = `type'_historical if year==`r(max)'
}
// Filling out missing values
foreach var of varlist economy region *current {
gsort code -`var'
bysort code: replace `var'=`var'[_n-1] if missing(`var')
}
sort code year

// Add other year interpretations
// The current year variable reflects the year the classifications/statuses were released
rename year year_release
lab var year_release "Year the classification was released"
// They represent the classifications applied to the fiscal year after they were released
// I.e. the income groups released July 1 2021 arecalled the FY22 income groups
gen year_fiscal = year_release+1
lab var year_fiscal "Fiscal year the classification applies to"
// For the income groups (and I think also IDA/FCV classification), the classifcation released in a given year rely on data from the prior year
gen year_data = year_release-1
lab var year_data "Year of the data the classifications are based upon"

lab var incgroup_current "Income group - latest year"
lab var ida_current      "Lending category - latest year"
lab var fcv_current      "FCV status - latest year"
lab var year             "Year"
lab var code             "Country code"
lab var region           "World Bank region"
lab var region_povcalnet "PovcalNet region"
order economy code year region region_povcalnet region_SSA incgroup* ida* fcv*

compress

save "OutputData/CLASS.dta", replace
