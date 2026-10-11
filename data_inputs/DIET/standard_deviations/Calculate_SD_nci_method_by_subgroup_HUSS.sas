/****************************************************************************
* SIMPLE Macro (Updated Version from Hanqui Luo)
* CALCULATE STANDARD DEVIATIONS USING NHANES 2017-MARCH 2020 + 2021-2023 DATA
* ORIGINAL AUTHOR: BROOKE BELL (05-19-25)
* ADAPTED BY: OLIVIA Y. WU (HUSS / LASTING adaptation)
*
* Changes from the original are marked with  >>> EDIT <<<
*****************************************************************************/

/*****************************************************************************
** Code may take a long time to complete due to complicated survey design
** The log will indicate if the process has been stopped due to errors.
******************************************************************************/

** Setting **;

* Remove libname;
LIBNAME _all_ CLEAR;

* Remove graphics;
ods graphics off;

/*** Directory *************************************************************
** >>> EDIT <<< Point this at YOUR OWN copy of the standard_deviations folder
** so you never overwrite the shared LASTING outputs. This folder must contain:
**   in/       nhanes1723_incl_ssb_adj_clean_long.csv
**             macro_input_LASTING_ALL_VARS.csv
**   out/      (empty)
**   results/  (empty; SIMPLE writes its output here - see "folder" in the CSV)
**   macros/   mixtran_macro_v2.21.sas, distrib_macro_v2.2.sas,
**             simple_macro_v3.4_bmb.sas, SIMPLELoop_v1.4.sas
**             (copy these four from the shared
**              /cluster/tufts/lasting/shared/LASTING/standard-deviations/macros)
****************************************************************************/

%let home = /cluster/tufts/lasting/shared/LASTING-methods_oyw/data_inputs/DIET/standard_deviations; /* >>> EDIT <<< */

/* >>> EDIT <<< Number of BRR replicates. Must be a multiple of 4 and at least the
   number of strata (expected 30 for 2017-Mar 2020 and 2021-2023, confirm with the
   strata count below). This SAME number must go in "endWeight" in the input CSV. */
%let nreps = 36;

libname in "&home/in";
libname out "&home/out";

* Include the required macros;
%include "&home/macros/mixtran_macro_v2.21.sas";
%include "&home/macros/distrib_macro_v2.2.sas";
%include "&home/macros/simple_macro_v3.4_bmb.sas"; /* edited macro from Brooke Bell */

* Import cleaned 24-h dietary recall data;
proc import OUT= WORK.nhanes
            DATAFILE= "&home/in/nhanes1723_incl_ssb_adj_clean_long.csv" /* >>> EDIT <<< */
            DBMS=CSV REPLACE;
     GETNAMES=YES;
     DATAROW=2;
     GUESSINGROWS=MAX; /* >>> EDIT <<< scan all rows so numeric columns are not read as text */
run;

* >>> EDIT <<< Quick check: every diet variable should show as Num, not Char;
proc contents data=nhanes varnum;
run;

proc sort data=nhanes OUT=nhanes_sort;
by seqn day;
run;

/* Calculate BRR weights */

* Check number of strata and PSUs (look at these in the output);
proc sql;
   create table new as
     select count(distinct(SDMVSTRA)) as STRAcount
            from nhanes_sort;
quit;

proc sql;
   create table new1 as
     select count(distinct(SDMVPSU)) as PSUcount
            from nhanes_sort;
quit;

proc print data=new; run;  /* >>> EDIT <<< print so the counts appear in the output */
proc print data=new1; run;

* Set repWT0 as wtnew (the combined-cycle weight created in script 02);
data nhanes_sort1;
set nhanes_sort;
repWT_0 = ceil(wtnew);
cluster = SDMVPSU;
run;

* Generate BRR replicate weights;
proc surveymeans data = nhanes_sort1 varmethod = brr(fay = 0.3 outweights = diet_brr reps = &nreps); /* >>> EDIT <<< */
   strata SDMVSTRA;
   cluster cluster;
   weight repWT_0;
   var fruit_exc_juice_adj; /* >>> EDIT <<< any variable in your data works here; this one is in the macro list */
run;

* Take ceiling of all BRR weight values (needs to be whole number);
data diet_brr1;
   set diet_brr;
      array nciwt[&nreps] RepWT_1-RepWt_&nreps; /* >>> EDIT <<< was hard-coded 36 */
	     do i = 1 to &nreps;
	       nciwt[i] = ceil(nciwt[i]);
		end;
   drop i;
run;

* Create temp dataset;
data diet_final;
set diet_brr1;
run;

/*****************************
** loop
** make the program efficient
******************************/

* Import input csv file;
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
 no = 17,  /* Number of columns (simulations) in the input CSV - change if you add/remove variables */
 inputFile =input /* input file */
 );
