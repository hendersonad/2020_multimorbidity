/*=========================================================================
DO FILE NAME:			prog_cleanPrescriptions

AUTHOR:					Kate Mansfield		
VERSION:				v2
DATE VERSION CREATED: 	v2 2018-Mar-13
						v1 2017-Aug-08

DATASETS USED: 	takes extracted prescription data from CPRD, that has had
				packtype and common dosages data merged in 
							
DESCRIPTION OF FILE:	
	Uses all available information to limit missing data in ndd and qty variables.
	
	Intention is to be able to use qty/ndd to calculate duration
	of prescription and therefore identify start and end dates >
	so aim of file is to use all data to ensure as little missing
	data in ndd and qty vars as possible.
	
	In subsequent files where ndd and qty are still missing I will use population
	median for duration of prescription.
	
MORE INFORMATION:
	SECTION A
		cleans ndd and qty vars as much as possible given available 
		info from free text for packtype_desc and free text field
			creates the following new vars:
					ndd_new
					qty_new
					asdir	// flags as directed prescriptions
					packtype_new
				
		NB: the text strings used here were collected from managing the
		data for a pilot analysis of a study from 2015 (aki1) and running this 
		once on the cases files for this analysis in early 2015.
		
	SECTION B
		If ndd or qty variables are missing or dodgy then use the
		numdays and dose_duration variables to update them if possible.
			numdays			// number of treatment days prescribed for a specific therapy event
			dose_duration	// the number of days the prescription is for 
	
	SECTION C
		Saves resulting file
				
EXAMPLE OF HOW TO USE:
		prog_cleanPrescriptions, prescriptionfile("${pathOut}/prescriptions-acearb-1") ///
			dofilename(haem-extract03-cleanPrescriptions) savefile("${pathOut}/prescriptions-clean-acearb-1")
	
*=========================================================================*/

/*******************************************************************************
#>> Define program
*******************************************************************************/
cap prog drop prog_cleanPrescriptions
program define prog_cleanPrescriptions

syntax, prescriptionfile(string) ///
	dofilename(string) savefile(string)
	
* prescriptionfile 	// path and file name containing prescription data
* dofilename		// name of do-file calling the program (to use to add notes to datasets created)
* savefile			// filename to save results







/*******************************************************************************
********************************************************************************
********************************************************************************
#SECTION A
	- clean ndd and qty variables
********************************************************************************
********************************************************************************
*******************************************************************************/	
* open file
use `prescriptionfile', clear




/*******************************************************************************
#A1. Generate dose variable (extracted from productname)
	- strength var also holds this but aim is to limit missing data
*******************************************************************************/	
gen firstnumpos=strpos(productname, "1") if strpos(productname, "1")>0
forvalues x=2/9 {
	replace firstnumpos=strpos(productname, "`x'") if ///
		strpos(productname, "`x'")<firstnumpos & strpos(productname, "`x'")>0
}

gen doseprodname = real(substr(productname, firstnumpos, 1))
forvalues i=2/10{
	replace doseprodname = real(substr(productname, firstnumpos, `i')) if ///
	real(substr(productname, firstnumpos, `i'))<.
}
drop firstnumpos
label var doseprodname "doseprodname: extracted from prodname var"





/*******************************************************************************
#A2. Create new qty and ndd vars to hold derived data (derived from packtype_desc and freetext)
	- data in qty and ndd vars are preserved 
	- will only use derived (new) vars if info in existing vars is missing
		or dodgy
*******************************************************************************/
gen qty_new=qty
recode qty_new 0=.  // there are some missing and some 0 values so make all 0 values==. (zero or missing==.)
label var qty_new "qty_new: derived from qty, updated using freetxt & packtype_desc"

gen ndd_new=ndd
recode ndd_new 0=. // again make all zero values missing
label var ndd_new "ndd_new: derived from ndd, updated using freetxt & packtype_desc"




/*******************************************************************************
#A3. Extract number of tablets from packtype_desc
	and save in packtype_new
*******************************************************************************/
gen firstnumpos=strpos(packtype_desc, "1") if strpos(packtype_desc, "1")>0
forvalues x=2/9 {
	replace firstnumpos=strpos(packtype_desc, "`x'") if ///
		strpos(packtype_desc, "`x'")<firstnumpos & strpos(packtype_desc, "`x'")>0
}

gen packtype_new = real(substr(packtype_desc, firstnumpos, 1))
forvalues i=2/10{
	replace packtype_new = real(substr(packtype_desc, firstnumpos, `i')) if ///
		real(substr(packtype_desc, firstnumpos, `i'))<.
}	
drop firstnumpos

* label new var
label var packtype_new "packtype_new: qty derived from packtype_desc"

* numerals in packtype descriptor will have wrongly altered packtype_new therefore set to missing
local packtypeMissing " "120 DOSE INHALE" "400GM" "1" "3" "1 DAILY" "
local packtypeMissing "`packtypeMissing' "1 THREE TIMES A" "1 EVERY DAY" "0" "
local packtypeMissing "`packtypeMissing' "1 MANE" "1 OD" "MLS X 2" "2BD" "1 AT NIGHT" "
local packtypeMissing "`packtypeMissing' "1-2 FOUR TIMES" "MLS X2" "TABLET(S) X 2" "4" "40 MG" "
local packtypeMissing "`packtypeMissing' "1 OM" "6M" "TAKE ONE 4 TIME" "PACK OF 0" "
local packtypeMissing "`packtypeMissing' "2 PUFFS WHEN RE" "INHALE 2 PUFFS" "ONE 5ML SPOONSF" "
local packtypeMissing "`packtypeMissing' "USE 1 DAILY WHE" "2AM, 1 DINNER" "2 PUFFS AS DIRE" "
local packtypeMissing "`packtypeMissing' "2 PFFS FOUR TIM" "FRUSEMIDE 40MG" "FUROSEMIDE 20" "1 TABLET ONCE A" "
local packtypeMissing "`packtypeMissing' "100 DOSE INHALE" "1" "X 2" "2" "
local packtypeMissing "`packtypeMissing' "5" "TAKE ONE AT NIG" ""  "1 EVERY DAY" "
local packtypeMissing "`packtypeMissing' "1 TWICE A DAY" "INHALE 2 DOSES" ""  "1 ON" "
local packtypeMissing "`packtypeMissing' "1 DAILY" "TAKE ONE 3 TIME" "1 OD"  "5ML EVERY NIGHT" "
local packtypeMissing "`packtypeMissing' "TABLET(S) X 2" "TABLET(S) X 4" "TABLET(S) X 3"  "X4" "
local packtypeMissing "`packtypeMissing' "PACK OF 0" "[3 MNTHS SUPPLY" "TABLET(S) X3"  "2.5" "LITRE 5MG/5ML L" "
local packtypeMissing "`packtypeMissing' "ONE 5ML SPOONSF" "3ML IMMEDIATELY" "2 TABLET(S) IN"  "1 EVERY DAY FOR" "
local packtypeMissing "`packtypeMissing' "TAVS 10MG" "TABLET(S) X5" "40MG LEFT KNEE"  "PACK OF 4 X 7" "
local packtypeMissing "`packtypeMissing' "ML     (4 MG /" "CAPSULES ( 1 TI" "20 MLS TWICE A"  "2  WHEN REQUIRE" "
local packtypeMissing "`packtypeMissing' "PRESC CHANGED 1" "1-2 TABS FOUR T" "75MGS DAILY"  "PACK OF 4X7" "
local packtypeMissing "`packtypeMissing' "1 EVERY DAY" "5ML" "1-2 FOUR TIMES" "2BD" "75MG TABS" "
local packtypeMissing "`packtypeMissing' "INHALE 2 PUFFS" "ONE 5ML SPOONSF" "TAB 1" "2 PFFS FOUR TIM" "
local packtypeMissing "`packtypeMissing' "1OD" "1 OM" "PACK OF 1 (11X2"  "ML 5MG/5ML LIQU" "
local packtypeMissing "`packtypeMissing' "TAKE ONE 4 TIME" "100MG TABLET(S)" "2 AT NIGHT"  "5ML UP TO TWICE" "
local packtypeMissing "`packtypeMissing' "CAPSULE(S) X 3P" "USE 3 TIMES/DAY" "OD28"  "1 OR 2 UP TO FO" "
local packtypeMissing "`packtypeMissing' "1 AT NIGHT FOR" "1 TABLET ONCE A" "3" "8 TO BE TAKEN O" "PACK OF 1OP" "
local packtypeMissing "`packtypeMissing' "2 AM, 1 DINNER" "1-2 FOUR TIMES" "120 DOSE NASAL" "
local packtypeMissing "`packtypeMissing' "3" "0.5ML AMPOULE(S" "5MG" "6" "12M" "SC  EVERY 12 WE" "
local packtypeMissing "`packtypeMissing' "120MG" "1 THREE TIMES A" "2 (OP)TPACK(S)" "2" "
local packtypeMissing "`packtypeMissing' "1 WEEKLY ON THE" "APPLY 1 EVERY 7" "2PUFFS TWICE A" "
local packtypeMissing "`packtypeMissing' "2 FOUR TIMES A" "2 TABLETS FOUR" "TABLET(S) X2" "
local packtypeMissing "`packtypeMissing' "2 NOCTE" "1 TWICE A DAY" "1 DROP QDS PRN" "1Y" "
local packtypeMissing "`packtypeMissing' "2.5 MG 4TABLET(" "2.5MG" "ONE DROP 4 TIME" ".5 OR 1 EVERY O" "
local packtypeMissing "`packtypeMissing' "5MG IN 5MLS LIQ" "10MLS EVERY NIG" "10ML TWICE DAIL" "
local packtypeMissing "`packtypeMissing' "2.5 MG 4TABLET(" "5ML IMMEDIATELY" "
local packtypeMissing "`packtypeMissing' "1 BD" "1TDS" "1 FOUR TIMES A" "1BD" "1MLS" "1 PRN" "1OM" "
local packtypeMissing "`packtypeMissing' "1 TWICE A DAY F" "1 DLY" "1ONPRN" "1-2 TABS TWICE" "
local packtypeMissing "`packtypeMissing' "1-2 EVERY DAY" "2 BD" "2 FOUR TIMES A" "2 DAILY" "
local packtypeMissing "`packtypeMissing' "TABLET(S) X2" "2 OP PACKS" "TAKE 2 4 TIMES/" "
local packtypeMissing "`packtypeMissing' "CAPSULE(S) X 3" "X3 TAB" "TABLET(S)3" "SUCK 4 TIMES/DA" "
local packtypeMissing "`packtypeMissing' "6" "10MG" "ML OF 10MG/5ML" "10ML TWICE A DA" "12M" "TABS 50MGM" "
foreach term1 in `packtypeMissing'{
	replace packtype_new=. if packtype_desc=="`term1'"
}

* numerals in packtype descriptor will have wrongly altered packtype_new
* therefore set to appropriate value
recode packtype_new 3=84 if packtype_desc=="3 X 28"
recode packtype_new .=28 if packtype_desc=="MONTH"
replace packtype_new=28 if packtype_desc=="1 PACK OF 28 (2" 
replace packtype_new=56 if packtype_desc=="2 * 28"
replace packtype_new=56 if packtype_desc=="2*28"
recode packtype_new 6=168 if packtype_desc=="6X28TABLET(S)"
recode packtype_new 2=80 if packtype_desc=="TABLET(S) (2X40"
recode packtype_new 2=30 if packtype_desc=="PACK OF 2X15"
recode packtype_new 6=168 if packtype_desc=="6X28TABLET(S)"
recode packtype_new 2=28 if packtype_desc=="PACK OF 2X14"
recode packtype_new 3=90 if packtype_desc=="TABLET(S) X 3MO"
recode packtype_new 1=100 if packtype_desc=="PACK OF 1O0"
recode packtype_new 2=1200 if packtype_desc=="2 BOTTLES 600ML"








/*******************************************************************************
#A4. Update ndd_new based on packtype description
*******************************************************************************/
* packtype descriptor suggests ndd should be 1
local ndd1 " "TAKE ONE AT NIG" "1 EVERY DAY" "ONE EVERY DAY" "
local ndd1 "`ndd1' "1 ON" "1 DAILY" "TAKE ONE DAILY"  "ONE EVERY NIGHT" "
local ndd1 "`ndd1' "TAKE ONE EACH M" "ONE AT NIGHT" "1 OD"  "TAKE ONE AS DIR" "
local ndd1 "`ndd1' "TAKE ONE TABLET" "ONE EVERY MORNI" "ONE DAILY"  "TAKE ONE ONCE D" "
local ndd1 "`ndd1' "1OD" "1 OM" "TAKE ONE A DAY"  "1 EVERY DAY FOR" "
local ndd1 "`ndd1' "ONE TABLET(S) E" "ONE EVERY DAY (" "ONE EACH EVENIN"  "1 AT NIGHT FOR" "
local ndd1 "`ndd1' "1 TABLET ONCE A" "1 MANE" "1 OD" "1 AT NIGHT" "
local ndd1 "`ndd1' "TAKE ONE DAILY" "TAKE ONE AS DIR" "ONE DAILY" "
local ndd1 "`ndd1' "1 EACH MORNING" "ONE 5ML SPOONSF" "ONE EVERY MORNI" "
local ndd1 "`ndd1' "ONE EVERY MORNI" "1 TABLET ONCE A" "1/2 TWICE A DAY" "
local ndd1 "`ndd1' "1 EVERY MORNING" "TAKE ONE CAPSUL" "TAKE ONE EVERY" "ONE TABLET DAIL" "
local ndd1 "`ndd1' "**TAKE ONE DAIL" "1 EVERY DAY (BE" "1 PRN" "
local ndd1 "`ndd1' "TAKE ONE EACH M" "1 NOCTE : QUANT" "1OM" "
local ndd1 "`ndd1' "ONE TABLET DAIL" "1 DLY" "	
foreach word1 in `ndd1'{
	recode ndd_new .=1 if packtype_desc=="`word1'"
}

* packtype descriptor suggests ndd should be 2
local ndd2 " "BD" "TWICE A DAY" "1 TWICE A DAY" "2 DAILY""
local ndd2 "`ndd2' "ONE TWICE A DAY" "APPLY TWICE DAI" "TAKE ONE TWICE"  "1 TABLET TWICE" "
local ndd2 "`ndd2' "TAKE TWO DAILY" "1 TABLET TWICE" "2 AT NIGHT"  "TWO DAILY OR AS" "
local ndd2 "`ndd2' "TAKE TWO AT NIGHT" "TWO EVERY NIGHT" "TAKE TWO NIGHTLY" "1 TWICE A DAY F" "
local ndd2 "`ndd2' "2 NOCTE" " ONE TABLET TWIC" "TWICE A DAY TO" "1 BD" "1BD" "
foreach word2 in `ndd2'{
	recode ndd_new .=2 if packtype_desc=="`word2'"
}

* packtype descriptor suggests ndd should be 3
local ndd3 " "THREE TIMES A D" "TAKE ONE 3 TIME" "ONE THREE TIMES" "
local ndd3 "`ndd3' "1 THREE TIMES A" "2AM, 1 DINNER" "1TDS" "1-2 TABS TWICE" "
local ndd3 "`ndd3' "USE 3 TIMES/DAY" "THREE AT NIGHT" "2 AM, 1 DINNER" "
foreach word3 in `ndd3'{
	recode ndd_new .=3 if packtype_desc=="`word3'"
}

* packtype descriptor suggests ndd should be 4
local ndd4 " "TAKE ONE 4 TIME" "2 BD" "TAKETWO TWICE A" "TAKETWO TWICE A" "2 BD" "
local ndd4 "`ndd4' "TAKE ONE 4 TIME" "1 FOUR TIMES A" "TWO TWICE A DAY" "SUCK 4 TIMES/DA" "
foreach word4 in `ndd4'{
	recode ndd_new .=4 if packtype_desc=="`word4'"
}

* other ndd's suggested by packtype descriptors
recode ndd_new .=0.75 if packtype_desc==".5 OR 1 EVERY O"
replace ndd_new=1.5 if packtype_desc=="1-2 EVERY DAY"
recode ndd_new .=5 if packtype_desc=="5ML EVERY NIGHT"
recode ndd_new .=6 if packtype_desc=="1-2 TABS FOUR T" | packtype_desc=="1-2 FOUR TIMES" | packtype_desc=="1-2 FOUR TIMES"
replace ndd_new=8 if packtype_desc=="2 FOUR TIMES A" | packtype_desc=="2 TABLETS FOUR" | packtype_desc=="TWO FOUR TIMES" | packtype_desc=="TAKE 2 4 TIMES/"
replace ndd_new=10 if packtype_desc=="10MLS EVERY NIG"
replace ndd_new=20 if packtype_desc=="10ML TWICE DAIL"







/*******************************************************************************
#A5. Update ndd_new based on free text
*******************************************************************************/
* free text suggests ndd is 1
* therefore replace ndd_new that are 0 with 1
local nddtext1 " "TAKE ONE IN THE EVENNG" "TAKE ONE CAPSULE A DAY TO LOWER BLOOD PRESSURE" "
local nddtext1 "`nddtext1' "TAKE ONE" "ONE DAAILY"  "1 ONE A DAY" "
local nddtext1 "`nddtext1' "ONE" "ONE IN AM" "1"  "1 EVE" "1 O.M." "1 TABLET AM" "
local nddtext1 "`nddtext1' "TAKE ONE IN AM" "TAKE ONE NIGHTLY" "
local nddtext1 "`nddtext1' "ONE DAILEY" "ONE AT NIGH" "1 EVENINGS"  "ONE AT BED TIME" "
local nddtext1 "`nddtext1' "IDAILY" "TAKE ONE EVENINGS" "0NE A DAY"  "1 DAI;Y" "1 DAILT" "
local nddtext1 "`nddtext1' "1 MNE" "TAKE ONE IN THE MORNINGS" "ONE NIGHTLY" "1 NIGHTLY" "1 IN AM" "
local nddtext1 "`nddtext1' "1 MAN" "ONE IN THE MORNIG" "ONE TABLET"  "1 EVERY" "1 MONE" "
local nddtext1 "`nddtext1' "ONE EVERY D" "TAKE ONE IN THE MORING" "1 MARNE"  "AM" "
local nddtext1 "`nddtext1' "TAKE ONE MORNINGS" "1 DAILLY" "
local nddtext1 "`nddtext1' "ONCE" "1MARNE" "1 OMM" "
local nddtext1 "`nddtext1' "ONE CAPSULE A DAY" "ONE ONE A DAY" "TAKE ONE TABLET" "IMANE"  "1 MORNE" "
local nddtext1 "`nddtext1' "1 AT BED TIME" "1 OB" "1 TAB" "
local nddtext1 "`nddtext1' "1 ODS" "1MONE" "1MNAE"  "1 DAILYY" "
local nddtext1 "`nddtext1' "1 TABLET(S)"  "1 NCTE" "
local nddtext1 "`nddtext1' "1ODE" "1 NOCE" "ONE TO BE TAKEN"  "ONE TABLET AM" "
local nddtext1 "`nddtext1' "MORNE" "1 IOD" "ONE TO BE T" "
local nddtext1 "`nddtext1' "1ID" "TAKE ONE BED TIME" "
local nddtext1 "`nddtext1' "TAKE ONE BEFORE BED" "1IM" "1MAN"  "
local nddtext1 "`nddtext1' "ONE EVERY N" "1 MID DAY" "TAKE ONE NOCHTE"  "HALF TWICE" "
local nddtext1 "`nddtext1' "1 TABLET" "ONCE NIGHTLY"  "ONE EVERY M" "
local nddtext1 "`nddtext1' "1 TABLET(S) AM" "1MNE" "MAN"  "
local nddtext1 "`nddtext1' "1DAILLY" "TAKE 1 TABLET" "ONE TABLET(S)" "1NO" "
local nddtext1 "`nddtext1'  "TAKE ONE AS BEFORE" "1 NCT"   "
local nddtext1 "`nddtext1' "1NOCE" "1 DILY" "TAKE 1 IN THE MORNINGS" "10D" "1 D" "
local nddtext1 "`nddtext1' "ONE DAILEY (WATER TABLET FOR FLUID RETENTION)" "TAKE 1" "IOM" "
local nddtext1 "`nddtext1' "TAKE ONE MID DAY" "#TAKE ONE EACH MORNI" "1OB" "ONE MID DAY" "
local nddtext1 "`nddtext1' "IOD" "1 TAB AM" "PM" "MNE" "1O" "ONE IN THE" "
local nddtext1 "`nddtext1' "1 DALIY" "1 AT 0800" "1EOD" "1NIGHTLY" "1 OS" "
local nddtext1 "`nddtext1' "10DS" "1 AT MID DAY" "1 EACH AM" "1 O"  "
local nddtext1 "`nddtext1' "1OS" "MARNE" "1MNAE" "ONE DAILLY" "
local nddtext1 "`nddtext1' "TAKE IN THE MORNINGS" "1NOCTE" "INOCTE" "DAILT" "
local nddtext1 "`nddtext1' "1 MNAE"  "TAKE ONE EACH AM" "TAKE ONE AT BED TIME" "NCTE" "1 NOTE" "
local nddtext1 "`nddtext1' "1 DAIY" "TAKE ONE TABLET ONE HOUR BEFORE NEEDED" "
local nddtext1 "`nddtext1' "1D"  "1 OPD" "10D"   "
local nddtext1 "`nddtext1' "AM" "##TAKE ONE EACH MORNING" "
local nddtext1 "`nddtext1' "##TAKE ONE EACH MORNI" "ONE TABLET" "1 MNE" "
local nddtext1 "`nddtext1' "1ID" "1 TABLET" "MARNE" "1 TAB" "
local nddtext1 "`nddtext1' "ONE TO BE T"  "TAKE ONE AT BED TIME" "1DS" "
local nddtext1 "`nddtext1' "TAKE ONE ONCE" "TAKE ONE TABLET" "
local nddtext1 "`nddtext1' "1 PD" "ID" "1 NOTE" "NCTE" "
local nddtext1 "`nddtext1' "1 DAI;Y" "1 MORNE"  "1PD" "
local nddtext1 "`nddtext1' "1 ID" "ONE EVERY D" "1 MARNE" "ONE CAPSULE A DAY" "1 EVERY MORNING AT 8AM" "
local nddtext1 "`nddtext1' "PM" "ONE IN AM" "1 D" "IOD" "1 TABLET AM" "
local nddtext1 "`nddtext1' "ONE TABLET AM" "1 AS BEFORE" "1 DO" "1 EACH MORING" "ONE ONE A DAY" "1 NCTE" "
local nddtext1 "`nddtext1' "1 NIGHTLY" "1 ONE A DAY" "ONE IN THE" "1DAILY" "ONE EVERY DAY A" "
local nddtext1 "`nddtext1' "TAKE ONE DAILY" "TAKE ONE EACH N" "1MAN" "ONE TO BE TAKEN" "1 ONCE" "
local nddtext1 "`nddtext1' "TAKE ONE MORNINGS" "TAKE ONE" "
local nddtext1 "`nddtext1' "1 DAIY" "
local nddtext1 "`nddtext1' "TAKE A DAY" "1 OID" "
local nddtext1 "`nddtext1' "1 OP" "
local nddtext1 "`nddtext1' "1ND" "OS" "TAKE ONE A.M." "DAILT" "
local nddtext1 "`nddtext1' "1MORNE" "TAKE 1 IN THE MORNINGS" "
local nddtext1 "`nddtext1' "ONE DAILYY" "1-D" "
local nddtext1 "`nddtext1' "1 CAP PRN"  "TAKE ONE IN THE MORNINGS FOR LOWERING BLOOD PRESSURE" "
local nddtext1 "`nddtext1' "TAKE ONE DAILEY" "2:00 AM" "TAKE ONE DAILEY" "
local nddtext1 "`nddtext1' "TAKE 1 IN THE MORNINGS" "TAKE ONE IN THE MORNINGS" "
local nddtext1 "`nddtext1' "1D" "1MAN" "1 MONE" "1 D" "1MAN" "1ODS" "10DPRN" "
local nddtext1 "`nddtext1' "ONE DAILEY (WATER TABLET FOR FLUID RETENTION)" "TAKE ONE AT 09.00" "
foreach a in `nddtext1'{
	recode ndd_new .=1 if text=="`a'"
}

* free text suggests ndd is 2 - therefore replace ndd that are 0 with 2
local nddtext2 " "TAKE TWO" "TWO" "TAKE TWO AS DIRECTED" "20M" "
local nddtext2 "`nddtext2' "TAKE ONE TWICE" "IBD" "TAKE TWO TABLETS"  "TAKE ONE TWICW A DAY" "
local nddtext2 "`nddtext2' "2 ONN" "TAKE TWO IN AM"  "ONE TWICE" "
local nddtext2 "`nddtext2' "2 IN AM" "1 DAILEY" "TWO IN AM"  "2MARNE" "10M 10N" "20N" "
local nddtext2 "`nddtext2' "1 TWICE" "2 EACH AM" "TAKE TWO EACH AM"  "
local nddtext2 "`nddtext2' "2 MNE" "2 MID DAY" "20M" "TAKE ONE TWIC A DAY" "
local nddtext2 "`nddtext2' "1 BS" "2 TABS" "TWICE" "TAKE ONE TWICW A DAY" "
local nddtext2 "`nddtext2' "TAKE ONE TWICW DAILY" "TAKE TWO" "BDAY" "
local nddtext2 "`nddtext2' "TAKE ONE TWIC A DAY" "IBD" "TAKE TWO DAILY" "TAKE ONE TWICE" "TWICE" "
local nddtext2 "`nddtext2' "2 TABS" "2 OP"  "
local nddtext2 "`nddtext2' "2 MARNE" "2 D" "2MAN" "20D" "2 MORNE" "2 MONE" "
local nddtext2 "`nddtext2' "TWO EVERY M" "TAKE 2" "2D" "TWO IN THE" "ONE TWICE A" "TAKE TWO IN THE MORNINGS" "
local nddtext2 "`nddtext2' "TAKE 2 IN THE MORNINGS" "20D" "TAKE TWO" "
local nddtext2 "`nddtext2' "TWO EVERY M" "TAKE 2" "2D" "TWO IN THE" "ONE TWICE A" "TAKE TWO IN THE MORNINGS" "
local nddtext2 "`nddtext2' "1 AT 08.00 1 AT 14.00" "
foreach b in `nddtext2'{
	recode ndd_new .=2 if text=="`b'"
}

* free text suggests ndd=3
local nddtext3 " "30D" "TAKE THREE" "TSD" "ONE THREE T" "20M 1ON" "
local nddtext3 "`nddtext3' "THREE" "ONE THREE A DAY" "TAKETHREEDAILY"  "1 TDDS" "
local nddtext3 "`nddtext3' "TAKE ONE THREE TIMES" "1TD" "1TDDS" "TAKE ONE THREE TIME A DAY" "
local nddtext3 "`nddtext3' "ONE THREE TIME A DAY" "1 THREE TIME A DAY" "1 TTDS" "
local nddtext3 "`nddtext3' "TAKE ONE THREE TIMES" "TAKE ONE THREE A DAY" "1 THREE A DAY" "
local nddtext3 "`nddtext3' "1 THREE TIMES" "ONE THREE TIMES" "ITDS" "TAKE ONE THREE TIME A DAY" "
local nddtext3 "`nddtext3' "ONE TO BE TAKEN THREE A DAY" "TOD" "1TDA" "
local nddtext3 "`nddtext3' "1 6-8 HOURLY" "
local nddtext3 "`nddtext3' "2MANEINOCTE" "THREE EVERY" "
foreach c in `nddtext3'{
	recode ndd_new .=3 if text=="`c'"
}

* text suggests ndd is 4
local nddtextFour " "40D" "112" "TAKE TWO TWICE" "
foreach d in `nddtextFour' {
	replace ndd_new=4 if text=="`d'"
}

* text suggests ndd is 5
local nddtextFive " "5MLS A DAY" "5ML A DAY" "
local nddtextFive "`nddtextFive' "ONE 5ML SPON" "5 ML" "50D" "5ML" "
local nddtextFive "`nddtextFive' "5MLS" "5 MLS A DAY" "5ML" "
foreach e in `nddtextFive' {
	replace ndd_new=5 if text=="`e'"
}

* free text suggests ndd=0.5
local nddtextHalf " "A HALF" "HALF" "TAKE ONE HALF A DAY" "0.50D" "
local nddtextHalf "`nddtextHalf' "TAKE HALF A TABLET" "TAKE ONE ALTERNATIVE DAYS" "
local nddtextHalf "`nddtextHalf' "HALF AS DIRECTED" "HALF A TABL" "HALF TABLET"  "HALF A TABLET" "
local nddtextHalf "`nddtextHalf' "1/2 TABLET" "HALF A TAB" "
local nddtextHalf "`nddtextHalf' "TAKE HALF A TABLET" "HALF TABLET(S)" " 
local nddtextHalf "`nddtextHalf' "ONE HALF A DAY" "1/2 TAB" "HALF TABLET" "HALF A TABLET" "ALTERNATIVE DAYS" "
local nddtextHalf "`nddtextHalf' "HALF A TAB" "
local nddtextHalf "`nddtextHalf' "0.5" "1 ALTERNATIVE DAYS" "
local nddtextHalf "`nddtextHalf' "TAKE ONE HALF" "	
foreach f in `nddtextHalf'{
	recode ndd_new .=0.5 if text=="`f'"
}

* free text suggests ndd=1.5
local nddtext1andHalf " "1 AND A HALF" "ONE OR TWO" "0.5" "
local nddtext1andHalf "`nddtext1andHalf' "ONE AND A H" "TAKE ONE AND A HALF" "ONE AND HALF" "1 AND HALF" "
local nddtext1andHalf "`nddtext1andHalf' "TAKE ONE AND A HALF" "1.5" "1-2 NCT" "
local nddtext1andHalf "`nddtext1andHalf' "TAKE TWO ONE DAY AND ONE THE NEXT" "	
foreach g in `nddtext1andHalf'{
	recode ndd_new .=1.5 if text=="`g'"
}

* text suggests ndd is 2.5
local nddtextTwoPtFive " "2.5 ML" "2.5MLS" "
foreach i in `nddtextTwoPtFive' {
	replace ndd_new=2.5 if text=="`i'"
}

* unable to assume any specific does if text is 'as directed' or 'prn' etc.
* flag as directed prescriptions so that can do sensitivity analysis if necessary
gen asdir=0
label var asdir "asdir: prescription text indicates prn prescription"

local nddtextASD " "AS DIRECTED" "TAKE AS DIRECTED" "USE AS DIRECTED" "ASD" "
local nddtextASD "`nddtextASD' "AS DIR" "AS SHOWN ON THE PACK" "AS PER PACK" "nddtextASD" "
local nddtextASD "`nddtextASD' "AS DIRECTED BY HOSPITAL" "AD" "AS DIRECTED BY LEAFLET IN PACKET" "
local nddtextASD "`nddtextASD' "AS DIRECTED BY CONSULTANT" "AS PER INSTRUCTIONS" "
local nddtextASD "`nddtextASD' "AS ADVISED" "DIRECTED" "TO BE TAKEN AS DIRECTED" "
local nddtextASD "`nddtextASD' "AS DIRECTED BY HOSP" "AS DIRECTED." "AS DITRECTED" "
local nddtextASD "`nddtextASD' "aS DIRECTED BY THE SPECIALIST" "TAKE AS SHOWN ON THE PACK" "
local nddtextASD "`nddtextASD' "AS ADVISED BY HOSPITAL" "AS DIRECTED BY HOSPITAL SPECIALIST" "
local nddtextASD "`nddtextASD' "TAKE AS INSTRUCTED" "TAKE" "WHEN REQUIRED" "PRN" "
local nddtextASD "`nddtextASD' "AS DIRECTED IN PACK" "1 ASD" "
local nddtextASD "`nddtextASD' "TAKE AS DIRECTED BY GP" "AS DIRECTED IN PACK" "1 ASD" "
local nddtextASD "`nddtextASD' "AS DIRECTED BY THE HOSPITAL" "nddtextASDECTED" "AS DIRC" "
local nddtextASD "`nddtextASD' "AS REQUIRED" "AS INSTRUCTED" "TAKE AS ADVISED" "
local nddtextASD "`nddtextASD' "AS DIRECTED" "TAKE AS DIRECTED BY HOSPITAL" "AS DIRECTED IN PACKET" "
local nddtextASD "`nddtextASD' "AS ADVICED" "TAKE ASD" "AS DIRETED" "
local nddtextASD "`nddtextASD' "TAKEAS DIRECTED" "'AS SHOWN ON THE PACK" "AS DIRECETD" "
local nddtextASD "`nddtextASD' "TAKE AS DIRECTED." "AS PX" "AS PRESCRIBED" "
local nddtextASD "`nddtextASD' "USE AS ADVISED" "AS PER INSTRUCTION" "TAKE MDS" "
local nddtextASD "`nddtextASD' "AS DIRECTED BY PACK" "TAKE AS DIRECTED BY YOUR DOCTOR" "
local nddtextASD "`nddtextASD' "AS DIR BY HOSP" "AS BEFORE" "AS PER HOSPITAL" "FOLLOW INSTRUCTIONS" "
local nddtextASD "`nddtextASD' "NORTH STAFFS URGENT CARE  DO NOT COPY RX" "AS DIRECTED ON THE PACK" "
local nddtextASD "`nddtextASD' "USE AS DIRECTED BY CONSULTANT" "AS ADV" "
local nddtextASD "`nddtextASD' "AS PER LEAFLET INSTRUCTIONS" "AS DIRECTED DIRECTED" "
local nddtextASD "`nddtextASD' "AS DIRECTED BY SPECIALIST" "USE AS DIRECTED." "
local nddtextASD "`nddtextASD' "AS/DIR" "AS DISCUSSED" "AS DIRECTION" "AS INDICATED" "1AS DIRECTED" "
local nddtextASD "`nddtextASD' "AS PER PACKET" "AS" "AS PER DIRECTIONS" "IN THE USUAL MANNER" "
local nddtextASD "`nddtextASD' "AS INSTRUCTED." "AS DIRECTED BY HOSPITAL CLINIC" "AS DIRECTED BY THE PACK" "
local nddtextASD "`nddtextASD' "AS NEEDED" "AS DIRECTED BY YOUR DOCTOR" "AD DIRECTED" "AS DIRECT" "
local nddtextASD "`nddtextASD' "AS DIRCTED" "AS AS DIRECTED" "A DAY" "AS DIRECTED BY RENAL UNIT" "
local nddtextASD "`nddtextASD' "AS RECOMMENDED" "USE UP TO DIRECTED" "TAKE AS DIRECTED BY DOCTOR" "
local nddtextASD "`nddtextASD' "AS DIRECTED BY HOSPITAL CONSULTANT" "USE AS NEEDED" "TAKE ONEAS DIRECTED" "
local nddtextASD "`nddtextASD' "USE AS PER INSTRUCTIONS" "ADS" "TAKE AS DIRECTED BY THE HOSPITAL" "
local nddtextASD "`nddtextASD' "AS DIRECTED ON PACKET" "ONE AS DIRECTED." "
local nddtextASD "`nddtextASD' "TAKE AS DIRECTED BY SPECIALIST" "USE ONE AS DIRECTED" "AS PER SCHEDULE" "
local nddtextASD "`nddtextASD' "AS PER HOSPITAL INSTRUCTIONS" "AS PER DRS INSTRUCTIONS" "
local nddtextASD "`nddtextASD' "USE AS INSTRUCTED" "AS IRECTED" "AS DIRECTED BY DOCTOR" "
local nddtextASD "`nddtextASD' "USE AS DIRECTED BY HOSPITAL" "AS DIRECTED BY MANUFACTURER" "
local nddtextASD "`nddtextASD' "AS PREVIOUSLY DIRECTED" "AS DIR BY HOSPITAL" "
local nddtextASD "`nddtextASD' "TAKE AS DIRECTED BY CONSULTANT" "AS DIRECTED AT HOSPITAL" "
local nddtextASD "`nddtextASD' "AS DIRECTED FOR DIABETES" "AS DRECTED" "USE AS DIRECETED" "AS IR" "
local nddtextASD "`nddtextASD' "AS DIRECTED BY HOSPTIAL" "UP TO DIRTECTED" "AS DIRCETED" "AS ADVISED." "
local nddtextASD "`nddtextASD' "AS ADVISED." "ASA DIRECTED" "AS DIRECTRED" "TAKE AS AGREED" "
local nddtextASD "`nddtextASD' "AS DIREECTED" "AS DIRECTED BY YOUR CONSULTANT" "
local nddtextASD "`nddtextASD' "AS DIRECTED BY DR" "WHEN REQUIRED FOR ANXIETY" "AS DIRECTED BY YOUR SPECIALIST" "
local nddtextASD "`nddtextASD' "TAKE AS NEEDED" "WHEN REQUIRED AS DIRECTED" "AS DIRECTED WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "AS DIRECTED FOR MIGRAINE" "TAKE ONE AS NEEDED FOR ANXIETY" "
local nddtextASD "`nddtextASD' "AS DIRECTED BY THE DOCTOR" "1 AS DIRECTED WHEN REQUIRED" "AS DIRECTED FOR MIGRAINE" "
local nddtextASD "`nddtextASD' "TAKE AS ADVISED BY HOSPITAL" "AS DIRECTED BY HOSPITAL" "AS DIRECTED BY PAEDIATRICIAN" "
local nddtextASD "`nddtextASD' "1 WHEN REQUIRED FOR MIGRAINE" "AS PER DOCTORS INSTRUCTION" "
local nddtextASD "`nddtextASD' "TAKE AS DIRECTED BY THE DOCTOR" "A DIR" "TAKE AS ADVICED" "AS DIREDTED" "
local nddtextASD "`nddtextASD' "AS DORECTED" "WHEN REQUIRED ONLY" "AS ADV." "AS ADVICED." "IMMEDIATELY WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "AS DIRECTED BY THE CONSULTANT" "AS DIRECTED BEFORE" "AS AGREED" "
local nddtextASD "`nddtextASD' "DOSE AS DIRECTED" "AS DIREC TED" "AS DIRETCED" "A DIRECTED" "DOSE AS DIRECTED BY HOSPITAL" "
local nddtextASD "`nddtextASD' "ASD WHEN REQUIRED" "USE WHEN REQUIRED AS DIRECTED" "AS DIRECTED BY HOSPITAL." "
local nddtextASD "`nddtextASD' "AS ADVISED BY THE HOSPITAL" "AS SHOWN ON THE PACK AS DIRECTED" "AS DIRECTED/TAKE AS NEEDED" "
local nddtextASD "`nddtextASD' "ASIDR" "A S DIRECTED" "USE AS REQD" "USE AS DIRECTED BY THE HOSPITAL" "
local nddtextASD "`nddtextASD' "WHEN REQUIRED" "TAKE AS DIRECTED" "USE AS DIRECTED" "FOR MIGRAINE" "ASDIRECTED" "
local nddtextASD "`nddtextASD' "AS ADVISED" "TAKE ONE WHEN REQUIRED" "10D" "TAKE WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "AS DIRECTED BY SPECIALIST" "AS DIRECTED (SLS)" "TAKE AS DIRECTED BY HOSPITAL" "
local nddtextASD "`nddtextASD' "AS DIRECTED BY THE HOSPITAL" "TAKE ASD" "AS DIRECTED." "
local nddtextASD "`nddtextASD' "1 PRN FOR ANXIETY" "USE ASD" "AS DIRECETED" "AS REQ" "AS INSTRUCTED" "
local nddtextASD "`nddtextASD' "1 ASD" "AS DIRECTED BY CONSULTANT" "ASD BY HOSPITAL" "
local nddtextASD "`nddtextASD' "TAKE AS DIR" "AS DIRECTED BY NEUROLOGIST" "DIR" "
local nddtextASD "`nddtextASD' "TO BE TAKEN AS DIRECTED" "AS DIRECTED BY HOSP" "AS DIRCTED" "
local nddtextASD "`nddtextASD' "TAKE AS REQUIRED" "AS ADVISED BY HOSPITAL" "AS ADVISED BY SPECIALIST" "
local nddtextASD "`nddtextASD' "1 AS DIRECTED FOR MIGRAINE" "1 AS REQ" "AS PER INSTRUCTIONS" "
local nddtextASD "`nddtextASD' "ONE WHEN REQUIRED SPARINGLY" "AS ADV" "AS PER HOSPITAL" "
local nddtextASD "`nddtextASD' "AS DIRECTED REDUCING DOSE" "REDUCING DOSE AS DIRECTED" "
local nddtextASD "`nddtextASD' "AS ADVICED" "AS PX" "AS DIRECTED FROM HOSPITAL" "ONE WHEN REQUIRED FOR ANXIETY" "
local nddtextASD "`nddtextASD' "AS DIRECT" "TAKE ONE WHEN NEEDED FOR ANXIETY" "USE AS REQUIRED" "
local nddtextASD "`nddtextASD' "TAKE ONE AS DIRECTED BY HOSPITAL" "AS PER HOSP" "AS REQUIRED." "
local nddtextASD "`nddtextASD' "TAKE AS DIRECTED BY YOUR DOCTOR" "PRN AS DIRECTED" "
local nddtextASD "`nddtextASD' "AS DIRECTED DIRECTED" "AS PER HOSPITAL INSTRUCTIONS" "ASDSIR" "
local nddtextASD "`nddtextASD' "TAKE ONE AS NEEDED FOR PANIC ATTACKS" "USE WHEN REQUIRED" "AS DIRECTED BY THE SPECIALIST" "
local nddtextASD "`nddtextASD' "ASD BY CONSULTANT" "AS" "TO BE USED WHEN REQUIRED" "AS DIRE" "
local nddtextASD "`nddtextASD' "OCCASIONAL USE" "AS INDICATED" "TAKEAS DIRECTED" "TAKE ONE IF REQUIRED" "
local nddtextASD "`nddtextASD' "REDUCING COURSE AS DIRECTED" "REDUCING" "WHEN NEEDED" "AS DIRESCTED" "
local nddtextASD "`nddtextASD' "AS DIRECTED BY GP" "TAKE ONE AS DIRECTED BY THE HOSPITAL" "TAKE WHEN NEEDED" "
local nddtextASD "`nddtextASD' "TAKE AS DIRECTED WHEN REQUIRED" "AS DIRECETD" "USE AS DIRECTED." "AS NEC" "
local nddtextASD "`nddtextASD' "TAKE ONE FOR MIGRAINE" "
local nddtextASD "`nddtextASD' "AS DIRECTED" "TAKE AS DIRECTED" "USE AS DIRECTED" "ASD" "
local nddtextASD "`nddtextASD' "AS DIR" "AS SHOWN ON THE PACK" "AS PER PACK" "ASDIR" "
local nddtextASD "`nddtextASD' "AS DIRECTED BY HOSPITAL" "AD" "AS DIRECTED BY LEAFLET IN PACKET" "
local nddtextASD "`nddtextASD' "AS DIRECTED BY CONSULTANT" "AS PER INSTRUCTIONS" "
local nddtextASD "`nddtextASD' "AS ADVISED" "DIRECTED" "TO BE TAKEN AS DIRECTED" "
local nddtextASD "`nddtextASD' "AS DIRECTED BY HOSP" "AS DIRECTED." "AS DITRECTED" "
local nddtextASD "`nddtextASD' "AS DIRECTED BY THE SPECIALIST" "TAKE AS SHOWN ON THE PACK" "
local nddtextASD "`nddtextASD' "AS ADVISED BY HOSPITAL" "AS DIRECTED BY HOSPITAL SPECIALIST" "
local nddtextASD "`nddtextASD' "TAKE AS INSTRUCTED" "TAKE" "WHEN REQUIRED" "PRN" "
local nddtextASD "`nddtextASD' "AS DIRECTED IN PACK" "1 ASD" "
local nddtextASD "`nddtextASD' "TAKE AS DIRECTED BY GP" "AS DIRECTED IN PACK" "1 ASD" "
local nddtextASD "`nddtextASD' "AS DIRECTED BY THE HOSPITAL" "ASDIRECTED" "AS DIRC" "
local nddtextASD "`nddtextASD' "AS REQUIRED" "AS INSTRUCTED" "TAKE AS ADVISED" "
local nddtextASD "`nddtextASD' "AS DIRECTED" "TAKE AS DIRECTED BY HOSPITAL" "AS DIRECTED IN PACKET" "
local nddtextASD "`nddtextASD' "AS ADVICED" "TAKE ASD" "AS DIRETED" "
local nddtextASD "`nddtextASD' "TAKEAS DIRECTED" "'AS SHOWN ON THE PACK" "AS DIRECETD" "
local nddtextASD "`nddtextASD' "TAKE AS DIRECTED." "AS PX" "AS PRESCRIBED" "
local nddtextASD "`nddtextASD' "USE AS ADVISED" "AS PER INSTRUCTION" "TAKE MDS" "
local nddtextASD "`nddtextASD' "AS DIRECTED BY PACK" "TAKE AS DIRECTED BY YOUR DOCTOR" "
local nddtextASD "`nddtextASD' "AS DIR BY HOSP" "AS BEFORE" "AS PER HOSPITAL" "FOLLOW INSTRUCTIONS" "
local nddtextASD "`nddtextASD' "NORTH STAFFS URGENT CARE  DO NOT COPY RX" "AS DIRECTED ON THE PACK" "
local nddtextASD "`nddtextASD' "USE AS DIRECTED BY CONSULTANT" "AS ADV" "
local nddtextASD "`nddtextASD' "AS PER LEAFLET INSTRUCTIONS" "AS DIRECTED DIRECTED" "
local nddtextASD "`nddtextASD' "AS DIRECTED BY SPECIALIST" "USE AS DIRECTED." "
local nddtextASD "`nddtextASD' "AS/DIR" "AS DISCUSSED" "AS DIRECTION" "AS INDICATED" "1AS DIRECTED" "
local nddtextASD "`nddtextASD' "AS PER PACKET" "AS" "AS PER DIRECTIONS" "IN THE USUAL MANNER" "
local nddtextASD "`nddtextASD' "AS INSTRUCTED." "AS DIRECTED BY HOSPITAL CLINIC" "AS DIRECTED BY THE PACK" "
local nddtextASD "`nddtextASD' "AS NEEDED" "AS DIRECTED BY YOUR DOCTOR" "AD DIRECTED" "AS DIRECT" "
local nddtextASD "`nddtextASD' "AS DIRCTED" "AS AS DIRECTED" "A DAY" "AS DIRECTED BY RENAL UNIT" "
local nddtextASD "`nddtextASD' "AS RECOMMENDED" "USE UP TO DIRECTED" "TAKE AS DIRECTED BY DOCTOR" "
local nddtextASD "`nddtextASD' "AS DIRECTED BY HOSPITAL CONSULTANT" "USE AS NEEDED" "TAKE ONEAS DIRECTED" "
local nddtextASD "`nddtextASD' "USE AS PER INSTRUCTIONS" "ADS" "TAKE AS DIRECTED BY THE HOSPITAL" "
local nddtextASD "`nddtextASD' "AS DIRECTED ON PACKET" "ONE AS DIRECTED." "
local nddtextASD "`nddtextASD' "TAKE AS DIRECTED BY SPECIALIST" "USE ONE AS DIRECTED" "AS PER SCHEDULE" "
local nddtextASD "`nddtextASD' "AS PER HOSPITAL INSTRUCTIONS" "AS PER DRS INSTRUCTIONS" "
local nddtextASD "`nddtextASD' "USE AS INSTRUCTED" "AS IRECTED" "AS DIRECTED BY DOCTOR" "
local nddtextASD "`nddtextASD' "USE AS DIRECTED BY HOSPITAL" "AS DIRECTED BY MANUFACTURER" "
local nddtextASD "`nddtextASD' "AS PREVIOUSLY DIRECTED" "AS DIR BY HOSPITAL" "
local nddtextASD "`nddtextASD' "TAKE AS DIRECTED BY CONSULTANT" "AS DIRECTED AT HOSPITAL" "
local nddtextASD "`nddtextASD' "AS DIRECTED FOR DIABETES" "AS DRECTED" "USE AS DIRECETED" "AS IR" "
local nddtextASD "`nddtextASD' "AS DIRECTED BY HOSPTIAL" "UP TO DIRTECTED" "AS DIRCETED" "AS ADVISED." "
local nddtextASD "`nddtextASD' "AS ADVISED." "ASA DIRECTED" "AS DIRECTRED" "TAKE AS AGREED" "
local nddtextASD "`nddtextASD' "AS DIREECTED" "AS DIRECTED BY YOUR CONSULTANT" "
local nddtextASD "`nddtextASD' "ASDIR" "DIRECTED" "PRN" "1 WHEN REQUIRED FOR ANXIETY" "AS NEEDED" "
local nddtextASD "`nddtextASD' "REDUCING DOSE" "TAKE MDU" "REDUCING COURSE" "REDUCE AS DIRECTED" "
local nddtextASD "`nddtextASD' "REDUCING AS DIRECTED" "IMMEDIATELY" "AS PER DOCTORS INSTRUCTION" "
local nddtextASD "`nddtextASD' "TAKE AS ADVICED" "AS DORECTED" "WHEN REQUIRED ONLY" "AS ADV." "
local nddtextASD "`nddtextASD' "SIG AS DIRECTED" "MFU" "AS PER CHART" "AS ADVICED" "USE AS DIR" "
local nddtextASD "`nddtextASD' "USE ONE AS REQUIRED" "AS DIRECTED BY THE CONSULTANT" "USE AS BEFORE" "
local nddtextASD "`nddtextASD' "USE ONE WHEN NEEDED" "AS DIRECTED BEFORE" "PDOC" "AS DIRECED""
local nddtextASD "`nddtextASD' "DOSE AS DIRECTED" "AS DIREC TED" "AS DIRETCED" "A DIRECTED"  "
local nddtextASD "`nddtextASD' "ASD WHEN REQUIRED" "AS DIECTED" "AS DIRECTED BY PHYSICIAN" "AS ADVISED BY THE HOSPITAL" "
local nddtextASD "`nddtextASD' "USE WHEN REQUIRED AS DIRECTED" "ONE  AS DIRECTED" "1ASDIR" "
local nddtextASD "`nddtextASD' "AS SHOWN ON THE PACK AS DIRECTED" "TAKE ONE TABLET ONE HOUR BEFORE NEEDED" "1SOS" "1 MD" "
local nddtextASD "`nddtextASD' "1 AS ADVISED" "ASIDR" "A S DIRECTED" "1ASD" "1 AT ONSET OF MIGRAINE" "USE AS REQD" "
local nddtextASD "`nddtextASD' "AS DIRECTED/TAKE AS NEEDED" "AS BEF" "MDU" "UT" "
local nddtextASD "`nddtextASD' "TAKE AS BEFORE" "AS DIRECTED BY HOSP." "APPLY AS NEEDED" "DISSOLVED UNDER THE TONGUE WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "TO BE USED AS DIRECTED" "UP TO DIRECTED" "AS DIRECTED BY ~~~" "AS DIREC" "ONE WHEN R" "
local nddtextASD "`nddtextASD' "AS PER WRITTEN INSTRUCTIONS" "AS NECESSARY" "AS DIRRECTED" "ASIR" "AS DIRECED" "
local nddtextASD "`nddtextASD' "AS PER INSTRUCTIONS FROM ~~~~~~~~~~~ DISTRICT HOSPITAL" "AS DIRECTED BY PSYCHIATRIST" "
local nddtextASD "`nddtextASD' "AS DIREC" "AS DIREC" "USE AS DIR." "AS D" "D" "USE  AS DIRECTED" "ONE WHEN R" "
local nddtextASD "`nddtextASD' "TAKE IN THE MORNINGS" "MORNE" "AS DIR." "
local nddtextASD "`nddtextASD' "AS DIR." "TAKE AS DIRECTED BY YOUR SPECIALIST" "1MDU" "
local nddtextASD "`nddtextASD' "ONE WHEN NECESSARY" "TAKE ONE OCCASIONALLY" "TAKE ONE HEN REQUIRED" "
local nddtextASD "`nddtextASD' "AS DIRECTED BY HOSPITAL DOCTOR" "1 ASDIR" "AS DIRECTED WHEN NECESSARY" "
local nddtextASD "`nddtextASD' "USE AS DIRECTED : QUANTITY: 50" "AS PER INSTRUCTED" "AD BY HOSPITAL" "
local nddtextASD "`nddtextASD' "AS AND WHEN REQUIRED" "1 MDS" "1OPD" "MDSS" "IF REQUIRED" "TAKE PRN" "	
local nddtextASD "`nddtextASD' "TAKE ONE AS DIRECTED" "ONE AS DIRECTED" "1 TAB AS DIRECTED"  "
local nddtextASD "`nddtextASD' "1 AS DIRECTED" "TAKE ONE AS DIRECTED." "ONE TABLET AS DIRECTED"  "
local nddtextASD "`nddtextASD' "1 AS DIR" "ONE TO BE TAKEN AS DIRECTED"  "1 TABLET AS DIRECTED" "
local nddtextASD "`nddtextASD' "ONE WHEN REQUIRED" "TAKE ONE ASD" "1 WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "TAKE ONE TABLET AS DIRECTED"  "1AS DIRECTED" "
local nddtextASD "`nddtextASD' "1 TAB AS DIRECTED BY THE DOCTOR" "
local nddtextASD "`nddtextASD' "TAKE ONE AS ADVISED" "1 TABLET(S) AS DIRECTED" "
local nddtextASD "`nddtextASD' "TAKE ONE AS NEEDED" "
local nddtextASD "`nddtextASD' "TAKE 1 AS DIRECTED" "ONE TABLET(S) AS DIRECTED" "
local nddtextASD "`nddtextASD' "1 AS DIRECTED BY HOSPITAL" "TAKE 1 TABLET(S) AS DIRECTED" " 
local nddtextASD "`nddtextASD' "1 WHEN REQUIRED AS DIRECTED" "  
local nddtextASD "`nddtextASD' "TAKE 1 TABLET AS DIRECTED." "1 PRN AS DIRECTED" "
local nddtextASD "`nddtextASD' "TAKE ONE AS REQUIRED" "TAKE ONE WHEN NEEDED" "1 AS NEEDED" "
local nddtextASD "`nddtextASD' "TAKE ONE AS DIRECTED BY HOSPITAL" "
local nddtextASD "`nddtextASD' "ONE AS REQUIRED" "ONE AS DIR" "
local nddtextASD "`nddtextASD' "ONE TO BE TAKEN AS REQUIRED" "ONE TABLET WHEN REQUIRED" "ONE AS NEEDED" "
local nddtextASD "`nddtextASD' "TAKE ONE MDU" "TAKE ONE AS DIRECTED BY THE HOSPITAL" "1 WHEN NECESSARY" "
local nddtextASD "`nddtextASD' "1 TABLET AS REQUIRED" "ONE AS DIRECTED WHEN REQUIRED" "ONE WHEN NEEDED" "
local nddtextASD "`nddtextASD' "1 TO BE TAKEN WHEN REQUIRED"  "ONE PRN" "
local nddtextASD "`nddtextASD' "TAKE ONE WHEN REQUIRED AS DIRECTED" "1 TABLET WHEN REQUIRED" "TAKE ONE IF REQUIRED" "
local nddtextASD "`nddtextASD' "1 SPARINGLY AS DIRECTED" "1 AS REQUIRED" "
local nddtextASD "`nddtextASD' "ONE WHEN REQUIRED AS DIRECTED" "1 TABLET(S) WHEN REQUIRED" "1 TABLET(S) AS REQUIRED" "
local nddtextASD "`nddtextASD' "TAKE 1 WHEN REQUIRED" "TAKE 1 PRN" "
local nddtextASD "`nddtextASD' "INSERT 1 DOSE AS DIRECTED" "TAKE ONE AS NECESSARY" "1 MDU" "
local nddtextASD "`nddtextASD' "TAKE ONE TABLET WHEN REQUIRED" "1 WHEN REQUIRED ONLY" "TAKE ONE ONLY IF NEEDED" "
local nddtextASD "`nddtextASD' "1 WHEN NEEDED" "TAKE ONE IF NEEDED" "TAKE ONE AS AGREED" "
local nddtextASD "`nddtextASD' "TAKE ONE AS DIRECTED WHEN REQUIRED" "1 WHEN REQUIRED SPARINGLY" "TAKE ONEPRN" "
local nddtextASD "`nddtextASD' "1 AS NECESSARY" "ONE AS REQ" "TAKE ONE AS DISCUSSED" "
local nddtextASD "`nddtextASD' "TAKE ONE WHEN NECESSARY" "1 PRN" "TAKE ONE PRN" "1PRN" "
local nddtextASD "`nddtextASD' "1 TAB PRN" "TAKE ONE WHEN REQUIRED" "1 AS DIRECTED." "1 AS SHOWN ON THE PACK" "
local nddtextASD "`nddtextASD' "TAKE ONE TABLET(S) AS DIRECTED" "
local nddtextASD "`nddtextASD' "1 OCCASIONALLY" "ONE TABLET AS REQUIRED" "
local nddtextASD "`nddtextASD' "ONE IF REQUIRED" "ONE OR WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "1 TO BE TAKEN AS DIRECTED" "1 AS DISCUSSED" "TAKE ONE DIRECTED" "
local nddtextASD "`nddtextASD' "1 TAB AS REQUIRED" "I AS DIRECTED" "1 TAB WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "ONE TO BE TAKEN IF REQUIRED" "TAKE ONE AS ADVICED" "
local nddtextASD "`nddtextASD' "ONE TABLET AS REQUIRED" " 
local nddtextASD "`nddtextASD' "USE ONE AS REQUIRED" "TAKE 1 WHEN NEEDED" "TAKE 1 AS NEEDED" "
local nddtextASD "`nddtextASD' "ONE TO BE TAKEN WHEN REQUIRED" "ONE IF NEEDED" "
local nddtextASD "`nddtextASD' "USE ONE WHEN NEEDED" "TAKE WHEN REQUIRED" "1 TD WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "ONE  AS DIRECTED" "1ASDIR" "1 AS ADVISED" "1ASD" "1 AT ONSET MIGRAINE" "
local nddtextASD "`nddtextASD' "ONE AS DIRECTED" "1 WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "A HALF OR ONE AS DIRECTED" "TAKE ONE WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "ONE WHEN REQUIRED." "1 TABLET WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "1 WHEN REQUIRED AS DIRECTED" "ONE TO BE TAKEN AS DIRECTED" "
local nddtextASD "`nddtextASD' "ONE AS NEEDED" "TAKE ONE PRN" "
local nddtextASD "`nddtextASD' "1 AS NEEDED" "1PRN" "TAKE 1 AS DIRECTED" "TAKE ONEPRN" "
local nddtextASD "`nddtextASD' "TAKE ONE TABLET AS REQUIRED" "1 AS NECESSARY" "
local nddtextASD "`nddtextASD' "1 AS DIR" "ONE AS DIRECTED WHEN REQUIRED" "ONE TABLET(S) WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "TAKE ONE TABLET WHEN REQUIRED" "TAKE ONE AS NECESSARY" "TAKE ONE TABLET AS DIRECTED" "
local nddtextASD "`nddtextASD' "TAKE ONE WHEN NEEDED" "1 TABLET(S) WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "TAKE ONE WHEN REQUIRED AS DIRECTED" "TAKE ONE IF NEEDED" "
local nddtextASD "`nddtextASD' "ONE TABLET WHEN REQUIRED" "TAKE ONE AS AGREED" "TAKE ONE AS DIR" "
local nddtextASD "`nddtextASD' "TAKE ONE TABLET(S) WHEN REQUIRED" "ONE TO BE TAKEN IF REQUIRED." "
local nddtextASD "`nddtextASD' "ONE TO BE TAKEN AS REQUIRED" "TAKE ONE AS ADVISED" "
local nddtextASD "`nddtextASD' "1 TABLET(S) AS DIRECTED" "TAKE ONE ONCE DAILY WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "ONE WHEN NEEDED" "1 TAKE AS NEEDED" "TAKE 1 PRN" "
local nddtextASD "`nddtextASD' "TAKE ONE AS DIRECTED WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "1 WHEN NECESSARY" "TAKE 1 AS REQUIRED" "1 WHEN REQUIRED." "
local nddtextASD "`nddtextASD' "TAKE ONEAS DIRECTED" "ONE TABLET(S) AS DIRECTED" "TAKE ONE EACH DAY WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "TAKE ONE WHEN REQUIRED." "ONE AS REQ" "
local nddtextASD "`nddtextASD' "TAKE ONE AS DIRECTED." "ONE CAPSULE WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "TAKE ONE WHEN NECESSARY" "TAKE ONE OR TWO WHEN NEEDED" "1 AS REQD" "
local nddtextASD "`nddtextASD' "ONE AS NECESSARY" "1 TAB PRN" "TAKE ONE TABLET(S) AS DIRECTED" "
local nddtextASD "`nddtextASD' "1 TAB AS DIR" "1 TAB WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "TAKE ONE AS NEEDED" "1 AS DIRECTED" "
local nddtextASD "`nddtextASD' "ONE AS REQUIRED" "TAKE ONE WHEN REQUIRED""
local nddtextASD "`nddtextASD' "ONE TO BE TAKEN IF REQUIRED" "TAKE ONE AS ADVICED" "
local nddtextASD "`nddtextASD' "ONE OR WHEN REQUIRED" "TAKE 1 WHEN NEEDED" "
local nddtextASD "`nddtextASD' "ONE TO BE TAKEN WHEN REQUIRED" "ONE IF NEEDED" "
local nddtextASD "`nddtextASD' "TAKE ONE AS INSTRUCTED" "1 CAP AS REQUIRED" "
local nddtextASD "`nddtextASD' "ONE WHEN REQUIRED DISSOLBED UNDER THE TONGUE" "
local nddtextASD "`nddtextASD' "TAKE ONE AS DIRECTED DISSOLVED UNDER THE TONGUE" "
local nddtextASD "`nddtextASD' "ONE DISSOLVED UNDER THE TONGUE WHEN REQUIRED" "**TAKE ONE AS DIRECTED**" "
local nddtextASD "`nddtextASD' "TAKE ONE DISSOLVED UNDER THE TONGUE WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "1 SUBLINGUALLY WHEN REQUIRED" "TAKE ONE ASDIR" "
local nddtextASD "`nddtextASD' "1 WHEN REQUIRED DISSOLVED UNDER THE TONGUE" "
local nddtextASD "`nddtextASD' "1 AS INSTRUCTED" "TAKE ONE DISSOLVED UNDER THE TONGUE AS DIRECTED" "
local nddtextASD "`nddtextASD' "TAKE ONE AS DIRECTED DISSOLVED UNDER THE TONGUE" "
local nddtextASD "`nddtextASD' "ONE WHEN REQUIRED" "TAKE ONE WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "TAKE 1 TABLET AS DIRECTED" "TAKE ONE AS DIRECTED" "
local nddtextASD "`nddtextASD' "TWO AS DIRECTED" "2 AS DIRECTED" "TWO TO BE TAKEN AS REQUIRED" "
local nddtextASD "`nddtextASD' "TAKE TWO WHEN REQUIRED" "2 TABS WHEN REQUIRED" "2 PRN" "
local nddtextASD "`nddtextASD' "TAKE 2 TABS WHEN REQUIRED" "2PRN" "
local nddtextASD "`nddtextASD' "TAKE 2 AS DIRECTED" "TWO WHEN NEEDED" "UP TO TWO WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "TAKE 2 TABLETS AS DIRECTED" "TAKETWO AS DIRECTED" "
local nddtextASD "`nddtextASD' "2 TABLET WHEN REQUIRED" "TWO TO BE TAKEN AS REQUIRED" "
local nddtextASD "`nddtextASD' "TWO AS NEEDED" "2 WHEN REQUIRED." "1-3 WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "TAKE 2 WHEN REQUIRED" "2 WHEN REQUIRED" "TWO AS DIRECTED" "
local nddtextASD "`nddtextASD' "TAKE TWO TABLETS WHEN REQUIRED" "TAKE TWO AS REQUIRED"  "
local nddtextASD "`nddtextASD' "TAKE TWO AS NEEDED" "TAKE TWO PRN" "TWO AS DIRECTED WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "TAKE TWO WHEN NEEDED" "TWO TABLETS WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "2 WHEN NEEDED" "TWO AS REQUIRED" "2 TABLETS WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "TWO TABLET(S) WHEN REQUIRED" "2 TABLETS AS DIRECTED" "
local nddtextASD "`nddtextASD' "TAKE 2 AS NEEDED" "2 AS NEEDED" "
local nddtextASD "`nddtextASD' "2 AS REQUIRED" "2 TABLETS AS REQUIRED" "TWO WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "TAKE 2 TABS WHEN REQUIRED" "2PRN" "TWO WHEN NEEDED" "
local nddtextASD "`nddtextASD' "UP TO TWO WHEN REQUIRED" "USE 2 TABLETS AS DIRECTED" "
local nddtextASD "`nddtextASD' "TAKETWO AS DIRECTED" "TWO AS NEEDED" "2 TABLET WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "TWO TO BE TAKEN AS REQUIRED" "
local nddtextASD "`nddtextASD' "2 WHEN REQUIRED" "2 AS REQ" "TWO TO BE TAKEN AS DIRECTED" "
local nddtextASD "`nddtextASD' "2-4 WHEN REQUIRED" "THREE WHEN REQUIRED" "THREE AS DIRECTED" "
local nddtextASD "`nddtextASD' "TAKE 3 AS DIRECTED" "
local nddtextASD "`nddtextASD' "SIX HOUR WHEN REQUIRED" "ONE QDS PRN" "TAKE 4 AS DIRECTED" "
local nddtextASD "`nddtextASD' "5 MLS WHEN REQUIRED" "5ML WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "5MLS AS DIRECTED" "5 ML WHEN REQUIRED" "FIVE AS DIRECTED" "
local nddtextASD "`nddtextASD' "HALF AS DIR" "HALF TABLET(S) AS DIRECTED" "
local nddtextASD "`nddtextASD' "HALF TABLET AS DIRECTED" "A HALF AS DIRECTED" "TAKE HALF AS DIRECTED" "
local nddtextASD "`nddtextASD' "HALF A TABLET AS REQUIRED" "TAKE HALF A TABLET AS DIRECTED" "
local nddtextASD "`nddtextASD' "1/2 TABLET(S) WHEN REQUIRED" "HALF TABLET WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "TAKE HALF TABLET AS NEEDED" "HALF A TABLET AS DIRECTED" "
local nddtextASD "`nddtextASD' "HALF A TABLET(S) WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "HALF AS NEEDED" "1-2 AS REQUIRED" "TAKE ONE OR TWO AS REQUIRED" "
local nddtextASD "`nddtextASD' "TAKE 1-2 WHEN REQUIRED" "TAKE ONE OR TWO WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "1-2 AS NEEDED" "ONE OR TWO" "1-2 AS DIRECTED" "
local nddtextASD "`nddtextASD' "TAKE ONE OR TWO AS DIRECTED" "HALF TABLET(S) WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "HALF AS DIRECTED" "TAKE HALF WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "TAKE HALF AS DIRECTED" "HALF A TABLET WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "HALF WHEN REQUIRED" "TAKE HALF A TABLET WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "TAKE HALF A TABLET AS NEEDED" "HALF A TABLET AS DIRECTED" "
local nddtextASD "`nddtextASD' "HALF A TABLET(S) WHEN REQUIRED" "HALF AS NEEDED" "
local nddtextASD "`nddtextASD' "A HALF WHEN REQUIRED" "TAKE HALF AS NEEDED" "TAKE HALF AS NEEDED" "
local nddtextASD "`nddtextASD' "ONE OR TWO AS DIRECTED" "TAKE ONE-TWO AS DIRECTED" "
local nddtextASD "`nddtextASD' "ONE OR TWO WHEN REQUIRED AS DIRECTED" "TAKE ONE OR TWO" "1-2 AS DIRECTED" "
local nddtextASD "`nddtextASD' "ONE OR TWO WHEN REQUIRED" "TAKE ONE TO TWO WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "TAKE 1-2 AS NEEDED" "1-2 TABLETS WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "1-2PRN" "TAKE ONE OR TWO PRN" "
local nddtextASD "`nddtextASD' "ONE OR TWO AS DIRECTED" "TAKE 1-2 AS DIRECTED" "
local nddtextASD "`nddtextASD' "1 -2 WHEN REQUIRED" "1 TO 2 PRN" "
local nddtextASD "`nddtextASD' "1 OR 2 AS REQUIRED" "1-2 AS NECESSARY" "
local nddtextASD "`nddtextASD' "1-2 TABS AS REQUIRED" "TAKE 1 OR 2" "
local nddtextASD "`nddtextASD' "1 TO 2 WHEN REQUIRED" "ONE OR TWO PRN" "
local nddtextASD "`nddtextASD' "ONE OR TWO AS REQUIRED" "1-2 TABS WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "ONE OR TWO TO BE TAKEN AS DIRECTED" "1 TO 2 AS DIRECTED" "
local nddtextASD "`nddtextASD' "1-2 WHEN REQUIRED." "1 OR 2 AS DIRECTED" "
local nddtextASD "`nddtextASD' "ONE TO TWO WHEN REQUIRED" "TAKE 1 OR 2 WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "TAKE 1-2 AS REQUIRED" "ONE OR TWO AS DIRECTED" "
local nddtextASD "`nddtextASD' "1 -2 AS DIRECTED" "1-2 PRN" "1 OR 2 WHEN REQUIRED AS DIRECTED" "
local nddtextASD "`nddtextASD' "1-2 WHEN REQUIRED AS DIRECTED" "TAKE ONE TO TWO AS DIRECTED" "
local nddtextASD "`nddtextASD' "TAKE 1 OR 2 AS DIRECTED" "1 OR 2 PRN" "1-2 TABLET(S) WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "ONE OR TWO WHEN REQUIRED AS DIRECTED" "
local nddtextASD "`nddtextASD' "1 OR 2 TABLETS WHEN REQUIRED" "1 OR 2 AS NEEDED" "
local nddtextASD "`nddtextASD' "1OR2 WHEN REQUIRED" "1-2 WHEN NECESSARY" "TAKE ONE OR 2 AS DIRECTED" "
local nddtextASD "`nddtextASD' "1-2 WHEN REQUIRED" "TAKE ONE OR 2 AS NEEDED" "TAKE ONE OR TWO WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "1 OR 2 WHEN REQUIRED" "TAKE ONE OR TWO AS NEEDED" "1-2 AS NECESSARY" "
local nddtextASD "`nddtextASD' "1-2 TABS AS REQUIRED" "
local nddtextASD "`nddtextASD' "TAKE 1 OR 2" "1 TO 2 WHEN REQUIRED" "ONE OR TWO PRN" "ONE OR TWO AS REQUIRED" "
local nddtextASD "`nddtextASD' "1-2 TABS WHEN REQUIRED" "1 TO 2 AS DIRECTED" "ONE OR TWO TO BE TAKEN AS DIRECTED" "
local nddtextASD "`nddtextASD' "1-2 WHEN REQUIRED" "1 OR 2" "
local nddtextASD "`nddtextASD' "ONE OR TWO TO BE TAKEN AS REQUIRED" "ONE OR TWO TO BE TAKEN WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "1-2 ASD" "ONE OR TWO AS DIRECTED WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "TAKE ONE OR TWO TABLETS WHEN REQUIRED." "1 OR 2 TABS WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "1-20D" "ONE OR TWO AS NEEDED" "ONE TO TWO AS DIRECTED" "
local nddtextASD "`nddtextASD' "HALF TO ONE WHEN REQUIRED" "HALF TO ONE TABLET WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "HALF OR 1 WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "1/2 TO 1 WHEN REQUIRED" "HALF OR ONE TABLET WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "A HALF OR ONE WHEN REQUIRED" "
local nddtextASD "`nddtextASD' "2-3 PRN" "TWO OR THREE WHEN REQUIRED" "TWO OR THREE AS DIRECTED" "
foreach asdir in `nddtextASD' {
	recode asdir 0=1 if text=="`asdir'"
}

* recode ndd_new if free text suggests an alternative figure
recode ndd_new 10=1 if text=="10M"
recode ndd_new 10.5=1.5 if text=="1-20M"
recode ndd_new 20=2 if text=="20M"
recode ndd_new 20=2 if text=="10M 10N"
recode ndd_new 30=3 if text=="30M"
recode ndd_new 10.5=1.5 if text=="1-20M"
recode ndd_new 20=2 if text=="20M"
recode ndd_new 20=2 if text=="20N"
recode ndd_new 22=4 if text=="11 TWICE A DAY"

* assume 11 means 2 tablets (similar to handwritten shorthand for 2 tabs)
local 11equal2 " "11 DAILY" "11 IN THE MORNING" "11 EVERY MORNING" "
foreach bd in `11equal2' {
	recode ndd_new 11=2 if text=="`bd'"
}













/*******************************************************************************
#A6. Use HF code to further clean data
	- from file: 10a_severe_immuno_at_index_steroids
	- cleaning based on R/V of steroid data
*******************************************************************************/
foreach x in "6/DAY" "6OD" "6 OD" "6 DAILY" "6 A DAY FOR 5 D" "2 TAB TDS"  "6 TAB A DAY" "TAKE 6 PER DAY"{
	list packtype_new ndd_new ndd text if packtype_desc=="`x'" 
	recode ndd_new 0=6 if packtype_desc=="`x'"
	replace packtype_new=. if packtype_desc=="`x'"
} /*end foreach x in "6/DAY" "6OD" "6 OD" "6 DAILY" "6 A DAY FOR 5 D" "2 TAB TDS"  "6 TAB A DAY" "TAKE 6 PER DAY"*/

recode ndd_new 0=3 if packtype_desc=="1 TDS" 
replace packtype_new=. if packtype_desc=="1 TDS" 

recode ndd_new 0=1 if (packtype_desc=="1 EVERY MORNING" | packtype_desc=="1 T OD" )
replace packtype_new=. if (packtype_desc=="1 EVERY MORNING" | packtype_desc=="1 T OD" )

foreach x in "8 DAILY FOR  1" "8OD" "8 OD" "8 OD"  "TAKE 8 TABS IN" "8D" {
	recode ndd_new 0=8 if packtype_desc=="`x'"
	replace packtype_new=. if packtype_desc=="`x'"
} /*end foreach x in "8 DAILY FOR  1" "8OD" "8 OD" "8 OD"  "TAKE 8 TABS IN" "8D"*/

recode ndd_new 0=2 if packtype_desc=="2OD" 
replace packtype_new=. if packtype_desc=="2OD" 
recode ndd_new 0=5 if packtype_desc=="5OD" 
replace packtype_new=. if packtype_desc=="5OD" 
replace packtype_new=308 if packtype_desc=="11 PACKS OF 28" 
replace packtype_new=140 if packtype_desc=="5X28 TABLETS"
replace packtype_new=. if packtype_desc=="30MG DAILY REDU"

recode ndd_new 1=0 if text=="EVERY MORNING AS DIRECTED"
recode ndd_new 3=0 if text=="AS DIRECTED WITH MEALS"
recode ndd_new 16=8 if text=="EIGHT IMMEDIATELY AND EIGHT EVERY MORNING"
recode ndd_new 16=8 if text=="EIGHT TABS (AS A SINGLE MORNING DOSE) DAILY FOR FIVE DAYS TO SEVEN DAYS"
recode ndd_new 0=6 if text=="6 IN THE MORINING FOR ONE WEEK"
recode ndd_new 0=1 if text=="1 D"
replace ndd_new=30/doseprodname if text=="30MG EVERY DAY" | (text=="30MG DAILY") | (text=="30 MG DAILY") | (text=="30MG EVERY DAY FOR 5 DAYS") | text=="30 MG EVERY DAY" | text=="30MG"
replace ndd_new=40/doseprodname if text=="40MG EVERY DAY" | (text=="40MG DAILY")
replace ndd_new=10/doseprodname if text=="10MG DAILY" | (text=="10MG EVERY DAY")
replace ndd_new=5/doseprodname if text=="5MG DAILY"
replace ndd_new=2/doseprodname if text=="2MG DAILY"
replace ndd_new=4/doseprodname if text=="4MG DAILY"
recode ndd_new 24=6 if text=="6 EVERY DAY AS A AS A AS A SINGLE DAILY DOSE WITH FOOD DAILY DOSE WITH FOOD DAILY DOSE WITH FOOD PLEASE COMPLETE THE PLEASE COMPLETE THE PLEASE COMPLETE THE COURSE"

recode ndd_new 0=8 if text=="8D"
recode ndd_new 0=8 if text=="8 D"
recode ndd_new 0=6 if text=="6D"
recode ndd_new 0=6 if text=="6 D"
recode ndd_new 0=6 if text=="60D"
recode ndd_new 0=1 if text=="1D"
recode ndd_new 0=10 if text=="10D"
recode ndd_new 0=8 if text=="80D"
recode ndd_new 0=4 if text=="4D"
recode ndd_new 0=4 if text=="3D"
recode ndd_new 0=4 if text=="40D"
recode ndd_new 0=30 if text=="30MG"
recode ndd_new 0=20 if text=="20MG"
recode ndd_new 0=40 if text=="40MG"
recode ndd_new 0=1 if text=="1 TAB MDU"
recode ndd_new 0=1 if text=="1 DAIY"
recode ndd_new 0=1 if text=="1 IN AM"
recode ndd_new 0=0.5 if text=="TAKE ONE ALTERNATIVE DAYS"

recode ndd_new 24=6 if text=="6 EVERY DAY AS A AS A AS A SINGLE DAILY DOSE WITH FOOD DAILY DOSE WITH FOOD DAILY DOSE WITH FOOD PLEASE COMPLETE THE PLEASE COMPLETE THE PLEASE COMPLETE THE COURSE"
recode ndd_new 24=0 if text=="BY ~~~ OOH"
recode ndd_new 24=0 if text=="GPOOH"
recode ndd_new 40=0 if text=="40N" | text=="40M"
recode ndd_new 36=6 if text=="TIMES SIX DAILY"
recode ndd_new 9=8 if text=="EIGHT A DAY IN ONE GO IN THE MORNING  FOR 5 DAYS. STEROIDS" 
recode ndd_new 12=6 if text=="6 EVERY DAY AS A SINGLE DAILY DOSE WITH FOOD PLEASE COMPLETE THE COURSE" 
recode ndd_new 12=6 if text=="SIX IMMEDIATELY AND EVERY MORNING WITH MEALS" 
recode ndd_new 4.5=6 if text=="6OD FOR 7 DAYS AND THEN SEE THE DR OR ASTHMA NURSE TO ASSES BREATHING AROUND DAY 5-7 TO ASSES BREATHING AND DECIDE ON FURTHER TREATMENT. TAKE THE 6 TABS ALL IN ONE GO IN THE MORNINGS EXCEPT FOR THE FIRSTDAY WHEN YOU SHOULD TAKE THE FIRST SIX AS"
recode ndd_new 0.14300001=1 if text=="1 TAB DAILY DISP WKLY"
recode ndd_new 0.14300001=1 if text=="ONE DAILY WEEKLY DISPENSE"
recode ndd_new 1.143=1 if text=="1 DAILY; WEEKLY DISPENSE"

tab ndd_new
tab ndd_new, sort f

/*
NDD is MG (<1% Rx): 
	Convert ndd from total dose in mg perday to number of tablets:
	NTD: NDD (total dose in mg per day) / doseprodname (dose individual tablet
*/
replace ndd_new=ndd_new/doseprodname if dose_unit=="MG" & ndd_new!=0

*Assum higher ndd's are in MG
foreach x in 20 25 30 40 {
	tab text if ndd_new==`x' & doseprodname>1
	replace ndd_new=ndd_new/doseprodname if ndd_new==`x' & doseprodname>1
} /*end foreach x in 20 25 30 40*/








/*
Will run diagnostics in the file that calls this program

/*******************************************************************************
#A7. Run DIAGNOSTICS on packtype_new and ndd vars 
	output will be saved in log files that will be manually reviewed and 
	dealt with as necessary in individual exposure do-files.
*******************************************************************************/
*------------------------------------------------------------------------------
* A7.1	create a table to review manually in order to manually change 
*		incorrect packtypes
*------------------------------------------------------------------------------	
tab packtype packtype_new, miss



*------------------------------------------------------------------------------
* A7.2 Check most commonly used free texts (~top 90%)
*------------------------------------------------------------------------------
/*
	In individual exposure do-files can manually go through the top 90% 
	list of free texts and change ndd_new
	where it doesn't match with the text.
	can also change packtype_new where a quantity is given in the text.
	Code below displays most common free texts.
*/
display "**********most commonly used free texts**********"
preserve
	sum patid
	local tot =`r(N)'
	bysort text: gen bigN=_N
	bysort text: gen littleN=_n
	gsort -bigN
	keep if littleN==1
	sum
	gen tot_percent=(bigN/`tot')*100
	gen cum_total_percent=tot_percent[1]
	replace cum_total=tot_percent[_n]+ cum_total_percent[_n-1] if _n>1
	list text ndd ndd_new cum_total /*create a list free texts and assoc NDD*/
restore



*------------------------------------------------------------------------------
* A7.3 Check text where ndd_new is missing (i.e. ndd==0 & ndd_new==.)
*------------------------------------------------------------------------------
/*
	In individual exposure do-files will manually go through
	and amend ndd manually where possible
*/
display "**********text where ndd_new is missing**********"
preserve
	drop if text==""
	keep if ndd_new==.
	sum patid
	local tot =`r(N)'
	sort text
	bysort text: gen bigN=_N
	bysort text: gen littleN=_n
	gsort -bigN
	keep if littleN==1
	gen tot_percent=(bigN/`tot')*100
	gen cum_total_percent=tot_percent[1]
	replace cum_total=tot_percent[_n]+ cum_total_percent[_n-1] if _n>1
	list text ndd ndd_new bigN tot_percent cum_total
restore

*/









/*******************************************************************************
********************************************************************************
********************************************************************************
#SECTION B
	- If ndd or qty variables are missing or dodgy then use the
		numdays and dose_duration variables to update them if possible.
			numdays			// number of treatment days prescribed for a specific therapy event
			dose_duration	// the number of days the prescription is for 
********************************************************************************
********************************************************************************
*******************************************************************************/

/*******************************************************************************
#B1. Recode missing vars for dose_duration, numdays and qty_new
	to 0 instead of .
*******************************************************************************/
* dose duration is a str var so change to numeric
generate dose_duration_num = real(dose_duration)	
drop dose_duration							// drop old var
rename dose_duration_num dose_duration		// rename new var
label var dose_duration "If specified, the num days the prescription is for"

* recode
recode dose_duration .=0
recode numdays .=0
recode qty_new .=0
tab qty_new



/*******************************************************************************
#B2. use packtype_new var to update qty_new var if qty_new is missing 
*******************************************************************************/
replace qty_new=packtype_new if qty_new==0 & packtype_new!=.



/*******************************************************************************
#B3. use numdays and dose_dur variables from common dosages file 
	to update qty_new variable if it is <7 or missing
*******************************************************************************/
* i. numdays * ndd_new
replace qty_new=numdays*ndd_new if (qty_new<7 & numdays!=0 & ndd_new!=0 & qty_new!=0) /* if qty_new<7 */
replace qty_new=numdays*ndd_new if qty_new==0 /*if qty_new==0*/
recode qty_new .=0 /*set missing values created above back to 0*/				

* ii. dose duration * ndd_new 
replace qty_new=dose_dur*ndd_new if (qty_new<7 & dose_dur!=0 & ndd_new!=0 & qty_new!=0) /* if qty_new<7*/
replace qty_new=dose_dur*ndd_new if qty_new==0 /*if qty_new==0*/
recode qty_new .=0 /*set missing values created above back to 0*/				



/*******************************************************************************
#B4. Where NDD is greater than QTY, change QTY to zero
*******************************************************************************/
replace qty_new=0 if ndd_new>qty_new & ndd_new!=. & qty_new!=0
tab qty_new, miss




/*******************************************************************************
#B5. Implausible values of QTY to missing (0)
*******************************************************************************/
* #B5.1 if qty is less than ndd or qty<7
replace qty_new=0 if qty_new<ndd_new
replace qty_new=0 if qty_new<7 & qty!=0 & doseprodname<=5

* #B5.2 high values of qty
* max duration of prescription for stable longterm conditions in the UK is 3 months
* for TABLETS if prescription duration is max of 3months if qty 3000=33/day; 2000=22/day; 1500=17/day; and 1000=11/day
* know from distribution of ndd that max ndd (not ml) (aki2 study): ACE/ARB=7.5; BB=25; CCB=20; thiaz=10; Ksparing=9; and loop=16
* therefore set to 3000 for tablets

* for LIQUIDS (1000ml=1 litres) if prescription is max of 3months if qty 3000=33ml/day; 4000=44ml/day; 7000=78ml/day; 9000=100ml/day
* therefore set to 9000ml max for liquids
replace qty_new=packtype_new if qty_new>1000 & packtype_new!=. & dose_unit!="ML" // use packtype_new var to update qty if it is not missing and qty is >1000
replace qty_new=0 if qty_new>3000 & qty_new!=. & dose_unit!="ML"	// assume more than 3000 tablets in 3/12 is implausible 
replace qty_new=0 if qty_new>9000 & qty_new!=. & dose_unit=="ML" 	// assume more than 9 litres in 3/12 is implausible



/*******************************************************************************
#B6.	Summarise cleaned QTY and NDD
*******************************************************************************/
tab qty_new
sum qty_new, detail

tab ndd_new, miss
sum ndd_new if ndd!=0, detail 


















/*******************************************************************************
********************************************************************************
********************************************************************************
#SECTION C
	- Save the resulting file 
********************************************************************************
********************************************************************************
*******************************************************************************/
label data "cleaned prescription data"
notes: cleaned prescription data
notes: `dofilename' / TS
compress
save `savefile', replace






end
