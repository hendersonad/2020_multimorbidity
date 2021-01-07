version 15
clear all
capture log close

* find path file location and run it
mm_extract paths

* create a filename global that can be used throughout the file
global filename "temp-create-dummy-files"

global dummyDataOut "J:\EHR-Working\Julian\2020_multimorbidity\"
cd ${MMpathIn}


#delimit ;
local filenames  
	Clinical_extract_ecz_extract3_1.dta
	Immunisation_extract_ecz_extract3_1.dta
	Referral_extract_ecz_extract3_1.dta
	Test_extract_ecz_extract3_1.dta	
	;
#delimit cr
display `"`filenames'"'
set seed 1010120412
foreach ii of local filenames {
	display `"`ii'"'
	use `"`ii'"' , clear
	sample 0.01
	count
	l in 1 
	egen patid2 = group(patid)
	gen patid3 = round(patid2*runiform(1,100),1)
	keep patid3 eventdate medcode
	rename patid3 dummy_patid
	save ${dummyDataOut}\`ii', replace
	export delim ${dummyDataOut}/`ii'_txt.txt, replace
}
