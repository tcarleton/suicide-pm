

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

**********************************************************************************
*						                                                         *
* first stage                               *
**********************************************************************************

use data_winsorize, clear

loc outfile = "$resdir/tables/table_first_wp`pp'.tex"

cap erase "$resdir/tables/table_first_wp`pp'.tex"
cap erase "$resdir/tables/table_first_wp`pp'.txt"

keep if d24_rate !=. & pm25 !=. & TINumD1 !=. & tem_ave !=. & pre !=. & ssd !=. & win !=. & rhu !=. & prs !=. 

foreach V of varlist TINumD1 TIStrD1 TIIndD1 {

ivreghdfe pm25 `V' $control2, absorb(dsp_code week) cluster(dsp_code week)
tab year if e(sample)
outreg2 using "`outfile'", label tex(frag) ///
append ctitle(pm25) dec(4) ///
keep(`V') ///
addtext(County FE, Yes, Week FE, Yes, Clustering: County and week, Yes)
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


foreach A of varlist TINumD1 TIIndD1 TIStrD1 {
foreach V of varlist d24_rate fd24_rate md24_rate {
	
 loc outfilester "$resdir/ster/winsor_p`pp'_`V'_`A'.ster"

  ivreghdfe `V' $control2 (pm25=`A'), absorb(dsp_code week) cluster(dsp_code week) 
  
  * save estimates from main model for use in figures
  estimates save "`outfilester'", replace
  
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(IV, `A', Weather, Quadratic, FE, County FE and Week FE, Clustering, County and week)
  
}
}
*


**********************************************************************************
*						                                                         *
* OLS vs IV                              *
**********************************************************************************

use data_winsorize, clear

loc outfile = "$resdir/tables/table_main_wp`pp'.tex"

cap erase "$resdir/tables/table_main_wp`pp'.tex"
cap erase "$resdir/tables/table_main_wp`pp'.txt"


foreach V of varlist d24_rate fd24_rate md24_rate {

  ivreghdfe `V' $control2 (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code week)
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V': IV) dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(County FE, Yes, Week FE, Yes, Clustering: County and week, Yes)
  
  reghdfe `V' $control pm25, absorb(dsp_code week) cluster(dsp_code week)
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V': FE) dec(4) ///
  keep(pm25) ///
  addtext (County FE, Yes, Week FE, Yes, Clustering: County and week, Yes)
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

foreach V of varlist d24_rate fd24_rate md24_rate {
	loc outfilester "$resdir/ster/winsor_p`pp'_`V'_clNone.ster"
  
  ivreghdfe `V' $control2 (pm25=TINumD1), absorb(dsp_code week) 
  estimates save "`outfilester'", replace
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE, Clustering, No)
  
}
*

*** cluster by week 

foreach V of varlist d24_rate fd24_rate md24_rate {
	loc outfilester "$resdir/ster/winsor_p`pp'_`V'_clWeek.ster"
  ivreghdfe `V' $control2 (pm25=TINumD1), absorb(dsp_code week) cluster(week)
  estimates save "`outfilester'", replace
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE, Clustering, Week)
  
}
*

*** cluster by county

foreach V of varlist d24_rate fd24_rate md24_rate {
	loc outfilester "$resdir/ster/winsor_p`pp'_`V'_clCounty.ster"
  ivreghdfe `V' $control2 (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code)
  estimates save "`outfilester'", replace
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE, Clustering, County)
  
}
*

*** cluster by county and week (PREFERRED)

foreach V of varlist d24_rate fd24_rate md24_rate {
  ivreghdfe `V' $control2 (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code week)
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE, Clustering, County and week)
  
}
*



**********************************************************************************
*						                                                         *
* Robustness: Weather controls                                 *
**********************************************************************************

use data_winsorize, clear

loc outfile = "$resdir/tables/table_weather_wp`pp'.tex"

cap erase "$resdir/tables/table_weather_wp`pp'.tex"
cap erase "$resdir/tables/table_weather_wp`pp'.txt"


global control ///
tem_ave ///
pre-prs 

global control_bins ///
tem_ave_pbin* pre_pbin10-prs_pbin100

*** no weather controls

foreach V of varlist d24_rate fd24_rate md24_rate {
	loc outfilester "$resdir/ster/winsor_p`pp'_`V'_noWeather.ster"
  ivreghdfe `V' (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code week) 
  estimates save "`outfilester'", replace
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(IV, TINumD1, Weather, No, FE, County FE and Week FE, Clustering, County and week)
  
}
*

*** weather linear

foreach V of varlist d24_rate fd24_rate md24_rate {
	loc outfilester "$resdir/ster/winsor_p`pp'_`V'_linWeather.ster"
  ivreghdfe `V' $control (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code week) 
  estimates save "`outfilester'", replace
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(IV, TINumD1, Weather, Linear, FE, County FE and Week FE, Clustering, County and week)
  
}
*

*** weather quadratic (PREFERRED)

foreach V of varlist d24_rate fd24_rate md24_rate {
  ivreghdfe `V' $control2 (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code week)
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE, Clustering, County and week)
  
}
*

*** weather bins 

foreach V of varlist d24_rate fd24_rate md24_rate {
	loc outfilester "$resdir/ster/winsor_p`pp'_`V'_binWeather.ster"
  ivreghdfe `V' $control_bins (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code week) 
  estimates save "`outfilester'", replace
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(IV, TINumD1, Weather, Bins, FE, County FE and Week FE, Clustering, County and week)
  
}
*


**********************************************************************************
*						                                                         *
* Robustness: Fixed effects                                 *
**********************************************************************************

use data_winsorize, clear


loc outfile = "$resdir/tables/table_fe_wp`pp'.tex"

cap erase "$resdir/tables/table_fe_wp`pp'.tex"
cap erase "$resdir/tables/table_fe_wp`pp'.txt"

*** county and week fe (PREFERRED)

foreach V of varlist d24_rate fd24_rate md24_rate {

  ivreghdfe `V' $control2 (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code week)
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE, Clustering, County and week)
  
}
*

*** county-year and week fe

foreach V of varlist d24_rate fd24_rate md24_rate {
	loc outfilester "$resdir/ster/winsor_p`pp'_`V'_cYwFE.ster"
  ivreghdfe `V' $control2 (pm25=TINumD1), absorb(dsp_code#year week) cluster(dsp_code week)
  estimates save "`outfilester'", replace
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(IV, TINumD1, Weather, Quadratic, FE, County-year FE and Week FE, Clustering, County and week)
  
}
*

*** county-month and week fe

foreach V of varlist d24_rate fd24_rate md24_rate {
	loc outfilester "$resdir/ster/winsor_p`pp'_`V'_cMwFE.ster"
  ivreghdfe `V' $control2 (pm25=TINumD1), absorb(dsp_code#month week) cluster(dsp_code week)
  estimates save "`outfilester'", replace
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(IV, TINumD1, Weather, Quadratic, FE, County-month FE and Week FE, Clustering, County and week)
  
}
*

*** province week trend

tab dsp_prov, gen(prov)
forvalues i=1(1)31{
 gen provt`i'1=prov`i'*week
 gen provt`i'2=prov`i'*week^2
}
*

foreach V of varlist d24_rate fd24_rate md24_rate {
	loc outfilester "$resdir/ster/winsor_p`pp'_`V'_provTFE.ster"
  ivreghdfe `V' $control2 provt* (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code week)
  estimates save "`outfilester'", replace
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE and Province trend, Clustering, County and week)
  
}
*

*** county week trend

tab dsp_code, gen(county)
forvalues i=1(1)161{
 gen countyt`i'1=county`i'*week
 *gen countyt`i'2=county`i'*week^2
}
*

foreach V of varlist d24_rate fd24_rate md24_rate {
	loc outfilester "$resdir/ster/winsor_p`pp'_`V'_counTFE.ster"
  ivreghdfe `V' $control2 countyt* (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code week)
  estimates save "`outfilester'", replace
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE and County trend, Clustering, County and week)
  
}
*


**********************************************************************************
*						                                                         *
* Dynamics: lagged air pollution                                  *
**********************************************************************************

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

cap erase "table_lag_wp`pp'.tex"
cap erase "table_lag_wp`pp'.txt"

foreach V of varlist d24_rate fd24_rate md24_rate {
foreach i of numlist 1/10 {
  loc outfilester "$resdir/ster/winsor_p`pp'_`V'_lag`i'.ster"
  ivreghdfe `V' ///
  tem_ave*_ave`i' pre*_ave`i' ssd*_ave`i' win*_ave`i' rhu*_ave`i' prs*_ave`i' /// 
  (pm25_ave`i'=TINumD1_ave`i'), absorb(dsp_code week) cluster(dsp_code week)
  estimates save "`outfilester'", replace
  outreg2 using "table_lag_wp`pp'.tex", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25_ave`i') ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///   
  addtext(IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE, Clustering, County and week)
}
}
*

**********************************************************************************
*						                                                         *
* Dynamics: distributed lag model using reduced form
**********************************************************************************

use data_winsorize, clear

cap erase "table_lag_reduce_wp`pp'.tex"
cap erase "table_lag_reduce_wp`pp'.txt"

tsset dsp_code week

foreach V of varlist $control2 TINumD1 {
  foreach i of numlist 1/10 {
     gen `V'_lag`i'=L`i'.`V'
}
}
*

foreach V of varlist d24_rate fd24_rate md24_rate {

*** 1 lag

  reghdfe `V' TINumD1 tem_ave pre-prs tem_ave2-prs2 *lag1, ///
  absorb(dsp_code week) cluster(dsp_code week)
  lincom TINumD1+TINumD1_lag1
  scalar b=r(estimate)
  scalar se=r(se)
  local b=round(b,0.0001)
  local se=round(se,0.0001)
  local t=round(b/se, 0.0001)
  outreg2 using "table_lag_reduce_wp`pp'.tex", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep (TINumD1*) ///
  addtext (sum, `b', sum_se, `se', sum_t, `t')

*** 2 lag

  reghdfe `V' TINumD1 tem_ave pre-prs tem_ave2-prs2 *lag1 *lag2, ///
  absorb(dsp_code week) cluster(dsp_code week)
  lincom TINumD1+TINumD1_lag1+TINumD1_lag2
  scalar b=r(estimate)
  scalar se=r(se)
  local b=round(b,0.0001)
  local se=round(se,0.0001)
  local t=round(b/se, 0.0001)
  outreg2 using "table_lag_reduce_wp`pp'.tex", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep (TINumD1*) ///
  addtext (sum, `b', sum_se, `se', sum_t, `t')

*** 3 lag

  reghdfe `V' TINumD1 tem_ave pre-prs tem_ave2-prs2 *lag1 *lag2 *lag3, ///
  absorb(dsp_code week) cluster(dsp_code week)
  lincom TINumD1+TINumD1_lag1+TINumD1_lag2+TINumD1_lag3
  scalar b=r(estimate)
  scalar se=r(se)
  local b=round(b,0.0001)
  local se=round(se,0.0001)
  local t=round(b/se, 0.0001)
  outreg2 using "table_lag_reduce_wp`pp'.xls", ///
  append ctitle(`V') dec(4) ///
  keep (TINumD1*) ///
  addtext (sum, `b', sum_se, `se', sum_t, `t')

*** 4 lag

  reghdfe `V' TINumD1 tem_ave pre-prs tem_ave2-prs2 *lag1 *lag2 *lag3 *lag4, ///
  absorb(dsp_code week) cluster(dsp_code week)
  lincom TINumD1+TINumD1_lag1+TINumD1_lag2+TINumD1_lag3+TINumD1_lag4
  scalar b=r(estimate)
  scalar se=r(se)
  local b=round(b,0.0001)
  local se=round(se,0.0001)
  local t=round(b/se, 0.0001)
  outreg2 using "table_lag_reduce_wp`pp'.tex", label tex(frag)  ///
  append ctitle(`V') dec(4) ///
  keep (TINumD1*) ///
  addtext (sum, `b', sum_se, `se', sum_t, `t')
  
*** 5 lag

  reghdfe `V' TINumD1 tem_ave pre-prs tem_ave2-prs2 *lag1 *lag2 *lag3 *lag4 *lag5, ///
  absorb(dsp_code week) cluster(dsp_code week)
  lincom TINumD1+TINumD1_lag1+TINumD1_lag2+TINumD1_lag3+TINumD1_lag4+TINumD1_lag5
  scalar b=r(estimate)
  scalar se=r(se)
  local b=round(b,0.0001)
  local se=round(se,0.0001)
  local t=round(b/se, 0.0001)
  outreg2 using "table_lag_reduce_wp`pp'.tex", label tex(frag)  ///
  append ctitle(`V') dec(4) ///
  keep (TINumD1*) ///
  addtext (sum, `b', sum_se, `se', sum_t, `t')
  
  *** 6 lag

  reghdfe `V' TINumD1 tem_ave pre-prs tem_ave2-prs2 *lag1 *lag2 *lag3 *lag4 *lag5 *lag6, ///
  absorb(dsp_code week) cluster(dsp_code week)
  lincom TINumD1+TINumD1_lag1+TINumD1_lag2+TINumD1_lag3+TINumD1_lag4+TINumD1_lag5+TINumD1_lag6
  scalar b=r(estimate)
  scalar se=r(se)
  local b=round(b,0.0001)
  local se=round(se,0.0001)
  local t=round(b/se, 0.0001)
  outreg2 using "table_lag_reduce_wp`pp'.tex", label tex(frag)  ///
  append ctitle(`V') dec(4) ///
  keep (TINumD1*) ///
  addtext (sum, `b', sum_se, `se', sum_t, `t')
  
  *** 7 lag

  reghdfe `V' TINumD1 tem_ave pre-prs tem_ave2-prs2 *lag1 *lag2 *lag3 *lag4 *lag5 *lag6 *lag7, ///
  absorb(dsp_code week) cluster(dsp_code week)
  lincom TINumD1+TINumD1_lag1+TINumD1_lag2+TINumD1_lag3+TINumD1_lag4+TINumD1_lag5+TINumD1_lag6+TINumD1_lag7
  scalar b=r(estimate)
  scalar se=r(se)
  local b=round(b,0.0001)
  local se=round(se,0.0001)
  local t=round(b/se, 0.0001)
  outreg2 using "table_lag_reduce_wp`pp'.tex", label tex(frag)  ///
  append ctitle(`V') dec(4) ///
  keep (TINumD1*) ///
  addtext (sum, `b', sum_se, `se', sum_t, `t')
  
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
  outreg2 using "table_lag_reduce_wp`pp'.tex", label tex(frag)  ///
  append ctitle(`V') dec(4) ///
  keep (TINumD1*) ///
  addtext (sum, `b', sum_se, `se', sum_t, `t')
  
  *** 9 lag

  reghdfe `V' TINumD1 tem_ave pre-prs tem_ave2-prs2 *lag1 *lag2 *lag3 *lag4 *lag5 *lag6 *lag7 *lag8 *lag9, ///
  absorb(dsp_code week) cluster(dsp_code week)
  lincom TINumD1+TINumD1_lag1+TINumD1_lag2+TINumD1_lag3+TINumD1_lag4+TINumD1_lag5+TINumD1_lag6+TINumD1_lag7+TINumD1_lag8+TINumD1_lag9
  scalar b=r(estimate)
  scalar se=r(se)
  local b=round(b,0.0001)
  local se=round(se,0.0001)
  local t=round(b/se, 0.0001)
  outreg2 using "table_lag_reduce_wp`pp'.tex", label tex(frag)  ///
  append ctitle(`V') dec(4) ///
  keep (TINumD1*) ///
  addtext (sum, `b', sum_se, `se', sum_t, `t')
  
  *** 10 lag

  reghdfe `V' TINumD1 tem_ave pre-prs tem_ave2-prs2 *lag1 *lag2 *lag3 *lag4 *lag5 *lag6 *lag7 *lag8 *lag9 *lag10, ///
  absorb(dsp_code week) cluster(dsp_code week)
  lincom TINumD1+TINumD1_lag1+TINumD1_lag2+TINumD1_lag3+TINumD1_lag4+TINumD1_lag5+TINumD1_lag6+TINumD1_lag7+TINumD1_lag8+TINumD1_lag9+TINumD1_lag10
  scalar b=r(estimate)
  scalar se=r(se)
  local b=round(b,0.0001)
  local se=round(se,0.0001)
  local t=round(b/se, 0.0001)
  outreg2 using "table_lag_reduce_wp`pp'.tex", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep (TINumD1*) ///
  addtext (sum, `b', sum_se, `se', sum_t, `t')

}


