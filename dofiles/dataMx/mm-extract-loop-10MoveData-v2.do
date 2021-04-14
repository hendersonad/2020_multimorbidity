* format the datafiles for stata code to run 
clear
adopath + C:/Users/lsh1510922/Documents/2020_multimorbidity
mm_extract paths
global pathAnalysis "Z:\GPRD_GOLD\Ali\2020_multimorbidity\analysis"

local S = "eczema"

di  "`S'"
	// `study'_patient_info.csv
	use "${pathIn}/Patient_extract_mm_`S'_extract_matched_1.dta", clear
	export delim "${pathAnalysis}/`S'_patient_info.csv", replace

	// `study'_case_control_sets.csv
	use "${pathOut}/expANDunexppool-main-multimorb-`S'-CCmatch_selected_matches.dta", clear
	export delim "${pathAnalysis}/`S'_case_control_set.csv", replace
	
	// `study'_read_chapter.csv
	use "${pathIn}/`S'_READ.dta", clear
	export delim "${pathAnalysis}/`S'_read_chapter.csv", replace
