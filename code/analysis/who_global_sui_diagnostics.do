
**********************************************************************************

* This script uses World Health Organization country-by-year suicide rate
* data to summarize global trends in suicide rates and to compare China's
* experience with other nations

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
	
use "$datadir/who_suicide/suiciderate_adm0_2000_2019.dta", clear

set scheme plotplain

**********************************************************************************				                                                         *
* Global unweighted avg suicide rate over time
**********************************************************************************

preserve

// OECD list
clear
insheet using "$datadir/who_suicide/oecd.csv"
replace iso="IRL" if iso=="IRE" // inconsistent with WHOd
tempfile oecd
save "`oecd'", replace

// WB low and middle income
clear
import excel using "$datadir/who_suicide/CLASS.xls", sheet("Groups") firstrow
keep if GroupCode=="LMY" 
ren CountryCode iso
gen lowmidinc=1
tempfile class
save "`class'", replace

restore
merge m:1 iso using "`oecd'"
replace oecd=0 if _merge==1
drop _merge

merge m:1 iso using "`class'"
tab _merge
drop if _merge==2 // small countries not in WHO
replace lowmidinc = 0 if _merge==1
drop _merge

// avg by group
egen globalmn_suirate = mean(suiciderate_tot), by(year)
egen oecdmn_suirate = mean(suiciderate_tot) if oecd==1, by(year)
egen lomidinc_suirate = mean(suiciderate_tot) if lowmidinc==1, by(year)
gen china_suirate = suiciderate_tot if iso=="CHN"

collapse (firstnm) *_suirate, by(year)

* for rest of paper consistency, convert rates to weekly per 1 million
foreach V of varlist *_suirate {
	replace `V' = `V'*10
}

/* colors matching map in fig 1
160 0 33 (red)
27 81 156 (blue)
238 135 98 (coral)
*/

tw line oecdmn_suirate year , lcolor("27 81 156")  lpattern(solid) || ///
	line  globalmn_suirate year, lcolor(black) lpattern(solid)  || ///
	line lomidinc_suirate year , lcolor("238 135 98") lpattern(solid)  || ///
	line china_suirate year , lcolor("160 0 33") lpattern(solid)  || ///
	sc oecdmn_suirate year , mlcolor("27 81 156") mfcolor(white) msymbol(+) || ///
	sc  globalmn_suirate year, mlcolor(black) mfcolor(white) msymbol(S)  || ///
	sc lomidinc_suirate year , mlcolor("238 135 98") mfcolor(white) msymbol(T) || ///
	sc china_suirate year , mlcolor("160 0 33") mfcolor(white) msymbol(D)  ///
	legend(order(5 "OECD" 6 "Global" 7 "Low & Middle Income" 8 "China")) ///
	ytitle("Annual suicide rate per 1 million") ///
		xtitle("") ///
		ylabel(, nogrid) xlabel(, nogrid) 

	graph export "$resdir/figures/figure_1_WHO.pdf", replace	

// pct change low and mid inc vs oecd
loc oecdpctchange = (oecdmn_suirate[_N]-oecdmn_suirate[1])/oecdmn_suirate[1]
loc lowmidincpctchange = (lomidinc_suirate[_N]-lomidinc_suirate[1])/lomidinc_suirate[1]
di `oecdpctchange'
di `lowmidincpctchange'
di "pct difference in trend lowinc to oecd: " (`lowmidincpctchange'-`oecdpctchange')/`oecdpctchange'
di `lowmidincpctchange'/`oecdpctchange'
	
// how many countries have declining sui rate?
		
use "$datadir/who_suicide/suiciderate_adm0_2000_2019.dta", clear
keep if year==2000 | year==2019
sort iso year
bysort iso: gen decrease = (suiciderate_tot[2]<suiciderate_tot[1])
keep if year == 2019
tab decrease



