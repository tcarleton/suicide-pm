

**********************************************************************************

* This script runs the main regression in Zhang et al., as well as a set of
* robustness tests, with results shown in Figure 2A.

* Data called by this script are assembled in code/clean/1_merge.do. All suicide 
* and population data are proprietary and were accessed under user agreements 
* that do not allow for public distribution. Therefore, this code is for 
* transparency purposes only, and cannot directly be run with publicly available 
* data.

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
	
use data, clear

* choose amount of winsorization: 98% is used in the main results
loc pp = 98 

foreach V of varlist d24_rate fd24_rate md24_rate {
egen `V'_phigh=pctile(`V'), p(`pp')
replace `V'=. if `V'>`V'_phigh
}
*

foreach V of varlist tem_ave pre-prs {
gen `V'2=`V'^2
}
*

global control2 ///
tem_ave pre-prs tem_ave2 pre2-prs2

label var pm25 "PM2.5" 

save data_winsorize, replace


**********************************************************************************
*						                                                         *
* Compare suicide data with other studies                                         *
**********************************************************************************

******************************************************* compare with Tamma
* average annual state suicide rate in India is 114  per 1 million people 
use data_winsorize, clear
collapse (sum) d24_rate fd24_rate md24_rate (firstnm) t_dsppop f_dsppop m_dsppop, by(dsp_code year)
sum d24_rate fd24_rate md24_rate
sum d24_rate [aw=t_dsppop]
sum fd24_rate [aw=f_dsppop]
sum md24_rate [aw=m_dsppop]

* annual county suicide rate is 55.52 per 1 million people, lower than India
* weighted average by population for each county is 57.15 

******************************************************* compare with Zou
* average month county suicide rate in US is 9.76 per 1 million people 
use data_winsorize, clear
collapse (sum) d24_rate (firstnm) t_dsppop, by(dsp_code year month)
sum d24_rate 
sum d24_rate [aw=t_dsppop]
* month county suicide rate is 4.63 per 1 million people, lower than US
* weighted average by population for each county is 4.76

**********************************************************************************
*						                                                         *
* summary statistics                                                    *
**********************************************************************************
use data_winsorize, clear

*** summary statistics
sum d24_rate f*d24_rate m*d24_rate

* weighted by population
sum d24_rate [aw=t_dsppop]
sum fd24_rate [aw=f_dsppop]
sum md24_rate [aw=m_dsppop]

************across provinces
tabstat d24_rate, by(provname)

*************across month
tabstat d24_rate, by(month)
* higher in warm season

************across years
tabstat d24_rate fd24_rate md24_rate, by(year)
tabstat pm25 TINumD1 tem_ave, by(year)

* decreasing overall

*************urban rural
tabstat d24_rate, by(year)
tabstat fd24_rate, by(year)
tabstat md24_rate, by(year)
tabstat d24_rate if urb_rur==1, by(year)
tabstat d24_rate if urb_rur==2, by(year)
tabstat fd24_rate if urb_rur==1, by(year)
tabstat md24_rate if urb_rur==1, by(year)
tabstat fd24_rate if urb_rur==2, by(year)
tabstat md24_rate if urb_rur==2, by(year)

***********pollution
sum aqi-co

************inversion
sum TI*

*** weather
sum tem_ave_pbin10-tem_ave_pbin100
sum tem_ave-prs 

*********************************************************************************				                                                    
* Export summary stats to latex table
**********************************************************************************

use data_winsorize, clear

qui ivreghdfe d24_rate $control2 (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code week) 
keep if e(sample)

est clear  // clear the est locals

estpost tabstat d24_rate fd24_rate md24_rate pm25 TINumD1 tem_ave pre ssd win rhu prs, c(stat) stat(mean sd min max)


label var d24_rate "Total weekly suicide rate (per 1 mil.)"
label var fd24_rate "Female weekly suicide rate (per 1 mil.)"
label var md24_rate "Male weekly suicide rate (per 1 mil.)"
label var TINumD1 "Weekly number of inversions"

label var tem_ave "Daily average temperature (C)"
label var pre "Daily precipitation (mm)" 
label var ssd  "Daily average sunshine duration (h)"
label var win  "Daily average wind speed (m/s)"
label var rhu "Daily average relative humidity (\%)"
label var prs "Daily average barometric pressure (hpa)"


esttab, ///
 cells("mean(fmt(%13.2fc)) sd(fmt(%13.2fc)) min max") nonumber ///
  nomtitle nonote noobs label collabels("Mean" "SD" "Min" "Max")
  
esttab using "$resdir/tables/summstats.tex", replace ////
 cells("mean(fmt(%13.2fc)) sd(fmt(%13.2fc)) min max") nonumber ///
  nomtitle nonote noobs label booktabs f ///
  collabels("Mean" "SD" "Min" "Max")

**********************************************************************************
*						                                                         *
* first stage                               *
**********************************************************************************

use data_winsorize, clear

loc outfile = "$resdir/tables/table_first_wp`pp'.tex"

cap erase "$resdir/tables/table_first_wp`pp'.tex"
cap erase "$resdir/tables/table_first_wp`pp'.txt"

keep if d24_rate !=. & pm25 !=. & TINumD1 !=. & tem_ave !=. & pre !=. & ssd !=. & win !=. & rhu !=. & prs !=. 

label var TINumD1 "No. of inversions"
label var TIStrD1 "Inversion strength ($^\circ$C)" 
label var TIIndD1 "No. days with inversion"

foreach V of varlist TINumD1 TIStrD1 TIIndD1 {

loc outfilester "$resdir/ster/firststage_winsor_p`pp'_`V'.ster"

reghdfe pm25 `V' $control2, absorb(dsp_code week) cluster(dsp_code week)
estimates save "`outfilester'", replace
outreg2 using "`outfile'", label tex(frag) ///
append dec(3) nonotes keep(`V') nocons ///
addtext(County FE, X, Week-of-sample FE, X)
}
*


**********************************************************************************
*						                                                         *
* IV: Main                             *
**********************************************************************************

use data_winsorize, clear

loc outfile = "$resdir/tables/table_iv_wp`pp'.tex"

cap erase "$resdir/tables/table_iv_wp`pp'.tex"
cap erase "$resdir/tables/table_iv_wp`pp'.txt"

label var pm25 "PM2.5"

foreach A of varlist TINumD1 TIStrD1 TIIndD1  { // can add other thermal layers: TINumD2 TIStrD2 TIIndD2
	foreach V of varlist fd24_rate md24_rate {
	
		loc outfilester "$resdir/ster/winsor_p`pp'_`V'_`A'.ster"

		qui ivreghdfe `V' $control2 (pm25=`A'), absorb(dsp_code week) cluster(dsp_code week) 
  
		* save estimates from main model for use in figures
		estimates save "`outfilester'", replace
		}
	
	* table for paper just calls total suicide rate
	loc outfilester "$resdir/ster/winsor_p`pp'_d24_rate_`A'.ster"
	qui ivreghdfe d24_rate $control2 (pm25=`A'), absorb(dsp_code week) cluster(dsp_code week) first
	estimates save "`outfilester'", replace
  

	  outreg2 using "`outfile'", label tex(frag) ///
	  append dec(4) ///
	  keep(pm25) nocons nonotes ///
	  addstat(First stage F-stat,e(widstat), p-value, e(idp), AR Chi2 p-value, e(archi2p), SW S-stat,e(sstatp)) ///
	  addtext(IV, `A', County FE, X, Week-of-sample FE, X)
  }


**********************************************************************************
*						                                                         *
* OLS vs IV                              *
**********************************************************************************

use data_winsorize, clear

loc outfile = "$resdir/tables/table_main_wp`pp'.tex"

cap erase "$resdir/tables/table_main_wp`pp'.tex"
cap erase "$resdir/tables/table_main_wp`pp'.txt"

label var pm25 "PM2.5" 

foreach V of varlist d24_rate fd24_rate md24_rate {

  qui ivreghdfe `V' $control2 (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code week) first
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V': IV) dec(4) ///
  keep(pm25) nocons nonotes ///
  addstat(First stage F-stat,e(widstat), p-value, e(idp), AR Chi2 p-value, e(archi2p), SW S-stat,e(sstatp)) ///
  addtext(County FE, X, Week-of-sample FE, X)
  
  loc outfilester "$resdir/ster/winsor_p`pp'_`V'_OLS.ster"
   
  qui reghdfe `V' $control pm25, absorb(dsp_code week) cluster(dsp_code week)
  * save estimates for use in figures
  estimates save "`outfilester'", replace
  
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V': FE) dec(4) ///
  keep(pm25) nocons nonotes ///
  addtext (County FE, X, Week-of-sample FE, X)
}

*

**********************************************************************************
*						                                                         *
* Robustness: clustering                              *
**********************************************************************************

use data_winsorize, clear

loc outfile = "$resdir/tables/table_cluster_wp`pp'.tex"

cap erase "$resdir/tables/table_cluster_wp`pp'.tex"
cap erase "$resdir/tables/table_cluster_wp`pp'.txt"


*** no clustering

foreach V of varlist d24_rate  {
	loc outfilester "$resdir/ster/winsor_p`pp'_`V'_clNone.ster"
  
  qui ivreghdfe `V' $control2 (pm25=TINumD1), absorb(dsp_code week) first
  estimates save "`outfilester'", replace
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) nocons nonotes ///
  addstat(First stage F-stat,e(widstat), p-value, e(idp), AR Chi2 p-value, e(archi2p), SW S-stat,e(sstatp)) ///
  addtext(County FE, X, Week-of-sample FE, X, Clustering, None)
  
}
*

*** cluster by week 

foreach V of varlist d24_rate  {
	loc outfilester "$resdir/ster/winsor_p`pp'_`V'_clWeek.ster"
  qui ivreghdfe `V' $control2 (pm25=TINumD1), absorb(dsp_code week) cluster(week) first
  estimates save "`outfilester'", replace
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) nocons nonotes ///
  addstat(First stage F-stat,e(widstat), p-value, e(idp), AR Chi2 p-value, e(archi2p), SW S-stat,e(sstatp)) ///
  addtext(County FE, X, Week-of-sample FE, X, Clustering, Week)
  
}
*

*** cluster by county

foreach V of varlist d24_rate  {
	loc outfilester "$resdir/ster/winsor_p`pp'_`V'_clCounty.ster"
  qui ivreghdfe `V' $control2 (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code) first
  estimates save "`outfilester'", replace
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) nocons nonotes ///
  addstat(First stage F-stat,e(widstat), p-value, e(idp), AR Chi2 p-value, e(archi2p), SW S-stat,e(sstatp)) ///
  addtext(County FE, X, Week-of-sample FE, X, Clustering, County)
  
}
*

*** cluster by county and week (PREFERRED)

foreach V of varlist d24_rate {
  qui ivreghdfe `V' $control2 (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code week) first
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) nocons nonotes ///
  addstat(First stage F-stat,e(widstat), p-value, e(idp), AR Chi2 p-value, e(archi2p), SW S-stat,e(sstatp)) ///
  addtext(County FE, X, Week-of-sample FE, X, Clustering, County and week)
  
}
*



**********************************************************************************
*						                                                         *
* Robustness: Weather controls                                 *
**********************************************************************************

use data_winsorize, clear
loc pp = 98
loc outfile = "$resdir/tables/table_weather_wp`pp'.tex"

cap erase "$resdir/tables/table_weather_wp`pp'.tex"
cap erase "$resdir/tables/table_weather_wp`pp'.txt"


global control ///
tem_ave ///
pre-prs 

global control_bins ///
tem_ave_pbin* pre_pbin10-prs_pbin100

*** no weather controls

foreach V of varlist d24_rate  {
	loc outfilester "$resdir/ster/winsor_p`pp'_`V'_noWeather.ster"
  qui ivreghdfe `V' (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code week) first
  estimates save "`outfilester'", replace
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) nocons nonotes ///
  addstat(First stage F-stat,e(widstat), p-value, e(idp), AR Chi2 p-value, e(archi2p), SW S-stat,e(sstatp)) ///
  addtext(County FE, X, Week-of-sample FE, X, Weather, None)
  
}
*

*** weather linear

foreach V of varlist d24_rate  {
	loc outfilester "$resdir/ster/winsor_p`pp'_`V'_linWeather.ster"
  qui ivreghdfe `V' $control (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code week) first
  estimates save "`outfilester'", replace
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) nocons nonotes ///
  addstat(First stage F-stat,e(widstat), p-value, e(idp), AR Chi2 p-value, e(archi2p), SW S-stat,e(sstatp)) ///
  addtext(County FE, X, Week-of-sample FE, X, Weather, Linear)
  
}
*

*** weather quadratic (PREFERRED)

foreach V of varlist d24_rate  {
  qui ivreghdfe `V' $control2 (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code week) first
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) nocons nonotes ///
  addstat(First stage F-stat,e(widstat), p-value, e(idp), AR Chi2 p-value, e(archi2p), SW S-stat,e(sstatp)) ///
  addtext(County FE, X, Week-of-sample FE, X, Weather, Quadratic)
  
}
*

*** weather bins 

foreach V of varlist d24_rate  {
	loc outfilester "$resdir/ster/winsor_p`pp'_`V'_binWeather.ster"
  qui ivreghdfe `V' $control_bins (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code week) first 
  estimates save "`outfilester'", replace
  if e(sstatp) == . {
   loc sstatp = 0
  } 
else {
	loc sstatp = e(sstatp)
  }
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) nocons nonotes ///
  addstat(First stage F-stat,e(widstat), p-value, e(idp), AR Chi2 p-value, e(archi2p), SW S-stat, `sstatp') ///
  addtext(County FE, X, Week-of-sample FE, X, Weather, Binned)
}
*


**********************************************************************************
*						                                                         *
* Robustness: Fixed effects                                 *
**********************************************************************************
loc pp = 98
use data_winsorize, clear


loc outfile = "$resdir/tables/table_fe_wp`pp'.tex"

cap erase "$resdir/tables/table_fe_wp`pp'.tex"
cap erase "$resdir/tables/table_fe_wp`pp'.txt"

*** county and week fe (PREFERRED)

foreach V of varlist d24_rate  {

  qui ivreghdfe `V' $control2 (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code week) first
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) nocons nonotes ///
  addstat(First stage F-stat,e(widstat), p-value, e(idp), AR Chi2 p-value, e(archi2p), SW S-stat,e(sstatp)) ///
  addtext(County FE, X, County-year FE, -- , County-month FE, --, Week-of-sample FE, X, Prov. time trend, --, County time trend, -)
  
}
*

*** county-year and week fe

foreach V of varlist d24_rate  {
	loc outfilester "$resdir/ster/winsor_p`pp'_`V'_cYwFE.ster"
  qui ivreghdfe `V' $control2 (pm25=TINumD1), absorb(dsp_code#year week) cluster(dsp_code week) first
  estimates save "`outfilester'", replace
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) nocons nonotes ///
  addstat(First stage F-stat,e(widstat), p-value, e(idp), AR Chi2 p-value, e(archi2p), SW S-stat,e(sstatp)) ///
  addtext(County FE, --, County-year FE, X, County-month FE, --, Week-of-sample FE, X, Prov. time trend, --, County time trend, --)
  
}
*

*** county-month and week fe

foreach V of varlist d24_rate  {
	loc outfilester "$resdir/ster/winsor_p`pp'_`V'_cMwFE.ster"
  qui ivreghdfe `V' $control2 (pm25=TINumD1), absorb(dsp_code#month week) cluster(dsp_code week) first
  estimates save "`outfilester'", replace
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) nocons nonotes ///
  addstat(First stage F-stat,e(widstat), p-value, e(idp), AR Chi2 p-value, e(archi2p), SW S-stat,e(sstatp)) ///
  addtext(County FE, --, County-year FE, --, County-month FE, X, Week-of-sample FE, X, Prov. time trend, --, County time trend, --)
  
}
*

*** county-quarter of sample
cap drop quarter 
gen quarter = ceil(month/3)
foreach V of varlist d24_rate  {
	loc outfilester "$resdir/ster/winsor_p`pp'_`V'_cMwFE.ster"
  qui ivreghdfe `V' $control2 (pm25=TINumD1), absorb(dsp_code#year#quarter) cluster(dsp_code week) first
  estimates save "`outfilester'", replace
  /*outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) nocons nonotes ///
  addstat(First stage F-stat,e(widstat), p-value, e(idp), AR Chi2 p-value, e(archi2p), SW S-stat,e(sstatp)) ///
  addtext(County FE, --, County-year FE, --, County-month FE, X, Week-of-sample FE, X, Prov. time trend, --, County time trend, --)
  */
}
*


*** province week trend

tab dsp_prov, gen(prov)
forvalues i=1(1)31{
 gen provt`i'1=prov`i'*week
 gen provt`i'2=prov`i'*week^2
}
*

foreach V of varlist d24_rate {

	loc outfilester "$resdir/ster/winsor_p`pp'_`V'_provTFE.ster"
   ivreghdfe `V' $control2 provt* (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code week) // note can't recover first stage w collinearity
  estimates save "`outfilester'", replace
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) nocons nonotes ///
  addstat(First stage F-stat,e(widstat), p-value, e(idp), AR Chi2 p-value, 0, SW S-stat,0) ///
  addtext(County FE, X, County-year FE, --, County-month FE, --, Week-of-sample FE, X, Prov. time trend, X, County time trend, --)
  
}
*

*** county week trend

tab dsp_code, gen(county)
forvalues i=1(1)161{
 gen countyt`i'1=county`i'*week
 *gen countyt`i'2=county`i'*week^2
}
*

foreach V of varlist d24_rate  {
	loc outfilester "$resdir/ster/winsor_p`pp'_`V'_counTFE.ster"
  qui ivreghdfe `V' $control2 countyt* (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code week) // note can't recover first stage w collinearity
  estimates save "`outfilester'", replace
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) nocons nonotes ///
  addstat(First stage F-stat,e(widstat), p-value, e(idp), AR Chi2 p-value, 0, SW S-stat,0) ///
  addtext(County FE, X, County-year FE, --, County-month FE, --, Week-of-sample FE, X, Prov. time trend, --, County time trend, X)
 
}
*


**********************************************************************************
*						                                                         *
* Dynamics: lagged air pollution                                  *
**********************************************************************************
loc pp = 98
use data_winsorize, clear
tsset dsp_code week

foreach V of varlist pm25 TINumD1 $control2 {
  foreach i of numlist 1/10 {
     gen `V'_lag`i'=L`i'.`V'
}
}
*

foreach V of varlist pm25 TINumD1 $control2 {
  gen `V'_ave1=(`V'+`V'_lag1)/2
  gen `V'_ave2=(`V'+`V'_lag1+`V'_lag2)/3
  gen `V'_ave3=(`V'+`V'_lag1+`V'_lag2+`V'_lag3)/4
  gen `V'_ave4=(`V'+`V'_lag1+`V'_lag2+`V'_lag3+`V'_lag4)/5
  gen `V'_ave5=(`V'+`V'_lag1+`V'_lag2+`V'_lag3+`V'_lag4+`V'_lag5)/6
  gen `V'_ave6=(`V'+`V'_lag1+`V'_lag2+`V'_lag3+`V'_lag4+`V'_lag5+`V'_lag6)/7
  gen `V'_ave7=(`V'+`V'_lag1+`V'_lag2+`V'_lag3+`V'_lag4+`V'_lag5+`V'_lag6+`V'_lag7)/8
  gen `V'_ave8=(`V'+`V'_lag1+`V'_lag2+`V'_lag3+`V'_lag4+`V'_lag5+`V'_lag6+`V'_lag7+`V'_lag8)/9
  gen `V'_ave9=(`V'+`V'_lag1+`V'_lag2+`V'_lag3+`V'_lag4+`V'_lag5+`V'_lag6+`V'_lag7+`V'_lag8+`V'_lag9)/10
  gen `V'_ave10=(`V'+`V'_lag1+`V'_lag2+`V'_lag3+`V'_lag4+`V'_lag5+`V'_lag6+`V'_lag7+`V'_lag8+`V'_lag9+`V'_lag10)/11 
}
*

cap erase "$resdir/tables/table_lag_wp`pp'.tex"
cap erase "$resdir/tables/table_lag_wp`pp'.txt"

loc outfile = "$resdir/tables/table_lag_wp`pp'.tex"


foreach V of varlist d24_rate {
foreach i of numlist 1/10 {
  loc outfilester "$resdir/ster/winsor_p`pp'_`V'_lag`i'.ster"
  qui ivreghdfe `V' ///
  tem_ave*_ave`i' pre*_ave`i' ssd*_ave`i' win*_ave`i' rhu*_ave`i' prs*_ave`i' /// 
  (pm25_ave`i'=TINumD1_ave`i'), absorb(dsp_code week) cluster(dsp_code week) first
  estimates save "`outfilester'", replace
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25_ave`i') nocons nonotes ///
  addstat(First stage F-stat,e(widstat), p-value, e(idp), AR Chi2 p-value, e(archi2p), SW S-stat,e(sstatp)) ///   
  addtext( County FE, X, Week-of-sample FE, X)
}
}
*

**********************************************************************************
*						                                                         *
* Dynamics: distributed lag model using reduced form
**********************************************************************************
loc pp = 98
use data_winsorize, clear

cap erase "$resdir/tables/table_lag_reduce_wp`pp'.tex"
cap erase "$resdir/tables/table_lag_reduce_wp`pp'.txt"

loc outfile = "$resdir/tables/table_lag_reduce_wp`pp'.tex"

tsset dsp_code week

foreach V of varlist $control2 TINumD1 {
  foreach i of numlist 1/8 {
     gen `V'_lag`i'=L`i'.`V'
}
}

foreach i of numlist 1/8 {
	label var TINumD1_lag`i' "Inversions, lag `i'"
}

*

foreach V of varlist d24_rate {
  
*** 1 lag

  reghdfe `V' TINumD1 tem_ave pre-prs tem_ave2-prs2 *lag1, ///
  absorb(dsp_code week) cluster(dsp_code week)
  lincom TINumD1+TINumD1_lag1
  scalar b=r(estimate)
  scalar se=r(se)
  local b=round(b,0.0001)
  local se=round(se,0.0001)
  local t=round(b/se, 0.0001)
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep (TINumD1*) nocons nonotes ///
  addtext (Cum. effect, `b', Cum. effect SE, `se', Cum. effect t-stat, `t')

*** 2 lag

  reghdfe `V' TINumD1 tem_ave pre-prs tem_ave2-prs2 *lag1 *lag2, ///
  absorb(dsp_code week) cluster(dsp_code week)
  lincom TINumD1+TINumD1_lag1+TINumD1_lag2
  scalar b=r(estimate)
  scalar se=r(se)
  local b=round(b,0.0001)
  local se=round(se,0.0001)
  local t=round(b/se, 0.0001)
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep (TINumD1*) nocons nonotes ///
  addtext (Cum. effect, `b', Cum. effect SE, `se', Cum. effect t-stat, `t')

*** 3 lag

  reghdfe `V' TINumD1 tem_ave pre-prs tem_ave2-prs2 *lag1 *lag2 *lag3, ///
  absorb(dsp_code week) cluster(dsp_code week)
  lincom TINumD1+TINumD1_lag1+TINumD1_lag2+TINumD1_lag3
  scalar b=r(estimate)
  scalar se=r(se)
  local b=round(b,0.0001)
  local se=round(se,0.0001)
  local t=round(b/se, 0.0001)
 outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep (TINumD1*) nocons nonotes ///
  addtext (Cum. effect, `b', Cum. effect SE, `se', Cum. effect t-stat, `t')

*** 4 lag

  reghdfe `V' TINumD1 tem_ave pre-prs tem_ave2-prs2 *lag1 *lag2 *lag3 *lag4, ///
  absorb(dsp_code week) cluster(dsp_code week)
  lincom TINumD1+TINumD1_lag1+TINumD1_lag2+TINumD1_lag3+TINumD1_lag4
  scalar b=r(estimate)
  scalar se=r(se)
  local b=round(b,0.0001)
  local se=round(se,0.0001)
  local t=round(b/se, 0.0001)
  outreg2 using "`outfile'", label tex(frag)  ///
  append ctitle(`V') dec(4) ///
  keep (TINumD1*) nocons nonotes ///
  addtext (Cum. effect, `b', Cum. effect SE, `se', Cum. effect t-stat, `t')
  
*** 5 lag

  reghdfe `V' TINumD1 tem_ave pre-prs tem_ave2-prs2 *lag1 *lag2 *lag3 *lag4 *lag5, ///
  absorb(dsp_code week) cluster(dsp_code week)
  lincom TINumD1+TINumD1_lag1+TINumD1_lag2+TINumD1_lag3+TINumD1_lag4+TINumD1_lag5
  scalar b=r(estimate)
  scalar se=r(se)
  local b=round(b,0.0001)
  local se=round(se,0.0001)
  local t=round(b/se, 0.0001)
  outreg2 using "`outfile'", label tex(frag)  ///
  append ctitle(`V') dec(4) ///
  keep (TINumD1*) nocons nonotes ///
  addtext (Cum. effect, `b', Cum. effect SE, `se', Cum. effect t-stat, `t')
  
  *** 6 lag

  reghdfe `V' TINumD1 tem_ave pre-prs tem_ave2-prs2 *lag1 *lag2 *lag3 *lag4 *lag5 *lag6, ///
  absorb(dsp_code week) cluster(dsp_code week)
  lincom TINumD1+TINumD1_lag1+TINumD1_lag2+TINumD1_lag3+TINumD1_lag4+TINumD1_lag5+TINumD1_lag6
  scalar b=r(estimate)
  scalar se=r(se)
  local b=round(b,0.0001)
  local se=round(se,0.0001)
  local t=round(b/se, 0.0001)
  outreg2 using "`outfile'", label tex(frag)  ///
  append ctitle(`V') dec(4) ///
  keep (TINumD1*) nocons nonotes ///
  addtext (Cum. effect, `b', Cum. effect SE, `se', Cum. effect t-stat, `t')
  
  *** 7 lag

  reghdfe `V' TINumD1 tem_ave pre-prs tem_ave2-prs2 *lag1 *lag2 *lag3 *lag4 *lag5 *lag6 *lag7, ///
  absorb(dsp_code week) cluster(dsp_code week)
  lincom TINumD1+TINumD1_lag1+TINumD1_lag2+TINumD1_lag3+TINumD1_lag4+TINumD1_lag5+TINumD1_lag6+TINumD1_lag7
  scalar b=r(estimate)
  scalar se=r(se)
  local b=round(b,0.0001)
  local se=round(se,0.0001)
  local t=round(b/se, 0.0001)
  outreg2 using "`outfile'", label tex(frag)  ///
  append ctitle(`V') dec(4) ///
  keep (TINumD1*) nocons nonotes ///
  addtext (Cum. effect, `b', Cum. effect SE, `se', Cum. effect t-stat, `t')
  
  *** 8 lag (save for figure - 2 months based on previous PM lit)
  loc outfilester "$resdir/ster/winsor_p`pp'_`V'_lagRF8.ster"
  reghdfe `V' TINumD1 tem_ave pre-prs tem_ave2-prs2 *lag1 *lag2 *lag3 *lag4 *lag5 *lag6 *lag7 *lag8, ///
  absorb(dsp_code week) cluster(dsp_code week)
  estimates save "`outfilester'", replace
  lincom TINumD1+TINumD1_lag1+TINumD1_lag2+TINumD1_lag3+TINumD1_lag4+TINumD1_lag5+TINumD1_lag6+TINumD1_lag7+TINumD1_lag8
  scalar b=r(estimate)
  scalar se=r(se)
  local b=round(b,0.0001)
  local se=round(se,0.0001)
  local t=round(b/se, 0.0001)
  outreg2 using "`outfile'", label tex(frag)  ///
  append ctitle(`V') dec(4) ///
  keep (TINumD1*) nocons nonotes ///
  addtext (Cum. effect, `b', Cum. effect SE, `se', Cum. effect t-stat, `t')
  
}


**********************************************************************************
*						                                                         *
* Pollutants                        *
**********************************************************************************
loc pp = 98
use data_winsorize, clear

cap erase "$resdir/tables/table_pollutant_wp`pp'.tex"
cap erase "$resdir/tables/table_pollutant_wp`pp'.txt"

loc outfile = "$resdir/tables/table_pollutant_wp`pp'.tex"


foreach A of varlist aqi-co {
foreach V of varlist d24_rate {
qui ivreghdfe `V' $control2 (`A'=TINumD1), absorb(dsp_code week) cluster(dsp_code week) first
outreg2 using "`outfile'", ///
append ctitle(`V') dec(4) ///
keep(`A') ///
addstat(First stage F-stat,e(widstat), p-value, e(idp), AR Chi2 p-value, e(archi2p), SW S-stat,e(sstatp)) ///
addtext(County FE, X, Week-of-sample FE, X)

}
}
*

*********************************************************************************				                                                    
* Poisson model
**********************************************************************************

/* 
* To conduct instrumental variables in a Poisson model, we use the procedure 
* outlined by Lin and Wooldridge (2017). The original article can be found here: http://www.weilinmetrics.com/uploads/5/1/4/0/51404393/nonlinear_panel_cre_endog_20170309.pdf	
* This statalist discussion also discusses implementation details: https://www.statalist.org/forums/forum/general-stata-discussion/general/1381373-ivpoisson-with-panel-data-fixed-effects		                        */   

loc pp = 98

use data_winsorize, clear

cap erase "$resdir/tables/table_poisson_wp`pp'.tex"
cap erase "$resdir/tables/table_poisson_wp`pp'.txt"

loc outfile = "$resdir/tables/table_poisson_wp`pp'.tex"

cap drop *resid*

// Step 1: Regress endogenous variable on controls and instrument, using FE. Obtain residuals
reghdfe pm25 $control2 TINumD1, absorb(dsp_code week) residuals(pm25_resid)

// Step 2: Use Poisson model to regress outcome variable on endog. vbl, controls, *and* residuals
foreach V of varlist d24_rate fd24_rate md24_rate {
	
	ppmlhdfe `V' pm25 pm25_resid $control2, a(dsp_code week) vce(cluster dsp_code)
	outreg2 using "`outfile'", tex(frag) label keep(pm25)  ///
	append ctitle("`V'") dec(4) nocons nonotes ///
	addtext (County FE, X,  Week-of-sample FE, X)

}

// Point estimates above are correct, but we need to bootstrap SEs over this two step processs
cap drop *resid*
capture program drop mypoisson

program define mypoisson, rclass
	cap drop *resid*
	qui reghdfe pm25 $control2 TINumD1, absorb(dsp_code week) residuals(pm25_resid)
	qui ppmlhdfe d24_rate pm25 pm25_resid $control2, a(dsp_code week) vce(cluster dsp_code)
	local beta_all = _b[pm25]
	qui ppmlhdfe fd24_rate pm25 pm25_resid $control2, a(dsp_code week) vce(cluster dsp_code)
	local beta_f = _b[pm25]
	qui ppmlhdfe md24_rate pm25 pm25_resid $control2, a(dsp_code week) vce(cluster dsp_code)
	local beta_m = _b[pm25]
	
	ereturn clear
		
	return scalar betaALL = `beta_all'
	return scalar betaF = `beta_f'
	return scalar betaM = `beta_m'

end

bootstrap all=r(betaALL) fem=r(betaF) male=r(betaM), reps(100) nodrop cluster(dsp_code) idcluster(newid) group(dsp_code): mypoisson

// store results
matrix betas = e(b)
matrix SEs = e(se)

// save results 
svmat double betas , name(betas)
svmat double SEs, name(ses)
keep if _n==1
keep betas* ses*
ren betas1 betas_ALL
ren betas2 betas_FEM
ren betas3 betas_MALE
ren ses1 ses_ALL
ren ses2 ses_FEM
ren ses3 ses_MALE

outsheet using "$resdir/tables/table_poisson_wp`pp'_bootstrap.csv", comma replace

