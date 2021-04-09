

version 15
clear all
capture log close

* find path file location and run it
adopath + "J:\EHR-working\Ali\2020_multimorbidity"
mm_extract paths


global dataZdrive = "Z:\GPRD_GOLD\Ali\2020_multimorbidity\in"

cd ${dataZdrive}

filelist, dir(.) pattern("*.dta")

drop if regexm(filename, "matched")
l filename
save "${pathPostDofiles}\dataMx\myJdriveDTA.dta", replace

local obs = _N
di `obs'

forvalues i =1/`obs' {
	//di `i'
	use "${pathPostDofiles}\dataMx\myJdriveDTA.dta" in `i' , clear	
	local f = filename
	di "`f'"
	erase "`f'"
}
