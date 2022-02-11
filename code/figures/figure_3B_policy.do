**********************************************************************************

* This script computes how many suicides have been avoided due to stated
* policy goals and actual policy impacts on air pollution in a key set of 
* Chinese cities, using results from Ma et al. (2019). 
* Results from this script are shown in Figure 3B.

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


** Calculate total population in each region in Table 4 of Ma et al
use  "$datadir/pop2000_2019.dta", clear 

// convert population to total levels (currently in units of 10,000)
gen pop_tot = pop*10000

sort county_id year

* pollution data until 2018, so I'll drop them
drop if year>2017   // since Ma et al show 2013-2017 changes in pm 

xtset county_id year

keep if year>=2013

gen dsp_code=county_id

** extract the first 2 digits of the county code to identify regions
tostring county_id, replace
gen firstdigits=substr(county_id,1,2)
destring firstdigits, replace


** merge with census data
preserve
use "$datadir/pop2015.dta", clear
tostring code, gen(county_id)
tempfile pop2015
save "`pop2015'", replace

restore
merge m:1 county_id using "`pop2015'"

rename total pop2015
drop _merge

****** Region dummies

* Beijing
gen beijing=(firstdigits==11)

* Yangtze River Delta
gen yrd=(firstdigits==31 | firstdigits==32 | firstdigits==33 | firstdigits==34)

* Pearl River Delta
gen prd=(firstdigits==44)

*  Jingjinji (note that it includes Beijing)
gen jingjinji= (firstdigits==11 | firstdigits==12 | firstdigits==13) 

* Region
gen region=.
replace region=1 if yrd==1
replace region=2 if prd==1
replace region=3 if jingjinji==1

** since there are missings in the population data I'll use the average over the study period
bysort dsp_code: egen av_pop_tot=mean(pop_tot)

drop if year==.

tempfile countypop
save "`countypop'", replace

collapse (firstnm) av_pop_tot pop2015, by(dsp_code region)
drop if region==.

** there are some counties in YRD that have missing population data in all years
* use census data instead

replace av_pop_tot= pop2015 if av_pop_tot==.

* now add the average population over 2013-2017 in each county by region
collapse (sum) av_pop_tot, by(region)


tempfile regions
save "`regions'", replace

use "`countypop'", clear


collapse (firstnm) av_pop_tot, by(dsp_code beijing)
drop if beijing==0

collapse (sum) av_pop_tot, by(beijing)

gen region=4

drop beijing

append using "`regions'", generate(filenum)

sort region 

label define regionlab 1 "YRD" 2 "PRD" 3 "Jingjinji" 4 "Beijing"
label values region regionlab

format av_pop_tot %12.2f

drop filenum

save "$datadir/intermediate/pop_region.dta", replace

clear

* import info from table 4 from Ma et al (2019)
* I saved this csv inside  the data folder in Box 
import delimited "$datadir/pm_maetal.csv"

merge 1:1 region using  "$datadir/intermediate/pop_region.dta"

drop _merge

* percent decrease variables are in decimals
label var pm25_pdec_1 "percent decrease goal"
label var pm25_pdec_2 "percent decrease actual"
label var pm25_13 "pm 2.5 level 2013"
label var pm25_17 "pm 2.5 level 2017"

* for Beijing the goal was controlling pm 2.5 at a level of 60
replace pm25_pdec_1=(pm25_13 -60)/pm25_13 if region==4
replace pm25_pdec_2= (pm25_13 - pm25_17)/ pm25_13 if region==4

* calculate pm 2.5 decrease in levels
forvalues i=1/2 {
	gen pm25_dec_`i' = pm25_13* pm25_pdec_`i'
}	

label var pm25_dec_1 "pm 2.5 decrease goal"
label var pm25_dec_2 "pm 2.5 decrease actual"
 
save  "$datadir/intermediate/pmpop_maetal.dta", replace

***************************
** Calculate # of suicides
***************************

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

format prop_suic_diff_`i' prop_suic_13_`i'  %12.2f

}

* drop PRD because it has a much smaller population than other regions and ~zero lives saved
drop if region==2
drop region_name

reshape long pm25_dec_ pm25_pdec_ lives_ prop_suic_diff_ prop_suic_13_, i(region) j(data)

label var data "1=goal 2=actual"
label define datalab 1 "goal" 2 "actual" 
label values data datalab

** Position variable to create space between groups
gen n=_n

gen pos=.
replace pos=n if region==1
replace pos=n+1 if region==3
replace pos=n+2 if region==4


twoway (bar lives pos if data==1) ///
       (bar lives pos if data==2) ///
	   (scatter lives pos if data==1, m(i) mlabel(prop_suic_diff_) mlabposition(12)) ///
	   (scatter lives pos if data==2, m(i) mlabel(prop_suic_diff_) mlabposition(12)) , ///
       legend(order(1 "policy goal" 2 "actual")) ///
       xlabel( 1.5 "YRD" 4.5 "Jingjinji" 7.5 "Beijing", noticks nogrid) ///
	   xsca(noline) ///
       xtitle("Region", size(small)) ytitle("Total avoided suicides due to pollution control policies: 2013-2017", size(small)) ///
	   note("Note: The number on top of each column represents lives saved as a percentage of the observed 2013-2017 suicide decline", size(vsmall) )
	   
** need to check suicide decline number, especially in Beijing and Jingjinji where some counties had missing suicide information
* alternatively, we could use % of suicides in 2013 (prop_suic_13_)
	 
graph export "$resdir/figures/Fig3B_maetal.pdf", replace	 

