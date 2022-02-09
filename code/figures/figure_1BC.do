
**********************************************************************************

* This script generates panels B and C of Figure 1 in Zhang et al.

* Data called by this script are assembled in code/clean/1_merge.do. All suicide 
* and population data are proprietary and were accessed under user agreements 
* that do not allow for public distribution. Therefore, this code is for 
* transparency purposes only, and cannot directly be run with publicly available 
* data.

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
	cd $datadir
	} 
	else {
	di "NEED TO CONFIGURE FILEPATH FOR THIS USER"
	}


use data_winsorize, clear

set scheme plotplain

// clean up dates
gen date = mdy(month, day ,year)
gen weekdate = wofd(date)
gen modate = mofd(date)
preserve

**********************************************************************************
* Figure 1B: Trend in suicide over time		                                                  
**********************************************************************************

// smooth by week (raw data) or month (avg across month)?
loc smooth = "weekdate" // "modate"

// collapse across different groups
collapse (mean) d24_rate [aw=t_dsppop], by(`smooth')
tempfile totrate
save "`totrate'", replace

// by gender and rural/urban
foreach ss in "m" "f" {
	restore
	preserve
	collapse (mean) `ss'd24_rate [aw=`ss'_dsppop], by(`smooth')
	tempfile `ss'rate
	save "``ss'rate'", replace
	}
	
// overlay
restore 
preserve
use "`totrate'", clear
foreach ss in "m" "f" {
	merge 1:1 `smooth' using "``ss'rate'"
	drop _merge
	}

if "`smooth'" == "weekdate" {
	format `smooth' %tw
}
else {
	format `smooth' %tm
	}
	
// show linear trend line
	
tw  line md24_rate `smooth', lcolor("167 203 226") lpattern(solid) || ///
	line d24_rate `smooth', lcolor(black) lpattern(solid) lwidth(medthick) || ///
	line fd24_rate `smooth', lcolor("236 133 95") lpattern(solid) ///
	legend(order(1 "Male" 2 "Total" 3 "Female")) ///
	ylabel(, nogrid) xlabel(, nogrid) ///
	ytitle("Suicide rate (per 10,000)") xtitle("Date")
	
graph export "$resdir/figures/figure_1B_`smooth'.pdf", replace	

**********************************************************************************
* Figure 1C: Pollution and Inversions                                            
**********************************************************************************

* first stage 

use data_winsorize, clear
global control2 ///
pre-prs pre2-prs2

keep if d24_rate !=. & pm25 !=. & TINumD1 !=. & tem_ave !=. & pre !=. & ssd !=. & win !=. & rhu !=. & prs !=. 

reghdfe pm25 TINumD1 $control2, absorb(dsp_code week) cluster(dsp_code week)

loc mmin = 0
loc mmax = 20
loc omit = 10
loc obs = `mmax'-`mmin'

drop if _n>0	
keep pm25 TINumD1
loc obsr = round(`obs') +1

set obs `obsr'
replace TINumD1 = _n + `mmin' +1 

predictnl that = _b[TINumD1]*(TINumD1-`omit'), ci(lower upper)

tw rarea upper lower TINumD1, color("60 122 183%60") || line that TINumD1, lpattern(solid) lcolor("60 122 183") lwidth(medthick) ///
	yline(0, lwidth(vthin) lcolor(gs9) lpattern(shortdash)) ylabel(,nogrid) xlabel(,nogrid) ///
	xtitle("Number of inversions per week") ytitle("Weekly average PM2.5 (ug/m3)") legend(off)
graph export "$resdir/figures/figure_1C.pdf", replace	
