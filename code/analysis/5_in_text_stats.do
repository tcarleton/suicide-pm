
**********************************************************************************

* This script uses data ane estimates results from Zhang et al., 
* to compute key statistics cited throughout the main text.

* Data called by this script are assembled in code/clean/1_merge.do. 
* Estimation results called by this script are computed in varios do-files in 
* code/analysis/. 

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

* set up outfile -- stat, detail, estimate
capture postutil clear
postfile stats str30(statname) str50(details) stat stat_se stat_pval using "$resdir/tables/intext_stats_table.dta", replace

**********************************************************************************				                                                         *
* Descriptions of the data
**********************************************************************************

use data_winsorize, clear

* Total observations in the data
qui ivreghdfe d24_rate $control2 (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code week) 
count if e(sample)
post stats ("totobs") ("total obs in est sample") (`r(N)') (.) (.)

* Total counties in the data
preserve
collapse (mean) pm25, by(dsp_code)
count
post stats ("totcounties") ("total counties") (`r(N)') (.) (.)
restore

* On average across China, levels of PM25 have declined by XX% between 2013 and 2017
preserve
collapse (mean) pm25, by(week)
qui reg pm25 week 
predict pm25hat
gen out = ((pm25hat[_N]-pm25hat[1])/pm25hat[1])*100
qui summ out
post stats ("pct_chg_chn_pm25") ("pct change in CHN avg PM25") (`r(mean)') (.) (.)
restore

* average suicide rate across data
foreach V of varlist d24_rate fd24_rate md24_rate {
	qui summ `V'
	loc avg_`V' = `r(mean)'
	post stats ("avg_`V'") ("avg over sample") (`r(mean)') (`r(sd)') (.)
}


**********************************************************************************				                                                         *
* IV effect sizes
**********************************************************************************

* one microgram per cubic meter increase in PM casuses X increase in suicide rate with p value 
foreach V of varlist d24_rate fd24_rate md24_rate {
	qui ivreghdfe `V' $control2 (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code week) 
	local t = _b[pm25]/_se[pm25]
	local p =2*ttail(e(df_r),abs(`t'))
	post stats ("b_`V'") ("eff of 1 unit inc on sui rate") (_b[pm25]) (_se[pm25]) (`p')
}

* SD increase in PM25 causes an increase in weekly suicide rates of XX (p-value)
* use within-location SD 
loneway pm25 dsp_code
loc within_sd = r(sd_w)
	
foreach V of varlist d24_rate fd24_rate md24_rate {
	qui ivreghdfe `V' $control2 (pm25=TINumD1), absorb(dsp_code week) cluster(dsp_code week) 
	lincom _b[pm25]*`within_sd'
	post stats ("bSD_`V'") ("eff of 1SD inc on suirate") (r(estimate)) (r(se)) (r(p))
	
	* pct above average rate
	loc aspct = (r(estimate)/`avg_`V'')*100
	post stats ("bSD_`V'_aspct") ("eff of 1SD inc on sui rate as pct avg") (`aspct') (.) (.)
}

**********************************************************************************				                                                         *
* Simulation effect sizes
**********************************************************************************

use "$datadir/lives_saved.dta", clear

* overall, air quality improvements in China have avoided XX suicides and PM increases have caused YY suicides 
preserve
egen CHN_totlives_saved = sum(lives_saved) if lives_saved>0
qui summ CHN_totlives_saved
post stats ("tot_lives_saved_CHN") ("total lives saved in CHN") (r(mean)) (.) (.)
egen CHN_totlives_lost = sum(lives_saved) if lives_saved<0
qui summ CHN_totlives_lost
post stats ("tot_lives_lost_CHN") ("total lives lost in CHN") (r(mean)) (.) (.)
restore

* Binhai and Wuhou avoided XX suicides
preserve
egen binhai_totlives = sum(lives_saved) if dsp_code==120116
egen wuhou_totlives = sum(lives_saved) if dsp_code==510107
summ binhai_totlives
post stats ("tot_lives_saved_Binhai") ("total lives saved in Binhai") (r(mean)) (.) (.)
summ wuhou_totlives
post stats ("tot_lives_saved_Wuhou") ("total lives saved in Wuhou") (r(mean)) (.) (.)
restore

* XX counties experienced increased suicide deaths due to air quality declines. this is yy% of all counties in the data
preserve
collapse (sum) lives_saved, by(dsp_code)
count 
loc totcounties = r(N)
count if lives_saved>0 
loc totcounties_ls = r(N)
loc pctcounties_ls = (`totcounties_ls'/`totcounties')*100
post stats ("no_cnties_lives_saved") ("no cnties saving lives") (`totcounties_ls') (.) (.)
post stats ("pct_cnties_lives_saved") ("pct cnties saving lives") (`pctcounties_ls') (.) (.)


* XX% of china's average suicide rate decline is attribuatble to improvements in air quality 

postclose stats
