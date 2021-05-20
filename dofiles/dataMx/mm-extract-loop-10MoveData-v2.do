* format the datafiles for stata code to run 
clear
adopath + C:/Users/lsh1510922/Documents/2020_multimorbidity
adopath + /Users/lsh1510922/Documents/Postdoc/2020_multimorbidity/
mm_extract , computer(mac)

global pathAnalysis "/Volumes/DATA/sec-file-b-volumea/EPH/EHR group/GPRD_GOLD/Ali/2020_multimorbidity/analysis"

local S = "asthma"

di  "`S'"
	// `study'_patient_info.csv
	use "${pathIn}/Patient_extract_mm_`S'_extract_matched_1.dta", clear
	export delim "${pathAnalysis}/`S'_patient_info.csv", replace
local S = "asthma"
	// `study'_case_control_sets.csv
	use "${pathOut}/expANDunexppool-main-multimorb-`S'-CCmatch_selected_matches.dta", clear
	export delim "${pathAnalysis}/`S'_case_control_set.csv", replace
	
	// `study'_read_chapter.csv -- TOO big, read in as .dta to R code instead
	//use "${pathIn}/`S'_READ.dta", clear
	//export delim "${pathAnalysis}/`S'_read_chapter.csv", replace
