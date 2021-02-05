********************
*** INTRODUCTION ***
********************
/* 
This .do-file creates a .dta with current and historical income group, IDA and FCV classifications 
for each of the 218 economies the World Bank's operates with, from 1988 to 2020. 
1988 is the first year with income classification data.
The income, lending and FCV data for fiscal year YYYY is mapped to year YYYY-1.
For example, the FY2021 income groups (which were launched July 1 2020) are mapped to 2020.
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
import excel "InputData/OGHIST.xls", sheet("Country Analytical History") cellrange(A5:AI240) firstrow clear
rename A code
rename Banks economy
drop if missing(code)
compress
// Creating income classifications for countries that didn't exist
// Giving Kosovo Serbia's income classification before it became a separate country
*br if inlist(code,"SRB","XKX")
foreach var of varlist FY08-FY09 {
replace `var' = "UM" if code=="XKX"
}
// Giving Serbia, Montenegro and Kosovo Yugoslavia's income classification before they become separate countries
*br if inlist(code,"YUG","SRB","MNE","XKX")
foreach var of varlist FY94-FY07 {
replace `var' = "LM" if inlist(code,"SRB","MNE","XKX")
}
drop if code=="YUG"
// Giving all Yugoslavian countries Yugoslavia's income classification before they became separate countries
*br if inlist(code,"YUGf","HRV","SVN","MKD","BIH","SRB","MNE","XKX")
foreach var of varlist FY89-FY93 {
replace `var' = "UM" if inlist(code,"HRV","SVN","MKD","BIH","SRB","MNE","XKX")
}
drop if code=="YUGf"
// Giving Czeck and Slovakia Czeckoslovakia's income classification before they became separate countries
*br if inlist(code,"CSK","CZE","SVK")
foreach var of varlist FY92-FY93 {
replace `var' = "UM" if inlist(code,"HRV","CZE","SVK")
}
drop if code=="CSK"
// Dropping three economies that are not among the WB's 218 economies
drop if inlist(code,"MYT","ANT","SUN")

// Changing variable names
local year = 1988
foreach var of varlist FY89-FY21 {
rename `var' y`year'
local year = `year' + 1
}
drop economy
// Reshaping to long format
reshape long y, i(code) j(year)
rename y incgroup_historical
replace incgroup_historical = "" if incgroup_historical==".."
// Assume income group carries backwards when missing
* br if missing(incgroup_historical)
gsort code -year
bysort code: replace incgroup_historical = incgroup_historical[_n-1] if missing(incgroup_historical) & year>=1988
// Changing label/format
replace incgroup = "High income"         if incgroup=="H"
replace incgroup = "Upper middle income" if incgroup=="UM"
replace incgroup = "Lower middle income" if inlist(incgroup,"LM","LM*")
replace incgroup = "Low income"          if incgroup=="L"
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

******************
*** FCV FY2020 ***
******************
bysort code (year): replace fcv_historical = fcv_historical[_n-1] if year==2019
// Making the changes from the FY19 list
replace fcv_historical = "No"  if year==2019 & inlist(code,"CIV","DJI","MOZ","TGO")       & year==2019
replace fcv_historical = "Yes" if year==2019 & inlist(code,"BFA","CMR","NER","NGA","VEN") & year==2019
save "OutputData/CLASS.dta", replace

******************
*** FCV FY2021 ***
******************
bysort code (year): replace fcv_historical = fcv_historical[_n-1] if year==2020
// Making the changes from the FY19 list
replace fcv_historical = "Yes" if year==2020 & inlist(code,"MOZ","LAO") & year==2020
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
rename regioncode ssasubregion
lab var ssasubregion "SSA subregion"
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
lab var incgroup_current "Income group - latest year"
lab var ida_current      "Lending category - latest year"
lab var fcv_current      "FCV status - latest year"
order economy code year region* ssasubregion incgroup* ida* fcv*

compress

save "OutputData/CLASS.dta", replace
