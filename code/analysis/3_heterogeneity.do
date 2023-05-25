
**********************************************************************************

* This script estimates heterogeneity in the effect of air pollution on suicide/main_2017
* in Zhang et al. Results from this script are shown in Figure 2B.

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
	
* choose amount of winsorization
loc pp = 98 	

use data, clear

foreach V of varlist d24_rate fd24_rate md24_rate {
egen `V'_phigh=pctile(`V'), p(`pp')
replace `V'=. if `V'>`V'_phigh
}
*
cap drop tem_ave2-prs2
foreach V of varlist tem_ave pre-prs {
gen `V'2=`V'^2
}
*

global control2 ///
tem_ave pre-prs tem_ave2 pre2-prs2

save data_winsorize, replace

**********************************************************************************
*						                                                         *
* 1) main specification                  *
**********************************************************************************	

estimates use "$resdir/ster/winsor_p98_d24_rate_TINumD1.ster"
estimates

**********************************************************************************
*						                                                         *
* 2) by age                          *
**********************************************************************************

use data, clear

loc outfile = "$resdir/tables/table_age_wp`pp'.tex"

cap erase "$resdir/tables/table_age_wp`pp'.tex"
cap erase "$resdir/tables/table_age_wp`pp'.txt"

foreach V of varlist tem_ave pre-prs {
gen `V'2=`V'^2
}
*

global control2 ///
tem_ave pre-prs tem_ave2 pre2-prs2

*** gen death rates for 0-15

* population
gen f0_15_chinapop=f0_chinapop+f1_chinapop+f5_chinapop+f10_chinapop
gen m0_15_chinapop=m0_chinapop+m1_chinapop+m5_chinapop+m10_chinapop
gen t0_15_chinapop=f0_15_chinapop+m0_15_chinapop

* death rate
gen f0_15d24_rate=(f0d24_rate*f0_chinapop+f1d24_rate*f1_chinapop ///
+f5d24_rate*f5_chinapop+f10d24_rate*f10_chinapop) ///
/f0_15_chinapop

gen m0_15d24_rate=(m0d24_rate*m0_chinapop+m1d24_rate*m1_chinapop ///
+m5d24_rate*m5_chinapop+m10d24_rate*m10_chinapop) ///
/m0_15_chinapop

gen t0_15d24_rate=(f0_15d24_rate*f0_15_chinapop+m0_15d24_rate*m0_15_chinapop)/t0_15_chinapop

sum *0_15d24_rate

*** gen death rates for 15-65

* population
gen f15_65_chinapop=f15_chinapop+f20_chinapop+f25_chinapop+f30_chinapop ///
+f35_chinapop+f40_chinapop+f45_chinapop+f50_chinapop ///
+f55_chinapop+f60_chinapop

gen m15_65_chinapop=m15_chinapop+m20_chinapop+m25_chinapop+m30_chinapop ///
+m35_chinapop+m40_chinapop+m45_chinapop+m50_chinapop ///
+m55_chinapop+m60_chinapop

gen t15_65_chinapop=f15_65_chinapop+m15_65_chinapop

* death rate
gen f15_65d24_rate=(f15d24_rate*f15_chinapop+f20d24_rate*f20_chinapop ///
+f25d24_rate*f25_chinapop+f30d24_rate*f30_chinapop ///
+f35d24_rate*f35_chinapop+f40d24_rate*f40_chinapop ///
+f45d24_rate*f45_chinapop+f50d24_rate*f50_chinapop ///
+f55d24_rate*f55_chinapop+f60d24_rate*f60_chinapop) ///
/f15_65_chinapop

gen m15_65d24_rate=(m15d24_rate*m15_chinapop+m20d24_rate*m20_chinapop ///
+m25d24_rate*m25_chinapop+m30d24_rate*m30_chinapop ///
+m35d24_rate*m35_chinapop+m40d24_rate*m40_chinapop ///
+m45d24_rate*m45_chinapop+m50d24_rate*m50_chinapop ///
+m55d24_rate*m55_chinapop+m60d24_rate*m60_chinapop) ///
/m15_65_chinapop

gen t15_65d24_rate=(f15_65d24_rate*f15_65_chinapop+m15_65d24_rate*m15_65_chinapop)/t15_65_chinapop

sum *15_65d24_rate

*** gen death rates for 65 above

* population
gen f65_85_chinapop=f65_chinapop+f70_chinapop+f75_chinapop+f80_chinapop+f85_chinapop
gen m65_85_chinapop=m65_chinapop+m70_chinapop+m75_chinapop+m80_chinapop+m85_chinapop
gen t65_85_chinapop=f65_85_chinapop+m65_85_chinapop

* death rates
gen f65_85d24_rate=(f65d24_rate*f65_chinapop+f70d24_rate*f70_chinapop ///
+f75d24_rate*f75_chinapop+f80d24_rate*f80_chinapop ///
+f85d24_rate*f85_chinapop)/f65_85_chinapop

gen m65_85d24_rate=(m65d24_rate*m65_chinapop+m70d24_rate*m70_chinapop ///
+m75d24_rate*m75_chinapop+m80d24_rate*m80_chinapop ///
+m85d24_rate*m85_chinapop)/m65_85_chinapop

gen t65_85d24_rate=(f65_85d24_rate*f65_85_chinapop+m65_85d24_rate*m65_85_chinapop)/t65_85_chinapop

sum *65_85d24_rate

*** winsorize

foreach V of varlist d24_rate fd24_rate md24_rate *15_65d24_rate *65_85d24_rate {
egen `V'_phigh=pctile(`V'), p(`pp')
replace `V'=. if `V'>`V'_phigh
}
*

save data_winsorize_demographics, replace

foreach V of varlist d24_rate fd24_rate md24_rate *0_15d24_rate *15_65d24_rate *65_85d24_rate {
	
  loc outfilester "$resdir/ster/winsor_p`pp'_`V'_TINumD1.ster" 
  ivreghdfe `V' $control2 (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code week)
  estimates save "`outfilester'", replace
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE, Clustering, County and week)
}
*

**********************************************************************************
*						                                                         *
* 3) polluted vs less-polluted                    *
**********************************************************************************

use "data_winsorize.dta", clear

tostring dsp_code, replace
gen prov_code=substr(dsp_code,1,2)
destring dsp_code prov_code, replace

* avg pollution terciles
preserve
collapse (mean) pm25, by(dsp_code)
xtile pm25_tile = pm25, nq(3)
tempfile tiles
save "`tiles'", replace
restore

merge m:1 dsp_code using "`tiles'"
drop _merge

tabstat d24_rate fd24_rate md24_rate, by(pm25_tile)

loc outfile = "$resdir/tables/table_avgPM25_wp`pp'.tex"

cap erase "$resdir/tables/table_avgPM25_wp`pp'.tex"
cap erase "$resdir/tables/table_avgPM25_wp`pp'.txt"

*** baseline
foreach V of varlist d24_rate fd24_rate md24_rate {

  ivreghdfe `V' $control2 (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code week)
  outreg2 using "`outfile'", label tex(frag)  ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(Sample, Full, IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE, Clustering, County and week)

}
*

** first tercile
foreach V of varlist d24_rate fd24_rate md24_rate {

  loc outfilester "$resdir/ster/winsor_p`pp'_`V'_avgPM25Tercile1.ster"
  
  ivreghdfe `V' $control2 (pm25=TINumD1) if pm25_tile==1, absorb(dsp_code week) cluster(dsp_code week)
  
  estimates save "`outfilester'", replace
  
  outreg2 using "`outfile'", label tex(frag)  ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(Sample, Tercile1, IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE, Clustering, County and week)
}

** second tercile
foreach V of varlist d24_rate fd24_rate md24_rate {

  loc outfilester "$resdir/ster/winsor_p`pp'_`V'_avgPM25Tercile2.ster"
  
  ivreghdfe `V' $control2 (pm25=TINumD1) if pm25_tile==2, absorb(dsp_code week) cluster(dsp_code week)
  
  estimates save "`outfilester'", replace
  
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(Sample, Tercile2, IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE, Clustering, County and week)
}

*** highest tercile

foreach V of varlist d24_rate fd24_rate md24_rate {

  loc outfilester "$resdir/ster/winsor_p`pp'_`V'_avgPM25Tercile3.ster"
  
  ivreghdfe `V' $control2 (pm25=TINumD1) if pm25_tile==3, absorb(dsp_code week) cluster(dsp_code week)
  
  estimates save "`outfilester'", replace
  
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(Sample, Tercile3, IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE, Clustering, County and week)
}
*


**********************************************************************************
*						                                                         *
* 4) urban vs rural                         *
**********************************************************************************

use "data_winsorize.dta", clear

loc outfile = "$resdir/tables/table_urban_wp`pp'.tex"

cap erase "$resdir/tables/table_urban_wp`pp'.tex"
cap erase "$resdir/tables/table_urban_wp`pp'.txt"

tab urb_rur
tabstat d24_rate fd24_rate md24_rate, by(urb_rur)
tabstat pm25, by(urb_rur)


* full sample
foreach V of varlist d24_rate fd24_rate md24_rate {

  ivreghdfe `V' $control2 (pm25=TINumD1) , absorb(dsp_code week) cluster(dsp_code week)
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(Sample, Full, IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE, Clustering, County and week)
  
}
*

* urban
foreach V of varlist d24_rate fd24_rate md24_rate {

  loc outfilester "$resdir/ster/winsor_p`pp'_`V'_urban.ster"
  
  ivreghdfe `V' $control2 (pm25=TINumD1) if urb_rur==1, absorb(dsp_code week) cluster(dsp_code week)
  
  estimates save "`outfilester'", replace
  
  outreg2 using "`outfile'", label tex(frag)  ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(Sample, Urban, IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE, Clustering, County and week)
  
}
*

* rural
foreach V of varlist d24_rate fd24_rate md24_rate {

  loc outfilester "$resdir/ster/winsor_p`pp'_`V'_rural.ster"
  
  ivreghdfe `V' $control2 (pm25=TINumD1) if urb_rur==2, absorb(dsp_code week) cluster(dsp_code week)
  
  estimates save "`outfilester'", replace
  
  outreg2 using "`outfile'", label tex(frag)  ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(Sample, Rural, IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE, Clustering, County and week)
  
}
*


**********************************************************************************
*						                                                         *
* 5) rich vs poor                      *
**********************************************************************************

use "data_winsorize.dta", clear

loc outfile = "$resdir/tables/table_rich_wp`pp'.tex"

cap erase "$resdir/tables/table_rich_wp`pp'.tex"
cap erase "$resdir/tables/table_rich_wp`pp'.txt"

tostring dsp_code, replace
gen prov_code=substr(dsp_code,1,2)
destring dsp_code prov_code, replace

***https://en.wikipedia.org/wiki/List_of_Chinese_administrative_divisions_by_GDP_per_capita
* use 2015 data

gen rich=1 if prov_code==11 | prov_code==31 | prov_code==12 | prov_code==32 ///
| prov_code==33 | prov_code==35 | prov_code==44 | prov_code==37 ///
| prov_code==15 | prov_code==50 | prov_code==21 | prov_code==42 ///
| prov_code==21 | prov_code==61 | prov_code==64 

replace rich=0 if rich==.

tabstat d24_rate fd24_rate md24_rate, by(rich)

*** baseline

foreach V of varlist d24_rate fd24_rate md24_rate {

  ivreghdfe `V' $control2 (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code week)
  outreg2 using "`outfile'",  label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(Sample, Full, IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE, Clustering, County and week)

}
*

*** rich

foreach V of varlist d24_rate fd24_rate md24_rate {

  loc outfilester "$resdir/ster/winsor_p`pp'_`V'_rich.ster"
  
  ivreghdfe `V' $control2 (pm25=TINumD1) if rich==1, absorb(dsp_code week) cluster(dsp_code week)
  
  estimates save "`outfilester'", replace
  
  outreg2 using "`outfile'",  label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(Sample, Rich, IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE, Clustering, County and week)

}
*

*** poor

foreach V of varlist d24_rate fd24_rate md24_rate {

  loc outfilester "$resdir/ster/winsor_p`pp'_`V'_poor.ster"
  
  ivreghdfe `V' $control2 (pm25=TINumD1) if rich==0, absorb(dsp_code week) cluster(dsp_code week)
  
  estimates save "`outfilester'", replace
  
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(Sample, Poor, IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE, Clustering, County and week)

}
*



**********************************************************************************
*						                                                         *
* 6) seasons                   *
**********************************************************************************

use "data_winsorize.dta", clear

loc outfile = "$resdir/tables/table_seasons_wp`pp'.tex"

cap erase "$resdir/tables/table_seasons_wp`pp'.tex"
cap erase "$resdir/tables/table_seasons_wp`pp'.txt"

tostring dsp_code, replace
gen prov_code=substr(dsp_code,1,2)
destring dsp_code prov_code, replace

* seasons
gen season = "spring" if month>=4 & month<=6
replace season = "summer" if month>=7 & month<=9
replace season = "fall" if month>=10 & month<=12
replace season = "winter" if month>=1 & month<=3

tabstat d24_rate fd24_rate md24_rate, by(season)

*** baseline
foreach V of varlist d24_rate fd24_rate md24_rate {

  ivreghdfe `V' $control2 (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code week)
  outreg2 using "`outfile'", label tex(frag)  ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(Sample, Full, IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE, Clustering, County and week)

}
*

*** spring

foreach V of varlist d24_rate fd24_rate md24_rate {

  loc outfilester "$resdir/ster/winsor_p`pp'_`V'_spring.ster"
  
  ivreghdfe `V' $control2 (pm25=TINumD1) if season=="spring", absorb(dsp_code week) cluster(dsp_code week)
  
  estimates save "`outfilester'", replace
  
  outreg2 using "`outfile'", label tex(frag)  ///
  replace ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(Sample, Spring, IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE, Clustering, County and week)
}
*

*** summer

foreach V of varlist d24_rate fd24_rate md24_rate {

  loc outfilester "$resdir/ster/winsor_p`pp'_`V'_summer.ster"
  
  ivreghdfe `V' $control2 (pm25=TINumD1) if season=="summer", absorb(dsp_code week) cluster(dsp_code week)
  
  estimates save "`outfilester'", replace
  
  outreg2 using "`outfile'", label tex(frag)  ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(Sample, Summer, IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE, Clustering, County and week)
}
*

*** fall

foreach V of varlist d24_rate fd24_rate md24_rate {

  loc outfilester "$resdir/ster/winsor_p`pp'_`V'_fall.ster"
  
  ivreghdfe `V' $control2 (pm25=TINumD1) if season=="fall", absorb(dsp_code week) cluster(dsp_code week)
  
  estimates save "`outfilester'", replace
  
  outreg2 using "`outfile'", label tex(frag)  ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(Sample, Fall, IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE, Clustering, County and week)
}
*

*** winter

foreach V of varlist d24_rate fd24_rate md24_rate {

  loc outfilester "$resdir/ster/winsor_p`pp'_`V'_winter.ster"
  
  ivreghdfe `V' $control2 (pm25=TINumD1) if season=="winter", absorb(dsp_code week) cluster(dsp_code week)
  
  estimates save "`outfilester'", replace
  
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(Sample, Winter, IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE, Clustering, County and week)
}
*

**********************************************************************************
*						                                                         *
* 7) avg suicide rate                  *
**********************************************************************************

use "data_winsorize.dta", clear

tostring dsp_code, replace
gen prov_code=substr(dsp_code,1,2)
destring dsp_code prov_code, replace

* avg suicide rate terciles
preserve
collapse (mean) d24_rate, by(dsp_code)
xtile sui_tile = d24_rate, nq(3)
tempfile tiles
save "`tiles'", replace
restore

merge m:1 dsp_code using "`tiles'"
drop _merge

tabstat d24_rate fd24_rate md24_rate, by(sui_tile)

loc outfile = "$resdir/tables/table_avgsui_wp`pp'.tex"

cap erase "$resdir/tables/table_avgsui_wp`pp'.tex"
cap erase "$resdir/tables/table_avgsui_wp`pp'.txt"

*** baseline
foreach V of varlist d24_rate fd24_rate md24_rate {

  ivreghdfe `V' $control2 (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code week)
  outreg2 using "`outfile'", label tex(frag)  ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(Sample, Full, IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE, Clustering, County and week)

}
*

** first tercile
foreach V of varlist d24_rate fd24_rate md24_rate {

  loc outfilester "$resdir/ster/winsor_p`pp'_`V'_avgsuiTercile1.ster"
  
  ivreghdfe `V' $control2 (pm25=TINumD1) if sui_tile==1, absorb(dsp_code week) cluster(dsp_code week)
  
  estimates save "`outfilester'", replace
  
  outreg2 using "`outfile'", label tex(frag)  ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(Sample, Tercile1, IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE, Clustering, County and week)
}

** second tercile
foreach V of varlist d24_rate fd24_rate md24_rate {

  loc outfilester "$resdir/ster/winsor_p`pp'_`V'_avgsuiTercile2.ster"
  
  ivreghdfe `V' $control2 (pm25=TINumD1) if sui_tile==2, absorb(dsp_code week) cluster(dsp_code week)
  
  estimates save "`outfilester'", replace
  
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(Sample, Tercile2, IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE, Clustering, County and week)
}

*** highest tercile

foreach V of varlist d24_rate fd24_rate md24_rate {

  loc outfilester "$resdir/ster/winsor_p`pp'_`V'_avgsuiTercile3.ster"
  
  ivreghdfe `V' $control2 (pm25=TINumD1) if sui_tile==3, absorb(dsp_code week) cluster(dsp_code week)
  
  estimates save "`outfilester'", replace
  
  outreg2 using "`outfile'", label tex(frag) ///
  append ctitle(`V') dec(4) ///
  keep(pm25) ///
  addstat(KP Test,e(widstat), p-value, e(idp)) ///
  addtext(Sample, Tercile3, IV, TINumD1, Weather, Quadratic, FE, County FE and Week FE, Clustering, County and week)
}
*


