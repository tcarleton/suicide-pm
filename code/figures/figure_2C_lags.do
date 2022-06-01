**********************************************************************************

* This script generates panel C of Figure 2 in Zhang et al.

* Data called by this script are assembled in 2_regression.do and 
* 3_heterogeneity.do. 

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

clear
 
set scheme plotplain

loc outcome = "d24_rate" // can make figure for men or women only if desired
loc p = "p98" // amount of winsorization

**********************************************************************************
* Pull in reduced form lag results                                               
**********************************************************************************

// Parameters
loc lags 8
loc N = `lags'+4
set obs `N'
gen lag = _n-1

// main
estimates use "$sterdir/winsor_`p'_`outcome'_lagRF8.ster"  

**********************************************************************************
* Plot                                       
**********************************************************************************

// yline parameterization for display 
replace lag = -1 in `N'
replace lag = 0.5 if lag>`lags'+1
replace lag = `lags'+.5 if lag>`lags'
gen yline1 = 0 if lag < 0
gen yline2 = 0 if lag >=0
sort lag

gen b = .
foreach num of numlist 90 95 {
	gen lb`num' = .
	gen ub`num' = .
}

// cumulative effects
lincom TINumD1 + TINumD1_lag1 + TINumD1_lag2+ TINumD1_lag3+ TINumD1_lag4+ TINumD1_lag5+ TINumD1_lag6+ TINumD1_lag7+ TINumD1_lag8
replace b = r(estimate) if lag == -1
replace lb95 = r(estimate)-1.96*r(se) if lag == -1
replace ub95 = r(estimate)+1.96*r(se) if lag == -1
replace lb90 = r(estimate)-1.645*r(se) if lag == -1
replace ub90 = r(estimate)+1.645*r(se) if lag == -1

// contemporaneous
replace b = _b[TINumD1] if lag == 0
replace lb95 = _b[TINumD1]-1.96*_se[TINumD1] if lag == 0
replace ub95 = _b[TINumD1]+1.96*_se[TINumD1] if lag == 0
replace lb90 = _b[TINumD1]-1.645*_se[TINumD1] if lag == 0
replace ub90 = _b[TINumD1]+1.645*_se[TINumD1] if lag == 0

// each lag 	
foreach ll of numlist 1/8  {
	replace b = _b[TINumD1_lag`ll'] if lag == `ll'
	replace lb95 = _b[TINumD1_lag`ll']-1.96*_se[TINumD1_lag`ll'] if lag == `ll'
	replace ub95 = _b[TINumD1_lag`ll']+1.96*_se[TINumD1_lag`ll'] if lag == `ll'
	replace lb90 = _b[TINumD1_lag`ll']-1.645*_se[TINumD1_lag`ll'] if lag == `ll'
	replace ub90 = _b[TINumD1_lag`ll']+1.645*_se[TINumD1_lag`ll'] if lag == `ll'
}	

// plot
tw ///
	(rspike ub95 lb95 lag if lag<0,  color("105 106 107%40") lwidth(medthick)) ///
	(rspike ub90 lb90 lag if lag<0,  color("105 106 107%80") lwidth(medthick)) ///
	(sc b lag if lag<0,  mcolor("105 106 107") msymbol(O) msize(medlarge)) ///
	(rspike ub95 lb95 lag if lag>=0,  color("60 122 183%40") lwidth(medthick)) ///
	(rspike ub90 lb90 lag if lag>=0,  color("60 122 183%80") lwidth(medthick)) ///
	(sc b lag if lag>=0,  mcolor("60 122 183") msymbol(circle) mfcolor(white) msize(medlarge)), /// 
	xline(-0.5, lcolor(gs6) lpattern(solid)) ///
	yline(0, lcolor(gs12) lpattern(shortdash)) ///
	ytitle("Effect of thermal inversions on suicides per 10,000", margin(zero)) ///
	xtitle("lag (weeks)") ylabel(, nogrid) ///
	xscale(r(-1.5 8)) ///
	xlabel(-1 `" "Cumulative" "effect" "' 0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 "5" 6 "6" 7 "7" 8 "8", nogrid) ///
	legend(off) 
	
graph export "$resdir/figures/figure_2C.pdf", replace	


