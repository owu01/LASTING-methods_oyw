
*Processed Meat SAS Program of the US National Cancer Institute

FOR DAY 1 DIETARY RECALL DATA ONLY-- day 1 program in 'Meat code day 2' file

Updated 7-21-21 by Lauren O'Connor

Variable created with this program include the following and can be found in Supplemental Table 4 of the below reference:

VARIABLE NAME		  DESCRIPTION
cured_redmeat	      Cured red meat: Component disaggregated from cured meat FPED, described as red meat preserved by smoking, curing, salting, and/or the addition of chemical preservatives
total_redmeat	      Total red meat: Combination of uncured red meat and cured red meat
cured_poultry	      Cured poultry: Component disaggregated from cured meat FPED, described as poultry preserved by smoking, curing, salting, and/or the addition of chemical preservatives
total_proc_poultry    Total processed poultry: Combination of cured poultry and the PF_poult FPED component of the WWEIA category of chicken patties, nuggets, and tenders
total_poultry	      Total poultry: Combination of uncured poultry and cured poultry 
Nug_pat_fil	          Chicken nuggets, patties, and fillets: PF_poult FPED component from WWEIA category 2204 i.e. chicken nuggets, patties, and tenders
Red_and_cured_1	      Red and cured meat: Combination of uncured red meat and cured red meat + cured poultry 
Red_and_processed_2	  Red and processed meat: Combination of uncured red meat, cured red meat, cured poultry + chicken patties, nuggets, and tenders

Details of how decisions about how to disaggregate 'cured meat' into 'cured red meat' and 'cured poultry'
are described in detail in the O'Connor et al. manuscript [Citation TBA-- doi: 10.1093/jn/nxab316].

Questions?
Please contact the Risk Factor Assessment Branch at RFAB@mail.nih.gov. 


Files that results from this program include:
out.meat_day1:     participant-level data with all food codes reported per participant for day 1
				   i.e. individual food level, with multiple lines of intake per participant for day 1
out.meat_day1_sum: participant-level data with all indidivual food codes summed across day 1
					i.e. total intake level, with one line of intake per participant for day 1 

*Steps of this SAS program for DAY 1
1. Description of datafiles used
2. Instructions and links for importing datafiles
3. Preparing data files to merge
4. Isolating additional food descriptions and ingredients
5. Merge WWEIA, Ingredients, additional descriptions, and FPEDS by cycle
6. Merge demographics, FPED IFF, NHANES IFF day 1 by seqn
7. Combine all datafiles for each cycle
8. Append all cycles of interest
9. Apply meat code to day 1 data
10. Proc means to total meat intakes for day 1

This program is set up so that users can run a series of macros and choose which NHANES cycles they want to apply the macro.
Run each macro as you come across them from the macro statement to the mend statement, then use the following cycle-specific codes to call those data.
(CHANGED: the original wording here contained macro keywords that SAS tried to execute inside this comment.)

UPDATE FOR NHANES 2017-MARCH 2020 PRE-PANDEMIC (cycle label 1720) AND AUGUST 2021-AUGUST 2023 (cycle label 2123)
Every edit made for this update is flagged with a comment starting  *** CHANGED  so you can find them by searching for that text.
Both cycles are processed and appended, but analyse them separately (BY SDDSRVYR: 66 = 2017-Mar 2020, 12 = 2021-2023),
because the two releases have different sample designs, weights and day-1 recall procedures.

TEMPORARY WORKAROUND: there is no FPED for August 2021-August 2023 yet. Until it is released, the 2021-2023
cycle uses the FPED for 2017-March 2020: each food in DR1IFF_L is matched by food code to the 2017-2020
FPED per-100 g file and scaled by grams eaten. Food codes that are new in 2021-2023 have no match and get
missing food pattern values. Every edit for this workaround is flagged  *** TEMPORARY  so it can be undone
once the new FPED is out.


*Create a library;
*** CHANGED: set your own folder once here. It must contain an "in" and an "out" subfolder;
%let path = C:\GitHub\LASTING-methods_oyw\data_inputs\DIET\dietary_intake\CODE\Processed_Meat;
libname IN  "&path.\in";
libname OUT "&path.\out";


**************************************************
1. Description of datafiles used for each cycle
**************************************************
NHANES IFF: lists individual foods reported by each participant, i.e. multiple food codes per participant

FPED per 100g of FNDDS food code: FPED values for each food code within FNDDS, does not include participant-level data
								  Includes the 'Main description' for each food code

FPED Individual food file (IFF): lists the FPED values for each individual food reported by each participant

WWEIA food groups: groups 'as consumed' in the US, linked to each food code, does not include participant-level data  

Demographics: participant-level data for various demographic variables 

Additional food code desriptions: Some food codes can link to additional descriptions which includes additional information 
							      or in some cases, brand names.

Ingredients: Food codes link to 'ingredients' or 'SR codes', depending on the cycle. This file will list ingredients/SR codes
	         that comprise each food code to obtain information for mixed dishes.



**************************************************
2. Instructions and links for importing datafiles
   that are described above
**************************************************

*Importing NHANES IFF files;

*First, run each macro;
*** CHANGED: the macro now takes the full XPT file name, because the pre-pandemic file is named P_DR1IFF
    (prefix) while the 2021-2023 file is named DR1IFF_L (suffix). Download both from the CDC NHANES website;
%macro IFF (file);
libname XPIFF xport "&path.\in\&file..XPT"; 
	proc copy in=XPIFF out=WORK;
run;
libname XPIFF clear;
%mend;

*Second, choose the cycle(s) of interest;
%IFF (P_DR1IFF);
%IFF (DR1IFF_L);

*Rename datafiles;
proc datasets library=WORK nolist;
	change 	
		    P_DR1IFF= DR1IFF_1720
			DR1IFF_L= DR1IFF_2123;
run;


*Importing FPED per 100g of FNDDS food code files
	FPEDS were downloaded in SAS format and saved directly to library then double click to extract
	Example file name: FPED_1718_sas.exe 
	These files list each FPED value per 100 g of each FNDDS food code available in that data cycle
	Found at this link under "databases and SAS datasets" > first file under each NHANES cycle
			https://www.ars.usda.gov/northeast-area/beltsville-md-bhnrc/beltsville-human-nutrition-
			research-center/food-surveys-research-group/docs/fped-databases/

*Importing FPED IFF files
	FPEDs were downloaded in SAS format and saved directly to library then double click to extract
	These files list each food reported by seqn, so multiple lines of data per seqn
	Found at this link under "databases and SAS datasets" > Food Patterns equivalents for foods in the WWEIA, NHANES cycle > FPED DR1IFF:
			https://www.ars.usda.gov/northeast-area/beltsville-md-bhnrc/beltsville-human-nutrition
			-research-center/food-surveys-research-group/docs/fped-databases/

*Importing WWEIA food group files
	These files list food code, food description, category number, category description, and # of reports per day
	WWEIA Food categories for each cycle found here, second link (excel file) under "Files" for each survey cycle at: 
			https://www.ars.usda.gov/northeast-area/beltsville-md-bhnrc/
			beltsville-human-nutrition-research-center/food-surveys-research-group/docs/dmr-food-categories/
	These files are in excel format, save the first sheet as CSV to import using the following code;

%macro WWEIA (cycle);
PROC IMPORT OUT= WORK.WWEIA&cycle 
     DATAFILE= "&path.\in\WWEIA&cycle._foodcat_FNDDS.csv" 
     DBMS=CSV REPLACE;
     GETNAMES=YES;
     DATAROW=2; 
RUN;

%mend;

*** CHANGED: cycles. Save the WWEIA food category file for each release as
    WWEIA1720_foodcat_FNDDS.csv and WWEIA2123_foodcat_FNDDS.csv;
%WWEIA (1720);
%WWEIA (2123);


*Importing demographic files
	Demo files are in XPT format and contain weights and survey specific criteria needed for analyses
	Files found here: https://wwwn.cdc.gov/nchs/nhanes/Search/DataPage.aspx?Component=Demographics;
*** CHANGED: full file name, same reason as the IFF macro (P_DEMO vs DEMO_L);
%macro DEMO (file);
libname XPDEMO xport "&path.\in\&file..XPT"; 
	proc copy in=XPDEMO out=WORK;
run;
libname XPDEMO clear;
%mend;

%DEMO (P_DEMO);
%DEMO (DEMO_L);


*Rename datafiles;
proc datasets library=WORK nolist;
	change 	
		    P_DEMO= demo_1720
			DEMO_L= demo_2123;
run;

*Importing Additional food code descriptions and Ingredients
		Files found here as a zip-like file of multiple files from access:
			https://www.ars.usda.gov/northeast-area/beltsville-md-bhnrc/beltsville-human-nutrition-research-center/
			food-surveys-research-group/docs/fndds-download-databases/
		The files have the same name for most cycles so download first to a new data folder and change the names
		Addfooddesc=additional food descriptions and either fnddsrlink or fnddsingred=ingredients depending on cycle
		These files were downloaded and manually exported from access to excel to CSV then to SAS below;

%macro ADDDESCR (cycle);

/*PROC IMPORT OUT= AddFoodDesc_&cycle */
/*     DATAFILE= "&path.\in\addfooddesc_&cycle..csv" */
/*     DBMS=CSV REPLACE;*/
/*     GETNAMES=YES;*/
/*     DATAROW=2; */

/*PROC IMPORT OUT= FNDDSingred_&cycle */
/*     DATAFILE= "&path.\in\fnddsingred_&cycle..csv" */
/*     DBMS=CSV REPLACE;*/
/*     GETNAMES=YES;*/
/*     DATAROW=2; */
/*RUN;*/

DATA AddFoodDesc_&cycle;
SET IN.addfooddesc_&cycle;
RUN;

DATA FNDDSingred_&cycle;
SET IN.fnddsingred_&cycle;
RUN;

%mend;

*** CHANGED: cycles. Save the FNDDS files matching each release in the IN library as
    addfooddesc_1720, fnddsingred_1720, addfooddesc_2123 and fnddsingred_2123;
%ADDDESCR (1720);
%ADDDESCR (2123);



**************************************************
   3. Preparing data files to merge which includes
       checking consistency of variable names
**************************************************

*Run the code for the cycles of interest-- this section does not have a macro due to inconsistencies across cycles;

*************
****2017-Mar 2020****
************;
*** CHANGED: new block for cycle 1720. Read every PROC CONTENTS output: if a column has a different name
    in this release (e.g. food_code vs Food_code, Ingredient_description), fix the rename= to match;

*1720 FPED IFF;
proc contents data=in.fped_dr1iff_1720 varnum; 
run;
data fped_dr1iff_1720;
	set in.fped_dr1iff_1720 (rename=(DR1IFDCD=FOODCODE));
run;

*1720 WWEIA;
proc contents data=WWEIA1720 varnum; 
run;
data WWEIA1720;
	set WWEIA1720 (rename=(food_code=FOODCODE));
run;

*1720 Additional food code descriptions;
proc contents data=addfooddesc_1720; 
run;
data Add_1720;
	set addfooddesc_1720 (rename=(food_code=FOODCODE));
run;
proc contents data= Add_1720 varnum;
run;

*1720 Ingredient file;
proc contents data=fnddsingred_1720; 
run;
data Ing_1720;
	set fnddsingred_1720 (rename=(Ingredient_description=INGREDIENTS Food_code=FOODCODE));
run;
proc contents data= Ing_1720 varnum;
run;

*1720 NHANES IFF;
*** CHANGED: in the pre-pandemic file the dietary weights are named WTDRD1PP and WTDR2DPP.
    They are renamed to WTDRD1 and WTDR2D so both cycles share one weight variable after appending;
data dr1iff_1720;
	set dr1iff_1720 (rename=(DR1IFDCD=FOODCODE WTDRD1PP=WTDRD1 WTDR2DPP=WTDR2D));
run;


*************
****2021-2023****
************;
*** CHANGED: new block for cycle 2123. Read every PROC CONTENTS output: if a column has a different name
    in this release (e.g. food_code vs Food_code, Ingredient_description), fix the rename= to match;

*2123 FPED IFF;
*** TEMPORARY: no FPED DR1IFF file exists for 2021-2023 yet. It is built further down, after the
    NHANES IFF block, from the 2017-2020 FPED per-100 g file (in.fped_1720);

*2123 WWEIA;
proc contents data=WWEIA2123 varnum; 
run;
data WWEIA2123;
	set WWEIA2123 (rename=(food_code=FOODCODE));
run;

*2123 Additional food code descriptions;
proc contents data=addfooddesc_2123; 
run;
data Add_2123;
	set addfooddesc_2123 (rename=(food_code=FOODCODE));
run;
proc contents data= Add_2123 varnum;
run;

*2123 Ingredient file;
proc contents data=fnddsingred_2123; 
run;
data Ing_2123;
	set fnddsingred_2123 (rename=(Ingredient_description=INGREDIENTS Food_code=FOODCODE));
run;
proc contents data= Ing_2123 varnum;
run;

*2123 NHANES IFF;
data dr1iff_2123;
	set dr1iff_2123 (rename=(DR1IFDCD=FOODCODE));
run;

*** TEMPORARY: build an FPED individual foods file for 2021-2023 from the 2017-2020 FPED.
    Each 2021-2023 food is matched by FOODCODE to the 2017-2020 per-100 g values, and each
    food pattern component is scaled by grams eaten:  DR1I_X = X * DR1IGRMS / 100.
    Run PROC CONTENTS on in.fped_1720 first: if its components are not named F_CITMLB, PF_MEAT
    and so on (without the DR1I_ prefix), change the per100 array below to match;
proc contents data=in.fped_1720 varnum;
run;

proc sort data=dr1iff_2123 (keep=SEQN DR1ILINE FOODCODE DR1IGRMS) out=iff2123_foods;
	by FOODCODE;
run;
proc sort data=in.fped_1720 out=fped100_1720;
	by FOODCODE;
run;

data fped_dr1iff_2123;
	merge iff2123_foods (in=a) fped100_1720 (in=b drop=DESCRIPTION);
	by FOODCODE;
	if a;
	FPED_MATCH = b;
	array per100 {37} F_CITMLB F_OTHER F_JUICE F_TOTAL
		V_DRKGR V_REDOR_TOMATO V_REDOR_OTHER V_REDOR_TOTAL
		V_STARCHY_POTATO V_STARCHY_OTHER V_STARCHY_TOTAL V_OTHER V_TOTAL V_LEGUMES
		G_WHOLE G_REFINED G_TOTAL
		PF_MEAT PF_CUREDMEAT PF_ORGAN PF_POULT PF_SEAFD_HI PF_SEAFD_LOW PF_MPS_TOTAL
		PF_EGGS PF_SOY PF_NUTSDS PF_LEGUMES PF_TOTAL
		D_MILK D_YOGURT D_CHEESE D_TOTAL
		OILS SOLID_FATS ADD_SUGARS A_DRINKS;
	array perfood {37} DR1I_F_CITMLB DR1I_F_OTHER DR1I_F_JUICE DR1I_F_TOTAL
		DR1I_V_DRKGR DR1I_V_REDOR_TOMATO DR1I_V_REDOR_OTHER DR1I_V_REDOR_TOTAL
		DR1I_V_STARCHY_POTATO DR1I_V_STARCHY_OTHER DR1I_V_STARCHY_TOTAL DR1I_V_OTHER DR1I_V_TOTAL DR1I_V_LEGUMES
		DR1I_G_WHOLE DR1I_G_REFINED DR1I_G_TOTAL
		DR1I_PF_MEAT DR1I_PF_CUREDMEAT DR1I_PF_ORGAN DR1I_PF_POULT DR1I_PF_SEAFD_HI DR1I_PF_SEAFD_LOW DR1I_PF_MPS_TOTAL
		DR1I_PF_EGGS DR1I_PF_SOY DR1I_PF_NUTSDS DR1I_PF_LEGUMES DR1I_PF_TOTAL
		DR1I_D_MILK DR1I_D_YOGURT DR1I_D_CHEESE DR1I_D_TOTAL
		DR1I_OILS DR1I_SOLID_FATS DR1I_ADD_SUGARS DR1I_A_DRINKS;
	do i = 1 to 37;
		if FPED_MATCH then perfood{i} = per100{i} * DR1IGRMS / 100;
		else perfood{i} = .;
	end;
	keep SEQN DR1ILINE FOODCODE DR1IGRMS FPED_MATCH DR1I_: ;
run;

*** TEMPORARY: how much of 2021-2023 intake has no 2017-2020 FPED match.
    Check both the share of foods and the share of grams that are unmatched;
proc freq data=fped_dr1iff_2123;
	tables FPED_MATCH;
run;
proc means data=fped_dr1iff_2123 sum;
	class FPED_MATCH;
	var DR1IGRMS;
run;

*** TEMPORARY: list the unmatched food codes, most often reported first, so you can see whether
    any are meat or poultry items (these would be missed by the processed meat rules);
proc sql;
	create table unmatched_2123 as
	select FOODCODE, count(*) as n_reports, sum(DR1IGRMS) as total_grams
	from fped_dr1iff_2123
	where FPED_MATCH = 0
	group by FOODCODE
	order by n_reports desc;
quit;


*Foodcode variable across cycles are now consistently named and files can be merged as needed;


**************************************************************
4.  Isolating additional food code descriptions and ingredients
**************************************************************
This macro will transpose addititional foodcode descriptions and then reaggregate
text into one cell in order to text-mine later on;

%macro Add_descriptions (cycle);

PROC TRANSPOSE DATA = Add_&cycle
 OUT = Add_&cycle._T; 
 BY FOODCODE;
 VAR Additional_food_description;
RUN;

data Add_&cycle._T1;
	set Add_&cycle._T;
	length cat $2000.;
 	*** CHANGED: OF COL: uses every transposed column, not just the first 23, so long lists are not cut off;
 	cat=catx(',', of COL:);
run;

data Add_&cycle._T1;
	set Add_&cycle._T1 (rename=(cat=ADDL_DESCR));
	run;

data Add_&cycle._T1;
	set Add_&cycle._T1 (keep=ADDL_DESCR foodcode);
run;

%mend;

*** CHANGED: cycles;
%Add_descriptions (1720);
%Add_descriptions (2123);

*Additional descriptions should now be listed in one cell for each foodcode across cycles


*This is the same macro above but for ingredients;
%macro Ingredients (cycle);
PROC TRANSPOSE DATA = Ing_&cycle
 OUT = Ing_&cycle._T; 
 BY FOODCODE;
 VAR Ingredients;
RUN;

data Ing_&cycle._T1;
	set Ing_&cycle._T;
	length cat $2000.;
 	*** CHANGED: OF COL: uses every transposed column, not just the first 23, so long lists are not cut off;
 	cat=catx(',', of COL:);
run; 
data Ing_&cycle._T1;
	set Ing_&cycle._T1 (rename=(cat=Ing));
	run;

data Ing_&cycle._T1;
	set Ing_&cycle._T1 (keep=Ing foodcode);
run;

data Ing_&cycle._T1;
	set Ing_&cycle._T1 (rename= (Ing=INGREDIENTS));
run;

%mend;

*This code will run the macro above for all cycles listed;
*** CHANGED: cycles;
%Ingredients (1720);
%Ingredients (2123);

*Ingredients should now be listed in one cell for each foodcode across cycles


*****************************************************************************
5. Merge WWEIA, ingredients, additional descriptions, and FPEDS/100g by cycle
*****************************************************************************

These data are at the food code-level, not participant-level. They are merged by food code.;

*** TEMPORARY: added fped= so 2021-2023 can use the 2017-2020 FPED per-100 g file (and its descriptions).
    When the new FPED is out, remove fped=1720 from the 2123 call below;
%macro WAIP (cycle, fped=&cycle);

proc sort data=WWEIA&cycle; by FOODCODE;
run;
proc sort data=ADD_&cycle._T1; by FOODCODE;
run;
proc sort data=Ing_&cycle._T1; by FOODCODE;
run;
proc sort data=in.fped_&fped; by FOODCODE;
run;
data W_A_I_P&cycle;
	merge WWEIA&cycle ADD_&cycle._T1 Ing_&cycle._T1 in.fped_&fped; 
	by FOODCODE;
	keep FOODCODE DESCRIPTION ADDL_DESCR INGREDIENTS category_number category_description;
run;

%mend;

*** CHANGED: cycles;
%WAIP (1720);
%WAIP (2123, fped=1720);  *** TEMPORARY;

**********************************************************
6. Merge demographics, FPED IFF, NHANES IFF day 1 by seqn
**********************************************************;

*These datafiles are on the participant-level. They are merged by participant ID 'seqn'.;

%macro FPEDDEMO (cycle);

proc sort data=fped_dr1iff_&cycle OUT=fped&cycle; 
	by seqn foodcode; 
run;

proc sort data=dr1iff_&cycle OUT=iff&cycle; 
	by seqn foodcode; 
run;

data FPED_IFF&cycle;
	merge fped&cycle iff&cycle;
	by seqn foodcode;
run;


proc sort data=demo_&cycle OUT=demo&cycle; 
	by seqn; 
run;

data FPED_DEMO&cycle;
	merge FPED_IFF&cycle demo&cycle;
	by seqn;
run;

%mend;

*** CHANGED: cycles;
%FPEDDEMO (1720);
%FPEDDEMO (2123);


************************************************
7. Combine all datafiles for each cycle
************************************************;

*Combine food code-level data and participant-level data by foodcode.;

%macro CYCLEDATA (cycle);
data W_A_I_P&cycle._1;
	set W_A_I_P&cycle;
	run;

proc sort data=W_A_I_P&cycle._1 OUT=WAIP&cycle; 
	by foodcode ; 
run;

proc sort data=FPED_DEMO&cycle OUT=FD&cycle; 
	by foodcode; 
run;

data data&cycle;
	merge WAIP&cycle FD&cycle;
	by foodcode ;
run;

%mend;

*** CHANGED: cycles;
%CYCLEDATA (1720);
%CYCLEDATA (2123);

*********************************
8. Append all cycles of interest
*********************************;
*** CHANGED: cycles. The LENGTH statement stops SAS from truncating DESCRIPTION / INGREDIENTS text
    to the shorter length used in the first file, which would break the word searches in step 9;
data cycles_day1;
	length DESCRIPTION $500 ADDL_DESCR INGREDIENTS $2000 category_description $200;
	set data1720 data2123;
	run;


***********************************
9. Apply meat code to day 1 data
***********************************;
	
data out.meat_day1;
	set cycles_day1 ;

	if DR1I_PF_CUREDMEAT>0 then select;
		
	*Beef, excludes ground;
		when (category_number=2002) do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*1), 0.01); 
			cured_poultry =0; 		end;

	*Ground beef;
		when (category_number=2004) do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*1), 0.01); 
			cured_poultry =0; 		end;

	*Pork;
		when (category_number=2006) do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*1), 0.01); 
			cured_poultry =0; 		end;

	*Lamb, goat, game;
		when (category_number=2008) do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*1), 0.01); 
			cured_poultry =0; 		end;

	*Chicken, whole pieces;
		when (category_number=2202) 	 do;
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01); end;

	*Chicken patties, nuggets, and tenders;
		when (category_number=2204) 	 do;
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01); end; 

	*Turkey, duck, and other poultry;
		when (category_number=2206) 	 do;
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01); end;
	
	*Eggs and omelettes- DESCRIPTION;
		when (category_number=2502 AND find(DESCRIPTION,'turkey','i')ge 1) do;  
    		cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01); 								   end;

		when (category_number=2502 AND find(DESCRIPTION,'chicken','i')ge 1) do;
    		cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01); 
																			end;				  
	*Cold cuts and cured meat- DESCRIPTION;
		when (category_number=2602 AND find(DESCRIPTION,'meat','i', 1) AND find(ADDL_DESCR,'poultry','i', 1) ge 1) do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 	end;											

		when (category_number=2602 AND find(DESCRIPTION,'chicken', 'i', 1)  AND find(DESCRIPTION,'beef', 'i', 1) AND find(DESCRIPTION,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number=2602 AND find(DESCRIPTION,'chicken', 'i', 1)   AND find(DESCRIPTION,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=2602 AND find(DESCRIPTION,'chicken', 'i', 1)   AND find(DESCRIPTION,'beef', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=2602 AND find(DESCRIPTION,'chicken', 'i', 1)  ge 1) do; 
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01);		  end;

		when (category_number=2602 AND find(DESCRIPTION,'turkey', 'i', 1)  AND find(DESCRIPTION,'beef', 'i', 1) AND find(DESCRIPTION,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number=2602 AND find(DESCRIPTION,'turkey', 'i', 1)   AND find(DESCRIPTION,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=2602 AND find(DESCRIPTION,'turkey', 'i', 1)   AND find(DESCRIPTION,'beef', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=2602 AND find(DESCRIPTION,'turkey', 'i', 1)  ge 1) do; 
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01);		  end;
		 
	*Bacon- DESCRIPTION;
		when (category_number=2604 AND find(DESCRIPTION,'turkey','i') ge 1) do;
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01); 									end; 

		when (category_number=2604 AND find(DESCRIPTION,'chicken','i') ge 1) do;
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01); 									end;


	*Frankfurters- DESCRIPTION & ADDL_DESCR;
		
		when (category_number=2606 AND find(DESCRIPTION,'meat','i', 1) AND find(DESCRIPTION,'poultry','i', 1) ge 1) do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 	end;

		when (category_number=2606 AND find(DESCRIPTION,'chicken', 'i', 1)  AND find(DESCRIPTION,'beef', 'i', 1) AND find(DESCRIPTION,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number=2606 AND find(DESCRIPTION,'chicken', 'i', 1)   AND find(DESCRIPTION,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=2606 AND find(DESCRIPTION,'chicken', 'i', 1)   AND find(DESCRIPTION,'beef', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=2606 AND find(DESCRIPTION,'chicken', 'i', 1)  ge 1) do; 
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01);		  end;

		when (category_number=2606 AND find(DESCRIPTION,'turkey', 'i', 1)  AND find(DESCRIPTION,'beef', 'i', 1) AND find(DESCRIPTION,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number=2606 AND find(DESCRIPTION,'turkey', 'i', 1)   AND find(DESCRIPTION,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=2606 AND find(DESCRIPTION,'turkey', 'i', 1)   AND find(DESCRIPTION,'beef', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=2606 AND find(DESCRIPTION,'turkey', 'i', 1)  ge 1) do; 
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01);		  end;
		 
				when (category_number=2606 AND find(ADDL_DESCR,'meat','i', 1) AND find(ADDL_DESCR,'poultry','i', 1) ge 1) do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 	end;

		when (category_number=2606 AND find(ADDL_DESCR,'chicken', 'i', 1)  AND find(ADDL_DESCR,'beef', 'i', 1) AND find(ADDL_DESCR,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number=2606 AND find(ADDL_DESCR,'chicken', 'i', 1)   AND find(ADDL_DESCR,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=2606 AND find(ADDL_DESCR,'chicken', 'i', 1)   AND find(ADDL_DESCR,'beef', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=2606 AND find(ADDL_DESCR,'chicken', 'i', 1)  ge 1) do; 
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01);		  end;

		when (category_number=2606 AND find(ADDL_DESCR,'turkey', 'i', 1)  AND find(ADDL_DESCR,'beef', 'i', 1) AND find(ADDL_DESCR,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number=2606 AND find(ADDL_DESCR,'turkey', 'i', 1)   AND find(ADDL_DESCR,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=2606 AND find(ADDL_DESCR,'turkey', 'i', 1)   AND find(ADDL_DESCR,'beef', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=2606 AND find(ADDL_DESCR,'turkey', 'i', 1)  ge 1) do; 
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01);		  end;

	*Bacon- DESCRIPTION;
		when (category_number=2604 AND find(DESCRIPTION,'turkey','i') ge 1) do;
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01); 									end; 

		when (category_number=2604 AND find(DESCRIPTION,'chicken','i') ge 1) do;
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01); 									end;
			
	*Sausages- DESCRIPTION & ADDITIOANL DESCRIPTION;		 

	when (category_number=2608 AND find(DESCRIPTION,'meat','i', 1) AND find(DESCRIPTION,'poultry','i', 1) ge 1) do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 	end;

		when (category_number=2608 AND find(DESCRIPTION,'chix','i') ge 1) do;
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01); 									 end;

		when (category_number=2608 AND find(DESCRIPTION,'chicken', 'i', 1)  AND find(DESCRIPTION,'beef', 'i', 1) AND find(DESCRIPTION,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number=2608 AND find(DESCRIPTION,'chicken', 'i', 1)   AND find(DESCRIPTION,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=2608 AND find(DESCRIPTION,'chicken', 'i', 1)   AND find(DESCRIPTION,'beef', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=2608 AND find(DESCRIPTION,'chicken', 'i', 1)  ge 1) do; 
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01);		  end;

		when (category_number=2608 AND find(DESCRIPTION,'turkey', 'i', 1)  AND find(DESCRIPTION,'beef', 'i', 1) AND find(DESCRIPTION,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number=2608 AND find(DESCRIPTION,'turkey', 'i', 1)   AND find(DESCRIPTION,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=2608 AND find(DESCRIPTION,'turkey', 'i', 1)   AND find(DESCRIPTION,'beef', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=2608 AND find(DESCRIPTION,'turkey', 'i', 1)  ge 1) do; 
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01);		  end;

		
	when (category_number=2608 AND find(ADDL_DESCR,'meat','i', 1) AND find(ADDL_DESCR,'poultry','i', 1) ge 1) do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 	end;

		when (category_number=2608 AND find(ADDL_DESCR,'chix','i') ge 1) do;
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01); 									 end;

		when (category_number=2608 AND find(ADDL_DESCR,'chicken', 'i', 1)  AND find(ADDL_DESCR,'beef', 'i', 1) AND find(ADDL_DESCR,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number=2608 AND find(ADDL_DESCR,'chicken', 'i', 1)   AND find(ADDL_DESCR,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=2608 AND find(ADDL_DESCR,'chicken', 'i', 1)   AND find(ADDL_DESCR,'beef', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=2608 AND find(ADDL_DESCR,'chicken', 'i', 1)  ge 1) do; 
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01);		  end;

		when (category_number=2608 AND find(ADDL_DESCR,'turkey', 'i', 1)  AND find(ADDL_DESCR,'beef', 'i', 1) AND find(ADDL_DESCR,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number=2608 AND find(ADDL_DESCR,'turkey', 'i', 1)   AND find(ADDL_DESCR,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=2608 AND find(ADDL_DESCR,'turkey', 'i', 1)   AND find(ADDL_DESCR,'beef', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=2608 AND find(ADDL_DESCR,'turkey', 'i', 1)  ge 1) do; 
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01);		  end;


	*Beans, peas, and legumes;
		when (category_number=2802) do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*1), 0.01); 
			cured_poultry =0; 		end;
		
	*Mixed meat dishes- INGREDIENTS;
		when (category_number=3002 AND DR1I_PF_MEAT=0 AND DR1I_PF_POULT=0 AND find(INGREDIENTS,'chicken, canned', 'i', 1) AND find(INGREDIENTS,'beef', 'i', 1) AND find(INGREDIENTS,'pork', 'i', 1)ge 1) do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.33), 0.01); 		end;

		when (category_number=3002 AND DR1I_PF_MEAT=0 AND DR1I_PF_POULT=0 AND find(INGREDIENTS,'canned, chicken', 'i', 1) AND find(INGREDIENTS,'beef', 'i', 1) AND find(INGREDIENTS,'pork', 'i', 1) ge 1) do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.33), 0.01); 		end;

		when (category_number=3002 AND DR1I_PF_MEAT=0 AND DR1I_PF_POULT=0 AND find(INGREDIENTS,'chicken, canned', 'i', 1) AND find(INGREDIENTS,'beef', 'i', 1) ge 1) do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 		end;

		when (category_number=3002 AND DR1I_PF_MEAT=0 AND DR1I_PF_POULT=0 AND find(INGREDIENTS,'chicken, canned', 'i', 1)  AND find(INGREDIENTS,'pork', 'i', 1) ge 1) do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 		end;

		when (category_number=3002 AND DR1I_PF_MEAT=0 AND DR1I_PF_POULT=0 AND find(INGREDIENTS,'canned, chicken', 'i', 1) AND find(INGREDIENTS,'beef', 'i', 1) ge 1) do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 		end;

		when (category_number=3002 AND DR1I_PF_MEAT=0 AND DR1I_PF_POULT=0 AND find(INGREDIENTS,'canned, chicken', 'i', 1) AND find(INGREDIENTS,'pork', 'i', 1) ge 1) do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 		end;

	*Mixed poultry dishes- INGREDIENTS;
		when (category_number=3004 AND DR1I_PF_POULT=0) do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*1), 0.01); 
			cured_poultry =0; 	  end;

	*Mixed seafood dishes- INGREDIENTS;
		when (category_number=3006 AND DR1I_PF_POULT=0 AND find(INGREDIENTS,'chicken, canned', 'i', 1) ge 1) do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 		end;

		when (category_number=3006 AND  DR1I_PF_POULT=0 AND find(INGREDIENTS,'canned, chicken', 'i', 1) ge 1) do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 		end;

	*Mixed rice dishes- INGREDIENTS;
		when (category_number=3202 AND DR1I_PF_MEAT=0 AND DR1I_PF_POULT=0 AND find(INGREDIENTS,'chicken, canned', 'i', 1) AND find(INGREDIENTS,'beef', 'i', 1) AND find(INGREDIENTS,'pork', 'i', 1)ge 1) do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.33), 0.01); 		end;

		when (category_number=3202 AND DR1I_PF_MEAT=0 AND DR1I_PF_POULT=0 AND find(INGREDIENTS,'canned, chicken', 'i', 1) AND find(INGREDIENTS,'beef', 'i', 1) AND find(INGREDIENTS,'pork', 'i', 1) ge 1) do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.33), 0.01); 		end;

		when (category_number=3202 AND DR1I_PF_MEAT=0 AND DR1I_PF_POULT=0 AND find(INGREDIENTS,'chicken, canned', 'i', 1) AND find(INGREDIENTS,'beef', 'i', 1) ge 1) do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 		end;

		when (category_number=3202 AND DR1I_PF_MEAT=0 AND DR1I_PF_POULT=0 AND find(INGREDIENTS,'chicken, canned', 'i', 1)  AND find(INGREDIENTS,'pork', 'i', 1) ge 1) do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 		end;

		when (category_number=3202 AND DR1I_PF_MEAT=0 AND DR1I_PF_POULT=0 AND find(INGREDIENTS,'canned, chicken', 'i', 1) AND find(INGREDIENTS,'beef', 'i', 1) ge 1) do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 		end;

		when (category_number=3202 AND DR1I_PF_MEAT=0 AND DR1I_PF_POULT=0 AND find(INGREDIENTS,'canned, chicken', 'i', 1) AND find(INGREDIENTS,'pork', 'i', 1) ge 1) do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 		end;

		*Frankfurer sandwiches- DESCRIPTION;
		when (category_number=3703 AND find(DESCRIPTION,'meat','i', 1) AND find(DESCRIPTION,'poultry','i', 1) ge 1) do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 	end;

		when (category_number=3703 AND find(DESCRIPTION,'chicken', 'i', 1)  AND find(DESCRIPTION,'beef', 'i', 1) AND find(DESCRIPTION,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number=3703 AND find(DESCRIPTION,'chicken', 'i', 1)   AND find(DESCRIPTION,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=3703 AND find(DESCRIPTION,'chicken', 'i', 1)   AND find(DESCRIPTION,'beef', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=3703 AND find(DESCRIPTION,'chicken', 'i', 1)  ge 1) do; 
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01);		  end;

		when (category_number=3703 AND find(DESCRIPTION,'turkey', 'i', 1)  AND find(DESCRIPTION,'beef', 'i', 1) AND find(DESCRIPTION,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number=3703 AND find(DESCRIPTION,'turkey', 'i', 1)   AND find(DESCRIPTION,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=3703 AND find(DESCRIPTION,'turkey', 'i', 1)   AND find(DESCRIPTION,'beef', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=3703 AND find(DESCRIPTION,'turkey', 'i', 1)  ge 1) do; 
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01);		  end;
		 
		when (category_number=3703 AND find(ADDL_DESCR,'meat','i', 1) AND find(ADDL_DESCR,'poultry','i', 1) ge 1) do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 	end;

		when (category_number=3703 AND find(ADDL_DESCR,'chicken', 'i', 1)  AND find(ADDL_DESCR,'beef', 'i', 1) AND find(ADDL_DESCR,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number=3703 AND find(ADDL_DESCR,'chicken', 'i', 1)   AND find(ADDL_DESCR,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=3703 AND find(ADDL_DESCR,'chicken', 'i', 1)   AND find(ADDL_DESCR,'beef', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=3703 AND find(ADDL_DESCR,'chicken', 'i', 1)  ge 1) do; 
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01);		  end;

		when (category_number=3703 AND find(ADDL_DESCR,'turkey', 'i', 1)  AND find(ADDL_DESCR,'beef', 'i', 1) AND find(ADDL_DESCR,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number=3703 AND find(ADDL_DESCR,'turkey', 'i', 1)   AND find(ADDL_DESCR,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=3703 AND find(ADDL_DESCR,'turkey', 'i', 1)   AND find(ADDL_DESCR,'beef', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=3703 AND find(ADDL_DESCR,'turkey', 'i', 1)  ge 1) do; 
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01);		  end;


	*Chicken/turkey sandwich- INGREDIENTS;
		when (DR1I_PF_POULT=0 AND category_number=3704 AND find(INGREDIENTS,'chicken', 'i', 1) AND find(INGREDIENTS,'pork', 'i', 1) ge 1)  do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 			end;

		when (DR1I_PF_POULT=0 AND category_number=3704 AND find(INGREDIENTS,'turkey', 'i', 1) AND find(INGREDIENTS,'pork', 'i', 1) ge 1)  do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 			end;

		when (DR1I_PF_POULT=0 AND category_number=3704 AND find(INGREDIENTS,'chicken', 'i', 1) AND find(INGREDIENTS,'beef', 'i', 1) ge 1)  do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 			end;

		when (DR1I_PF_POULT=0 AND category_number=3704 AND find(INGREDIENTS,'turkey', 'i', 1) AND find(INGREDIENTS,'beef', 'i', 1) ge 1)  do;
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 			end;

		when (DR1I_PF_POULT=0 AND category_number=3704 AND find(INGREDIENTS,'chicken', 'i', 1) ge 1)  do;
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01); 			end;

		when (DR1I_PF_POULT=0 AND category_number=3704 AND find(INGREDIENTS,'turkey', 'i', 1) ge 1)  do;
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01); 			end;


	*Egg/breakfast sandwich- INGREDIENTS;
		when (category_number=3706 AND find(INGREDIENTS,'turkey','i')ge 1) do;  
    		cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01); 								  end;
		
		when (category_number=3706 AND find(INGREDIENTS,'chicken','i')ge 1) do;
    		cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01);							 		end;

	*Other sandwiches- INGREDIENTS;
		when (category_number=3708 AND  find(INGREDIENTS,'chicken', 'i', 1)  AND find(INGREDIENTS,'beef', 'i', 1) AND find(INGREDIENTS,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number=3708 AND find(INGREDIENTS,'chicken', 'i', 1)   AND find(INGREDIENTS,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=3708 AND find(INGREDIENTS,'chicken', 'i', 1)   AND find(INGREDIENTS,'beef', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=3708 AND find(INGREDIENTS,'chicken', 'i', 1)  ge 1) do; 
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01);		  end;

		when (category_number=3708 AND find(INGREDIENTS,'turkey', 'i', 1)  AND find(INGREDIENTS,'beef', 'i', 1) AND find(INGREDIENTS,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number=3708 AND find(INGREDIENTS,'turkey', 'i', 1)   AND find(INGREDIENTS,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=3708 AND find(INGREDIENTS,'turkey', 'i', 1)   AND find(INGREDIENTS,'beef', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=3708 AND find(INGREDIENTS,'turkey', 'i', 1)  ge 1) do; 
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01);		  end;

	*Egg/breakfast sandwich- INGREDIENTS;
		when (category_number=3706 AND find(INGREDIENTS,'turkey','i')ge 1) do;  
    		cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01); 								  end;
		
		when (category_number=3706 AND find(INGREDIENTS,'chicken','i')ge 1) do;
    		cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01);							 		end;

	*Pretzels/snack mix- INGREDIENTS;
		when (category_number=5008 AND  find(INGREDIENTS,'chicken', 'i', 1)  AND find(INGREDIENTS,'beef', 'i', 1) AND find(INGREDIENTS,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number=5008 AND find(INGREDIENTS,'chicken', 'i', 1)   AND find(INGREDIENTS,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=5008 AND find(INGREDIENTS,'chicken', 'i', 1)   AND find(INGREDIENTS,'beef', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=5008 AND find(INGREDIENTS,'chicken', 'i', 1)  ge 1) do; 
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01);		  end;

		when (category_number=5008 AND find(INGREDIENTS,'turkey', 'i', 1)  AND find(INGREDIENTS,'beef', 'i', 1) AND find(INGREDIENTS,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number=5008 AND find(INGREDIENTS,'turkey', 'i', 1)   AND find(INGREDIENTS,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=5008 AND find(INGREDIENTS,'turkey', 'i', 1)   AND find(INGREDIENTS,'beef', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=5008 AND find(INGREDIENTS,'turkey', 'i', 1)  ge 1) do; 
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01);		  end;

	*Mixed vegetable dishes- INGREDIENTS;
		when (category_number=6442 AND  find(INGREDIENTS,'chicken', 'i', 1)  AND find(INGREDIENTS,'beef', 'i', 1) AND find(INGREDIENTS,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number=6442 AND find(INGREDIENTS,'chicken', 'i', 1)   AND find(INGREDIENTS,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=6442 AND find(INGREDIENTS,'chicken', 'i', 1)   AND find(INGREDIENTS,'beef', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=6442 AND find(INGREDIENTS,'chicken', 'i', 1)  ge 1) do; 
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01);		  end;

		when (category_number=6442 AND find(INGREDIENTS,'turkey', 'i', 1)  AND find(INGREDIENTS,'beef', 'i', 1) AND find(INGREDIENTS,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number=6442 AND find(INGREDIENTS,'turkey', 'i', 1)   AND find(INGREDIENTS,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=6442 AND find(INGREDIENTS,'turkey', 'i', 1)   AND find(INGREDIENTS,'beef', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=6442 AND find(INGREDIENTS,'turkey', 'i', 1)  ge 1) do; 
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01);		  end;

		*Mixed vegetable dishes- INGREDIENTS;
		when (category_number=6802 AND  find(INGREDIENTS,'chicken', 'i', 1)  AND find(INGREDIENTS,'beef', 'i', 1) AND find(INGREDIENTS,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number=6802 AND find(INGREDIENTS,'chicken', 'i', 1)   AND find(INGREDIENTS,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=6802 AND find(INGREDIENTS,'chicken', 'i', 1)   AND find(INGREDIENTS,'beef', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=6802 AND find(INGREDIENTS,'chicken', 'i', 1)  ge 1) do; 
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01);		  end;

		when (category_number=6802 AND find(INGREDIENTS,'turkey', 'i', 1)  AND find(INGREDIENTS,'beef', 'i', 1) AND find(INGREDIENTS,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number=6802 AND find(INGREDIENTS,'turkey', 'i', 1)   AND find(INGREDIENTS,'pork', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=6802 AND find(INGREDIENTS,'turkey', 'i', 1)   AND find(INGREDIENTS,'beef', 'i', 1) ge 1) do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number=6802 AND find(INGREDIENTS,'turkey', 'i', 1)  ge 1) do; 
			cured_redmeat =0; 
			cured_poultry =Round((DR1I_PF_CUREDMEAT*1), 0.01);		  end;


*To note: The following WWEIA categories contain ham, pork, or bacon and
			are presumably all cured red meat according to the descriptive
			information used from FNDSS. These are not specifically coded into 
			the program above to save computing time.
				1602: Cheese
				3102: Bean, pea, legume dishes
				3104: Vegetable dishes
				3204: Pasta mixed dishes, excludes macaroni and cheese
				3206: Macaroni and cheese
				3208: Turnovers and other grain-based items
				3404: Stir-fry and soy-based sauce mixtures
				3502: Burritos and tacos
				3506: Other Mexican mixed dishes 
				3602: Pizza
				3702: Burgers (single code) 
				3802: Soups
				6411: Other dark green vegetables
				6430: Fried vegetables
				6804: French fries and other fried white potatoes
				6806: Mashed potatoes and white potato mixtures
				8012: Salad dressings and vegetable oils
				8406: Mustard and other condiments
				9008: Baby food: meat and dinners;

*All other DR1I_PF_CUREDMEAT defaults to cured red meat;
		otherwise do; 
			cured_redmeat =Round((DR1I_PF_CUREDMEAT*1), 0.01); 
			cured_poultry =0; 
			end; 	

	end; * for the first select statement;

*Default all else (i.e. not containing cured meat) to 0;
if DR1I_PF_CUREDMEAT=0 then do;
		cured_redmeat=0;
		cured_poultry=0;
		end;

*To create total processed poultry category;
if DR1I_PF_POULT>0 then select;
		when (category_number= 2204) do;
			Nug_Pat_Fil =Round((DR1I_PF_POULT*1), 0.01); 
			unproc_poultry=0; 
		end;

otherwise do;
		Nug_Pat_Fil =0; 
		unproc_poultry=Round((DR1I_PF_POULT*1), 0.01);
		end;

end; *select statement;

if DR1I_PF_POULT=0 then do;
	Nug_Pat_Fil =0; 
	unproc_poultry =0; 

		end;

*To create total red meat and total poultry categories;
	total_redmeat = Round((cured_redmeat  + DR1I_PF_MEAT), 0.01);
	total_poultry = Round((cured_poultry  + DR1I_PF_POULT), 0.01);
	total_proc_poultry= Round((cured_poultry  + Nug_Pat_Fil), 0.01);

*To create red and processed meat categories;
	Red_and_cured_1= Round((DR1I_PF_MEAT + DR1I_PF_CUREDMEAT), 0.01);
	Red_and_processed_2= Round((DR1I_PF_MEAT + DR1I_PF_CUREDMEAT + Nug_Pat_fil), 0.01);

	run;



*Label variables;
data out.meat_day1;
    set out.meat_day1;
    label DR1I_PF_meat        = 'Unprocessed red meat: Beef, veal, pork, lamb, and game meat; excludes organ meat and cured meat';
	label cured_redmeat       = 'Processed red meat: Component disaggregated from PF_Curedmeat, i.e. red meat preserved by smoking, curing, salting, and/or the addition of chemical preservatives';
	label total_redmeat       = 'Total red meat: Combination of PF_meat and cured_redmeat';
	label DR1I_PF_poult       = 'Unprocessed poultry: Chicken, turkey, Cornish hens, duck, goose, quail, and pheasant (game birds); excludes organ meat and cured meat';
	label cured_poultry       = 'Processed poultry: Component disaggregated from PF_Curedmeat, i.e. poultry preserved by smoking, curing, salting, and/or the addition of chemical preservatives';
	label total_proc_poultry  = 'Total processed poultry: Combination of cured_poultry and the WWEIA category of chicken patties, nuggets, and tenders';
	label unproc_poultry      = 'Unprocessed poultry minus chicken nuggets, patties, and fillets: Chicken, turkey, Cornish hens, duck, goose, quail, and pheasant (game birds); excludes organ meat, cured meat, and chicken nuggets, patties, and fillets';
	label total_poultry       = 'Total poultry: Combination of PF_poult and cured_poultry, includes chicken nuggets, patties, and fillets';
	label nug_pat_fil         = 'Chicken nuggets, patties, and fillets:	PF_poult from WWEIA category 2204';
	label DR1I_PF_curedmeat   = 'Total processed meat: Frankfurters, sausages, corned beef, cured ham and luncheon meat that are made from beef, pork, or poultry';
	label red_and_cured_1     =	'Red and cured meat: Combination of PF_meat + cured_redmeat + cured_poultry'; 
	label red_and_processed_2 = 'Red and processed meat: Combination of PF_meat + cured_redmeat + cured_poultry + chicken patties, nuggets, and tenders';
run;

***********************************************
10. Proc means to create meat intake totals
	for day 1 in a file called out.meat_day1
***********************************************;

	proc sort data=out.meat_day1;
	by seqn;
	run;


	PROC MEANS DATA=out.meat_day1 sum noprint;
	by seqn;
	where seqn>0;
	var DR1IGRMS
		DR1I_F_CITMLB
		DR1I_F_OTHER
		DR1I_F_JUICE
		DR1I_F_TOTAL
		DR1I_V_DRKGR
		DR1I_V_REDOR_TOMATO
		DR1I_V_REDOR_OTHER
		DR1I_V_REDOR_TOTAL
		DR1I_V_STARCHY_POTATO
		DR1I_V_STARCHY_OTHER
		DR1I_V_STARCHY_TOTAL
		DR1I_V_OTHER
		DR1I_V_TOTAL
		DR1I_V_LEGUMES
		DR1I_G_WHOLE
		DR1I_G_REFINED
		DR1I_G_TOTAL
		DR1I_PF_MEAT
		DR1I_PF_CUREDMEAT
		DR1I_PF_ORGAN
		DR1I_PF_POULT
		DR1I_PF_SEAFD_HI
		DR1I_PF_SEAFD_LOW
		DR1I_PF_MPS_TOTAL
		DR1I_PF_EGGS
		DR1I_PF_SOY
		DR1I_PF_NUTSDS
		DR1I_PF_LEGUMES
		DR1I_PF_TOTAL
		DR1I_D_MILK
		DR1I_D_YOGURT
		DR1I_D_CHEESE
		DR1I_D_TOTAL
		DR1I_OILS
		DR1I_SOLID_FATS
		DR1I_ADD_SUGARS
		DR1I_A_DRINKS
		cured_redmeat
		cured_poultry
		total_redmeat
		total_poultry
		unproc_poultry
		Nug_Pat_Fil
		total_proc_poultry
		Red_and_cured_1
		Red_and_processed_2
		DR1IKCAL
		DR1IPROT
		DR1ICARB
		DR1ISUGR
		DR1IFIBE
		DR1ITFAT
		DR1ISFAT
		DR1IMFAT
		DR1IPFAT
		DR1ICHOL
		DR1IATOC
		DR1IATOA
		DR1IRET
		DR1IVARA
		DR1IACAR
		DR1IBCAR
		DR1ICRYP
		DR1ILYCO
		DR1ILZ
		DR1IVB1
		DR1IVB2
		DR1INIAC
		DR1IVB6
		DR1IFOLA
		DR1IFA
		DR1IFF
		DR1IFDFE
		DR1ICHL
		DR1IVB12
		DR1IB12A
		DR1IVC
		DR1IVD
		DR1IVK
		DR1ICALC
		DR1IPHOS
		DR1IMAGN
		DR1IIRON
		DR1IZINC
		DR1ICOPP
		DR1ISODI
		DR1IPOTA
		DR1ISELE
		DR1ICAFF
		DR1ITHEO
		DR1IALCO
		DR1IMOIS
		DR1IS040
		DR1IS060
		DR1IS080
		DR1IS100
		DR1IS120
		DR1IS140
		DR1IS160
		DR1IS180
		DR1IM161
		DR1IM181
		DR1IM201
		DR1IM221
		DR1IP182
		DR1IP183
		DR1IP184
		DR1IP204
		DR1IP205
		DR1IP225
		DR1IP226;

	output out=out.meat_day1_sum  

	SUM=DR1IGRMS
		DR1I_F_CITMLB
		DR1I_F_OTHER
		DR1I_F_JUICE
		DR1I_F_TOTAL
		DR1I_V_DRKGR
		DR1I_V_REDOR_TOMATO
		DR1I_V_REDOR_OTHER
		DR1I_V_REDOR_TOTAL
		DR1I_V_STARCHY_POTATO
		DR1I_V_STARCHY_OTHER
		DR1I_V_STARCHY_TOTAL
		DR1I_V_OTHER
		DR1I_V_TOTAL
		DR1I_V_LEGUMES
		DR1I_G_WHOLE
		DR1I_G_REFINED
		DR1I_G_TOTAL
		DR1I_PF_MEAT
		DR1I_PF_CUREDMEAT
		DR1I_PF_ORGAN
		DR1I_PF_POULT
		DR1I_PF_SEAFD_HI
		DR1I_PF_SEAFD_LOW
		DR1I_PF_MPS_TOTAL
		DR1I_PF_EGGS
		DR1I_PF_SOY
		DR1I_PF_NUTSDS
		DR1I_PF_LEGUMES
		DR1I_PF_TOTAL
		DR1I_D_MILK
		DR1I_D_YOGURT
		DR1I_D_CHEESE
		DR1I_D_TOTAL
		DR1I_OILS
		DR1I_SOLID_FATS
		DR1I_ADD_SUGARS
		DR1I_A_DRINKS
		cured_redmeat
		cured_poultry
		total_redmeat
		total_poultry
		unproc_poultry
		Nug_Pat_Fil
		total_proc_poultry
		Red_and_cured_1
		Red_and_processed_2
		DR1IKCAL
		DR1IPROT
		DR1ICARB
		DR1ISUGR
		DR1IFIBE
		DR1ITFAT
		DR1ISFAT
		DR1IMFAT
		DR1IPFAT
		DR1ICHOL
		DR1IATOC
		DR1IATOA
		DR1IRET
		DR1IVARA
		DR1IACAR
		DR1IBCAR
		DR1ICRYP
		DR1ILYCO
		DR1ILZ
		DR1IVB1
		DR1IVB2
		DR1INIAC
		DR1IVB6
		DR1IFOLA
		DR1IFA
		DR1IFF
		DR1IFDFE
		DR1ICHL
		DR1IVB12
		DR1IB12A
		DR1IVC
		DR1IVD
		DR1IVK
		DR1ICALC
		DR1IPHOS
		DR1IMAGN
		DR1IIRON
		DR1IZINC
		DR1ICOPP
		DR1ISODI
		DR1IPOTA
		DR1ISELE
		DR1ICAFF
		DR1ITHEO
		DR1IALCO
		DR1IMOIS
		DR1IS040
		DR1IS060
		DR1IS080
		DR1IS100
		DR1IS120
		DR1IS140
		DR1IS160
		DR1IS180
		DR1IM161
		DR1IM181
		DR1IM201
		DR1IM221
		DR1IP182
		DR1IP183
		DR1IP184
		DR1IP204
		DR1IP205
		DR1IP225
		DR1IP226;

	*** CHANGED: shortened ID list. Many of the original demographic variables were dropped or renamed
	    in P_DEMO and DEMO_L, and PROC MEANS stops with an error if any ID variable is missing.
	    If you need other demographics, merge them back onto out.meat_day1_sum BY SEQN afterwards;
	ID RIAGENDR
		RIDAGEYR
		RIDRETH1
		RIDRETH3
		INDFMPIR
		SDMVPSU
		SDMVSTRA
		WTDRD1
		WTDR2D
		DR1DRSTZ
		DRABF
		DRDINT
		SDDSRVYR
		RIDSTATR
		DR1DAY;
run;


********************************************************
The final file is data.meat_day1_sum which has all FPEDs, 
the new FPED-aligned meat variables, all nutrient variables, 
and  all demographic variables summed across the day whole, 
i.e. one line of data per respondent
For mean intake analysis, this day 1 code can be used 
For usual intake analysis, continue to Meat day 2 file
See code below to create nutrient density variables
i.e. g of meat/1000 kcal consumed/participant
*******************************************************;

***********************************************
11. Options to check if the code ran properly
***********************************************;

*To check if the code ran properly, you can check data with USDA estimates for DR1I_PF_meat DR1I_PF_curedmeat  DR1I_PF_poult 
from the 'by Gender and Age' tables for 2+ years old across the various survey cycles from the website below:
https://www.ars.usda.gov/ARSUserFiles/80400530/pdf/fped/Table_1_FPED_GEN_1718.pdf

The nutrient density scores can also be crosschecked with the NCI's Cancer Trends Report
https://progressreport.cancer.gov/prevention/red_meat total_redmeat, and DR1I_PF_curedmeat click on the graph and download the CSV datafile;

	*** CHANGED: the data are sorted by SEQN, which puts cycle 66 before cycle 12, so BY SDDSRVYR
	    would fail. Sort by cycle first;
	proc sort data=out.meat_day1_sum; by sddsrvyr seqn; run;

	*Check against USDA values (published FPED tables for each release);
proc surveymeans data=out.meat_day1_sum nobs mean stderr ;
    strata SDMVSTRA;
    cluster SDMVPSU;
/*    domain INCOH;*/
	by sddsrvyr;
    var DR1I_PF_meat DR1I_PF_curedmeat  DR1I_PF_poult cured_redmeat total_redmeat nug_pat_fil unproc_poultry;
	weight WTDRD1;
 run;

	*** CHANGED: commented out. It needs a dataset called popratio and a variable INCOH, which this
	    program never creates (they come from the nutrient density code in the day 2 file);
/*	*Check against NCI values using the mean ratio i.e. mean of individual-level ratios;
proc surveymeans data= popratio nobs mean stderr ;
    strata SDMVSTRA;
    cluster SDMVPSU;
    domain INCOH;
	by sddsrvyr;
    var total_redmeat;
	weight WTDRD1;
	ratio 	 total_redmeat/DR1IKCAL;
 run;
*/

