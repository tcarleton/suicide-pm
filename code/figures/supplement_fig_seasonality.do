
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

* collapse to avg by date
collapse (mean) d24_rate fd24_rate md24_rate aqi pm* [aw=t_dsppop], by(year month week)

* plot
set scheme s1color
twoway line md24_rate week, color(black) xline(26 78 130 182 234, lcolor(sienna)) ///
 || line fd24_rate week, color(emerald) 
 
generate upper = 1.6
generate lower = 0.5

* gen spring dummy
gen spring = (month==4 | month==5 | month==6)

format week %tm

* plot
twoway line md24_rate week, color(black) ytitle("Weekly suicide rate per 1 million") ///
 || line fd24_rate week, color(emerald)  || rarea lower upper week if spring==1 & year==2013, color(gs12%60)  ///
 || rarea lower upper week if spring==1 & year==2014, color(gs12%60)  || rarea lower upper week if spring==1 & year==2015, color(gs12%60) ///
 || rarea lower upper week if spring==1 & year==2016, color(gs12%60) || rarea lower upper week if spring==1 & year==2017, color(gs12%60) ///
 legend(order(1 "Male" 2 "Female" 3 "Spring months"))
graph export "$resdir/figures/supp_fig_seasonality.pdf", replace	
	
