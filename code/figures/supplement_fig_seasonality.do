
**********************************************************************************
* This script plots the seasonality of suicide in China for 
* Supplementary Figure XX                       *
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
	
