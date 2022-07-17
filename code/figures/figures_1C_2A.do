
**********************************************************************************

* This script generates panel C of Figure 1 and panel A of Figure 2 in Zhang et al.

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
* Figure 1C: Trend in suicide over time		                                                  
**********************************************************************************

// smooth by week (raw data) or month (avg across month)?
loc smooth = "weekdate" // "modate"

// collapse across different groups
collapse (mean) d24_rate pm25 [aw=t_dsppop], by(`smooth')
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
	
/*// show linear trend line
tw line pm25 `smooth', lcolor(eltblue) lpattern(shortdash)	
	
tw  line md24_rate `smooth', lcolor("167 203 226") lpattern(solid) || ///
	line d24_rate `smooth', lcolor(black) lpattern(solid) lwidth(medthick) || ///
	line fd24_rate `smooth', lcolor("236 133 95") lpattern(solid) ///
	legend(order(1 "Male" 2 "Total" 3 "Female")) ///
	ylabel(, nogrid) xlabel(, nogrid) ///
	ytitle("Suicide rate (per 10,000)") xtitle("Date")


tw  line md24_rate `smooth', lcolor("167 203 226") lpattern(solid) yaxis(1) || ///
	line d24_rate `smooth', lcolor(black) lpattern(solid) lwidth(medthick) yaxis(1) || ///
	line fd24_rate `smooth', lcolor("236 133 95") lpattern(solid) yaxis(1) || ///
	line pm25 `smooth', lcolor(eltblue) lpattern(shortdash) yaxis(2) ///
	legend(order(1 "Male" 2 "Total" 3 "Female")) ///
	ylabel(, nogrid) xlabel(, nogrid) ///
	ytitle("Suicide rate (per 10,000)", axis(1)) ///
	ytitle("PM2.5 (ug/m3)", axis(2)) xtitle("Date")
*/

// double y-axes: show suicide and pm25	
tw  line d24_rate `smooth', lcolor(black%80) lpattern(solid) lwidth(medthick) yaxis(1) || ///
	line pm25 `smooth', lcolor(eltblue%80) lpattern(solid) lwidth(medthick) yaxis(2) lwidth(medthick)  || ///
	lfitci d24_rate `smooth', lcolor(black) lpattern(solid) lwidth(medthick) yaxis(1) fcolor(black%60) alwidth(none) || ///
	lfitci pm25 `smooth', lcolor(eltblue) lpattern(solid) lwidth(medthick) yaxis(2) fcolor(eltblue%60)   alwidth(none) ///
	legend(order(1 "Suicide rate" 4 "PM2.5")) ///
	ylabel(, nogrid) xlabel(, nogrid) ///
	ytitle("Weekly suicide rate per 1 million", axis(1)) ///
	ytitle("PM2.5 (ug/m3)", axis(2)) xtitle("Date")	
	
graph export "$resdir/figures/figure_1C_`smooth'.pdf", replace	

**********************************************************************************
* Figure 1C: Pollution and Inversions                                            
**********************************************************************************

* first stage 

use data_winsorize, clear
global control2 ///
pre-prs pre2-prs2

keep if d24_rate !=. & pm25 !=. & TINumD1 !=. & tem_ave !=. & pre !=. & ssd !=. & win !=. & rhu !=. & prs !=. 

// regress pm2.5 on all inversion variables, store coefficients
foreach V of varlist TINumD1 TIStrD1 TIIndD1 {
	reghdfe pm25 `V' $control2, absorb(dsp_code week) cluster(dsp_code week)
	loc b_`V' = _b[`V']
	loc se_`V' = _se[`V']
}


drop if _n>0
set obs 3
keep pm25 
gen group = "TINumD1"
replace group = "TIStrD1" in 2
replace group = "TIIndD1" in 3
drop pm25
gen beta = .
gen lower = .
gen upper = .

foreach V in "TINumD1" "TIStrD1" "TIIndD1" {
	replace beta = `b_`V'' if group=="`V'"
	replace lower = beta-1.96*`se_`V'' if group=="`V'"
	replace upper = beta+1.96*`se_`V'' if group=="`V'"
}

gen groupnum = _n
gen groupname = "Number of inversions" 
replace groupname = "Strength of inversion" in 2
replace groupname = "Presence of inversion" in 3

labmask groupnum, values(groupname)

tw  rspike upper lower groupnum, color("236 133 95") lwidth(thick) || sc beta groupnum, msymbol(O) mlcolor("236 133 95") mfcolor(white) msize(2.5) mlwidth(thick) /// 
	yline(0, lpattern(shortdash) lcolor(gs10)) ///
	ylabel(0(.5)2.5, nogrid) xlabel(1(1)3, nogrid valuelabel) ///
	ytitle("Effect of inversions on PM2.5") xtitle("Inversions variable") ///
	legend(order(2 "point estimate" 1 "95% confidence interval"))
	
	
graph export "$resdir/figures/figure_2A.pdf", replace	

