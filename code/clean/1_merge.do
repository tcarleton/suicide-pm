
**********************************************************************************

* This script cleans and merges the population, suicide, climate, and 
* pollution data for Zhang et al.

* Data assembled in this script are used to produce regressions run in all
* scripts in the code/analysis/ directory. All suicide and population data are 
* proprietary and were accessed under user agreements that do not allow for public 
* distribution. Therefore, this code is for transparency purposes only, and 
* cannot directly be run with publicly available data.

**********************************************************************************

clear all
set more off

// wd
cd ~
	if regexm("`c(pwd)'","/Users/tammacarleton")==1 {
	global root "~/Dropbox/suicide"
	global datadir "$root/main_2017"
	cd $root
	} 
	else {
	di "NEED TO CONFIGURE FILEPATH FOR THIS USER"
	}
	
**********************************************************************************
*						                                                         *
* dsp population data                                            *
**********************************************************************************
* the raw data are pop2013-pop2017

*** append first

use "$datadir/pop2013.dta", clear
foreach i of numlist 2014/2017 {
append using pop`i'
}
*
order year
sort code year 
drop dsp /* non-useful variable in some years */
drop region /*not useful */

*** check data
egen mtotal_1=rowtotal(m0-m85)
sum mtotal mtotal_1

egen ftotal_1=rowtotal(f0-f85)
sum ftotal ftotal_1

gen total_1=mtotal+ftotal
sum total total_1

gen t0_1=m0+f0
sum t0 t0_1

drop mtotal_1 ftotal_1 total_1 t0_1

foreach i of numlist 0 1 5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 {
rename m`i' m`i'pop
rename f`i' f`i'pop
rename t`i' t`i'pop
}
*

*** check missing data
duplicates drop code year, force
* no duplicates

unique code
* 633 counties
unique year
* 5 years
* total observation should be 633*5=3165
* the observation is 3025. Some counties must have missing years

bysort code: gen N_pop=_N
sort code year
order N_pop
unique code if N_pop!=5
*** there are 56 counties that have incomplete years

save "$datadir/pop.dta", replace


**********************************************************************************
*						                                                         *
* dsp death data                                            *
**********************************************************************************
* the raw data are death_2013_2017

use "$datadir/death_2013_2017.dta", clear
rename U081* d25* /* mental */
rename U157* d24* /* suicide */

foreach i of numlist 1/19 {
rename d24_dsp_Fage`i' f`i'd24
rename d24_dsp_Mage`i' m`i'd24
rename d25_dsp_Fage`i' f`i'd25
rename d25_dsp_Mage`i' m`i'd25
}
*

foreach a in f m {
  foreach b in 24 25 {
rename `a'1d`b' `a'X0d`b'
rename `a'2d`b' `a'X1d`b'
rename `a'3d`b' `a'X5d`b'
rename `a'4d`b' `a'X10d`b'
rename `a'5d`b' `a'X15d`b'
rename `a'6d`b' `a'X20d`b'
rename `a'7d`b' `a'X25d`b'
rename `a'8d`b' `a'X30d`b'
rename `a'9d`b' `a'X35d`b'
rename `a'10d`b' `a'X40d`b'
rename `a'11d`b' `a'X45d`b'
rename `a'12d`b' `a'X50d`b'
rename `a'13d`b' `a'X55d`b'
rename `a'14d`b' `a'X60d`b'
rename `a'15d`b' `a'X65d`b'
rename `a'16d`b' `a'X70d`b'
rename `a'17d`b' `a'X75d`b'
rename `a'18d`b' `a'X80d`b'
rename `a'19d`b' `a'X85d`b'
}
}
*

foreach i of numlist 0 1 5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 {
rename fX`i'd24 f`i'd24
rename mX`i'd24 m`i'd24
rename fX`i'd25 f`i'd25
rename mX`i'd25 m`i'd25
}
*

drop d25-d24_male

*** check missing data
sort code year week

duplicates drop code year week, force
** 11 obs dropped 

bysort code: gen N_week=_N
sort code year week
order N_week

unique code if N_week!=265
*71 counties have missing weeks

save "$datadir/temp.dta", replace

*** merge weeks that span across years
* for example, week 52 in 2013 is 2013.12.29 to 2013.12.31 with 3 days
* week 0 in 2014 is 2014.01.01 to 2014.01.04 with 4 days
* need to add them togther

gen group=1 if (year==2013 & week==52) | (year==2014 & week==0) 
order group

replace group=2 if (year==2014 & week==52) | (year==2015 & week==0) 
replace group=3 if (year==2015 & week==52) | (year==2016 & week==0) 

save "$datadir/temp1.dta", replace

use "$datadir/temp1.dta", clear
drop if group==.
collapse (firstnm) N_week year dspname week (sum) f0d25-m85d24, by(code group) 
save "$datadir/temp2.dta", replace

use "$datadir/temp1.dta", clear 
keep if group==.
append using "$datadir/temp2.dta"
drop group
sort code year week

* there are some counties have missing values for week 52
* drop week 0
drop if week==0 & year!=2013

*** generate week numbers in all years
*** the current week numbers are each year
rename week week_year
gen week=week_year
order N_week year code dspname week_year week
replace week=week+52 if year==2014
replace week=week+104 if year==2015
replace week=week+156 if year==2016
replace week=week+208 if year==2017

save "$datadir/death.dta", replace


**********************************************************************************
*						                                                         *
* calculate death rate                                            *
**********************************************************************************

use "$datadir/pop.dta", clear
unique code 
*633 counties

use "$datadir/death.dta", clear
unique code
* 599 counties

merge m:1 year code using pop
keep if _merge==3
drop _merge

sort code week

*********************************************************** calculate death rate
* the unit for pop is person
* adjust the unit to per million

foreach i of numlist 0 1 5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 {

gen m`i'd24_rate=(m`i'd24/m`i'pop)*1000000
gen m`i'd25_rate=(m`i'd25/m`i'pop)*1000000

gen f`i'd24_rate=(f`i'd24/f`i'pop)*1000000
gen f`i'd25_rate=(f`i'd25/f`i'pop)*1000000

}
*

save "$datadir/death_rate.dta", replace


**********************************************************************************
*						                                                         *
* create county code coordinance                                          *
**********************************************************************************
* death data use dsp code
* environment data use gis code

* generate dsp code file
use "$datadir/death_rate.dta", clear
duplicates drop code, force
keep code dspname
rename code dsp_code
rename dspname dsp_county
unique dsp_code
save "$datadir/dsp_code.dta", replace 

* merge with gis code
use "$datadir/dsp_code.dta", clear
gen gis_code=dsp_code
merge 1:1 gis_code using gis_code
*** there are 8 counties cannot be matched 
*** manually find it
drop if _merge==2

sort _merge dsp_code
*** cannot find 黑龙江省大兴安岭地区加格达奇
*** 江苏省扬州市江都区 the gis code should be 321088
replace gis_code=321088 if dsp_code==321012
*** cannot find 河南省开封市金明区
*** 重庆市綦江区 the gis code should be 500120
replace gis_code=500120 if dsp_code==500110
*** 重庆市大足区 the gis code should be 500121
replace gis_code=500121 if dsp_code==500111
*** 云南省红河哈尼族彝族自治州蒙自市 the gis code should be 532522
replace gis_code=532522 if dsp_code==532503
*** 陕西省韩城市 the gis code should be 610581
replace gis_code=610581 if dsp_code==619081
*** 甘肃省嘉峪关市市辖区 the gis code should be 620201
replace gis_code=620201 if dsp_code==620200

drop _merge
merge 1:1 gis_code using "$datadir/gis_code.dta"
keep if _merge==3
drop _merge
sort dsp_code
save "$datadir/dsp_gis_code.dta", replace


**********************************************************************************
*						                                                         *
* pollution data                                            *
**********************************************************************************

use "$datadir/pollution_county_daily_2013_2018.dta", clear

*** adjust county code

rename county_id gis_code
destring gis_code, replace

merge m:1 gis_code using "$datadir/dsp_gis_code.dta"
keep if _merge==3
drop _merge

duplicates drop dsp_code year month day, force

sort dsp_code year month day

*** generate week indicators to match with dsp data

* check if all data from 2013.1.18
count if year==2013 & month==1 & day<18
* all data start from 2013.1.18

* week 3 starts from 2013.1.20
* need to drop 2013.1.18 and 2013.1.19
drop if year==2013 & month==1 & day<20

* check if all days are continuous from 2013.1.20 to 2017.12.31 so we can generate week indicators
* 2013.01.20 to 2013.12.31: 346 days
* 2014: 365 days
* 2015: 365 days
* 2016: 366 days
* 2017: 365 days
* total: 1807 days
* note 2017.12.31 was missing, so there are 1806 days in total
drop if year>2017
sort dsp_code year month day
bysort dsp_code: gen day_total=_N
sum day_total
* all days are continuous
drop day_total

* generate week indicators
bysort dsp_code: gen n=_n
gen week=ceil(n/7)+2
drop n
sort dsp_code year month day
order year month day week

*** average to week level
collapse (mean) aqi-co (firstnm) year month day, by(dsp_code week)

save "$datadir/pollution_week.dta", replace


**********************************************************************************
*						                                                         *
* inversion                                            *
**********************************************************************************

use "$datadir/inversion_county_daily_2005_2017.dta", clear

*** adjust county code

rename county_code gis_code
keep if year>=2013

destring gis_code, replace
keep gis_code year month day TINumD1 TIIndD1 TIStrD1 TINumD2 TIIndD2 TIStrD2
merge m:1 gis_code using "$datadir/dsp_gis_code.dta"
keep if _merge==3
drop _merge

*** generate week indicators to match with dsp data

duplicates drop dsp_code year month day, force

*** generate week indicators to match with dsp data

* week 3 starts from 2013.1.20
* need to drop 2013.1.18 and 2013.1.19
drop if year==2013 & month==1 & day<20

* check if all days are continuous from 2013.1.20 to 2017.12.31 so we can generate week indicators
* 2013.01.20 to 2013.12.31: 346 days
* 2014: 365 days
* 2015: 365 days
* 2016: 366 days
* 2017: 365 days
* total: 1807 days
* note drop 2017.12.31 be consistent with pollution data, so there are 1806 days in total
drop if year==2017 & month==12 & day==31

sort dsp_code year month day
bysort dsp_code: gen day_total=_N
sum day_total
* all days are continuous
drop day_total

* generate week indicators
bysort dsp_code: gen n=_n
gen week=ceil(n/7)+2
drop n
sort dsp_code year month day
order dsp_code year month day week

*** average for inversion
collapse (sum) TINumD* TIIndD* (mean) TIStrD* (firstnm) year month day, by(dsp_code week)

save "$datadir/inversion_week.dta", replace


**********************************************************************************
*						                                                         *
* weather                                           *******************
**********************************************************************************

use "$datadir/weather_county_daily_2005_2017.dta", clear

// merge with ssd data from 2017, as this was not initially available and had to be added separately
preserve
use ssd2017, clear
tostring(county_id), replace
ren ssd ssd2017
tempfile ssdtemp
save "`ssdtemp'", replace
restore
merge 1:1 county_id year month day using "`ssdtemp'"
replace ssd = ssd2017 if year==2017
drop ssd2017
drop if _merge==2
drop _merge

rename county_id gis_code
keep if year>=2013
destring gis_code, replace
merge m:1 gis_code using "$datadir/dsp_gis_code.dta"
keep if _merge==3
drop _merge

sort dsp_code year month

duplicates drop dsp_code year month day, force

*** generate week indicators to match with dsp data

* week 3 starts from 2013.1.20
* need to drop 2013.1.18 and 2013.1.19
drop if year==2013 & month==1 & day<20

* check if all days are continuous from 2013.1.20 to 2017.12.31 so we can generate week indicators
* 2013.01.20 to 2013.12.31: 346 days
* 2014: 365 days
* 2015: 365 days
* 2016: 366 days
* 2017: 365 days
* total: 1807 days
* note drop 2017.12.31 be consistent with pollution data, so there are 1806 days in total
drop if year==2017 & month==12 & day==31

sort dsp_code year month day
bysort dsp_code: gen day_total=_N
sum day_total
* all days are continuous
drop day_total

* generate week indicators
bysort dsp_code: gen n=_n
gen week=ceil(n/7)+2
drop n
sort dsp_code year month day
order dsp_code year month day week

unique dsp_code if tem_ave==. 
* there are 11 counties mostly in Xizang have missing values for temperature only for one month

*** create days for 10 percentiles for all weather variables

foreach V of varlist tem_ave-prs {
  foreach i of numlist 10(10)90 {
  egen `V'_p`i'=pctile(`V'), p(`i')
}
}
*

foreach V of varlist tem_ave-prs {
  
  * below 10th
  gen `V'_pbin10=1 if `V'<`V'_p10
  replace `V'_pbin10=0 if `V'_pbin10==.

  * 10-90
  foreach i of numlist 10(10)80 {
    local j=`i'+10
    gen `V'_pbin`j'=1 if `V'>=`V'_p`i' & `V'<`V'_p`j'
    replace `V'_pbin`j'=0 if `V'_pbin`j'==.
  }
  *
  
  * above 90
  gen `V'_pbin100=1 if `V'>=`V'_p90
  replace `V'_pbin100=0 if `V'_pbin100==.
  *
}
*

collapse (sum) *bin* (mean) tem_ave-prs (firstnm) year month day, by(dsp_code week)

* for missing values
foreach V of varlist *bin* {
  replace `V'=. if tem_ave==.
}
*

* check for summary statistics
egen tem_ave_bin=rowtotal(tem_ave_pbin10-tem_ave_pbin100)

sum tem_ave_bin 
* the sum of most observations are 7
* the rest are caused by missing values 

save "$datadir/weather_week.dta", replace


**********************************************************************************
*						                                                         *
* national population data in 2010                                         *******************
**********************************************************************************
*pop2010.dta

**********************************************************************************
*						                                                         *
* merge                                          *******************
**********************************************************************************

* use dsp death data
use "$datadir/death_rate.dta", clear
rename code dsp_code 
rename dspname dsp_county

* merge with gis code book
merge m:1 dsp_code using "$datadir/dsp_gis_code.dta"
keep if _merge==3
drop _merge

* merge with inversion data
merge 1:1 dsp_code week using "$datadir/inversion_week.dta"
keep if _merge==3
drop _merge

* merge with weather data
merge 1:1 dsp_code week using "$datadir/weather_week.dta"
keep if _merge==3
drop _merge

* merge with pollution data
merge 1:1 dsp_code week using "$datadir/pollution_week.dta"
keep if _merge==3
drop _merge

* merge with 2010 population data
gen id=1 
merge m:1 id using "$datadir/pop2010.dta"
drop _merge id
sort dsp_code week 
drop N_week 

order dsp_code gis_code dsp_county gis_county provcode provname urb_rur year month day week week_year


**********************************************************************************
*						                                                         *
* label                                       *******************
**********************************************************************************

foreach V of varlist _all {
label var `V' "" 
}
*

*** dsp data

tostring dsp_code, replace
gen dsp_pref=substr(dsp_code,1,4)
gen dsp_prov=substr(dsp_code,1,2)
drop provcode

foreach V of varlist dsp_code dsp_pref dsp_prov {
  destring `V', replace
}
*

label var urb_rur "1: urban districts: 2: rural counties"

label var f0d25 "suicide cases for female 0-1"
label var f0d25 "mental death cases for female 0-1"

label var m0d25 "suicide cases for male 0-1"
label var m0d25 "mental death cases for male 0-1"

drop N_pop

label var mtotal "dsp total population for male: person"
label var m0pop "dsp population for male 0-1: person"

label var ftotal "dsp total population for female: person"
label var f0pop "dsp population for female 0-1: person" 

label var total "dsp total population: person"
label var t0pop "dsp population for 0-1: person" 

label var f0d24_rate "female 0-1 suicide rate: per 1m people"
label var f0d25_rate "female 0-1 mental death rate: per 1m people"
label var f1d24_rate "female 1-5"
label var f5d24_rate "female 5-10"
label var f10d24_rate "female 10-15"
label var f15d24_rate "female 15-20"
label var f20d24_rate "female 20-25"
label var f25d24_rate "female 25-30"
label var f30d24_rate "female 30-35"
label var f35d24_rate "female 35-40"
label var f40d24_rate "female 40-45"
label var f45d24_rate "female 45-50"
label var f50d24_rate "female 50-55"
label var f55d24_rate "female 55-60"
label var f60d24_rate "female 60-65"
label var f65d24_rate "female 65-70"
label var f70d24_rate "female 70-75"
label var f75d24_rate "female 75-80"
label var f80d24_rate "female 80-85"
label var f85d24_rate "female >=85"

*** air pollution data

label var aqi "air quality index"
label var pm25 "ug/m3"
label var o3 "ug/m3"
label var pm10 "ug/m3"
label var so2 "ug/m3"
label var no2 "ug/m3"
label var co "mg/m3"

*** inversion data

label var TINumD1 "inversion number using layers 1 and 2: times"
label var TIIndD1 "inversion days using layers 1 and 2: days"
label var TIStrD1 "inversion strength using layers 1 and 2: celsius"
label var TINumD2 "inversion number using layers 1 and 3: times"
label var TIIndD2 "inversion days using layers 1 and 3: days"
label var TIStrD2 "inversion strength using layers 1 and 3: celsius"

*** weather data

label var tem_ave_pbin10 "<10th percentile"
label var tem_ave_pbin100 ">90th percentile"

label var tem_ave "daily average temperature: C"
label var tem_max "daily max temperature: C"
label var tem_min "daily min temperature: C"
label var pre "precipitation: mm"
label var ssd "sunshine duration: h"
label var win "wind speed: m/s"
label var rhu "relative humidty: %"
label var prs "pressure: hpa"

drop tem_ave_bin 

************ rename all population data

*** dsp pop data

foreach i in 0 1 5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 {
rename m`i'pop m`i'_dsppop
rename f`i'pop f`i'_dsppop
}
*

drop mtotal ftotal total

gen m_dsppop=m0_dsppop+m1_dsppop+m5_dsppop+m10_dsppop+m15_dsppop+ ///
m20_dsppop+m25_dsppop+m30_dsppop+m35_dsppop+m40_dsppop+m45_dsppop+ ///
m50_dsppop+m55_dsppop+m60_dsppop+m65_dsppop+m70_dsppop+m75_dsppop+ ///
m80_dsppop+m85_dsppop 

gen f_dsppop=f0_dsppop+f1_dsppop+f5_dsppop+f10_dsppop+f15_dsppop+ ///
f20_dsppop+f25_dsppop+f30_dsppop+f35_dsppop+f40_dsppop+f45_dsppop+ ///
f50_dsppop+f55_dsppop+f60_dsppop+f65_dsppop+f70_dsppop+f75_dsppop+ ///
f80_dsppop+f85_dsppop 

gen t_dsppop=m_dsppop+f_dsppop

*** China pop data
foreach i in 0 1 5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 {
rename total`i' t`i'_chinapop
rename male`i' m`i'_chinapop
rename female`i' f`i'_chinapop
}
*

gen m_chinapop=m0_chinapop+m1_chinapop+m5_chinapop+m10_chinapop+m15_chinapop ///
+m20_chinapop+m25_chinapop+m30_chinapop+m35_chinapop+m40_chinapop ///
+m45_chinapop+m50_chinapop+m55_chinapop+m60_chinapop+m65_chinapop ///
+m70_chinapop+m75_chinapop+m80_chinapop+m85_chinapop 

gen f_chinapop=f0_chinapop+f1_chinapop+f5_chinapop+f10_chinapop+f15_chinapop ///
+f20_chinapop+f25_chinapop+f30_chinapop+f35_chinapop+f40_chinapop ///
+f45_chinapop+f50_chinapop+f55_chinapop+f60_chinapop+f65_chinapop ///
+f70_chinapop+f75_chinapop+f80_chinapop+f85_chinapop 

gen t_chinapop=m_chinapop+f_chinapop

*** construct death rates for certain groups using age adjusted 

*** for all females 

foreach i of numlist 24 25 {

gen fd`i'_rate=(f0d`i'_rate*f0_chinapop+f1d`i'_rate*f1_chinapop ///
+f5d`i'_rate*f5_chinapop+f10d`i'_rate*f10_chinapop ///
+f15d`i'_rate*f15_chinapop+f20d`i'_rate*f20_chinapop ///
+f25d`i'_rate*f25_chinapop+f30d`i'_rate*f30_chinapop ///
+f35d`i'_rate*f35_chinapop+f40d`i'_rate*f40_chinapop ///
+f45d`i'_rate*f45_chinapop+f50d`i'_rate*f50_chinapop ///
+f55d`i'_rate*f55_chinapop+f60d`i'_rate*f60_chinapop ///
+f65d`i'_rate*f65_chinapop+f70d`i'_rate*f70_chinapop ///
+f75d`i'_rate*f75_chinapop+f80d`i'_rate*f80_chinapop ///
+f85d`i'_rate*f85_chinapop) ///
/f_chinapop
label var fd`i'_rate "female d`i' rate"

*** for all males

gen md`i'_rate=(m0d`i'_rate*m0_chinapop+m1d`i'_rate*m1_chinapop ///
+m5d`i'_rate*m5_chinapop+m10d`i'_rate*m10_chinapop ///
+m15d`i'_rate*m15_chinapop+m20d`i'_rate*m20_chinapop ///
+m25d`i'_rate*m25_chinapop+m30d`i'_rate*m30_chinapop ///
+m35d`i'_rate*m35_chinapop+m40d`i'_rate*m40_chinapop ///
+m45d`i'_rate*m45_chinapop+m50d`i'_rate*m50_chinapop ///
+m55d`i'_rate*m55_chinapop+m60d`i'_rate*m60_chinapop ///
+m65d`i'_rate*m65_chinapop+m70d`i'_rate*m70_chinapop ///
+m75d`i'_rate*m75_chinapop+m80d`i'_rate*m80_chinapop ///
+m85d`i'_rate*m85_chinapop) ///
/m_chinapop
label var md`i'_rate "male d`i' rate"

*** for all population
gen d`i'_rate=(fd`i'_rate*f_chinapop+md`i'_rate*m_chinapop)/(f_chinapop+m_chinapop)
}
*

order dsp_code-d24_rate fd24_rate md24_rate d25_rate fd25_rate md25_rate 

save "$datadir/data.dta", replace 



