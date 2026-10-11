/*****************************************************************************
  Combine FNDDS 2017-2018 and FNDDS 2019-2020 files for use with
  WWEIA, NHANES 2017-March 2020 pre-pandemic data

  Why: food codes in the pre-pandemic data come from both FNDDS versions.
  This program keeps every 2019-2020 record, and adds 2017-2018 records
  only for food codes that are not in 2019-2020 (codes discontinued after
  2017-2018). Each food code therefore comes from one version only.

  Output (written to the IN library, the names the processed meat program
  expects):
     IN.addfooddesc_1720   additional food descriptions
     IN.fnddsingred_1720   ingredients

  Before running:
   1. Run FNDDS_2017-2018_sas.exe and FNDDS_2019-2020_sas.exe to extract
      the SAS datasets.
   2. Copy the AddFoodDesc and FNDDSIngred datasets from each into your
      "in\FNDDS" folder and rename them:
         addfooddesc_1718.sas7bdat   fnddsingred_1718.sas7bdat
         addfooddesc_1920.sas7bdat   fnddsingred_1920.sas7bdat
   3. Set the folder path below.
   4. Run STEP 1 only, check the PROC CONTENTS output, and change the
      food code variable name in STEP 2 if it is not Food_code.
*****************************************************************************/

/* path = the Processed_Meat folder (the one that contains "in" and "out") */
%let path = C:\GitHub\LASTING-methods_oyw\data_inputs\DIET\dietary_intake\CODE\Processed_Meat;

/* FNDDS = where the four FNDDS input files live (read from here) */
libname FNDDS "&path.\in\FNDDS";

/* IN = where the combined files are saved (the processed meat program reads from here) */
libname IN "&path.\in";

/* Name of the food code variable in the FNDDS SAS datasets.
   Change this if PROC CONTENTS shows a different name. */
%let fc = Food_code;


/*****************************************************************************
  STEP 1. Check variable names and types in all four files
*****************************************************************************/
proc contents data=FNDDS.addfooddesc_1718 varnum; run;
proc contents data=FNDDS.addfooddesc_1920 varnum; run;
proc contents data=FNDDS.fnddsingred_1718 varnum; run;
proc contents data=FNDDS.fnddsingred_1920 varnum; run;

/* Things to check in the output:
   - the food code variable has the same name in all four files (set &fc above)
   - shared variables have the same type (numeric or character) in both versions;
     if not, the combine step will stop with an error and the type must be fixed first
   - the description variables are named Additional_food_description and
     Ingredient_description (the processed meat program expects these) */

/*CHECKED, ALL OK - OYW 10/10/2026*/


/*****************************************************************************
  STEP 2. Combine. CORR keeps only the variables the two versions share.
  FNDDS_VERSION records which version each row came from.
*****************************************************************************/
proc sql;
  create table IN.addfooddesc_1720 as
    select *, 1920 as FNDDS_VERSION
      from FNDDS.addfooddesc_1920
    union all corr
    select *, 1718 as FNDDS_VERSION
      from FNDDS.addfooddesc_1718
      where &fc not in (select &fc from FNDDS.addfooddesc_1920)
    order by &fc;

  create table IN.fnddsingred_1720 as
    select *, 1920 as FNDDS_VERSION
      from FNDDS.fnddsingred_1920
    union all corr
    select *, 1718 as FNDDS_VERSION
      from FNDDS.fnddsingred_1718
      where &fc not in (select &fc from FNDDS.fnddsingred_1920)
    order by &fc;
quit;


/*****************************************************************************
  STEP 3. Checks
*****************************************************************************/

/* How many food codes came from each version */
title "Additional food descriptions: food codes by FNDDS version";
proc sql;
  select FNDDS_VERSION,
         count(distinct &fc) as n_food_codes,
         count(*)            as n_rows
    from IN.addfooddesc_1720
    group by FNDDS_VERSION;
quit;

title "Ingredients: food codes by FNDDS version";
proc sql;
  select FNDDS_VERSION,
         count(distinct &fc) as n_food_codes,
         count(*)            as n_rows
    from IN.fnddsingred_1720
    group by FNDDS_VERSION;
quit;

/* Each food code should come from one version only. Both tables should be empty. */
title "Food codes appearing under both versions (should be none)";
proc sql;
  select &fc, count(distinct FNDDS_VERSION) as n_versions
    from IN.addfooddesc_1720
    group by &fc
    having n_versions > 1;

  select &fc, count(distinct FNDDS_VERSION) as n_versions
    from IN.fnddsingred_1720
    group by &fc
    having n_versions > 1;
quit;
title;

/* Optional: check coverage against the pre-pandemic day 1 food file.
   Every food code reported in P_DR1IFF should have ingredient records.
   Remove the comment markers to run it. */
/*
libname XPIFF xport "&path.\in\P_DR1IFF.XPT";
proc copy in=XPIFF out=WORK; run;
libname XPIFF clear;

title "P_DR1IFF food codes with no ingredient records (should be none)";
proc sql;
  select DR1IFDCD, count(*) as n_reports
    from P_DR1IFF
    where DR1IFDCD not in (select &fc from IN.fnddsingred_1720)
    group by DR1IFDCD
    order by n_reports desc;
quit;
title;
*/

/*CHECKED, ALL OK - OYW 10/10/2026*/
