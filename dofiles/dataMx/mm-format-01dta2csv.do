

version 15
clear all
capture log close

* find path file location and run it
mm_extract paths


global dataJdrive = "J:\EHR-working\Ali\2020_multimorbidity\datafiles\"
local study = "eczema"

cd ${dataJdrive}
cd `study'
filelist, dir(.) pattern("*.dta")
l filename
save "${pathPostDofiles}\dataMx\myJdriveDTA.dta", replace

local obs = _N
di `obs'

forvalues i = 1/`obs' {
	//di `i'
	use "${pathPostDofiles}\dataMx\myJdriveDTA.dta" in `i' , clear	
	local f = filename
	di "`f'"
	use "`f'", clear 
	export delim "`f'.csv", replace
}
