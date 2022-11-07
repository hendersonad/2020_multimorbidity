program define rungprddefine

version 11

di "**"

qui {

*DEFINE
clear
clear matrix
cd "$gprdfiles"


*	TOTAL NUMBER PRACTICES
local practot = ${npractices$gprdbuild}

***********************************************************************************************
*CREATE LOG FILE
***********************************************************************************************
tempname myhandle
file open `myhandle' using Define_Summary_study_name_$studyname.txt, write replace
file write `myhandle' "************************************" _n "DEFINE SUMMARY: STUDY NAME $studyname, GPRD BUILD: $gprdbuild"  _n 
file write `myhandle' "************************************" _n _n
file write `myhandle' "Files created saved in $gprdfiles"_n _n

*Define menu
*Inclusion 1
file write `myhandle' _n "DEFINE CRITERIA" _n
file write `myhandle' _n "Inclusion 1" _n
file write `myhandle'  "Codelist location:  " "$inc1filenameORIGINAL" _n
file write `myhandle' "Files searched:  " "$inc1search"  _n
file write `myhandle' "Records in registration period:  " "$inc1inregperiod" _n
file write `myhandle'  "Patient has condition such that:  " "$inc1conditiontiming" _n
							
*Inclusion 2 (optional)
file write `myhandle' _n "Inclusion 2" _n
file write `myhandle'  "Codelist location:  " "$inc2filenameORIGINAL" _n
file write `myhandle' "Files searched:  " "$inc2search"  _n
file write `myhandle' "Records in registration period:  " "$inc2inregperiod" _n
file write `myhandle'  "Patient has condition such that:  " "$inc2conditiontiming" _n
file write `myhandle'  "Combine INC1 and INC2 with:  " "$inc2combine"  _n

*Date and gender restrictions (optional)
file write `myhandle' _n "Date and gender (optional search criteria)" _n
file write `myhandle'  "Study start date:  " "$studystartdate" _n
file write `myhandle'  "Study end date:  " "$studyenddate" _n
file write `myhandle'  "Genders included:  " "$gender" _n
file write `myhandle'  "Minimum age:  " "$minage" _n
file write `myhandle'  "Maximum age:  " "$maxage" _n
file write `myhandle'  "Months of prior registration:  " "$priorreg"  _n
file write `myhandle'  "Months of follow up:  " "$followup" _n
file write `myhandle'  _n _n "DEFINE SUMMARY" _n _n "Inclusion 1" _n

local timestart=c(current_time)

*APPLY INCLUSION CRITERIA 1 and 2:
forvalues inc_no=1/2 {
*SEARCH CODES IN CLINICAL, REFFERAL, TEST, IMMUNSATION FILES
tokenize "${inc`inc_no'search}"
if "`1'"!="" {
noi dib "Will be searching `1' `2' `3' `4' files for INC`inc_no'", stars
noi dib "(`practot' practices to search)"

if "`1'"=="therapy" local codevar "prodcode"
else local codevar "medcode"

*SEARCH FOR CODES IN SPECIFIED FILES
local timestart=c(current_time)

		forvalues filenumber=1/4 {
		if "``filenumber''"!="" {
		noi dib "Searching ``filenumber'' files for INC`inc_no'", stars
			foreach i of numlist 1/`practot' {
			noi di "`i' " _cont
			cap use "$path_STATA/``filenumber''`i'_reduced", clear
			if _rc!=0 & _rc!=601 exit _rc
			if _rc==0 {
			merge m:1 `codevar' using "${inc`inc_no'codelist}", keep(match) nogen
			if `i'==1 save "INC`inc_no'_``filenumber''_$studyname", replace
			if `i'>1 append using "INC`inc_no'_``filenumber''_$studyname"
			save "INC`inc_no'_``filenumber''_$studyname", replace
			} /*end of if _rc==0*/
			} /*end of practice loop*/
				file write `myhandle' "INC`inc_no'_``filenumber''_$studyname=" (_N) _n
			} /*end of if filenumber!="" */
			} /*end of loop around file types*/
			
			
noi di "Appending file types"
use "INC`inc_no'_`1'_$studyname", clear
if _rc!=0 & _rc!=601 exit _rc
di "append 	`1' `2' `3' `4' files"
cap append using "INC`inc_no'_`2'_$studyname"
if _rc!=0 & _rc!=601 exit _rc
cap append using "INC`inc_no'_`3'_$studyname"
if _rc!=0 & _rc!=601 exit _rc
cap append using "INC`inc_no'_`4'_$studyname"
if _rc!=0 & _rc!=601 exit _rc
save "INC`inc_no'_patients_$studyname", replace
			
file write `myhandle' "Total records found in searched files =" (_N) _n
nopeople patid
local total=r(N)
file write `myhandle' "Total number of people in searched files =" (`total') _n

gen pracid=mod(patid, 1000)

noi dib "Merging patient and practice information",stars
merge m:1 pracid using "$path_STATA/allpractices_$gprdbuild", keep(match) nogen keepusing(lcd uts)
merge m:1 patid using "$path_STATA/allpatients_$gprdbuild", keep(match) nogen keepusing(gender yob mob crd tod deathdate accept)
	
*Create Start/End date
gen startdate = max(crd, uts)
gen enddate = min(tod,lcd)
format startdate enddate %dD/N/CY

*CHECK MAX MEMORY USED
global memmax
qui memory
global memmax = ((r(width)+2*r(size_ptr))*_N)/10^6

noi dib "Applying date and gender criteria",stars
file write `myhandle' _n "INC`inc_no': Apply date and gender restrictions" _n

*PATIENT HAS CONDITION SUCH THAT
if "${inc`inc_no'conditiontiming}"=="anyinstudyperiod" {
di "${inc`inc_no'conditiontiming}"
di "$studystartdate"
drop if eventdate<d("$studystartdate") | eventdate>d("$studyenddate")
}
if "${inc`inc_no'conditiontiming}"=="anybeforestudyend" {
di "${inc`inc_no'conditiontiming}"
drop if eventdate>d("$studyenddate")
}
if "${inc`inc_no'conditiontiming}"=="firsteverinstudyperiod" {
di "${inc`inc_no'conditiontiming}"
collapse (min) eventdate, by (patid gender yob mob startdate enddate accept)
drop if eventdate<d("$studystartdate") | eventdate>d("$studyenddate")
}
nopeople patid
local total=r(N)
file write `myhandle' "Total number of people with condition ${inc`inc_no'conditiontiming}="(`total')  _n	
save "INC`inc_no'_patients_$studyname", replace	

*ARE RECORDS IN REGISTRATION PERIOD
if "${inc`inc_no'inregperiod}"=="yes" {
di "${inc`inc_no'inregperiod}"
	
*Drop where event occurs outside registration period
drop if  eventdate<start | eventdate>end
	
save "INC`inc_no'_patients_$studyname", replace	
nopeople patid
local total=r(N)
file write `myhandle' "Total number of people with record(s) within registration period="(`total')  _n	
}

*ARE PATIENTS ACCEPTABLE
drop if accept==0	
nopeople patid
local total=r(N)
file write `myhandle' "Total number of people who are acceptable="(`total')  _n	

************************	
*APPLY DATE AND GENDER RESTRICTIONS TO SELECTED RECORDS
	*GENDER
		*Drop genders not studied
		if "$gender"=="M" {
		keep if gender==1
		nopeople patid
local total=r(N)
		file write `myhandle'  "Total number of people meeting gender criterion=" (`total') _n
		}
		if "$gender"=="F" {
		keep if gender==2
		nopeople patid
local total=r(N)
		file write `myhandle' "Total number of people meeting gender criterion="(`total') _n
		}
		if "$gender"=="MF" {
		drop if gender==3
		nopeople patid
local total=r(N)
		file write `myhandle' "Total number of people meeting gender criterion=" (`total') _n
		}
		

*Generate index date	
rename eventdate indexdate

gen study_year=year(d("$studystartdate"))
gen age_studystart=study_year-yob

*gen event_year=year(indexdate)
gen index_year=year(indexdate)
gen age_indexdate=index_year-yob

	
	*AGE RESTRICTIONS
		tokenize $minage
		di "$minage"
		local age "`1'"
		*Drop if don't meet minimum age criteria
	
		if "`1'"!="" & "`2'"=="atstudystart" {
		di `age'
		drop if age_studystart<(`age')
		}
		if "`1'"!="" & "`2'"=="atindexdate" {
		di "$minage"
		drop if age_index<(`age')
		}
		
		tokenize $maxage
		local age "`1'"
		*Drop if exceed maximum age criteria
		if "`1'"!="" & "`2'"=="atstudystart" {
		di "$maxage"
		drop if age_studystart>(`age')
		}
		if "`1'"!="" & "`2'"=="atindexdate" {
		di "$maxage"
		drop if age_index>(`age')
		}
		nopeople patid
		local total=r(N)
		file write `myhandle' "Total number of people meeting age criterion=" (`total') _n
	
	*PRIOR REGISTRATION
		*Drop if don't have sufficient prior registration
		tokenize $priorreg
		local months "`1'"
		di `months'

		if "`1'"!="" & "`2'"=="atstudystart" {
		di "$priorreg"
		gen priorreg=(d("$studystartdate")-startdate)/(365/12)
		drop if priorreg<`months'
		}
		if "`1'"!="" & "`2'"=="atindexdate" {
		di "$priorreg"
		gen priorreg=(indexdate-startdate)/(365/12)
		drop if priorreg<`months'
		}
	
	*FOLLOW-UP
		*Drop if don't have sufficient follow up
		tokenize $followup
		local months "`1'"
		di `months'
		if "`1'"!="" & "`2'"=="atstudystart" {
		di "$followup"
		gen followup=(enddate-d("$studystartdate"))/(365/12)
		drop if followup<`months'
		}
		if "`1'"!="" & "`2'"=="atindexdate" {
		di "$followup"
		gen followup=(enddate-indexdate)/(365/12)
		drop if followup<`months'
		}
		nopeople patid
		local total=r(N)
		file write `myhandle' "Total number of people meeting prior registration / followup criterion=" (`total') _n


collapse (min) indexdate, by(patid)
qui sum patid
local total=r(N)
file write `myhandle' _n  "Final number of patients meeting inclusion criteria `inc_no'= " (`total')  _n	

save "INC`inc_no'_patients_$studyname", replace
}
}

*APPLY AND / OR CRITERIA	
if "$inc2combine"=="and" {
		di "$inc2combine"
		merge 1:1 patid using "INC1_patients_$studyname",  keep(match) nogen
		save "INC1&2_patients_$studyname", replace
		qui sum patid
		local total=r(N)
		file write `myhandle' _n   "INC1 AND INC2" _n "INC1&2_patients_$studyname="(`total')  _n	
		}
if "$inc2combine"=="or"{
		di "$inc2combine"
		append using "INC1_patients_$studyname"
		save "INC1or2_patients_$studyname", replace
		collapse (min) indexdate, by(patid)
		qui sum patid
		local total=r(N)
		file write `myhandle' _n "INC1 OR INC2"  _n "INC1or2_patients_$studyname=" (`total')  _n	
		}

file write `myhandle' _n _n _n "Final patient list in file results_$studyname=" (`total')  _n	
save "results_$studyname", replace

*Erase files not needed
cap erase "INC1_patients_$studyname.dta"
cap erase "INC2_patients_$studyname.dta"
cap erase "INC1_therapy_$studyname.dta"
cap erase "INC2_therapy_$studyname.dta"
cap erase "INC1_clinical_$studyname.dta"
cap erase "INC2_clinical_$studyname.dta"
cap erase "INC1_referral_$studyname.dta"
cap erase "INC2_referral_$studyname.dta"
cap erase "INC1_test_$studyname.dta"
cap erase "INC2_test_$studyname.dta"
cap erase "INC1_immunisation_$studyname.dta"
cap erase "INC2_immunisation_$studyname.dta"


local timeend=c(current_time)
file write `myhandle' _n "Time start= `timestart'" _n "Time end= `timeend'"
file write `myhandle' _n "Max memory used (MB) = $memmax"
noi di as txt `"(Results are in {browse "Define_Summary_study_name_$studyname.txt"})"'	

noi disp "Time start= `timestart'"
noi disp "Time end= `timeend'"
noi dib "Max memory used (MB) = $memmax"
}

file close `myhandle'

*AUDIT TRAIL:  save the define file within the audit folder
cap log close
local date:display %td_CCYY_NN_DD date(c(current_date), "DMY")
local time = subinstr(c(current_time), ":", "", 5)
qui file open file5 using "Define_Summary_study_name_$studyname.txt", read
/*log using "J:\EHR-Working\CPRDFaSTAudit\\`date'`time'_`c(username)'_define_$studyname", replace*/
log using "J:\EHR-Working\Helena\log\\`date'_`time'_`c(username)'_define_$studyname", replace
qui file read file5 line
qui while r(eof)==0 {
	noi display "`line'"
	file read file5 line
}
file close file5
log close

end


