 
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
loc sexagelist "m0_15" "f0_15" "m15_65" "f15_65" "m65_85" "f65_85"
loc seasonlist "spring" "summer" "fall" "winter"
loc urbanlist "urban" "rural"
loc incomelist "rich" "poor"
loc avgPM25list "avgPM25Tercile1" "avgPM25Tercile2" "avgPM25Tercile3"
loc avgsuilist "avgsuiTercile1" "avgsuiTercile2" "avgsuiTercile3"

// total obs = number of combinations
loc obs = 21


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
gen inobs = e(N) if modelgroup==1


// loop over male/female by agelist
loc i = 2
foreach sex in "`sexagelist'" {
	estimates use "$sterdir/winsor_p98_`sex'`outcome'_TINumD1.ster"
	replace specification = "`sex'" in `i'
	replace modelgroup = 2 in `i'
	replace beta = _b[pm25] in `i'
	replace se = _se[pm25] in `i'
	replace inobs = e(N) in `i'
	loc i = `i'+1
}

// loop over seasons
qui count if beta!=.
loc i = r(N)+1
foreach seas in "`seasonlist'" {
	estimates use "$sterdir/winsor_p98_`outcome'_`seas'.ster"
	replace specification = "`seas'" in `i'
	replace modelgroup = 3  in `i'
	replace beta = _b[pm25] in `i'
	replace se = _se[pm25] in `i'
	replace inobs = e(N) in `i'
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
	replace inobs = e(N) in `i'
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
	replace inobs = e(N) in `i'
	loc i = `i'+1
}


// loop over pollution levels
qui count if beta!=.
loc i = r(N)+1
foreach terc in "`avgPM25list'" {
	estimates use "$sterdir/winsor_p98_`outcome'_`terc'.ster"
	replace specification = "`terc'" in `i'
	replace modelgroup = 6  in `i'
	replace beta = _b[pm25] in `i'
	replace se = _se[pm25] in `i'
	replace inobs = e(N) in `i'
	loc i = `i'+1
}


// loop over average suicide levels
qui count if beta!=.
loc i = r(N)+1
foreach terc in "`avgsuilist'" {
	estimates use "$sterdir/winsor_p98_`outcome'_`terc'.ster"
	replace specification = "`terc'" in `i'
	replace modelgroup = 7  in `i'
	replace beta = _b[pm25] in `i'
	replace se = _se[pm25] in `i'
	replace inobs = e(N) in `i'
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
replace pos=row if modelgroup==7
replace pos=row+1 if modelgroup==6
replace pos=row+2 if modelgroup==5
replace pos=row+3 if modelgroup==4
replace pos=row+4 if modelgroup==3
replace pos=row+5 if modelgroup==2
replace pos=row+6 if modelgroup==1
order modelgroup row pos

summ pos
loc maxpos = r(max)

* main spec vertical line
local x_line_main_spec = beta[_N] // beta main specification (last obs)
local zeroline = 0

* clip large SIs (state clipping in caption)
foreach V of varlist ci90_hi ci90_lo ci95_hi ci95_lo {
	replace `V' = -.01 if `V' < -.01
	replace `V' = .05 if `V' >.05
}

* draft
loc mycolor = "105 106 107" //"167 203 226"
twoway /// 
	(pci 0 `x_line_main_spec' `maxpos' `x_line_main_spec', lcolor("`mycolor'") lwidth(thin) lp(shortdash)) /// line at main spec
	(rspike ci95_lo ci95_hi pos if modelgroup == 1, horizontal color("`mycolor'%30") yaxis(1)) /// 95% CI
	(rspike ci95_lo ci95_hi pos if modelgroup == 2, horizontal color(vermillion%50) yaxis(1)) /// 
	(rspike ci95_lo ci95_hi pos if modelgroup == 3, horizontal color(orangebrown%50) yaxis(1)) /// 
	(rspike ci95_lo ci95_hi pos if modelgroup == 4, horizontal color(eltgreen%50) yaxis(1)) /// 
	(rspike ci95_lo ci95_hi pos if modelgroup == 5, horizontal color(eltblue%50) yaxis(1)) /// 
	(rspike ci95_lo ci95_hi pos if modelgroup == 6, horizontal color(sea%50) yaxis(1)) /// 
	(rspike ci95_lo ci95_hi pos if modelgroup == 7, horizontal color(navy%50) yaxis(1)) /// 
	(rspike ci90_lo ci90_hi pos if modelgroup == 1, horizontal color("`mycolor'%80") yaxis(1)) /// 90% CI
	(rspike ci90_lo ci90_hi pos if modelgroup == 2, horizontal color(vermillion) yaxis(1)) ///
	(rspike ci90_lo ci90_hi pos if modelgroup == 3, horizontal color(orangebrown) yaxis(1)) ///
	(rspike ci90_lo ci90_hi pos if modelgroup == 4, horizontal color(eltgreen) yaxis(1)) ///
	(rspike ci90_lo ci90_hi pos if modelgroup == 5, horizontal color(eltblue) yaxis(1)) ///
	(rspike ci90_lo ci90_hi pos if modelgroup == 6, horizontal color(sea) yaxis(1)) ///
	(rspike ci90_lo ci90_hi pos if modelgroup == 7, horizontal color(navy) yaxis(1)) ///
	(pci 0 0 `maxpos' 0, lcolor(black) lwidth(medthick)) /// line at 0
	(scatter pos beta if modelgroup == 1, mcolor("`mycolor'") yaxis(1) msymbol(circle) msize(medlarge)) /// 
	(scatter pos beta if modelgroup == 2, mcolor(vermillion) yaxis(1) msymbol(circle) mfcolor(white) msize(medlarge)) /// 
	(scatter pos beta if modelgroup == 3, mcolor(orangebrown) yaxis(1) msymbol(circle) mfcolor(white) msize(medlarge)) /// 
	(scatter pos beta if modelgroup == 4, mcolor(eltgreen) yaxis(1) msymbol(circle) mfcolor(white) msize(medlarge)) /// 
	(scatter pos beta if modelgroup == 5, mcolor(eltblue) yaxis(1) msymbol(circle) mfcolor(white) msize(medlarge)) /// 
	(scatter pos beta if modelgroup == 6, mcolor(sea) yaxis(1) msymbol(circle) mfcolor(white) msize(medlarge)) ///
	(scatter pos beta if modelgroup == 7, mcolor(navy) yaxis(1) msymbol(circle) mfcolor(white) msize(medlarge)) ///
	, ///
	xscale(r(-.01 .05)) xlabel(-0.01(.01).05) ///
	yline(4 8 11 14 19 26, extend lstyle(foreground) lcolor(gs12)) /// 
	legend(off) ///
	xtitle("Effect of PM2.5 on weekly suicides per 1 million", size(medsmall)) /// 
	xlabel(, nogrid) ///
	ytitle("") ///
	ylabel(27 "{bf:Main specification}" /// 	spec 1
		25 "Male: ages 0-15" ///		spec 2		 
		24 "Female: ages 0-15" ///	
		23 "Male: ages 15-65" ///				
		22 "Female: ages 15-65" ///	
		21 "Male: ages 65-85" ///				 
		20 "Female: ages 65-85" ///	
		18 "Spring" ///
		17 "Summer" ///
		16 "Fall" ///
		15 "Winter" ///
		13 "Urban" /// spec 4
		12 "Rural" /// 	
		10 "Rich" /// spec 5
		9 "Poor" ///
		7 "Low avg. PM2.5" /// 
		6 "Mod. avg. PM2.5" /// spec 7
		5 "High avg. PM2.5" /// 
		3 "Low avg. suicide rate" /// 
		2 "Mod. avg. suicide rate" /// spec 6
		1 "High avg. suicide rate" /// 
		, ///
		angle(0) labsize(2.7) noticks nogrid) ///
		text(27 0.045 "n=139,196"  ///
			25 0.045 "n=141,793" ///
			24 0.045 "n=141,793" ///
			23 0.045 "n=139,169" ///
			22 0.045 "n=139,115" ///
			21 0.045 "n=139,036" ///
			20 0.045 "n=138,987" ///
			18 0.045 "n=34,794" ///
			17 0.045 "n=34,973" ///
			16 0.045 "n=35,469" ///
			15 0.045 "n=33,960" ///
			13 0.045 "n=49,924" ///
			12 0.045 "n=89,272" ///
			10 0.045 "n=59,117" ///
			9 0.045 "n=80,079" ///
			7 0.045 "n=44,053" ///
			6 0.045 "n=48,391" ///
			5 0.045 "n=46,796" ///
			3 0.045 "n=45,477" ///
			2 0.045 "n=47,947" ///
			1 0.045 "n=45,772" ///
			, place(e) size(small)) 
	
graph export "$resdir/figures/figure_2C.pdf", replace	
