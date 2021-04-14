clear
adopath + C:\Users\lsh1510922\Documents\2020_multimorbidity
mm_extract paths

use "${pathOut}\expANDunexppool-main-multimorb-asthma-CCmatch_selected_matches.dta"

gen setid = caseid
gsort caseid  contid
egen tag = tag(caseid)
bysort tag: gen tagno = _n 
replace tagno = . if tag == 0
gsort -tag tagno

cap drop setno
bysort caseid: egen setno = min(tagno)
gsort caseid  contid

drop tag tagno setid

bysort setno: gen id = _n
count if setno==.  
count if id==.  


save "${pathOut}\asthma_PatidInfo.dta", replace

//merge on case info, keep setno but generate new id = max(_n)+1
rename caseid patid
collapse (mean) patid (max) id, by(setno)
replace id=id+1
merge 1:1 patid using "${pathOut}\expANDunexppool-main-multimorb-asthma-CCmatch_sorted.dta" ///
	, keep(3)
assert case==1
tab case
tab case _merge
keep setno id case pracid sex yeardob startdate enddate indexdate 
save "${pathOut}\asthma_PatidInfo_cases.dta", replace


//merge on control info 
use "${pathOut}\asthma_PatidInfo.dta", clear
rename contid patid
merge m:1 patid using "${pathOut}\expANDunexppool-main-multimorb-asthma-CCmatch_sorted.dta" ///
	, keep(3)
tab case _merge
assert case==0
keep setno id case pracid sex yeardob  startdate enddate indexdate 

append using "${pathOut}\asthma_PatidInfo_cases.dta"

export delim "${pathOut}\asthma_PatidInfo_full.csv", replace
