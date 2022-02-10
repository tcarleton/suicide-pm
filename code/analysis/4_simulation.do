**********************************************************************************

* This script conducts a simulation to quantify how many suicides have been 
* avoided due to observed declines in air pollution in recent years. Results 
* from this script are shown in Figure 3.

* This script calls regression results from code/analysis/2_regression.do. 
* All suicide and population data are proprietary and were accessed under 
* user agreements that do not allow for public distribution. 

**********************************************************************************

**********************************************************************************				                                                         *
* Set up *
**********************************************************************************

// wd
cd ~
	if regexm("`c(pwd)'","/Users/tammacarleton")==1 {
	global root "~/Dropbox/suicide"
	global datadir "$root/main_2017"
	global codedir "~/Dropbox/Works_in_progress/git_repos/suicide-pm"
	global resdir "$codedir/results"
	global sterdir "$codedir/results/ster"
	cd $datadir
	} 
	else {
	di "NEED TO CONFIGURE FILEPATH FOR THIS USER"
	}
	
// toggles
	
* do you want to just run a quick test run?
loc test = "FALSE"

* do you want to plot some example trends?
loc plot = "FALSE"

**********************************************************
	* Estimate county-specific trends in pollution from 2013-2018
	* Use trends to construct counterfactual time series of pollution
**********************************************************

* Pollution data: by county-day, from 2013, Jan 18 (earliest date a county has data)
* All counties start in 2013, all end in 2018
use "$datadir/pollution_county_daily_2013_2018.dta", clear

* Collapse to weekly exactly as is done in the analysis
bysort county_id: gen n=_n
gen week=ceil(n/7)+107
drop n
sort county_id year month day
collapse (mean) aqi-co (firstnm) year month day, by(county_id week)


* generate county-specific time trends
egen uniqueccode = group(county_id)

* if testing only, keep just 10 counties
if "`test'" == "TRUE" {
	keep if uniqueccode <=10 
}

qui summ uniqueccode 

	* new way
	gen pm25_detrended = .
	gen pm25_trend = .
	gen constant = .
	forvalues i = `r(min)'/`r(max)' {
		qui summ pm25 if uniqueccode == `i'
		if `r(N)' != 0 {
			* starting week of sample for this county
			qui summ week if uniqueccode == `i'
			loc startwk = `r(min)'
			* generate detrended variable
			qui reg pm25 week if uniqueccode == `i'
			replace pm25_detrended = pm25 - _b[week]*(week-`startwk') if uniqueccode == `i' & week>= `startwk'
			replace pm25_trend = _b[week] if uniqueccode == `i' 
			replace constant = _b[_cons] if uniqueccode == `i' 
			di "Done with county # `i'"
			} 
			else {
			di "No PM observations to run trend estimation with"
			}
		}

* Added trend and constant in order to calculate alternative yhat_diff that avoids missing values

* predicted value of pm2.5 
gen pm25_hat= constant+(pm25_trend*week)
			
* plot check 
if "`plot'" == "TRUE" {
forvalues i = 1/10 {
	tw lfit pm25 week if uniqueccode == `i' , lcolor(gs9) || line pm25_detrended week if uniqueccode ==`i', color(navy*.5) lpattern(solid) || ///
	line pm25 week if uniqueccode == `i' , lcolor(navy) lpattern(solid) xlabel(, nogrid) ylabel(, nogrid) ytitle("PM2.5")
	graph export "$resdir/figures/appendix/detrending_example_county`i'.pdf", replace
	}
}

**********************************************************
		* Generate difference in the suicide rate between
		* actual and detrended pollution
**********************************************************

* main model, no lags, no heterogeneity
estimates use "$sterdir/winsor_p98_d24_rate_TINumD1.ster"
estimates

ren county_id dsp_code
destring dsp_code, replace

* compute difference in predicted suicide rates between "actual" (with trend)
* and "counterfactual" (without trend). Since the response function is linear,
* this is the same as beta times difference between predicted pollution in year 
* t and in year 0.

* find first week for each dsp_code
bysort dsp_code: egen firstweek = min(week)
bysort dsp_code: gen pm25_hat_fw= pm25_hat if week==firstweek
bysort dsp_code: replace pm25_hat_fw=pm25_hat_fw[_n-1] if pm25_hat_fw[_n-1]!=. 
		
gen yhat_diff = _b[pm25] *(pm25_hat_fw - pm25_hat)

* interpretation of yhat_diff: this is the change in the weekly suicide rate in each 
* county-week that is *due* to declining overall pollution levels 

if "`test'" == "FALSE" {
	save "$datadir/yhats_simulated.dta", replace
}


**********************************************************
		* County-specific total change in suicide rate
		* & county-specific total deaths saved
**********************************************************

*---------------------------*
** new population data
*---------------------------*

// clean up county population data for merge

use  "$datadir/pop2000_2019.dta", clear 

ren county_id dsp_code

// convert population to total levels (currently in units of 10,000)
gen pop_tot = pop*10000

sort dsp_code year

* pollution data until 2018, so drop 2019
drop if year==2019

xtset dsp_code year

keep if year>=2013
keep year dsp_code pop_tot pop

tab year

* unbalanced panel, more missings in the later years 

** add observations to the year variable even if the population is missing
* since we will impute missing values later

tsfill, full
tab year

** CHECKING missings in population data
 
codebook pop_tot

gen miss_pop_tot=1 if pop_tot==.
replace miss_pop_tot=0 if pop_tot!=.

tempfile ccpop
save "`ccpop'", replace

use "$datadir/yhats_simulated.dta", clear

// Note that this merge is imperfect because of some important
// county boundary changes that we cannot obtain correct population
// data for.
merge m:1 dsp_code year using "`ccpop'"

// to merge with census data
tostring dsp_code, gen(county_id)

ren _merge merge_code_popdata

preserve
use "$datadir/pop2015.dta", clear
tostring code, gen(county_id)
tempfile pop2015
save "`pop2015'", replace

restore
merge m:1 county_id using "`pop2015'"

rename total pop2015

* note that there are 95 counties without any population data that do have pm data
* tab dsp_code if pop_tot==. & pop2015==.

* drop the counties that don't appear in pm or population data
drop if _merge==2

drop aqi county_id o3 pm10 so2 no2 co uniqueccode _merge merge_code_popdata

* check population data
replace miss_pop_tot=1 if  miss_pop_tot==.

tempfile merged_data
save "`merged_data'", replace

** check number of weeks with missing population data in each county that did not merge

collapse (sum) miss_pop_tot, by(dsp_code year) 

gen nomissing=(miss_pop_tot==0)

collapse (sum) miss_pop_tot nomissing, by(dsp_code) 

rename miss_pop_tot miss_pop_wks
save "$datadir/Counties_missingpopdata.dta", replace

*******************************************
* Fill in holes in population data
*******************************************

use "`merged_data'", clear
merge m:1 dsp_code using "$datadir/Counties_missingpopdata.dta"

drop _merge

drop if week>396
* only 1 county satistfies this (only has census data)

* still unbalanced panel
xtset dsp_code week
drop if year==2018

** Identify which counties do not have any population data
* nomissing=0 are counties that don't have population data from yearbook

* Calculate average population by county over study period
bysort dsp_code: egen avpop_tot=mean(pop_tot)

****** for those counties without any year of population in the yearbook data -> use census data
replace avpop_tot=pop2015 if nomissing==0

* we have 68 counties for which there's no population data at all

*******************************
* Calculate lives saved
********************************

* total lives in each week -- NOTE: regression is run in rates that are deaths per million people
gen lives_saved = yhat_diff*(avpop_tot/1000000) // this is: number of lives saved in each county in each week due to PM declines

* total lives saved over the entire period, by county
bysort dsp_code: egen lives_saved_tot = sum(lives_saved)

* save for plotting
save "$datadir/lives_saved.dta", replace

preserve
* sum across the country
collapse (sum) lives_saved, by(year)

sort year
di "Total lives saved in 2017 = " lives_saved[_N]
*Total lives saved in 2017 = 14629.877

collapse (sum) lives_saved
di "Total lives saved over 2013-2017 period = " lives_saved[1]
* Total lives saved over 2013-2017 period = 40430.009

restore
/*
br dsp_code week pm25_detrended yhat_diff pop_tot pop_totm lives_saved lives_saved_tot if lives_saved ==.
* note that there are still cases in which lives saved is missing because
* pm data is missing and/or population data is missing
* e.g. in county  in county dsp_code==542325 there are holes in the pollution data
br if dsp_code==542325
*/

qui summ week if lives_saved !=.
keep if week==`r(max)'

sort lives_saved_tot
drop if lives_saved_tot==0
gen rank = _n

* Extract city code with first 4 digits of county code
tostring dsp_code, gen(county_id)

gen city_id=substr(county_id,1,4)
destring city_id, replace
* there are multiple counties per city so we'll label counties, not cities

sum lives_saved_tot	
di "Number of counties included in calculation = " r(N)	
*2721 counties	

** find 10 most populous counties
gen neg_avpoptot= - avpop_tot
sort neg_avpoptot

gen rank_avpoptot=_n

* 10 most populous counties:
gen top_pop=(rank_avpoptot<11)
tab dsp_code if top_pop==1

* label position
gen pos=9
replace pos=7 if dsp_code==	420113
replace pos=9 if dsp_code== 310112
replace pos=10 if dsp_code== 440306
replace pos=10 if dsp_code== 310116

* label key cities
gen dspname_Eng = "Baoan" if dsp_code==440306
replace dspname_Eng = "Guiping" if dsp_code==450881
replace dspname_Eng = "Minhang" if dsp_code==310112
replace dspname_Eng = "Jinshan" if dsp_code==310116
replace dspname_Eng = "Dongguan" if dsp_code==441900
replace dspname_Eng = "Pudong" if dsp_code==310115
replace dspname_Eng = "Chaoyang" if dsp_code==110105
replace dspname_Eng = "Haidian" if dsp_code==110108



	
count if lives_saved_tot!=.
loc xmax = r(N)

twoway (dropline lives_saved_tot rank if top_pop==1, mlabel(dspname_Eng) mlabv(pos) mlabsize(vsmall) msymbol(smdiamond) mcolor(gs8) msize(small) /// 
		lwidth(vthin) lpattern(solid) lcolor("236 133 95%80")) /// format of vertical lines/bars (area under graph)
		(dropline lives_saved_tot rank if top_pop==0, msymbol(smcircle) mcolor(gs8) msize(tiny) /// format of grey dots
		lwidth(vthin) lpattern(solid) lcolor("236 133 95%80")) /// format of vertical lines/bars (area under graph)
		, ///
		ytitle("Total avoided suicides per county: 2013-2017")  ///
		xtitle("Counties by rank order of avoided suicides") ///
		xlabel(0(400)`xmax', labcolor(bg) tlength(0) nogrid) yline(0, lpattern(solid) lcolor(gs12) lwidth(vthin)) ///
		xscale(r(0 `xmax') noextend) ylabel(-45(10)105)	///
		legend(off) 	
* Right now we label dsp_code-> could replace with county name		
		
graph export "$resdir/figures/Fig3A_rankorder.pdf", replace


