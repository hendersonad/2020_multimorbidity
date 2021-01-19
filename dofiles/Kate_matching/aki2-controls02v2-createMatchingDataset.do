/*=========================================================================
DO FILE NAME:	aki2-controls02v2-createMatchingDataset.do

AUTHOR:					KateMansfield		
VERSION:				v2.0
DATE VERSION CREATED:	v2 20-April-2015	- updated for new eligibleFrom and To dates
						v1 16-April-2015 					
					
DATABASE:				CPRD July 2014 build
						CPRD-HES version 10: 1/04/1997 to 31/3/2014

DESCRIPTION OF FILE:
	Creates a dataset containing all eligible cases and all potential controls
	Dataset needs to contain the following vars:
		patid
		pracid
		sex
		yeardob
		indexdate (cases only)
		startdate
		enddate
		case (1=case 0=non-case)
						
DATASETS USED: 		
	$pathDataDerived/controls-pool
	$pathDataDerived/cases-CKDstatus-eligiblepats
	$pathDataExtract/Patient_extract_aki2_1
									
DO FILES NEEDED:	aki2-pathsv2.do

DATASETS CREATED:	matching

STAGES:
	1. Open pool of patients eligible for control selection (>18 at study end, 
		registered with uts practice during study period and eligible for HES 
		linkage) format as above ready for merge with cases
	2. Open eligible cases file (patients eligible on study dates, esrd, 
		availability of SCr results) format as above ready for merge with 
		possible controls
	3. Merge case and control files and identify case/control flags
	
*=========================================================================*/
version 13
clear all
macro drop _all

/*******************************************************************************
>> identify file locations and set any locals
*******************************************************************************/
* cd to location of file containing all file paths
aki2 paths
run aki2-pathsv2.do


/*******************************************************************************
#1. Controls
*******************************************************************************/
use $pathDataDerived/controls-pool-02, clear
keep patid pracid gender yob eligibleFrom eligibleTo   

* rename vars for matching program
rename gender sex
rename yob yeardob

* create startdate and enddate vars
* NB: chosen not to just rename eligibleFrom and To vars - as keeping these
* for clarity since enddate might change if a control becomes a case
gen startdate=eligibleFrom
label var startdate "previously eligibleFrom" // for controls eligibleFrom = max(crdPlus1yr, uts, happy18th, date("4/1/1997", "MDY"))
format startdate %td

gen enddate=eligibleTo
label var enddate "previously eligibleTo" // for control eligibleTo = min(deathdate, tod, lcd, date("3/31/2014", "MDY"))
format enddate %td

order patid pracid sex yeardob startdate enddate

* generate a case/control var
gen case=0
label var case "1=eligible case; 0=potential control"



************ might get rid of line 82-96 and then merge rather than append at
* #3 if not duplicate patids allowed by matching program
/*------------------------------------------------------------------------------
#1.1 controls becoming cases
------------------------------------------------------------------------------*/
* a control can become a case - we can therefore use any eligible time for cases
* before their index dates - therefore need to identify indexdates for potential 
* controls that are eligible cases
* and reset enddate to equal to indexdate
merge 1:1 patid using $pathDataDerived/cases-CKDstatus-eligiblepats-02
drop firstExpClass baselineCKD

replace enddate=indexdate-1 if _merge==3
gen controlbecomescase=1 if _merge==3
recode controlbecomescase .=0
label var controlbecomescase "control becomes a case"
drop _merge

* save as a tempfile
tempfile controls
save `controls'



/*******************************************************************************
#2. Cases
*******************************************************************************/
use $pathDataDerived/cases-CKDstatus-eligiblepats-02, clear
keep patid indexdate eligible*

* add in gender and year of birth info
merge 1:1 patid using $pathDataExtract/Patient_extract_aki2_1, keep(match master) nogen
keep patid indexdate eligible* gender realyob 

* identify pracid
gen long pracid=mod(patid, 1000) 
label var pracid "pracid: unique practice id number"

* rename vars for matching program
rename gender sex
rename realyob yeardob
rename eligibleFrom startdate
label var startdate "previously eligibleFrom" // for cases eligibleFrom = max(crdPlus1yr, uts, happy18th, date("4/1/1997", "MDY"))
rename eligibleTo enddate
label var enddate "previously eligibleTo" // for cases eligibleTo = min(deathdate, tod, lcd, date("3/31/2014", "MDY")) 

order patid pracid sex yeardob indexdate startdate enddate

* generate case var
generate case=1
label var case "1=eligible case; 0=potential control"



/*******************************************************************************
#3. Create one file of cases and controls
*******************************************************************************/
append using `controls'
replace indexdate=. if controlbecomescase==1 // will also need to get rid of this is matching prog doesn't allow patids as both cases and controls




/*******************************************************************************
#4. Add notes and save
*******************************************************************************/
label data "eligible cases and all potential controls"
notes: aki2-controls02-createMatchingDataset.do / TS

save $pathDataDerived/matching-02, replace
