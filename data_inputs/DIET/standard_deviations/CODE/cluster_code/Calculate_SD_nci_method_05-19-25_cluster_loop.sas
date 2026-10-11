/****************************************************************************
* SIMPLE Macro (Updated Version from Hanqui Luo)
* CALCULATE STANDARD DEVIATIONS USING NHANES 2015-2016, 2017-2018 DATA
* AUTHOR: BROOKE BELL
* DATE: 05-19-25
* 
*****************************************************************************/

/*****************************************************************************
** Code may take a long time to complete due to complicated survey design  
** The log will indicate if the process has been stopped due to errors. 
******************************************************************************/

** Setting **;

* Clean the environment;

* Remove libname;
LIBNAME _all_ CLEAR;

* Remove graphics;
ods graphics off;

/*** Directory *************************************************************
** User should change this working directory to where they save the folder
****************************************************************************/

%let home = /cluster/tufts/lasting/shared/LASTING/standard-deviations;

libname in "&home/in";
libname out "&home/out";

* Include the required macros;
%include "&home/macros/mixtran_macro_v2.21.sas";
%include "&home/macros/distrib_macro_v2.2.sas";
%include "&home/macros/simple_macro_v3.4_bmb.sas"; * use my edited macro;

* Import cleaned 24-h dietary recall data;
proc import OUT= WORK.nhanes 
            DATAFILE= "&home/in/nhanes_incl_ssb_adj_clean_long.csv" 
            DBMS=CSV REPLACE;
     GETNAMES=YES;
     DATAROW=2; 
run;

proc sort data=nhanes OUT=nhanes_sort;
by seqn day;
run;

/* Calculate BRR weights */

* Check number of strata;
proc sql;
   create table new as 
     select count(distinct(SDMVSTRA)) as STRAcount 
            from nhanes_sort;
quit;

proc sql;
   create table new1 as 
     select count(distinct(SDMVPSU)) as STRAcount 
            from nhanes_sort;
quit;

* Set repWT0 as wtnew;
data nhanes_sort1;
set nhanes_sort;
repWT_0 = ceil(wtnew);
cluster = SDMVPSU;
run;

* Generate BRR, number of replicates = number of strata+4;
proc surveymeans data = nhanes_sort1 varmethod = brr(fay = 0.3 outweights = diet_brr reps = 34);
   strata SDMVSTRA;
   cluster cluster;
   weight repWT_0;
   var fruit_tot_adj;
run;

* Take ceiling of all BRR weight values (needs to be whole number);
data diet_brr1;
   set diet_brr;
      array nciwt[36] RepWT_1-RepWt_36;
	     do i = 1 to 36;
	       nciwt[i] = ceil(nciwt[i]);
		end;
run;

* Create temp dataset;
data diet_final;
set diet_brr1;
run;

/*****************************
** loop 
** make the program efficient
******************************/
     
* import input csv file;
* use test input file for now;
PROC IMPORT OUT= WORK.input 
            DATAFILE= "&home/in/macro_input_LASTING_ALL_VARS.csv" 
            DBMS=CSV REPLACE;
     GETNAMES=YES;
     DATAROW=2; 
	GUESSINGROWS=30; /* Include this line to ensure the variable names imported in full length */
RUN;

/* load loop command */
%include "&home/macros/SIMPLELoop_v1.4.sas";

/* loop for SIMPLE macro */
%SIMPLELoop(
 no = 17,  /* The total number of nutrients that you would like to analyze */
 inputFile =input /* input file */
 );


