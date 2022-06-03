**********************************************************************************

* This script computes how many suicides have been avoided due to stated
* policy goals and actual policy impacts on air pollution in a key set of 
* Chinese cities, using results from Ma et al. (2019). 
* Results from this script are shown in Figure 3C.

* This script calls regression results from code/analysis/2_regression.do. 
* All suicide and population data are proprietary and were accessed under 
* user agreements that do not allow for public distribution. 

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
	

set scheme plotplain

**********************************************************************************				                                                         *
* Ma et al calculation
**********************************************************************************


*---------------------------*
** new population data
*---------------------------*

import excel "$datadir/pop/pop.xlsx", sheet("Sheet1") firstrow clear

keep Year Beijing11 Jingjinji YRD PRD

xpose, clear

* Keep average population in the four regions
ren v6 avg_pop
keep avg_pop
drop in 1

gen region = "Beijing" in 1
replace region = "Jingjinji" in 2
replace region = "YRD" in 3
replace region = "PRD"  in 4

// convert population to total levels (currently in units of 10,000)
gen av_pop_tot = avg_pop*10000
drop avg_pop

tempfile popdata
save "`popdata'", replace

*---------------------------*
** Ma et al estimates
*---------------------------*

clear

* import info from table 4 from Ma et al (2019)
import delimited "$datadir/pm_maetal.csv", varnames(1)
ren ïregion region_order
ren region_name region

merge 1:1 region using  "`popdata'"
drop _merge

* percent decrease variables are in decimals
label var pm25_pdec_1 "percent decrease goal"
label var pm25_pdec_2 "percent decrease actual"
label var pm25_13 "pm 2.5 level 2013"
label var pm25_17 "pm 2.5 level 2017"

* for Beijing the goal was controlling pm 2.5 at a level of 60
replace pm25_pdec_1=(pm25_13 -60)/pm25_13 if region=="Beijing"
replace pm25_pdec_2= (pm25_13 - pm25_17)/ pm25_13 if region=="Beijing"

* calculate pm 2.5 decrease in levels
forvalues i=1/2 {
	gen pm25_dec_`i' = pm25_13* pm25_pdec_`i'
}	

label var pm25_dec_1 "pm 2.5 decrease goal"
label var pm25_dec_2 "pm 2.5 decrease actual"

* Made some adjustment to direct save as pmpop_maetal and merge with suicide data
ren region region_name
ren region_order region

save "$datadir/intermediate/pmpop_maetal.dta", replace

*---------------------------*
** Calculate the number of suicides avoided
** due to overall downward trends for all
** districts in the Ma et al regions
*---------------------------*

use "data_winsorize.dta", clear

** generate # of suicides
* I use t_dsppop instead of pop_tot because they are very similar and t_dsppop
* is always observed when d24_rate is observed, while pop_tot has many missing values
gen suicides= (d24_rate* t_dsppop)/1000000

* collapse to year-county
collapse (sum) suicides (firstnm) t_dsppop, by(dsp_code year)

xtset dsp_code year
* not a balanced panel

tsfill, full

** extract the first 2 digits of the county code to identify regions
tostring dsp_code, gen(county)
gen firstdigits=substr(county,1,2)
destring firstdigits, replace

****** Region dummies

* Beijing
gen beijing=(firstdigits==11)

* Yangtze River Delta
gen yrd=(firstdigits==31 | firstdigits==32 | firstdigits==33 | firstdigits==34)

* Pearl River Delta
gen prd=(firstdigits==44)

*  Jingjinji (note that it includes Beijing)
gen jingjinji= (firstdigits==11 | firstdigits==12 | firstdigits==13) 

**** TAMMA START EDITING HERE 

* Compute total suicides by year by region over the 2013-2017 period
gen insample_ma = (beijing==1 | yrd==1 | prd ==1 | jingjinji==1)
keep if insample_ma
bysort dsp_code year: egen totsui = sum(suicides)

* Region
gen region=.
replace region=1 if yrd==1
replace region=2 if prd==1
replace region=3 if jingjinji==1

drop if region==.

* check missing values
gen missing=(suicides==.)
tab year if missing==1
* missings only in 2015, 2016 and 2017

* so calculate the average population observed by county over 2013-2017
bysort dsp_code: egen av_dsppop=mean(t_dsppop)

* for suicides we could use the 2013 level because it's not affected by missings

tempfile countypop
save "`countypop'", replace

* collapse to year-region
collapse (sum) suicides av_dsppop, by(region year)

tempfile sregions
save "`sregions'", replace


** Beijing
use "`countypop'", clear

collapse (sum) suicides av_dsppop, by(beijing year)
drop if beijing==0

gen region=4

drop beijing

append using "`sregions'", generate(filenum)

sort region 

label define regionlab 1 "YRD" 2 "PRD" 3 "Jingjinji" 4 "Beijing"
label values region regionlab


drop filenum

sort region year

save "$datadir/intermediate/suiciderates_region.dta", replace

reshape wide suicides av_dsppop, i(region) j(year)

merge 1:1 region using "$datadir/intermediate/pmpop_maetal.dta"

rename av_dsppop2013 average_dsppop

drop _merge av_dsppop* 

format average_dsppop %12.2f

gen diff_suicides= suicides2013 - suicides2017 

label var average_dsppop "av. population with t_dsppop"
label var av_pop_tot "av. population with pop_tot & census"
* note that the population averages by region are very different
* depending on the data you use


save "$datadir/intermediate/pmpopsui_maetal.dta" , replace


********************
** Graph
********************

use  "$datadir/intermediate/pmpopsui_maetal.dta", clear

* main model, no lags, no heterogeneity
estimates use "$sterdir/winsor_p98_d24_rate_TINumD1.ster"
estimates


** calculate lives saved
* 1= goal, 2=actual

forvalues i=1/2 {
gen lives_`i' =  _b[pm25]*pm25_dec_`i' *(av_pop_tot/1000000)

format lives_`i' %12.0f

* lives saved as a proportion of suicide difference 2013-2017 
*(suicides in 2017 are underestimated due to missings in some counties)
gen prop_suic_diff_`i' = (lives_`i' / diff_suicides)*100

* lives saved as a proportion of suicides in 2013
gen prop_suic_13_`i' = (lives_`i' / suicides2013)*100

format prop_suic_diff_`i' prop_suic_13_`i'  %12.0f

}

* I'm not sure whether to drop PRD with new population data so I keeped it for now.
* drop if region==2
* drop region_name

reshape long pm25_dec_ pm25_pdec_ lives_ prop_suic_diff_ prop_suic_13_, i(region) j(data)

label var data "1=goal 2=actual"
label define datalab 1 "goal" 2 "actual" 
label values data datalab

** Position variable to create space between groups
gen n=_n

gen pos=.
replace pos=n if region==1
replace pos=n+1 if region==2
replace pos=n+2 if region==3
replace pos=n+3 if region==4

loc mycolorgreen = "11 78 68"
loc mycolortan = "201 152 76"


twoway (bar prop_suic_diff_ pos if data==1, lcolor("`mycolortan'") fcolor("`mycolortan'"%50) lwidth(medthick)) ///
       (bar prop_suic_diff_ pos if data==2, lcolor("`mycolorgreen'") fcolor("`mycolorgreen'"%50) lwidth(medthick)) ///
	   (scatter prop_suic_diff_ pos if data==1, m(i)  mlabposition(12)) ///
	   (scatter prop_suic_diff_ pos if data==2, m(i)  mlabposition(12)) , ///
       legend(order(1 "policy goal" 2 "actual")) ///
       xlabel(1.5 "Yellow River Delta" 4.5 "Pearl River Delta{superscript:*}" 7.5 "Jingjinji" 10.5 "Beijing", noticks nogrid) ///
	   xsca(noline) ///
       xtitle("", size(small)) ytitle("Percentage of suicide rate decline due to" "pollution control policies: 2013-2017", size(small)) ///
	   note("{superscript:*} Pearl River Delta experienced a ~20% increase in suicide rates from 2013 to 2017", size(vsmall))

graph export "$resdir/figures/Fig3C_maetal.pdf", replace	 
