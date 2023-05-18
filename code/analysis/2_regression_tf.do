

**********************************************************************************

* This script runs the main regression in Zhang et al., but with the Lee et al. 
* (2022) tF adjustments

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
	
**********************************************************************************
*						                                                         *
* IV: Main (tf)                         *
**********************************************************************************
loc pp = 98
use data_winsorize, clear

loc outfile = "$resdir/tables/table_iv_wp`pp'_tf.tex"

cap erase "$resdir/tables/table_iv_wp`pp'_tf.tex"
cap erase "$resdir/tables/table_iv_wp`pp'_tf.txt"

label var pm25 "PM2.5"

* for tf to work, need to hand create all FE
xi i.dsp_code
xi i.week, prefix(_W)
		
* tf model
loc outfilester "$resdir/ster/winsor_p`pp'_d24_rate_TINumD1_tf.ster"
tf d24_rate $control2 (pm25=TINumD1) _I* _W*, cluster(dsp_code week) 
  
* doesn't play nice with outreg2 // save a spreadsheet of results 
loc pp = 98
capture postutil clear
postfile tfmodel str30(modelrun) coef se_unadj lb_unadj ub_unadj Fstat se_tf lb_tf ub_tf using "$resdir/tables/table_vi_wp`pp'_tf", replace

post tfmodel ("tf_mainmodel") (`e(beta_hat)') (`e(unadj_se)') (`e(unadj_LB)') (`e(unadj_UB)')  (`e(F)') (`e(tF_se_beta_hat_05)') (`e(tF_LB_05)') (`e(tF_UB_05)')

postclose tfmodel
	
use "$resdir/tables/table_vi_wp98_tf.dta", clear

* save and write out results
outsheet using "$resdir/tables/table_vi_wp98_tf.csv", comma replace



  

