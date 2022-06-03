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

set scheme plotplain

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

gen yhat_actual = _b[pm25]*pm25
gen yhat_counterfactual = _b[pm25]*pm25_detrended	
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

// merge in crosswalk
use "$datadir/pop/id_new.dta", clear

* these counties (for which we have pollution data) have no 
* available and matching  population data (N=339/2,845)
drop if county_id_pop==. 
tempfile cw
save "`cw'", replace

use "$datadir/pop/pop_new.dta", clear
merge m:1 county_id_pop using "`cw'"
drop _merge

* these counties have population data but no matching IDs in the pollution data
* (i.e., cannot match county IDs across the two datasets)
drop if county_id_pol==.
ren county_id_pol dsp_code

// convert population to total levels (currently in units of 10,000)
gen pop_tot = pop*10000

sort dsp_code year

* pollution data range: 2013-2018
keep if year>=2013 & year<=2018

xtset dsp_code year

tempfile popdata
save "`popdata'", replace

*---------------------------*
** merge with simulated suicide rate changes
*---------------------------*

use "$datadir/yhats_simulated.dta", clear

merge m:1 dsp_code year using "`popdata'"
* all the unmerged observations are those for which county_id_pop==. in id_new.dta
* that is, they have no matching population data available (N=339/2845)
drop if _merge==1
drop _merge

*---------------------------*
** Calculate lives saved
*---------------------------*

* total lives in each week -- NOTE: regression is run in rates that are deaths per million people
gen lives_saved = yhat_diff*(pop_tot/1000000) // this is: number of lives saved in each county in each week due to PM declines

* total lives saved over the entire period, by county
bysort dsp_code (lives_saved) : gen allmissing = mi(lives_saved[1])
bysort dsp_code: egen lives_saved_tot = sum(lives_saved)
replace lives_saved_tot = . if allmissing // missingness here from missing aqi data

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
gen neg_poptot= - pop_tot
sort neg_poptot

gen rank_poptot=_n

* 10 most populous counties:
gen top_pop=(rank_poptot<11)
tab dsp_code if top_pop==1

* label position
gen pos=9
replace pos=7 if dsp_code==	320382
replace pos=10 if dsp_code== 321322
replace pos=10 if dsp_code== 310116

* label key cities
cap drop dspname_Eng
gen dspname_Eng = "Binhai New District" if dsp_code==120116 
replace dspname_Eng = "Minhang District" if dsp_code==310112
replace dspname_Eng = "Baoshan District" if dsp_code==310113 
replace dspname_Eng = "Pudong New District" if dsp_code==310115 
replace dspname_Eng = "Pizhou City" if dsp_code==320382 
replace dspname_Eng = "Shuyang County" if dsp_code==321322
replace dspname_Eng = "Jinjiang City" if dsp_code==350582 
replace dspname_Eng = "Lufeng City" if dsp_code==441581 
replace dspname_Eng = "Puning City" if dsp_code==445281  
replace dspname_Eng = "Wuhou District" if dsp_code==510107

* x axis range	
count if lives_saved_tot!=.
loc xmax = r(N)
di `xmax'
drop if rank>`xmax'

loc mycolorgreen = "11 78 68"
loc mycolortan = "201 152 76"

twoway (dropline lives_saved_tot rank if top_pop==0, msymbol(smcircle) mcolor("`mycolortan'") msize(tiny) /// format of grey dots
		lwidth(vthin) lpattern(solid) lcolor("`mycolorgreen'"%80)) /// format of vertical lines/bars (area under graph)
		(dropline lives_saved_tot rank if top_pop==1, mlabel(dspname_Eng) mlabv(pos) mlabsize(vsmall) msymbol(diamond) mcolor(white) msize(medium) mlcolor("`mycolortan'") /// 
		lwidth(vthin) lpattern(solid) lcolor("`mycolortan'%80")) /// format of vertical lines/bars (area under graph)
		, ///
		ytitle("Total avoided suicides per county: 2013-2017")  ///
		xtitle("Counties by rank order of avoided suicides") ///
		xlabel(0(400)`xmax', labcolor(bg) tlength(0) nogrid) yline(0, lpattern(solid) lcolor(gs12) lwidth(vthin)) ///
		xscale(r(0 `xmax') noextend) 	/// 
		legend(off) 		
		
graph export "$resdir/figures/Fig3B_rankorder.pdf", replace


