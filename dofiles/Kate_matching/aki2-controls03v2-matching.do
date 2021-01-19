/*=========================================================================
DO FILE NAME:	aki2-controls03v2-matching.do

AUTHOR:					KM 		
VERSION:				v2.0
DATE VERSION CREATED:	v2 20-April-2015 - edited for new case eligibility
						v1 16-April-2015 					
					
DATABASE:				CPRD July 2014 build
						CPRD-HES version 10: 1/04/1997 to 31/3/2014

DESCRIPTION OF FILE:
	Runs matching program.
	Two sections to program:
		1. Identifies number of cases without potential matches so that parameters
			can be reset before running rest of program.
		2. Extracts controls.
	
INSTRUCTIONS FOR USE:
	Dataset must contain cases and all potential controls, with the following variables:
		patid
		pracid
		sex
		yeardob
		indexdate (cases only)
		startdate
		enddate
		case (1=case 0=non-case)
	
	Change locals to requirements
	
WHEN RUN FOR aki1:
	* allowing 1yr diff in ages > 699 with zero matches
	* allowing 2yrs diff in ages > 140 with zero matches
	* allowing 3yrs diff in ages > 60 with zero matches
	* allowing 4yrs diff in ages > 37 with zero matches >> go with 37 and drop unmatched cases
		
DATASETS USED: 		
	$pathDataDerived/matching
									
DO FILES NEEDED:	aki2-pathsv2.do
					prog_matching.do

DATASETS CREATED:
	`dataset_path'/`dataset'_sorted
	`dataset_path'/`dataset'_allpotentialmatches
	`dataset_path'/`dataset'_cases_with_no_matches
	
	
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

run prog_matching.do

/*
syntax, dataset_path(string) dataset(string) ///
	match_sex(integer) match_age(integer) match_diffage(integer) //
	match_regperiod(integer) ///
	control_minpriorreg(integer) control_minfup(integer) ///
	nocontrols(integer) nopractices(integer) 
*/
* dataset_path			// paths of case/control pool file and path to save output
* dataset				// name of dataset containing all potential controls and eligible cases
* match_sex  			// 0=no, 1=yes
* match_age  			// 0=no, 1=yes
* match_diffage 		// Years difference - This must be entered
* match_regperiod		// 0=no, 1=yes
* control_minpriorreg 	// Days controls must be registered prior to index date of case
* control_minfup 0 		// Days controls must be registered after index date of case
* nocontrols			// number of controls to match to every case
* nopractices 	 		// Maximum practice ID number




/*******************************************************************************
#1. Run matching program with ***2*** years 
		- starting at 2 rather than 1 becuase had to go for 4 years in pilot
*******************************************************************************/
prog_matching, dataset_path($pathDataDerived\) dataset("matching") ///
	match_sex(1) match_age(1) match_diffage(2) ///
	match_regperiod(1) ///
	control_minpriorreg(0) control_minfup(0) ///
	nocontrols(10) nopractices(685) 

/*
Time started matching = 11:18:12
Time ended matching = 12:25:51
Number of cases with zero potential matches = 112
*/
	
	
	
/*******************************************************************************
#2. Run matching program with ***3*** years 
*******************************************************************************/	
prog_matching, dataset_path($pathDataDerived\) dataset("matching") ///
	match_sex(1) match_age(1) match_diffage(3) ///
	match_regperiod(1) ///
	control_minpriorreg(0) control_minfup(0) ///
	nocontrols(10) nopractices(685) 
	
/*
Time started matching = 13:04:23
Time ended matching = 14:27:40
Number of cases with zero potential matches = 85
*/	
	
	

	
/*******************************************************************************
#3. Run matching program with ***4*** years 
*******************************************************************************/	
prog_matching, dataset_path($pathDataDerived\) dataset("matching") ///
	match_sex(1) match_age(1) match_diffage(4) ///
	match_regperiod(1) ///
	control_minpriorreg(0) control_minfup(0) ///
	nocontrols(10) nopractices(685) 
	
/*
Time started matching = 14:35:44
Time ended matching = 16:14:25
Number of cases with zero potential matches = 74
*/	
	


	
/*******************************************************************************
#3. Run matching program with ***5*** years 
*******************************************************************************/	
prog_matching, dataset_path($pathDataDerived\) dataset("matching") ///
	match_sex(1) match_age(1) match_diffage(5) ///
	match_regperiod(1) ///
	control_minpriorreg(0) control_minfup(0) ///
	nocontrols(10) nopractices(685) 
	
/*
Time started matching = 17:04:55
Time ended matching = 19:07:01
Number of cases with zero potential matches = 68
*/
	

/*******************************************************************************
#4. Run matching program with ***6*** years 
*******************************************************************************/	
prog_matching, dataset_path($pathDataDerived\) dataset("matching") ///
	match_sex(1) match_age(1) match_diffage(6) ///
	match_regperiod(1) ///
	control_minpriorreg(0) control_minfup(0) ///
	nocontrols(10) nopractices(685) 

/*
Time started matching = 21:43:23
Time ended matching = 00:06:51
Number of cases with zero potential matches = 67
*/
	
	
/*******************************************************************************
#5. Select matches program with ***3*** years in age difference allowed
*******************************************************************************/	
/*
Difference in age allowed:
2 yrs 112 cases with zero potential matches
3 yrs 85 cases with zero potential matches
4 yrs 74 cases with zero potential matches
5 yrs 68 cases with zero potential matches
6 yrs 67 cases with zero potential matches

>> therefore decided to use 3 years age difference
*/	
prog_matching, dataset_path($pathDataDerived\) dataset("matching-02") ///
	match_sex(1) match_age(1) match_diffage(3) ///
	match_regperiod(1) ///
	control_minpriorreg(0) control_minfup(0) ///
	nocontrols(10) nopractices(685) 
		
	
/*
>> part 2

Time started selecting controls:  16:50:43
Time finshed selecting controls:  23:26:07


   (max) N1 |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |         40        0.01        0.01
          2 |         41        0.02        0.03
          3 |         55        0.02        0.05
          4 |         67        0.02        0.08
          5 |         58        0.02        0.10
          6 |         87        0.03        0.13
          7 |         72        0.03        0.16
          8 |         91        0.03        0.19
          9 |         93        0.03        0.22
         10 |    267,858       99.78      100.00
------------+-----------------------------------
      Total |    268,462      100.00

	
*/



	
	
	

