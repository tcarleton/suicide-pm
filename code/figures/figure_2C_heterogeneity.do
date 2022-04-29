 
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

/*
// specs to show:
	* main: TINumD1, county and week FE, county and week clustering, winsorized
	* heterogeneity: i) male vs female
					ii) age groups
					iii) high vs low pollution
					iv) urban vs rural
					v) rich vs poor
*/

// heterogeneity sets
*loc outcome_sex "md24_rate" "fd24_rate"
*loc outcome_age "t0_15d24_rate" "t15_65d24_rate" "t65_85d24_rate"

//loc sexlist "m" "f"
//loc agelist "0_15" "15_65" "65_85"
loc sexagelist "m0_15" "f0_15" "m15_65" "f15_65" "m65_85" "f65_85"
loc pollutionlist "polluted" "lesspolluted"
loc urbanlist "urban" "rural"
loc incomelist "rich" "poor"
loc avgsuilist "Tercile1" "Tercile2" "Tercile3"

// total obs = number of combinations
loc obs = 16


**********************************************************************************
* Pull in all heterogeneity results                                                
**********************************************************************************

// create a "results" dataset: cols = specification, fe, clustering, inst, weather controls, outliers, beta, se
set obs `obs'

// main
estimates use "$sterdir/winsor_p98_d24_rate_TINumD1.ster"
gen modelgroup = (_n==1)
gen specification = "main"
gen fe = "cwFE" 
gen clustering = "clCountyWeek" 
gen instrument = "TINumD1" 
gen weather = "quadWeather" 
gen outliers = "winsor_p98" 
gen beta = _b[pm25] if modelgroup==1
gen se = _se[pm25] if modelgroup==1


// loop over male/female by agelist
loc i = 2
foreach sex in "`sexagelist'" {
	estimates use "$sterdir/winsor_p98_`sex'`outcome'_TINumD1.ster"
	replace specification = "`sex'" in `i'
	replace modelgroup = 2 in `i'
	replace beta = _b[pm25] in `i'
	replace se = _se[pm25] in `i'
	loc i = `i'+1
}
/*
// loop over male/female
loc i = 2
foreach sex in "`sexlist'" {
	estimates use "$sterdir/winsor_p98_`sex'`outcome'_TINumD1.ster"
	replace specification = "`sex'" in `i'
	replace modelgroup = 2 in `i'
	replace beta = _b[pm25] in `i'
	replace se = _se[pm25] in `i'
	loc i = `i'+1
}

// loop over age groups
qui count if beta!=.
loc i = r(N)+1
foreach age in "`agelist'" {
	estimates use "$sterdir/winsor_p98_t`age'`outcome'_TINumD1.ster"
	replace specification = "`age'" in `i'
	replace modelgroup = 3  in `i'
	replace beta = _b[pm25] in `i'
	replace se = _se[pm25] in `i'
	loc i = `i'+1
}*/

// loop over pollution levels
qui count if beta!=.
loc i = r(N)+1
foreach pollution in "`pollutionlist'" {
	estimates use "$sterdir/winsor_p98_`outcome'_`pollution'.ster"
	replace specification = "`pollution'" in `i'
	replace modelgroup = 3  in `i'
	replace beta = _b[pm25] in `i'
	replace se = _se[pm25] in `i'
	loc i = `i'+1
}


// loop over urban/rural
qui count if beta!=.
loc i = r(N)+1
foreach urban in "`urbanlist'" {
	estimates use "$sterdir/winsor_p98_`outcome'_`urban'.ster"
	replace specification = "`urban'" in `i'
	replace modelgroup = 4  in `i'
	replace beta = _b[pm25] in `i'
	replace se = _se[pm25] in `i'
	loc i = `i'+1
}


// loop over income level
qui count if beta!=.
loc i = r(N)+1
foreach income in "`incomelist'" {
	estimates use "$sterdir/winsor_p98_`outcome'_`income'.ster"
	replace specification = "`income'" in `i'
	replace modelgroup = 5  in `i'
	replace beta = _b[pm25] in `i'
	replace se = _se[pm25] in `i'
	loc i = `i'+1
}

// loop over average suicide levels
qui count if beta!=.
loc i = r(N)+1
foreach terc in "`avgsuilist'" {
	estimates use "$sterdir/winsor_p98_`outcome'_avgsui`terc'.ster"
	replace specification = "`terc'" in `i'
	replace modelgroup = 6  in `i'
	replace beta = _b[pm25] in `i'
	replace se = _se[pm25] in `i'
	loc i = `i'+1
}


gsort -modelgroup
gen row = _n

gen ci95_lo = beta-1.96*se
gen ci95_hi = beta+1.96*se
gen ci90_lo = beta-1.645*se
gen ci90_hi = beta+1.645*se


cap drop dummy
gen dummy = 0

** Position variable to create space between groups
gen pos=.
replace pos=row if modelgroup==6
replace pos=row+1 if modelgroup==5
replace pos=row+2 if modelgroup==4
replace pos=row+3 if modelgroup==3
replace pos=row+4 if modelgroup==2
replace pos=row+5 if modelgroup==1

* main spec vertical line
local x_line_main_spec = beta[_N] // beta main specification (last obs)
local zeroline = 0


loc mycolor = "105 106 107" //"167 203 226"
twoway /// 
	(pci 0 `x_line_main_spec' 17 `x_line_main_spec', lcolor("`mycolor'") lwidth(thin) lp(shortdash)) /// line at main spec
	(rspike ci95_lo ci95_hi pos if modelgroup == 1, horizontal color("`mycolor'%30") yaxis(1)) /// 95% CI
	(rspike ci95_lo ci95_hi pos if modelgroup == 2, horizontal color(vermillion%50) yaxis(1)) /// 
	(rspike ci95_lo ci95_hi pos if modelgroup == 3, horizontal color(orangebrown%50) yaxis(1)) /// 
	(rspike ci95_lo ci95_hi pos if modelgroup == 4, horizontal color(eltblue%50) yaxis(1)) /// 
	(rspike ci95_lo ci95_hi pos if modelgroup == 5, horizontal color(sea%50) yaxis(1)) /// 
	(rspike ci95_lo ci95_hi pos if modelgroup == 6, horizontal color(navy%50) yaxis(1)) /// 
	(rspike ci90_lo ci90_hi pos if modelgroup == 1, horizontal color("`mycolor'%80") yaxis(1)) /// 90% CI
	(rspike ci90_lo ci90_hi pos if modelgroup == 2, horizontal color(vermillion) yaxis(1)) ///
	(rspike ci90_lo ci90_hi pos if modelgroup == 3, horizontal color(orangebrown) yaxis(1)) ///
	(rspike ci90_lo ci90_hi pos if modelgroup == 4, horizontal color(eltblue) yaxis(1)) ///
	(rspike ci90_lo ci90_hi pos if modelgroup == 5, horizontal color(sea) yaxis(1)) ///
	(rspike ci90_lo ci90_hi pos if modelgroup == 6, horizontal color(navy) yaxis(1)) ///
	(pci 0 0 17 0, lcolor(black) lwidth(medthick)) /// line at 0
	(scatter pos beta if modelgroup == 1, mcolor("`mycolor'") yaxis(1) msymbol(circle) msize(medlarge)) /// 
	(scatter pos beta if modelgroup == 2, mcolor(vermillion) yaxis(1) msymbol(circle) mfcolor(white) msize(medlarge)) /// 
	(scatter pos beta if modelgroup == 3, mcolor(orangebrown) yaxis(1) msymbol(circle) mfcolor(white) msize(medlarge)) /// 
	(scatter pos beta if modelgroup == 4, mcolor(eltblue) yaxis(1) msymbol(circle) mfcolor(white) msize(medlarge)) /// 
	(scatter pos beta if modelgroup == 5, mcolor(sea) yaxis(1) msymbol(circle) mfcolor(white) msize(medlarge)) /// 
	(scatter pos beta if modelgroup == 6, mcolor(navy) yaxis(1) msymbol(circle) mfcolor(white) msize(medlarge)) /// 
	, ///
	yline(3 6 9 13 16, extend lstyle(foreground) lcolor(gs12)) /// 
	legend(off) ///
	xtitle("Effect of PM2.5 on suicides per 10,000", size(medsmall)) /// 
	xlabel(, nogrid) ///
	ytitle("") ///
	ylabel(17 "{bf:Main specification}" /// 	spec 1
		15 "Male" ///				spec2        
		14 "Female" ///
		12 "Age 0-15" /// 	spec 3
		11 "Age 15-65" ///
		10 "Age 65-85" /// 	
		8 "Polluted" /// spec 4
		7 "Less polluted" ///
		5 "Urban" /// spec 5
		4 "Rural" /// 	
		2 "Rich" /// spec 6
		1 "Poor" /// 	
		, ///
		angle(0) labsize(2.7) noticks nogrid) 
	
	
graph export "$resdir/figures/figure_2C.pdf", replace	
