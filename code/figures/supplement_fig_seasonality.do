
**********************************************************************************
* This script plots the seasonality of suicide in China for 
* Supplementary Figures S1 and YY                       *
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

**********************************************************************************
			* Seasonality of suicides *
**********************************************************************************

* dates
gen date = mdy(month, day ,year)
gen weekdate = wofd(date)
gen modate = mofd(date)

* collapse to avg by date
collapse (mean) d24_rate fd24_rate md24_rate aqi pm* TINumD1 [aw=t_dsppop], by(weekdate month year)

* plot
set scheme s1color
twoway line md24_rate week, color(black) xline(26 78 130 182 234, lcolor(sienna)) ///
 || line fd24_rate week, color(emerald) 
 
generate upper = 1.6
generate lower = 0.5

* gen spring dummy
gen spring = (month==4 | month==5 | month==6)

format weekdate %tw

* plot: suicides over time
twoway line md24_rate weekdate, color(black) ytitle("Weekly suicide rate per 1 million") ///
 || line fd24_rate weekdate, color(emerald)  || rarea lower upper weekdate if spring==1 & year==2013, color(gs12%60)  ///
 || rarea lower upper weekdate if spring==1 & year==2014, color(gs12%60)  || rarea lower upper weekdate if spring==1 & year==2015, color(gs12%60) ///
 || rarea lower upper weekdate if spring==1 & year==2016, color(gs12%60) || rarea lower upper weekdate if spring==1 & year==2017, color(gs12%60) ///
 legend(order(1 "Male" 2 "Female" 3 "Spring months"))
graph export "$resdir/figures/supp_fig_seasonality.pdf", replace	

cap drop upperTI lowerTI
generate upperTI = 10
generate lowerTI = 0
	
* plot: inversions over time
twoway line TINumD1 weekdate, color(navy) ytitle("Number of weekly inversions") ///
 || rarea lowerTI upperTI weekdate if spring==1 & year==2013, color(gs12%60)  ///	
 || rarea lowerTI upperTI weekdate if spring==1 & year==2014, color(gs12%60)  || rarea lowerTI upperTI weekdate if spring==1 & year==2015, color(gs12%60) ///
 || rarea lowerTI upperTI weekdate if spring==1 & year==2016, color(gs12%60) || rarea lowerTI upperTI weekdate if spring==1 & year==2017, color(gs12%60) ///
 legend(order(1 "Thermal Inversions" 3 "Spring months"))
graph export "$resdir/figures/supp_fig_seasonality_TINumD1.pdf", replace	


**********************************************************************************
		* Residual variation in suicides, inversions, PM after removing FEs *
**********************************************************************************

set scheme s1color
use data_winsorize, clear

global control2 ///
tem_ave pre-prs tem_ave2 pre2-prs2


* dates
gen date = mdy(month, day ,year)
gen weekdate = wofd(date)
gen modate = mofd(date)
format weekdate %tw

capture drop *_resid*

foreach var in "d24_rate" "TINumD1" {
	qui reghdfe `var'  , a(dsp_code week) residuals(`var'_resid_main)
	qui reghdfe `var' , a(dsp_code#month week) residuals(`var'_resid_cm)
}

sort dsp_code weekdate	

loc width = "medthick"
loc id2 = 320382 
loc reg2 = "Pizhou" 
loc id1 = 430922
loc reg1 = "Taojiang" 

keep if dsp_code==`id1' | dsp_code==`id2'
gen dspname_Eng = "`reg1'" if dsp_code==`id1'
replace dspname_Eng = "`reg2'" if dsp_code==`id2'

keep *_resid* d24_rate weekdate dspname_Eng  TINumD1  
reshape wide *_resid* d24_rate   TINumD1 , i(weekdate) j(dspname_Eng) string

foreach var in "d24_rate" "TINumD1"  {
	if "`var'" == "d24_rate" {
		loc mycol1 = "black"
		loc mycol2 = "black%40"
		loc mytitle = "Suicide rate"
		}
	else {
		loc mycol1 = "dkgreen"
		loc mycol2 = "dkgreen%40"
		loc mytitle = "Thermal inversions"
	}

	* raw data
	tw line `var'`reg1' weekdate, color("`mycol1'") lwidth(`width') || line `var'`reg2' weekdate, color("`mycol2'") lpattern(solid) lwidth(`width') ///
	name(`var'_raw, replace) legend(order(1 "`reg1'" 2 "`reg2'")) ytitle("`mytitle'") title("Raw data") aspect(.8) ylabel(, nogrid)

	* residualized by space
	tw line `var'_resid_main`reg1' weekdate, color("`mycol1'") lwidth(`width') || line `var'_resid_main`reg2' weekdate, color("`mycol2'") lpattern(solid) lwidth(`width') ///
	name(`var'_space, replace) legend(order(1 "`reg1'" 2 "`reg2'")) ytitle("`mytitle'") title("County and week controls") aspect(.8) ylabel(, nogrid)


	* residualized by space and time
		tw line `var'_resid_cm`reg1' weekdate, color("`mycol1'") lwidth(`width') || line `var'_resid_cm`reg2' weekdate, color("`mycol2'") lpattern(solid) lwidth(`width') ///
	name(`var'_resid, replace) legend(order(1 "`reg1'" 2 "`reg2'")) ytitle("`mytitle'") title("County-month and week controls") aspect(.8) ylabel(, nogrid)
	
	}
	
	
graph combine TINumD1_raw TINumD1_space TINumD1_resid ///
	d24_rate_raw d24_rate_space d24_rate_resid, rows(2) altshrink imargin(vsmall)

graph export "$resdir/figures/supp_fig_residualization.pdf", replace
	
/*


	* raw data
	tw line `var'`reg2' weekdate, color("`mycol1'") lwidth(`width') lpattern(solid) ///
	name(`var'_raw, replace)  ytitle("`mytitle'") title("Raw data") aspect(.8) ylabel(, nogrid)


	* residualized by space
	tw line `var'_resid_main`reg2' weekdate, color("`mycol1'") lwidth(`width') lpattern(solid)  ///
	name(`var'_space, replace) xtitle("") ytitle("`mytitle'") title("County and week controls") aspect(.8) ylabel(, nogrid)


	* residualized by space and time
		tw line `var'_resid_cm`reg2' weekdate, color("`mycol1'") lwidth(`width') lpattern(solid)  ///
	name(`var'_resid, replace) xtitle("") ytitle("`mytitle'") title("County-month and week controls") aspect(.8) ylabel(, nogrid)
	
	
	
	}
	
	*/
