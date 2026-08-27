********************
*** INTRODUCTION ***
********************
/* 
This .do-file creates a .dta with current and historical income group, IDA, and FCV classifications 
for each of the 218 economies the World Bank's operates with, from 1988 to 2026. 
1988 is the first year with income classification data.
Created by: Daniel Gerszon Mahler (dmahler@worldbank.org)
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
import excel "InputData/OGHIST.xlsx", sheet("Country Analytical History") cellrange(A5:AO233) firstrow clear
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
forvalues yr=10/27 {
rename FY`yr' y20`yr'
}
reshape long y, i(code economy) j(year)
rename y income_group
replace income_group="" if income_group==".."
// Creating income classifications for countries that didn't exist
// Giving Kosovo the income classification of Serbia before it became a separate country
*br if inlist(code,"SRB","XKX")
gen SRB = income_group if code=="SRB"
gsort year -SRB
replace SRB = SRB[_n-1] if missing(SRB)
replace income_group = SRB if code=="XKX" & missing(income_group)
drop SRB
// Giving Serbia, Montenegro, and Kosovo the income classification of Yugoslavia before they become separate countries
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
// Giving Czeck and Slovakia the income classification of Czeckoslovakia before they became separate countries
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
ssc install distinct
distinct code
if r(ndistinct)!=218 {
disp in red "There is an error somewhere -- you do not have 218 distinct economies"
}
rename income_group incgroup
// Assume income group carries backwards when missing
gsort code -year
bysort code: replace incgroup = incgroup[_n-1] if missing(incgroup) & year>=1988
// Assume income group carries forwards when missing. Only applies to Venezuela 
bysort code (year): replace incgroup= incgroup[_n-1] if missing(incgroup) & year>=1988
replace incgroup = "Low income"          if incgroup=="L"
replace incgroup = "Lower middle income" if inlist(incgroup,"LM*","LM")
replace incgroup = "Upper middle income" if incgroup=="UM"
replace incgroup = "High income"         if incgroup=="H"
gen     incgroup_code = "HIC"  if incgroup =="High income"
replace incgroup_code = "UMIC" if incgroup == "Upper middle income"
replace incgroup_code = "LMIC" if incgroup == "Lower middle income"
replace incgroup_code = "LIC"  if incgroup == "Low income"
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
rename FCSFCV fcv
replace   fcv = "N"   if inrange(year,2000,2019) & missing(fcv)
replace   fcv = "No" if fcv=="N"
replace   fcv = "Yes" if fcv=="Y"
	
// IDA historical
rename eligibility ida
replace   ida = "Rest of the world" if ida=="other"
replace   ida = "Blend"             if ida=="BLEND"
*tab year ida_hist,m
replace ida = "Rest of the world" if missing(ida) & inrange(year,2000,2019)
save "OutputData/CLASS.dta", replace


**********************************
*** FY2020-FY2021 IDA CATEGORY ***
**********************************
foreach year in 2020 2021 {
import excel "InputData/CLASS_FY`year'.xls", sheet("List of economies") cellrange(C5:H224) firstrow clear
drop if _n==1
keep Code Lendingcat
rename Code code
rename Lendingcat ida`year'
replace ida = "Rest of the world" if ida==".."
tempfile `year'
save     ``year''
}
use    `2020', clear
merge   1:1 code using `2021', nogen
reshape long ida, i(code) j(year)
merge   1:1 code year using "OutputData/CLASS.dta", update replace nogen
sort    code year
save    "OutputData/CLASS.dta", replace

**********************************
*** FY2022-FY2027 IDA CATEGORY ***
**********************************
foreach year in 2022 2023 2024 2025 2026 2027 {
import excel "InputData/CLASS_FY`year'.xlsx", sheet("List of economies") firstrow clear
drop if missing(Region)
keep  Code Lendingcat
rename Code code
rename Lendingcat ida
replace ida = "Rest of the world" if missing(ida)
gen year = `year'
merge 1:1 code year using "OutputData/CLASS.dta",  replace update nogen
save    "OutputData/CLASS.dta", replace
}
gen     ida_code = "IDA"  if ida=="IDA"
replace ida_code = "BLND" if ida=="Blend"
replace ida_code = "IBRD" if ida=="IBRD"
replace ida_code = "REST" if ida=="Rest of the world"

*************************
*** FCV FY2020-FY2025 ***
*************************
// Making the changes from the FY19 list
bysort code (year): replace fcv = fcv[_n-1] if year==2020
replace fcv = "No"  if year==2020 & inlist(code,"CIV","DJI","MOZ","TGO")       
replace fcv = "Yes" if year==2020 & inlist(code,"BFA","CMR","NER","NGA","VEN") 
// Making the changes from the FY20 list
bysort code (year): replace fcv = fcv[_n-1] if year==2021
replace fcv = "Yes" if year==2021 & inlist(code,"MOZ","LAO")
// Making the changes from the FY21 list
bysort code (year): replace fcv = fcv[_n-1] if year==2022
replace fcv = "No"  if year==2022 & inlist(code,"GMB","LAO","LBR")       
replace fcv = "Yes" if year==2022 & inlist(code,"ARM","AZE","ETH")
// Making the changes from the FY22 list
bysort code (year): replace fcv = fcv[_n-1] if year==2023
replace fcv = "No"  if year==2023 & inlist(code,"ARM","AZE","KIR")       
replace fcv = "Yes" if year==2023 & inlist(code,"UKR")
// Making the changes from the FY23 list
bysort code (year): replace fcv = fcv[_n-1] if year==2024
replace fcv = "Yes" if year==2024 & inlist(code,"KIR","STP")
// Making the changes from the FY24 list
bysort code (year): replace fcv = fcv[_n-1] if year==2025
*Same as FY2024
// Making the changes from the FY25 list
bysort code (year): replace fcv = fcv[_n-1] if year==2026
replace fcv = "No" if year==2026 & code=="XKX"
// Making the changes from the FY26 list
bysort code (year): replace fcv = fcv[_n-1] if year==2027
replace fcv = "Yes" if year==2027 & code=="IRN"
replace fcv = "No" if year==2027 & inlist(code,"BDI","TCD","COG","COM","ERI","GNB","KIR","MHL")
replace fcv = "No" if year==2027 & inlist(code,"FSM","STP","SLB","TLS","TUV","VEN","ZWE")
gen fcv_code = "FCVN" if fcv=="No"
replace fcv_code = "FCVY" if fcv=="Yes"
save "OutputData/CLASS.dta", replace

************************
*** ADDING WB REGION ***
************************
import excel "InputData/CLASS_FY2026.xlsx", sheet("List of economies") firstrow clear
keep Code Region
keep if _n<=218
rename Region region
rename Code code

// Add region codes from WDI
gen     region_code = ""
replace region_code = "EAS" if region=="East Asia & Pacific"
replace region_code = "ECS" if region=="Europe & Central Asia"
replace region_code = "LCN" if region=="Latin America & Caribbean"
replace region_code = "MEA" if region=="Middle East, North Africa, Afghanistan & Pakistan"
replace region_code = "NAC" if region=="North America"
replace region_code = "SAS" if region=="South Asia"
replace region_code = "SSF" if region=="Sub-Saharan Africa"

merge 1:m code using "OutputData/CLASS.dta", nogen
save "OutputData/CLASS.dta", replace

*******************************
*** ADDING POVCALNET REGION ***
*******************************
// Run 2027.08.27. Will no longer give the right results if rerun
/*
pip tables, table(country_coverage) clear
keep  country_code pcn_region_code
duplicates drop
rename country_code code
rename pcn_region_code regionpcn_code
// Fetch names
preserve
pip tables, table(regions) clear
rename region_code regionpcn_code
keep if grouping_type=="region"
drop grouping_type
tempfile names
save `names'
restore
merge m:1 regionpcn_code using `names', nogen
rename region regionpcn
save "InputData/PovcalNet_region.dta", replace
*/
merge  m:1 code using "InputData/PovcalNet_region.dta", nogen
save "OutputData/CLASS.dta", replace

****************************
*** ADDING SSA SUBREGION ***
****************************
use "InputData/SSAregions.dta", clear
drop countryname
rename countrycode code
rename regioncode regionssa_code
gen regionssa     = "Eastern and Southern Africa" if regionssa_code=="AFE"
replace regionssa = "Western and Central Africa"  if regionssa_code=="AFW"
merge 1:m code using "OutputData/CLASS.dta", nogen
save "OutputData/CLASS.dta", replace

*********************************
*** FORMATTING AND FINALIZING ***
*********************************
isid code year

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

order economy code year* region region_code regionpcn* regionssa* incgroup* ida* fcv*

lab var economy        "Economy"
lab var code           "Country code"
lab var region         "World Bank region name"
lab var region_code    "World Bank region code"
lab var regionpcn      "PovcalNet region name"
lab var regionpcn_code "PovcalNet region code"
lab var regionssa      "SSA subregion name"
lab var regionssa_code "SSA subregion code"
lab var incgroup       "Income group name"
lab var incgroup_code  "Income group code"
lab var ida "Lending group"
lab var ida_code "Lending category code"
lab var fcv            "FCV status"
lab var fcv_code        "FCV status code"

compress

sort code year_data


save "OutputData\CLASS.dta", replace
