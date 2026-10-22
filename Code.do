clear all 
set more off 

cd "/Users/rebeccaspritzer/Desktop/Files"

use Projectv3.dta
br

*********************************** Data Setup ******************************************
*Calculate monthly volatility for WTI
	use "DCOILWTICO.dta", clear
	tsset observation_date, daily // set time as daily
		gen l_WTI = log(DCOILWTICO)
		gen d_lWTI = D.l_WTI // gen returns on oil prices

		gen mdate = mofd(observation_date) // define month
		format mdate %tm

		bysort mdate: egen stddev = sd(d_lWTI) // produce std. dev of returns
		gen WTI_Vol = stddev * sqrt(21) // avg US trading days in one month is 21. This gives a monthly vol.

	*drop irrelevant variables and adjust to time period
	keep mdate WTI_Vol
	duplicates drop	
	drop if mdate < tm(1990m1)
	drop if mdate > tm(2025m12)

	save WTI_Vol.dta, replace
	
*Calculate Monthly Prices for S&P500
	use "SP500_Daily_Data.dta", clear
	tsset Date, daily // set time as daily
	gen l_SP500 = log(IndexValue) // take logs of daily values
	
	gen mdate = mofd(Date) // define month
	format mdate %tm
	
	bysort mdate: egen SP500 = mean(l_SP500) // average of logged daily index value
	keep mdate SP500
	duplicates drop
	
	label variable SP500 "Monthly Average of Log(Daily Index Value)"
	save SP500_Monthly_Data.dta, replace
	
*Merge main dataset with WTI Vol & SP500
	use Projectv3, clear
	drop H
	drop if MONTH_YEAR == . // remove blanks

	*Data is for period from 1990 through 2025
	gen mdate = mofd(MONTH_YEAR)
	format mdate %tm
	tsset mdate, monthly // set time as monthly 

	merge 1:1 mdate using WTI_Vol // WTI volatility merge
	drop _merge
	
	merge 1:1 mdate using SP500_Monthly_Data
	drop _merge

*Adjust real price of oil data by US CPI
	*missing data for October 2025 CPI since US government shutdown so will linear interpolate that value first
	ipolate CPI mdate, gen(cpi_filled)
	replace CPI = cpi_filled if CPI == .
	drop cpi_filled
	
	*inflation adjustment
	replace RPO = (RPO / CPI) * 100

*markers for graphs
	local y1990 = tm(1990m1) 
	local y2000 = tm(2000m1)
	local y2010 = tm(2010m1)
	local y2020 = tm(2020m1)

*1. Stationarity Checks + Fixes
	*i. Price of Crude Oil (Real Price of Oil)
	tsline RPO if mdate >= tm(1990m1), ///
		xlabel(`y1990' `y2000' `y2010' `y2020', format(%tmCY)) ///
		xtitle("") ///
		ytitle("USD / Barrel") ///
		title("Real Price of Oil", size(medium)) ///
		lcolor(black) ///
		name(RPO, replace)

		corrgram RPO
		ac RPO, name(ac_RPO, replace)
		graph combine RPO ac_RPO, cols(2) name(comb_RPO, replace) // visual evidence that process is not stationary
		dfuller RPO // fail to reject the null ----> non-stationary
		dfgls RPO // fail to reject the null ----> non-stationary
		
		*Make WTI Price stationary by taking first difference
		gen l_RPO = log(RPO)
		gen d_lRPO = D.l_RPO
		dfuller d_lRPO // reject the null, process is stationary
		dfgls d_lRPO // reject the null, process is stationary
		
		tsline d_lRPO if mdate >= tm(1990m1), /// Graph of difference price
		xlabel(`y1990' `y2000' `y2010' `y2020', format(%tmCY)) ///
		xtitle("") ///
		ytitle("USD / Barrel") ///
		title("Difference of Log of Real Price of Oil", size(medium)) ///
		lcolor(black) ///
		name(d_lRPO, replace)
		
		graph combine RPO d_lRPO, /// combine graphs
		xsize(14) ysize(7) ///
		rows(1) ///
		iscale(*0.8) ///
		name(combined_RPO, replace)
		
	*ii. Stock Price Returns (SP500)
	tsline SP500 if mdate >= tm(1990m1), ///
		xlabel(`y1990' `y2000' `y2010' `y2020', format(%tmCY)) ///
		xtitle("") ///
		ytitle("USD") ///
		title("Monthly Average of Log(S&P 500 Index Value)", size(medium))  ///
		lcolor(black) ///
		name(SP500, replace)
		
		corrgram SP500
		ac SP500, name(ac_SP500, replace)
		graph combine SP500 ac_SP500, cols(2) name(comb_SP500, replace) // visual evidence that process is not stationary
		dfuller SP500 // fail to reject the null ----> non-stationary
		dfgls SP500 // fail to reject the null ----> non-stationary
		
		*Take returns of stock prices
		gen d_lSP500 = D.SP500 * 100
		dfuller d_lSP500  // reject the null, process is stationary
		dfgls d_lSP500 // lower lags reject the null, so evidence process is now stationary. Other literature uses SP500 as stationary variable
		
		tsline d_lSP500 if mdate >= tm(1990m1), /// graph of returns
		xlabel(`y1990' `y2000' `y2010' `y2020', format(%tmCY)) ///
		xtitle("") ///
		ytitle("") ///
		title("Returns of S&P500", size(medium)) ///
		lcolor(black) ///
		name(d_lSP500, replace)
		
		graph combine SP500 d_lSP500, ///
		xsize(14) ysize(7) ///
		rows(1) ///
		iscale(*0.8) ///
		name(combined_SP500, replace)
		
	*iii. REA
	tsline REA if mdate >= tm(1990m1), ///
		xlabel(`y1990' `y2000' `y2010' `y2020', format(%tmCY)) ///
		xtitle("") ///
		ytitle("% Dev. From Trend") ///
		title("Real Economic Activity", size(medium))  ///
		lcolor(black) ///
		name(REA, replace)
		
		graph export "REA.png", width(2000) replace // Figure 2 in paper
		
		corrgram REA
		ac REA, name(ac_REA, replace)
		graph combine REA ac_REA, cols(2) name(comb_REA, replace) // looks somewhat stationary
		dfuller REA // reject the null at 5% and 10% ---> stationary
		dfgls REA // lower lags are significant so reject the null. ADF and PP tests done on lines below for unit root test table show REA is stationary so that is what I will use in VAR. Also what is used in other papers as a stationary variable 
		
	*iv. GLOBAL_OIL_PROD
		tsline GLOBAL_OIL_PROD if mdate >= tm(1990m1), ///
		xlabel(`y1990' `y2000' `y2010' `y2020', format(%tmCY)) ///
		xtitle("") ///
		ytitle("Mb/d") ///
		title("Global Production: Crude Oil", size(medium))  ///
		lcolor(black) ///
		name(GLOBAL_OIL_PROD, replace)
		
		corrgram GLOBAL_OIL_PROD
		ac GLOBAL_OIL_PROD, name(ac_GLOBAL_OIL_PROD, replace)
		graph combine GLOBAL_OIL_PROD ac_GLOBAL_OIL_PROD, cols(2) name(comb_GLOBAL_OIL_PROD, replace) // visual evidence that process is not stationary
		dfuller GLOBAL_OIL_PROD // fail to reject the null ----> non-stationary
		dfgls GLOBAL_OIL_PROD // reject the null process is stationary. However Phillips Peron test finds non stationarity and literature uses oil production growth. therefore, will align with existing literature.
		
		*Take difference of logs for global production
		gen l_globalpro = log(GLOBAL_OIL_PROD)
		gen d_lglobalpro = D.l_globalpro * 100
		dfuller d_lglobalpro // reject the null, process is stationary
		dfgls d_lglobalpro // reject the null, process is stationary
		
		tsline d_lglobalpro if mdate >= tm(1990m1), /// graph percent change
		xlabel(`y1990' `y2000' `y2010' `y2020', format(%tmCY)) ///
		xtitle("") ///
		ytitle("") ///
		title("% Change of Global Production of Crude Oil", size(medium)) ///
		lcolor(black) ///
		name(d_lglobalpro, replace)
		
		graph combine GLOBAL_OIL_PROD d_lglobalpro, ///
		xsize(14) ysize(7) ///
		rows(1) ///
		iscale(*0.8) ///
		name(combined_GLOBAL_OIL_PROD, replace)
		
	*v. WTI_Vol
	tsline WTI_Vol if mdate >= tm(1990m1), ///
		xlabel(`y1990' `y2000' `y2010' `y2020', format(%tmCY)) ///
		xtitle("") ///
		ytitle("") ///
		title("Volatility of WTI Price", size(medium))  ///
		lcolor(black) ///
		name(WTI_Vol, replace)
		
		graph export "WTI_Vol.png", width(2000) replace // Figure 3 in paper
		
		corrgram WTI_Vol
		ac WTI_Vol, name(ac_WTI_Vol, replace)
		graph combine WTI_Vol ac_WTI_Vol, cols(2) name(comb_WTI_Vol, replace) // visual evidence that process is stationary
		dfuller WTI_Vol // reject the null ----> stationary
		dfgls WTI_Vol // reject the null --->stationary

	/* In summary, all variables are now stationary. 
	1. d_lSP500: monthly returns of the S&P 500 in percentage
	2. d_lRPO: first difference of real price of oil
	3. d_lglobalpro: percent change of global production of Crude Oil
	4. REA: real economic activity index
	5. WTI_Vol: monthly volatility of WTI
	*/ 
	
*label variables
label variable d_lRPO "Change in Real Oil Price"
label variable d_lSP500 "S&P 500 Returns (%)"
label variable REA "Global Economic Activity"
label variable d_lglobalpro "Growth in Global Oil Production (%)"
label variable WTI_Vol "Volatility of WTI Price"

save overall_clean_data.dta, replace

*3. Overall graph of variables for paper
graph combine combined_RPO combined_SP500 combined_GLOBAL_OIL_PROD, ///
	xsize(10) ysize(14) ///
	rows(4) ///
	name(combined_total, replace)
	
graph export "data_summary.png", width(2000) replace // Figure 1 in paper

*Table 1: Descriptive Statistics
	estpost summarize REA d_lglobalpro d_lRPO d_lSP500 WTI_Vol, detail

	esttab using summary_table.tex, replace ///
		cells("mean(fmt(3)) p50(fmt(3)) max(fmt(3)) min(fmt(3)) sd(fmt(3)) skewness(fmt(3)) kurtosis(fmt(3)) count(fmt(0))") ///
		label nonumber nomtitle booktabs ///
		coeflabels(d_rea "Diff. REA" ///
				   d_lglobalpro "% Change Global Production" ///
				   d_lRPO "Diff. Log(RPO)" ///
				   d_lSP500 "S&P500 Returns" ///
				   WTI_Vol "WTI Volatility") ///
		collabels("Mean" "Median" "Max" "Min" "Std. Dev." "Skewness" "Kurtosis" "N")
		
*Table 2: Unit Root Tests

capture matrix drop unit_results // setup matrix for results
eststo clear // clear any existing estimates

local pre REA SP500 RPO GLOBAL_OIL_PROD // pre adjusted variables
local post d_lglobalpro d_lRPO d_lSP500 WTI_Vol // post adjusted variables

*Loop to conduct unit root tests
foreach v in `pre' `post' {
    
    *ADF
    quietly dfuller `v', lags(1)
    local at = r(Zt)
    local ap = r(p)
    
    *PP
    quietly pperron `v'
    local pt = r(Zt)
    local pp = r(p)
    
    * Add row to matrix
    matrix row = (`at', `ap', `pt', `pp')
    matrix rownames row = "`v'"
    matrix unit_results = (nullmat(unit_results) \ row)
}

matrix colnames unit_results = "ADF (t)" "ADF (p)" "PP (t)" "PP (p)" // name columns
esttab matrix(unit_results, fmt(3)) using unitroot_matrix.tex, replace // export
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*
*********************************** Reduced Form VAR Model ******************************************
*Test for which lag length to use in VAR model
varsoc d_lglobalpro REA d_lRPO d_lSP500, maxlag(10) // Best fit is a lag length of one or five. Five minimises AIC.
matrix lag_results = r(stats) // put results of lag length test into matrix
matrix clean_stats = lag_results[1...., 1] , lag_results[1...., 7] , lag_results[1....,9] // only include columns with Lag, AIC, and BIC
matrix colnames clean_stats = "Lag" "AIC" "SBIC"

esttab matrix(clean_stats, fmt(3)) using lag_length.tex, replace /// export to tex file
    booktabs ///
    nonumber nomtitle

var d_lglobalpro REA d_lRPO d_lSP500, lags(1/5) // five lags
vargranger // granger causality test
matrix granger = r(gstats)
esttab matrix(granger, fmt(3)) using granger_results.tex, replace ///
booktabs ///
collabels("Equation" "Excluded" "chi2" "df" "Prob > chi2")

varlmar, mlag(5) // serial correlation
// no remaining autocorrelation at first 3 lags. although some autocorrelation detected at lag 4, earlier lags having none indicate the VAR captures the short run dynamics well.
matrix lm_test = r(lm)
esttab matrix(lm_test, fmt(3)) using lm_test.tex, replace ///
booktabs ///
collabels("Lag" "chi2" "df" "Prob > chi2")

varstable, graph // stability
// condition satisfied, VAR is stable
// add graph
graph export "varstable.png", width(2000) replace // Appendix A figure

varnorm // normality
// Reject the null that residuals are normally distributed. common for stock returns / oil prices and not required for VAR
matrix norm_test = r(jb)
esttab matrix(norm_test, fmt(3)) using norm_test.tex, replace ///
booktabs ///
collabels("Equation" "chi2" "df" "Prob > chi2")

*---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*
*********************************** Variance Decomposition - Overall Period ******************************************
clear
use overall_clean_data, clear
tsset mdate, monthly

var d_lglobalpro REA d_lRPO d_lSP500, lags(1/5)

*impulse response functions
irf set oilmodel, replace
irf create oilmodel, step(24) order(d_lglobalpro REA d_lRPO d_lSP500) replace
irf describe oilmodel

irf table fevd mse, impulse(d_lglobalpro REA d_lRPO d_lSP500) response(d_lSP500) noci // table 

// stock price response to oil production
irf graph irf, impulse(d_lglobalpro) response(d_lSP500) ///
yline(0) ///
ciopts(color(gs12%40)) ///
xlabel(0(4)24) ///
title("Response of Stock Returns to Global Oil Production Innovation") ///
ytitle("Percent") ///
xtitle("Months After Shock") ///
name(impulse_response_1, replace)

// stock price response to real economic activity
irf graph irf, impulse(REA) response(d_lSP500) ///
yline(0) ///
ciopts(color(gs12%40)) ///
xlabel(0(4)24) ///
title("Response of Stock Returns to Global Aggregate Demand Innovation") ///
ytitle("Percent") ///
xtitle("Months After Shock") ///
name(impulse_response_2, replace)

// stock price response to oil price changes
irf graph irf, impulse(d_lRPO) response(d_lSP500) ///
yline(0) ///
ciopts(color(gs12%40)) ///
xlabel(0(4)24) ///
title("Response of Stock Returns to Oil Price Innovation") ///
ytitle("Percent") ///
xtitle("Months After Shock") ///
name(impulse_response_3, replace)

// combine graphs for paper
graph combine impulse_response_1 impulse_response_2 impulse_response_3, ///
cols(3) ///
xsize(12) ysize(4) ///
name(irf_combined, replace)

graph export "impulse_response_overall.png", width(2000) replace

*********************************** Variance Decomposition - Volatility ******************************************
varsoc WTI_Vol d_lglobalpro d_lSP500 REA, maxlag(10) // still 5 lags even when using WTI_Vol
matrix lag_results = r(stats) // put results of lag length test into matrix
matrix clean_stats = lag_results[1...., 1] , lag_results[1...., 7] , lag_results[1....,9] // only include columns with Lag, AIC, and BIC
matrix colnames clean_stats = "Lag" "AIC" "SBIC"

esttab matrix(clean_stats, fmt(3)) using lag_length_vol.tex, replace /// export to tex file
    booktabs ///
    nonumber nomtitle

var REA d_lglobalpro WTI_Vol d_lSP500, lags(1/5) // five lags
vargranger // granger causality test
matrix granger = r(gstats)
esttab matrix(granger, fmt(3)) using granger_results_vol.tex, replace ///
booktabs ///
collabels("Equation" "Excluded" "chi2" "df" "Prob > chi2")

varlmar, mlag(5) // serial correlation
// no remaining autocorrelation at first 3 lags. although some autocorrelation detected at lag 4, earlier lags having none indicate the VAR captures the short run dynamics well.
matrix lm_test = r(lm)
esttab matrix(lm_test, fmt(3)) using lm_test_vol.tex, replace ///
booktabs ///
collabels("Lag" "chi2" "df" "Prob > chi2")

varstable, graph // stability
// condition satisfied, VAR is stable
// add graph
graph export "varstable_vol.png", width(2000) replace // Appendix A figure

varnorm // normality
// Reject the null that residuals are normally distributed. common for stock returns / oil prices and not required for VAR
matrix norm_test = r(jb)
esttab matrix(norm_test, fmt(3)) using norm_test_vol.tex, replace ///
booktabs ///
collabels("Equation" "chi2" "df" "Prob > chi2")

irf set volmodel.irf, replace
irf create volmodel, step(24) order(d_lglobalpro REA WTI_Vol d_lSP500) replace 

irf table fevd mse, impulse(d_lglobalpro REA WTI_Vol d_lSP500) response(d_lSP500) noci

// stock price response to oil price changes
irf graph irf, impulse(WTI_Vol) response(d_lSP500) ///
yline(0) ///
ciopts(color(gs12%40)) ///
xlabel(0(4)24) ///
title("Response of Stock Returns to Oil Volatility") ///
ytitle("Percent") ///
xtitle("Months After Shock") ///
name(impulse_response_vol, replace)

graph export "impulse_response_vol.png", width(2000) replace

*********************************** COVID-19 Considerations******************************************
use overall_clean_data, clear
tsset mdate, monthly

gen covid = 0 // gen variable to define COVID period
replace covid = 1 if mdate >= tm(2020m3) & mdate <= tm(2020m6)

label variable covid "COVID Demand Shock"

*Include COVID period as exogenous in VAR model
var d_lglobalpro REA d_lRPO d_lSP500, lags(1/5) exog(covid)

varstable, graph
graph export "varstable_covid.png", width(2000) replace // remains stable

*PRE-COVID VAR
var d_lglobalpro REA d_lRPO d_lSP500 if mdate < tm(2020m3), lags(1/5)

irf set precovid_irf, replace
irf create precovid_model, step(24) order(d_lglobalpro REA d_lRPO d_lSP500) replace

irf graph irf, impulse(REA) response(d_lSP500) /// graph pre-covid IRF for aggregate demand shocks
yline(0) ///
ciopts(color(gs12%40)) ///
xlabel(0(4)24) ///
title("Stock Return Response to Aggregate Demand Shock (Pre-COVID)") ///
ytitle("Percent") ///
xtitle("Months After Shock") ///
name(irf_precovid, replace)

irf graph irf, impulse(d_lglobalpro) response(d_lSP500) /// graph pre-covid IRF for supply shocks
yline(0) ///
ciopts(color(gs12%40)) ///
xlabel(0(4)24) ///
title("Stock Return Response to Supply Shock (Pre-COVID)") ///
ytitle("Percent") ///
xtitle("Months After Shock") ///
name(irf_precovid2, replace)

irf graph irf, impulse(d_lRPO) response(d_lSP500) /// graph pre-covid IRF for oil price shocks
yline(0) ///
ciopts(color(gs12%40)) ///
xlabel(0(4)24) ///
title("Stock Return Response to Oil Price Shock (Pre-COVID)") ///
ytitle("Percent") ///
xtitle("Months After Shock") ///
name(irf_precovid3, replace)

*POST-COVID VAR
var d_lglobalpro REA d_lRPO d_lSP500 if mdate >= tm(2020m3), lags(1/5)

irf set postcovid_irf, replace
irf create postcovid_model, step(24) order(d_lglobalpro REA d_lRPO d_lSP500) replace

irf graph irf, impulse(REA) response(d_lSP500) /// graph post-covid IRF for aggregate demand shocks
yline(0) ///
ciopts(color(gs12%40)) ///
xlabel(0(4)24) ///
title("Stock Return Response to Aggregate Demand Shock (Post-COVID)") ///
ytitle("Percent") ///
xtitle("Months After Shock") ///
name(irf_postcovid, replace)

irf graph irf, impulse(d_lglobalpro) response(d_lSP500) /// graph post-covid IRF for supply shocks
yline(0) ///
ciopts(color(gs12%40)) ///
xlabel(0(4)24) ///
title("Stock Return Response to Supply Shock (Post-COVID)") ///
ytitle("Percent") ///
xtitle("Months After Shock") ///
name(irf_postcovid2, replace)

irf graph irf, impulse(d_lRPO) response(d_lSP500) /// graph post-covid IRF for price shocks
yline(0) ///
ciopts(color(gs12%40)) ///
xlabel(0(4)24) ///
title("Stock Return Response to Oil Price Shock (Post-COVID)") ///
ytitle("Percent") ///
xtitle("Months After Shock") ///
name(irf_postcovid3, replace)

graph combine irf_precovid irf_postcovid, /// combine two periods
cols(2) ///
xsize(10) ysize(4) ///
name(irf_covid_comparison, replace)

graph export "irf_covid_comparison.png", width(2000) replace

graph combine irf_precovid2 irf_postcovid2, /// combine two periods
cols(2) ///
xsize(10) ysize(4) ///
name(irf_covid_comparison, replace)

graph export "irf_covid_comparison2.png", width(2000) replace

graph combine irf_precovid3 irf_postcovid3, /// combine two periods
cols(2) ///
xsize(10) ysize(4) ///
name(irf_covid_comparison, replace)

graph export "irf_covid_comparison3.png", width(2000) replace

*WTI VOL - switch model
*Include COVID period as exogenous in VAR model
var d_lglobalpro REA WTI_Vol d_lSP500 if mdate < tm(2020m3), lags(1/5)

irf set precovid_irf2, replace
irf create precovid_model2, step(24) order(d_lglobalpro REA WTI_Vol d_lSP500) replace

irf graph irf, impulse(WTI_Vol) response(d_lSP500) /// graph pre-covid IRF for WTI Vol
yline(0) ///
ciopts(color(gs12%40)) ///
xlabel(0(4)24) ///
title("Stock Return Response to WTI Volatility (Pre-COVID)") ///
ytitle("Percent") ///
xtitle("Months After Shock") ///
name(irf_precovid4, replace)

var d_lglobalpro REA WTI_Vol d_lSP500 if mdate >= tm(2020m3), lags(1/5)

irf set postcovid_irf2, replace
irf create postcov_model2, step(24) order(d_lglobalpro REA WTI_Vol d_lSP500) replace

irf graph irf, impulse(WTI_Vol) response(d_lSP500) /// graph post-covid IRF for WTI Vol
yline(0) ///
ciopts(color(gs12%40)) ///
xlabel(0(4)24) ///
title("Stock Return Response to WTI Volatility (Post-COVID)") ///
ytitle("Percent") ///
xtitle("Months After Shock") ///
name(irf_postcovid4, replace)

graph combine irf_precovid4 irf_postcovid4, /// combine two periods
cols(2) ///
xsize(10) ysize(4) ///
name(irf_covid_comparison4, replace)

