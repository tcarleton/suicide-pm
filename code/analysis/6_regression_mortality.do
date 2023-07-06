
**********************************************************************************

* This script runs the main regression in Zhang et al., but with respiratory and 
* cardiovascular mortality as an outcome instead of suicide (in a far more 
* limited sample due to data availability)

* The results from this analysis are presented in SI Appendix Fig S11
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

use "data_d1920.dta", clear

* choose amount of winsorization
loc pp = 98 

foreach V of varlist d19_rate d20_rate md19_rate md20_rate fd19_rate fd20_rate {
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

save data_winsorize_d1920, replace

**********************************************************************************
*						                                                         *
* OLS vs IV                              *
**********************************************************************************
use data_winsorize_d1920, clear

cap erase "table_main_wp_d1920.xls"
cap erase "table_main_wp_d1920.txt"

foreach V of varlist d_rate_ad {

  ivreghdfe `V' $control2 (pm25=TINumD1), first absorb(i.dsp_code i.week) cluster(dsp_code week)
  outreg2 using "table_main_wp_d1920.xls", ///
  append ctitle(`V': IV) dec(4) ///
  keep(pm25) ///
  addstat(KP F-stat,e(widstat), p-value, e(idp), AR Chi2 p-value, e(archi2p), SW S-stat,e(sstatp)) ///
  addtext(County FE, Yes, Week FE, Yes, Clustering: County and week, Yes)
 
  reghdfe `V' $control2 pm25, absorb(i.dsp_code i.week) cluster(dsp_code week)
  outreg2 using "table_main_wp_d1920.xls", ///
  append ctitle(`V': FE) dec(4) ///
  keep(pm25) ///
  addtext (County FE, Yes, Week FE, Yes, Clustering: County and week, Yes)
}

