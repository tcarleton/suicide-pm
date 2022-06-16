
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
	global sterdir "$codedir/results/ster"
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


* On average across China, suicide rates have declined by XX% between 2013 and 2017
preserve
collapse (mean) d24_rate, by(week)
qui reg d24_rate week 
predict d24_rate_hat
gen out = ((d24_rate_hat[_N]-d24_rate_hat[1])/d24_rate_hat[1])*100
qui summ out
post stats ("pct_chg_chn_sui") ("pct change in CHN avg sui rate") (`r(mean)') (.) (.)
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
restore

**********************************************************************************				                                                         *
* Percent of China's decline in the suicide rate attributable to improvements in air quality
**********************************************************************************

* load estimating sample 
use data_winsorize, clear

* compute detrended pollution for all in sample locations 
egen uniqueccode = group(dsp_code)
qui summ uniqueccode 
gen pm25_detrended = .
gen pm25_trend = .
gen constant = .
forvalues i = `r(min)'/`r(max)' {
	qui summ pm25 if uniqueccode == `i'
	if `r(N)' != 0 {
		* starting week of sample for this county
		qui summ week if uniqueccode == `i'
		loc startwk = `r(min)'
		* generate detrended variable
		qui reg pm25 week if uniqueccode == `i'
		replace pm25_detrended = pm25 - _b[week]*(week-`startwk') if uniqueccode == `i' & week>= `startwk'
		replace pm25_trend = _b[week] if uniqueccode == `i' 
		replace constant = _b[_cons] if uniqueccode == `i' 
		di "Done with county # `i'"
			} 
		else {
			di "No PM observations to run trend estimation with"
			}
	}

* call estimates from main regression
estimates use "$sterdir/winsor_p98_d24_rate_TINumD1.ster"
estimates

* predicted suicide rate with actual PM25
predict yhat_actual 

* predicted suicide rate with detrended PM25
ren pm25 pm25_actual
ren pm25_detrended pm25
predict yhat_counterfactual

summ yhat_actual, detail
summ yhat_counterfactual, detail

* trend in predicted suicides under actual pm25
reg d24_rate week
loc beta_raw = _b[week]
reg yhat_actual week
loc beta_actual = _b[week]
reg yhat_counterfactual week
loc beta_counterfactual = _b[week]

* percent of trend due to pollution
loc pct_trend_pm = (`beta_actual'-`beta_counterfactual'/`beta_raw')*100
di `pct_trend_pm'

post stats ("pct_decline_pm") ("pct CHN sui decline due to pm25") (`pct_trend_pm') (.) (.)

**********************************************************************************				                                                         *
* Percent of global suicides that take place in China
**********************************************************************************

use "$datadir/who_suicide/suiciderate_adm0_2000_2019.dta", clear

// global average suicide rate = 9 per 100,000
loc globalsui2019 = 9*(7700000000)/100000

// china
summ suiciderate_tot if iso=="CHN" & year==2019
loc chinarate2019 = r(mean)
loc chinasui2019 = `chinarate2019'*(1398000000)/100000

// share
loc sharechina = `chinasui2019'/`globalsui2019'
di `sharechina'

post stats ("pct_global_sui_chn") ("pct of global suicides in china in 2019") (`sharechina') (.) (.)

**********************************************************************************				                                                         *
* Global average suicide stats
**********************************************************************************

use "$datadir/who_suicide/collapsed_suiciderate_adm0.dta", clear

* average rate in 2000 (per 1 million)
summ globalmn_suirate if year == 2000
loc globalsui2000 = r(mean)

* average rate in 2019
summ globalmn_suirate if year == 2019
loc globalsui2019 = r(mean)

post stats ("global_sui_rate_2000") ("global average suicide rate 2000") (`globalsui2000') (.) (.)
post stats ("global_sui_rate_2019") ("global average suicide rate 2019") (`globalsui2019') (.) (.)

postclose stats

* save csv
use "$resdir/tables/intext_stats_table.dta", clear
outsheet using "$resdir/tables/intext_stats_table.csv", comma replace
