**********************************************************************************

* This script generates panel B of Figure 2 in Zhang et al.

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

/*
// specs to show:
	* main: TINumD1, county and week FE, county and week clustering, winsorized
	* robustness: FGLS, FE, clustering, weather controls
*/

loc outcome = "d24_rate" // can make figure for men or women only if desired, using md24_rate or fd24_rate
loc p = "p98" // amount of winsorization

// robustness sets
loc felist "cMwFE" "counTFE" "cYwFE" "provTFE"
loc weatherlist "binWeather" "linWeather" "noWeather" 
loc cluslist "clNone" "clCounty" "clWeek"
loc instlist "TIIndD1" "TIStrD1" "OLS"

// total obs = number of combinations
loc obs = 14

**********************************************************************************
* Pull in all robustness results                                                
**********************************************************************************

// create a "results" dataset: cols = fe, clustering, inst, weather controls, outliers, beta, se
set obs `obs'

// main
estimates use "$sterdir/winsor_p98_d24_rate_TINumD1.ster"
gen modelgroup = (_n==1)
gen fe = "cwFE" 
gen clustering = "clCountyWeek" 
gen instrument = "TINumD1" 
gen weather = "quadWeather" 
gen outliers = "winsor_p98" 
gen beta = _b[pm25] if modelgroup==1
gen se = _se[pm25] if modelgroup==1

// loop over FEs
loc i = 2
foreach fe in "`felist'" {
	estimates use "$sterdir/winsor_p98_`outcome'_`fe'.ster"
	replace fe = "`fe'" in `i'
	replace modelgroup = 2 in `i'
	replace beta = _b[pm25] in `i'
	replace se = _se[pm25] in `i'
	loc i = `i'+1
}

// loop over weather
qui count if beta!=.
loc i = r(N)+1
foreach we in "`weatherlist'" {
	estimates use "$sterdir/winsor_p98_`outcome'_`we'.ster"
	replace weather = "`we'" in `i'
	replace modelgroup = 3  in `i'
	replace beta = _b[pm25] in `i'
	replace se = _se[pm25] in `i'
	loc i = `i'+1
}


// loop over clustering
qui count if beta!=.
loc i = r(N)+1
foreach cl in "`cluslist'" {
	estimates use "$sterdir/winsor_p98_`outcome'_`cl'.ster"
	replace clustering = "`cl'" in `i'
	replace modelgroup = 4 in `i'
	replace beta = _b[pm25] in `i'
	replace se = _se[pm25] in `i'
	loc i = `i'+1
}

// loop over instruments
qui count if beta!=.
loc i = r(N)+1
foreach iv in "`instlist'" {
	estimates use "$sterdir/winsor_p98_`outcome'_`iv'.ster"
	replace instrument = "`iv'" in `i'
	replace modelgroup = 5 in `i'
	replace beta = _b[pm25] in `i'
	replace se = _se[pm25] in `i'
	loc i = `i'+1
}

**********************************************************************************
* Pull in all robustness results                                                
**********************************************************************************

gsort -modelgroup
gen row = _n

gen ci95_lo = beta-1.96*se
gen ci95_hi = beta+1.96*se
gen ci90_lo = beta-1.645*se
gen ci90_hi = beta+1.645*se

* put OLS at top
replace row = 15 if instrument=="OLS"
sort row
replace row = row-1

* main spec vertical line
local x_line_main_spec = beta[_N-1]
local zeroline = 0

cap drop dummy
gen dummy = 0

loc mycolor = "105 106 107" //"167 203 226"
twoway /// 
	(pci 0 `x_line_main_spec' 14 `x_line_main_spec', lcolor("`mycolor'") lwidth(thin) lp(shortdash)) /// line at main spec
	(rspike ci95_lo ci95_hi row, horizontal color(gs10%40) yaxis(1)) ///
	(rspike ci90_lo ci90_hi row, horizontal color("`mycolor'%80") yaxis(1)) ///
	(pci 0 0 14 0, lcolor(black) lwidth(medthick)) /// line at 0
	(scatter row beta if modelgroup == 1, mcolor("`mycolor'") yaxis(1) msymbol(circle) msize(medlarge)) /// 
	(scatter row beta if modelgroup != 1, mcolor("`mycolor'") yaxis(1) msymbol(circle) mfcolor(white) msize(medlarge)) /// 
	, ///
	legend(off) ///
	xtitle("Effect of PM2.5 on weekly suicides per 1 million", size(medsmall)) /// 
	xlabel(, nogrid) ///
	ytitle("") ///
	ylabel(14 "OLS (no instrument)" /// OLS
		13 "{bf:Main specification}" /// 	spec 1
		12 "County x mo. FE" ///
		11 "County trends" ///
		10 "County x yr. FE" ///
		9 "Prov. trends" ///
		8 "Nonpar. weather" /// 	spec 2
		7 "Linear weather" ///
		6 "Weather omitted" /// 	spec 3
		5 "No clustering" ///
		4 "County clusters" ///
		3 "Week clusters" /// 	spec 5
		2 "Inversion days inst." ///
		1 "Inversion strength inst." /// 	spec 5
		, ///
		angle(0) labsize(2.7) noticks ) 
	
	
graph export "$resdir/figures/figure_2B.pdf", replace	

