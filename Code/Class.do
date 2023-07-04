********************
*** INTRODUCTION ***
********************
/* 
This .do-file creates a .dta with current and historical income group, IDA, and FCV classifications 
for each of the 218 economies the World Bank's operates with, from 1988 to 2024. 
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
import excel "InputData/OGHIST.xlsx", sheet("Country Analytical History") cellrange(A5:AL238) firstrow clear
drop if missing(A)
rename A code
rename Banksfiscalyear economy
compress
forvalues yr=89/99 {
rename FY`yr' y19`yr'
}
forvalues yr=0/9 {
rename FY0`yr' y200`yr'
}
forvalues yr=10/24 {
rename FY`yr' y20`yr'
}
reshape long y, i(code economy) j(year)
rename y income_group
replace income_group="" if income_group==".."
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
replace incgroup_historical = "Low income" if incgroup_historical=="L"
replace incgroup_historical = "Lower middle income" if inlist(incgroup_historical,"LM*","LM")
replace incgroup_historical = "Upper middle income" if incgroup_historical=="UM"
replace incgroup_historical = "High income" if incgroup_historical=="H"
save "OutputData/CLASS.dta", replace

******************************************
*** FY2000-FY2019 IDA AND FCV CATEGORY ***
******************************************
import excel "InputData/IDA-FCV.xlsx", sheet("Sheet1") firstrow clear
drop unique iso2 N SS PSW SUF Refugees Country RegionCode eligibility_sincefy12
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
replace   fcv_historical = "N"   if inrange(year,2000,2019) & missing(fcv_historical)
replace   fcv_historical = "No"  if fcv_historical=="N"
replace   fcv_historical = "Yes" if fcv_historical=="Y"
	
// IDA historical
rename eligibility ida_historical
label var ida_historical "Lending group - historically"
replace   ida_historical = "Rest of the world" if ida_historical=="other"
replace   ida_historical = "Blend"             if ida_historical=="BLEND"
*tab year ida_hist,m
replace ida_historical = "Rest of the world" if missing(ida_historical) & inrange(year,2000,2019)
save "OutputData/CLASS.dta", replace


**********************************
*** FY2020-FY2021 IDA CATEGORY ***
**********************************
foreach year in 2020 2021 {
import excel "InputData/CLASS_FY`year'.xls", sheet("List of economies") cellrange(C5:H224) firstrow clear
drop if _n==1
keep Code Lendingcat
rename Code code
rename Lendingcat ida_historical`year'
replace ida = "Rest of the world" if ida==".."
tempfile `year'
save     ``year''
}
use    `2020', clear
merge   1:1 code using `2021', nogen
reshape long ida_historical, i(code) j(year)
merge   1:1 code year using "OutputData/CLASS.dta", update replace nogen
sort    code year
save    "OutputData/CLASS.dta", replace

**********************************
*** FY2022-FY2024 IDA CATEGORY ***
**********************************
foreach year in 2022 2023 2024 {
import excel "InputData/CLASS_FY`year'.xlsx", sheet("List of economies") firstrow clear
drop if missing(Region)
keep  Code Lendingcat Region
rename Code code
rename Region region
rename Lendingcat ida_historical
replace ida = "Rest of the world" if missing(ida)
gen year = `year'
merge 1:1 code year using "OutputData/CLASS.dta",  replace update nogen
save    "OutputData/CLASS.dta", replace
}

******************
*** FCV FY2020 ***
******************
bysort code (year): replace fcv_historical = fcv_historical[_n-1] if year==2020
// Making the changes from the FY19 list
replace fcv_historical = "No"  if year==2020 & inlist(code,"CIV","DJI","MOZ","TGO")       
replace fcv_historical = "Yes" if year==2020 & inlist(code,"BFA","CMR","NER","NGA","VEN") 
save "OutputData/CLASS.dta", replace

******************
*** FCV FY2021 ***
******************
bysort code (year): replace fcv_historical = fcv_historical[_n-1] if year==2021
// Making the changes from the FY20 list
replace fcv_historical = "Yes" if year==2021 & inlist(code,"MOZ","LAO")
save "OutputData/CLASS.dta", replace

******************
*** FCV FY2022 ***
******************
bysort code (year): replace fcv_historical = fcv_historical[_n-1] if year==2022
// Making the changes from the FY21 list
replace fcv_historical = "No"  if year==2022 & inlist(code,"GMB","LAO","LBR")       
replace fcv_historical = "Yes" if year==2022 & inlist(code,"ARM","AZE","ETH")
save "OutputData/CLASS.dta", replace

******************
*** FCV FY2023 ***
******************
bysort code (year): replace fcv_historical = fcv_historical[_n-1] if year==2023
// Making the changes from the FY22 list
replace fcv_historical = "No"  if year==2023 & inlist(code,"ARM","AZE","KIR")       
replace fcv_historical = "Yes" if year==2023 & inlist(code,"UKR")
save "OutputData/CLASS.dta", replace

******************
*** FCV FY2024 ***
******************
bysort code (year): replace fcv_historical = fcv_historical[_n-1] if year==2024
// Making the changes from the FY23 list
replace fcv_historical = "Yes" if year==2024 & inlist(code,"KIR","STP")
save "OutputData/CLASS.dta", replace

*************************
*** ADDING PIP REGION ***
*************************
pip tables, table(country_coverage) clear
keep   country_code pcn_region_code
duplicates drop
rename country_code code
rename pcn_region_code region_pip
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
// The current year variable reflects the year of the fiscal year
rename year year_fiscal
lab var year_fiscal "Fiscal year the classification applies to"
// They represent the classifications that were released in year
gen year_release = year_fiscal-1
lab var year_release "Year the classification was released"
// For the income groups (and I think also IDA/FCV classification), the classifcation released in a given year rely on data from the prior year
gen year_data = year_release-1
lab var year_data "Year of the data the classifications are based upon"

lab var incgroup_current "Income group - latest year"
lab var ida_current      "Lending category - latest year"
lab var fcv_current      "FCV status - latest year"
lab var code             "Country code"
lab var region           "World Bank region"
lab var region_pip       "PIP region"
order economy code year* region region_pip region_SSA incgroup* ida* fcv*

compress

save "OutputData/CLASS.dta", replace
