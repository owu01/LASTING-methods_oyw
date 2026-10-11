*Processed Meat SAS Program of the US National Cancer Institute

FOR DAY 2 DIETARY RECALL DATA ONLY-- day 1 program called 'Meat Code day 1' 

Updated 7-21-21 by Lauren O'Connor

Day 2 data can be used to calibrate day 1 data in regression calibration to correct for
measurement error and estimate percentiles/distributions using the using the NCI method found here:
https://epi.grants.cancer.gov/diet/usualintakes/method.html

Variable created with this program include the following and can be found in the 'Meat Code day 1' file and citation below:

Files that results from this program include:
out.meat_day2:        participant-level data with all food codes reported per participant for day 1
				      i.e. individual food level, with multiple lines of intake per participant for day 1
out.meat_day2_sum:    participant-level data with all indidivual food codes summed across day 1
					  i.e. total intake level, with one line of intake per participant for day 1 
out.meat_usual_intake:participant-level data with all indidivual food codes summed across day 1 and then summed across day 2
					  i.e. two lines of intake data per person, one is total for day 1 and other is total for day 2 (if applicable)

Details of how decisions about how to disaggregate 'cured meat' into 'cured red meat' and 'cured poultry'
are described in detail in the O'Connor et al. manuscript [Citation TBA-- doi: 10.1093/jn/nxab316].

Questions?
Please contact the Risk Factor Assessment Branch at RFAB@mail.nih.gov. 


UPDATE FOR NHANES 2017-MARCH 2020 PRE-PANDEMIC (cycle label 1720) AND AUGUST 2021-AUGUST 2023 (cycle label 2123)
This is the NCI day 2 program, updated the same way as the day 1 program
(Processed_Meat_Day1_NHANES_2017-2023.sas). Day 2 variable names are kept as in the NCI original
(FOODCODE2, DESCRIPTION2, category_number2, cured_redmeat_day2, total_redmeat_day2 and so on).
Edits are flagged  *** CHANGED  and the temporary FPED workaround for 2021-2023 is flagged  *** TEMPORARY.

HOW TO RUN: run Processed_Meat_Day1_NHANES_2017-2023.sas first, in the SAS session, and then run this
program WITHOUT closing SAS. This program reuses WORK datasets made by the day 1 program
(W_A_I_P1720, W_A_I_P2123, demo_1720, demo_2123) and reads out.meat_day1_sum.

TEMPORARY WORKAROUND: there is no FPED for August 2021-August 2023 yet. Until it is released, the
2021-2023 day 2 foods are matched by food code to the 2017-2020 FPED per-100 g file and scaled by grams
eaten, as in the day 1 program. Food codes that are new in 2021-2023 get missing food pattern values.

*Steps of this SAS program for DAY 2
1. Run steps 1-5 from 'Meat code day 1' SAS program
2. Rename variables for day 2 in W_A_I_P files from day 1
3. Import NHANES IFF day 2 files
4. Rename day 2 foodcode variable in day 2 IFF files
5. Merge demographics, FPED IFF, NHANES IFF day 2 by seqn
6. Combine all datafiles for each cycle day 2
7. Append all cycles of interest
8. Cured meat code day 2
9. Proc means to total meat intakes for day 2
	file called meat_day2
10. Append day 1 and day 2 for usual intake
	file called meat_usualintake


*Create a library;
*** CHANGED: set your folder once here (the same path as in the day 1 program);
%let path = C:\GitHub\LASTING-methods_oyw\data_inputs\DIET\dietary_intake\CODE\Processed_Meat;
libname IN  "&path.\in";
libname OUT "&path.\out";

*********************************
1. Run steps 1-5 from Day 1 code
*********************************

Use the W_A_I_P files genereated from step 5 of the 'Meat code day 1' 


******************************************************
2. Rename day 2 variables for W_A_I_P files from day 1
******************************************************;
%macro RENAME (cycle);

data W_A_I_P&cycle._day2;
	set W_A_I_P&cycle (rename=(FOODCODE=FOODCODE2 
								DESCRIPTION = DESCRIPTION2
								ADDL_DESCR = ADDL_DESCR2
								INGREDIENTS = INGREDIENTS2
								category_number = category_number2
								category_description =category_description2));
run;

%mend;

*** CHANGED: cycles;
%RENAME (1720);
%RENAME (2123);


*************************************************
3. Import NHANES IFF day 2 files
*************************************************;
*** CHANGED: the macro now takes the full XPT file name (P_DR2IFF for 2017-March 2020,
    DR2IFF_L for 2021-2023). Put both files in the in folder;
%macro IFFTWO (file);
libname XPIFF2 xport "&path.\in\&file..XPT"; 
	proc copy in=XPIFF2 out=work;
run;
libname XPIFF2 clear;
%mend;

%IFFTWO (P_DR2IFF);
%IFFTWO (DR2IFF_L);

*Rename datafiles;
proc datasets library=WORK nolist;
	change 	
		    P_DR2IFF= DR2IFF_1720
			DR2IFF_L= DR2IFF_2123;
run;


*****************************************************
4. Rename day 2 foodcode variable in day 2 IFF files
****************************************************;
*** CHANGED: no macro here, because the two cycles need different steps;

*2017-March 2020 FPED day 2 IFF;
proc contents data=in.fped_dr2iff_1720 varnum;
run;
data fped_dr2iff_1720;
	set in.fped_dr2iff_1720 (rename=(DR2IFDCD=FOODCODE2));
run;

*2017-March 2020 NHANES day 2 IFF;
*** CHANGED: the pre-pandemic dietary weights WTDRD1PP and WTDR2DPP are renamed to WTDRD1 and WTDR2D
    so both cycles share one weight variable after appending;
data dr2iff_1720;
	set dr2iff_1720 (rename=(DR2IFDCD=FOODCODE2 WTDRD1PP=WTDRD1 WTDR2DPP=WTDR2D));
run;

*2021-2023 NHANES day 2 IFF;
data dr2iff_2123;
	set dr2iff_2123 (rename=(DR2IFDCD=FOODCODE2));
run;

*** TEMPORARY: build the 2021-2023 FPED day 2 IFF from the 2017-2020 FPED per-100 g file (in.fped_1720).
    Each food pattern component is scaled by grams eaten:  DR2I_X = X * DR2IGRMS / 100;
proc sort data=dr2iff_2123 (keep=SEQN DR2ILINE FOODCODE2 DR2IGRMS) out=iff2123_foods_day2;
	by FOODCODE2;
run;
proc sort data=in.fped_1720 out=fped100_1720_day2 (rename=(FOODCODE=FOODCODE2));
	by FOODCODE;
run;

data fped_dr2iff_2123;
	merge iff2123_foods_day2 (in=a) fped100_1720_day2 (in=b drop=DESCRIPTION);
	by FOODCODE2;
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
	array perfood {37} DR2I_F_CITMLB DR2I_F_OTHER DR2I_F_JUICE DR2I_F_TOTAL
		DR2I_V_DRKGR DR2I_V_REDOR_TOMATO DR2I_V_REDOR_OTHER DR2I_V_REDOR_TOTAL
		DR2I_V_STARCHY_POTATO DR2I_V_STARCHY_OTHER DR2I_V_STARCHY_TOTAL DR2I_V_OTHER DR2I_V_TOTAL DR2I_V_LEGUMES
		DR2I_G_WHOLE DR2I_G_REFINED DR2I_G_TOTAL
		DR2I_PF_MEAT DR2I_PF_CUREDMEAT DR2I_PF_ORGAN DR2I_PF_POULT DR2I_PF_SEAFD_HI DR2I_PF_SEAFD_LOW DR2I_PF_MPS_TOTAL
		DR2I_PF_EGGS DR2I_PF_SOY DR2I_PF_NUTSDS DR2I_PF_LEGUMES DR2I_PF_TOTAL
		DR2I_D_MILK DR2I_D_YOGURT DR2I_D_CHEESE DR2I_D_TOTAL
		DR2I_OILS DR2I_SOLID_FATS DR2I_ADD_SUGARS DR2I_A_DRINKS;
	do i = 1 to 37;
		if FPED_MATCH then perfood{i} = per100{i} * DR2IGRMS / 100;
		else perfood{i} = .;
	end;
	keep SEQN DR2ILINE FOODCODE2 DR2IGRMS FPED_MATCH DR2I_: ;
run;

*** TEMPORARY: how much of 2021-2023 day 2 intake has no 2017-2020 FPED match;
proc freq data=fped_dr2iff_2123;
	tables FPED_MATCH;
run;
proc means data=fped_dr2iff_2123 sum;
	class FPED_MATCH;
	var DR2IGRMS;
run;
proc sql;
	create table unmatched_2123_day2 as
	select FOODCODE2, count(*) as n_reports, sum(DR2IGRMS) as total_grams
	from fped_dr2iff_2123
	where FPED_MATCH = 0
	group by FOODCODE2
	order by n_reports desc;
quit;


***********************************************************
5. Merge demographics, FPED IFF, NHANES IFF day 2 by seqn
***********************************************************;

%macro FPEDDEMOTWO (cycle);

proc sort data=fped_dr2iff_&cycle OUT=fped&cycle._day2; 
	by seqn foodcode2; 
run;

proc sort data=dr2iff_&cycle OUT=iff&cycle._day2; 
	by seqn foodcode2; 
run;

data FPED_IFF&cycle._day2;
	merge fped&cycle._day2 iff&cycle._day2;
	by seqn foodcode2;
run;


proc sort data=demo_&cycle OUT=demo&cycle; 
	by seqn; 
run;

data FPED_DEMO&cycle._day2;
	merge FPED_IFF&cycle._day2 demo&cycle;
	by seqn;
run;

%mend;

*** CHANGED: cycles;
%FPEDDEMOTWO (1720);
%FPEDDEMOTWO (2123);


************************************************
6. Combine all datafiles for each cycle day 2
************************************************;

%macro CYCLEDATATWO (cycle);
proc sort data= W_A_I_P&cycle._day2 OUT=WAIp&cycle._day2; 
	by foodcode2; 
run;

proc sort data= FPED_DEMO&cycle._day2 OUT=FD&cycle._day2; 
	by foodcode2; 
run;

data data&cycle._day2;
	merge WAIP&cycle._day2 FD&cycle._day2;
	by foodcode2;
run;

%mend;

*** CHANGED: cycles;
%CYCLEDATATWO (1720);
%CYCLEDATATWO (2123);


*********************************
7. Append all cycles of interest
*********************************;
*** CHANGED: cycles. The LENGTH statement stops SAS from cutting DESCRIPTION2 / INGREDIENTS2 text
    to the shorter length in the first file, which would break the word searches in step 8;
data  cycles_day2;
	length DESCRIPTION2 $500 ADDL_DESCR2 INGREDIENTS2 $2000 category_description2 $200;
	set data1720_day2 data2123_day2;
	run;



***********************************
8. Cured meat code day 2
***********************************;
	
data out.meat_day2;
	set  cycles_day2 ;

	if DR2I_PF_CUREDMEAT>0 then select;
		
	*Beef, excludes ground;
		when (category_number2=2002) do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01); 
			cured_poultry_day2 =0; 		end;

	*Ground beef;
		when (category_number2=2004) do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01); 
			cured_poultry_day2 =0; 		end;

	*Pork;
		when (category_number2=2006) do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01); 
			cured_poultry_day2 =0; 		end;

	*Lamb, goat, game;
		when (category_number2=2008) do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01); 
			cured_poultry_day2 =0; 		end;

	*Chicken, whole pieces;
		when (category_number2=2202) 	 do;
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01); end;

	*Chicken patties, nuggets, and tenders;
		when (category_number2=2204) 	 do;
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01); end; 

	*Turkey, duck, and other poultry;
		when (category_number2=2206) 	 do;
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01); end;
	
	*Eggs and omelettes- DESCRIPTION2;
		when (category_number2=2502 AND find(DESCRIPTION2,'turkey','i')ge 1) do;  
    		cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01); 								   end;

		when (category_number2=2502 AND find(DESCRIPTION2,'chicken','i')ge 1) do;
    		cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01); 
																			end;				  
	*Cold cuts and cured meat- DESCRIPTION2;
		when (category_number2=2602 AND find(DESCRIPTION2,'meat','i', 1) AND find(ADDL_DESCR2,'poultry','i', 1) ge 1) do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 	end;											

		when (category_number2=2602 AND find(DESCRIPTION2,'chicken', 'i', 1)  AND find(DESCRIPTION2,'beef', 'i', 1) AND find(DESCRIPTION2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number2=2602 AND find(DESCRIPTION2,'chicken', 'i', 1)   AND find(DESCRIPTION2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=2602 AND find(DESCRIPTION2,'chicken', 'i', 1)   AND find(DESCRIPTION2,'beef', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=2602 AND find(DESCRIPTION2,'chicken', 'i', 1)  ge 1) do; 
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01);		  end;

		when (category_number2=2602 AND find(DESCRIPTION2,'turkey', 'i', 1)  AND find(DESCRIPTION2,'beef', 'i', 1) AND find(DESCRIPTION2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number2=2602 AND find(DESCRIPTION2,'turkey', 'i', 1)   AND find(DESCRIPTION2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=2602 AND find(DESCRIPTION2,'turkey', 'i', 1)   AND find(DESCRIPTION2,'beef', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=2602 AND find(DESCRIPTION2,'turkey', 'i', 1)  ge 1) do; 
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01);		  end;
		 
	*Bacon- DESCRIPTION2;
		when (category_number2=2604 AND find(DESCRIPTION2,'turkey','i') ge 1) do;
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01); 									end; 

		when (category_number2=2604 AND find(DESCRIPTION2,'chicken','i') ge 1) do;
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01); 									end;


	*Frankfurters- DESCRIPTION2 & ADDL_DESCR2;
		
		when (category_number2=2606 AND find(DESCRIPTION2,'meat','i', 1) AND find(DESCRIPTION2,'poultry','i', 1) ge 1) do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 	end;

		when (category_number2=2606 AND find(DESCRIPTION2,'chicken', 'i', 1)  AND find(DESCRIPTION2,'beef', 'i', 1) AND find(DESCRIPTION2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number2=2606 AND find(DESCRIPTION2,'chicken', 'i', 1)   AND find(DESCRIPTION2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=2606 AND find(DESCRIPTION2,'chicken', 'i', 1)   AND find(DESCRIPTION2,'beef', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=2606 AND find(DESCRIPTION2,'chicken', 'i', 1)  ge 1) do; 
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01);		  end;

		when (category_number2=2606 AND find(DESCRIPTION2,'turkey', 'i', 1)  AND find(DESCRIPTION2,'beef', 'i', 1) AND find(DESCRIPTION2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number2=2606 AND find(DESCRIPTION2,'turkey', 'i', 1)   AND find(DESCRIPTION2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=2606 AND find(DESCRIPTION2,'turkey', 'i', 1)   AND find(DESCRIPTION2,'beef', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=2606 AND find(DESCRIPTION2,'turkey', 'i', 1)  ge 1) do; 
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01);		  end;
		 
				when (category_number2=2606 AND find(ADDL_DESCR2,'meat','i', 1) AND find(ADDL_DESCR2,'poultry','i', 1) ge 1) do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 	end;

		when (category_number2=2606 AND find(ADDL_DESCR2,'chicken', 'i', 1)  AND find(ADDL_DESCR2,'beef', 'i', 1) AND find(ADDL_DESCR2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number2=2606 AND find(ADDL_DESCR2,'chicken', 'i', 1)   AND find(ADDL_DESCR2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=2606 AND find(ADDL_DESCR2,'chicken', 'i', 1)   AND find(ADDL_DESCR2,'beef', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=2606 AND find(ADDL_DESCR2,'chicken', 'i', 1)  ge 1) do; 
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01);		  end;

		when (category_number2=2606 AND find(ADDL_DESCR2,'turkey', 'i', 1)  AND find(ADDL_DESCR2,'beef', 'i', 1) AND find(ADDL_DESCR2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number2=2606 AND find(ADDL_DESCR2,'turkey', 'i', 1)   AND find(ADDL_DESCR2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=2606 AND find(ADDL_DESCR2,'turkey', 'i', 1)   AND find(ADDL_DESCR2,'beef', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=2606 AND find(ADDL_DESCR2,'turkey', 'i', 1)  ge 1) do; 
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01);		  end;

	*Bacon- DESCRIPTION2;
		when (category_number2=2604 AND find(DESCRIPTION2,'turkey','i') ge 1) do;
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01); 									end; 

		when (category_number2=2604 AND find(DESCRIPTION2,'chicken','i') ge 1) do;
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01); 									end;
			
	*Sausages- DESCRIPTION2 & ADDITIOANL DESCRIPTION2;		 

	when (category_number2=2608 AND find(DESCRIPTION2,'meat','i', 1) AND find(DESCRIPTION2,'poultry','i', 1) ge 1) do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 	end;

		when (category_number2=2608 AND find(DESCRIPTION2,'chix','i') ge 1) do;
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01); 									 end;

		when (category_number2=2608 AND find(DESCRIPTION2,'chicken', 'i', 1)  AND find(DESCRIPTION2,'beef', 'i', 1) AND find(DESCRIPTION2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number2=2608 AND find(DESCRIPTION2,'chicken', 'i', 1)   AND find(DESCRIPTION2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=2608 AND find(DESCRIPTION2,'chicken', 'i', 1)   AND find(DESCRIPTION2,'beef', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=2608 AND find(DESCRIPTION2,'chicken', 'i', 1)  ge 1) do; 
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01);		  end;

		when (category_number2=2608 AND find(DESCRIPTION2,'turkey', 'i', 1)  AND find(DESCRIPTION2,'beef', 'i', 1) AND find(DESCRIPTION2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number2=2608 AND find(DESCRIPTION2,'turkey', 'i', 1)   AND find(DESCRIPTION2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=2608 AND find(DESCRIPTION2,'turkey', 'i', 1)   AND find(DESCRIPTION2,'beef', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=2608 AND find(DESCRIPTION2,'turkey', 'i', 1)  ge 1) do; 
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01);		  end;

		
	when (category_number2=2608 AND find(ADDL_DESCR2,'meat','i', 1) AND find(ADDL_DESCR2,'poultry','i', 1) ge 1) do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 	end;

		when (category_number2=2608 AND find(ADDL_DESCR2,'chix','i') ge 1) do;
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01); 									 end;

		when (category_number2=2608 AND find(ADDL_DESCR2,'chicken', 'i', 1)  AND find(ADDL_DESCR2,'beef', 'i', 1) AND find(ADDL_DESCR2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number2=2608 AND find(ADDL_DESCR2,'chicken', 'i', 1)   AND find(ADDL_DESCR2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=2608 AND find(ADDL_DESCR2,'chicken', 'i', 1)   AND find(ADDL_DESCR2,'beef', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=2608 AND find(ADDL_DESCR2,'chicken', 'i', 1)  ge 1) do; 
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01);		  end;

		when (category_number2=2608 AND find(ADDL_DESCR2,'turkey', 'i', 1)  AND find(ADDL_DESCR2,'beef', 'i', 1) AND find(ADDL_DESCR2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number2=2608 AND find(ADDL_DESCR2,'turkey', 'i', 1)   AND find(ADDL_DESCR2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=2608 AND find(ADDL_DESCR2,'turkey', 'i', 1)   AND find(ADDL_DESCR2,'beef', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=2608 AND find(ADDL_DESCR2,'turkey', 'i', 1)  ge 1) do; 
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01);		  end;


	*Beans, peas, and legumes;
		when (category_number2=2802) do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01); 
			cured_poultry_day2 =0; 		end;
		
	*Mixed meat dishes- INGREDIENTS2;
		when (category_number2=3002 AND DR2I_PF_MEAT=0 AND DR2I_PF_POULT=0 AND find(INGREDIENTS2,'chicken, canned', 'i', 1) AND find(INGREDIENTS2,'beef', 'i', 1) AND find(INGREDIENTS2,'pork', 'i', 1)ge 1) do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.33), 0.01); 		end;

		when (category_number2=3002 AND DR2I_PF_MEAT=0 AND DR2I_PF_POULT=0 AND find(INGREDIENTS2,'canned, chicken', 'i', 1) AND find(INGREDIENTS2,'beef', 'i', 1) AND find(INGREDIENTS2,'pork', 'i', 1) ge 1) do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.33), 0.01); 		end;

		when (category_number2=3002 AND DR2I_PF_MEAT=0 AND DR2I_PF_POULT=0 AND find(INGREDIENTS2,'chicken, canned', 'i', 1) AND find(INGREDIENTS2,'beef', 'i', 1) ge 1) do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 		end;

		when (category_number2=3002 AND DR2I_PF_MEAT=0 AND DR2I_PF_POULT=0 AND find(INGREDIENTS2,'chicken, canned', 'i', 1)  AND find(INGREDIENTS2,'pork', 'i', 1) ge 1) do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 		end;

		when (category_number2=3002 AND DR2I_PF_MEAT=0 AND DR2I_PF_POULT=0 AND find(INGREDIENTS2,'canned, chicken', 'i', 1) AND find(INGREDIENTS2,'beef', 'i', 1) ge 1) do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 		end;

		when (category_number2=3002 AND DR2I_PF_MEAT=0 AND DR2I_PF_POULT=0 AND find(INGREDIENTS2,'canned, chicken', 'i', 1) AND find(INGREDIENTS2,'pork', 'i', 1) ge 1) do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 		end;

	*Mixed poultry dishes- INGREDIENTS2;
		when (category_number2=3004 AND DR2I_PF_POULT=0) do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01); 
			cured_poultry_day2 =0; 	  end;

	*Mixed seafood dishes- INGREDIENTS2;
		when (category_number2=3006 AND DR2I_PF_POULT=0 AND find(INGREDIENTS2,'chicken, canned', 'i', 1) ge 1) do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 		end;

		when (category_number2=3006 AND  DR2I_PF_POULT=0 AND find(INGREDIENTS2,'canned, chicken', 'i', 1) ge 1) do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 		end;

	*Mixed rice dishes- INGREDIENTS2;
		when (category_number2=3202 AND DR2I_PF_MEAT=0 AND DR2I_PF_POULT=0 AND find(INGREDIENTS2,'chicken, canned', 'i', 1) AND find(INGREDIENTS2,'beef', 'i', 1) AND find(INGREDIENTS2,'pork', 'i', 1)ge 1) do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.33), 0.01); 		end;

		when (category_number2=3202 AND DR2I_PF_MEAT=0 AND DR2I_PF_POULT=0 AND find(INGREDIENTS2,'canned, chicken', 'i', 1) AND find(INGREDIENTS2,'beef', 'i', 1) AND find(INGREDIENTS2,'pork', 'i', 1) ge 1) do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.33), 0.01); 		end;

		when (category_number2=3202 AND DR2I_PF_MEAT=0 AND DR2I_PF_POULT=0 AND find(INGREDIENTS2,'chicken, canned', 'i', 1) AND find(INGREDIENTS2,'beef', 'i', 1) ge 1) do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 		end;

		when (category_number2=3202 AND DR2I_PF_MEAT=0 AND DR2I_PF_POULT=0 AND find(INGREDIENTS2,'chicken, canned', 'i', 1)  AND find(INGREDIENTS2,'pork', 'i', 1) ge 1) do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 		end;

		when (category_number2=3202 AND DR2I_PF_MEAT=0 AND DR2I_PF_POULT=0 AND find(INGREDIENTS2,'canned, chicken', 'i', 1) AND find(INGREDIENTS2,'beef', 'i', 1) ge 1) do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 		end;

		when (category_number2=3202 AND DR2I_PF_MEAT=0 AND DR2I_PF_POULT=0 AND find(INGREDIENTS2,'canned, chicken', 'i', 1) AND find(INGREDIENTS2,'pork', 'i', 1) ge 1) do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 		end;

		*Frankfurer sandwiches- DESCRIPTION2;
		when (category_number2=3703 AND find(DESCRIPTION2,'meat','i', 1) AND find(DESCRIPTION2,'poultry','i', 1) ge 1) do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 	end;

		when (category_number2=3703 AND find(DESCRIPTION2,'chicken', 'i', 1)  AND find(DESCRIPTION2,'beef', 'i', 1) AND find(DESCRIPTION2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number2=3703 AND find(DESCRIPTION2,'chicken', 'i', 1)   AND find(DESCRIPTION2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=3703 AND find(DESCRIPTION2,'chicken', 'i', 1)   AND find(DESCRIPTION2,'beef', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=3703 AND find(DESCRIPTION2,'chicken', 'i', 1)  ge 1) do; 
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01);		  end;

		when (category_number2=3703 AND find(DESCRIPTION2,'turkey', 'i', 1)  AND find(DESCRIPTION2,'beef', 'i', 1) AND find(DESCRIPTION2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number2=3703 AND find(DESCRIPTION2,'turkey', 'i', 1)   AND find(DESCRIPTION2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=3703 AND find(DESCRIPTION2,'turkey', 'i', 1)   AND find(DESCRIPTION2,'beef', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=3703 AND find(DESCRIPTION2,'turkey', 'i', 1)  ge 1) do; 
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01);		  end;
		 
		when (category_number2=3703 AND find(ADDL_DESCR2,'meat','i', 1) AND find(ADDL_DESCR2,'poultry','i', 1) ge 1) do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 	end;

		when (category_number2=3703 AND find(ADDL_DESCR2,'chicken', 'i', 1)  AND find(ADDL_DESCR2,'beef', 'i', 1) AND find(ADDL_DESCR2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number2=3703 AND find(ADDL_DESCR2,'chicken', 'i', 1)   AND find(ADDL_DESCR2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=3703 AND find(ADDL_DESCR2,'chicken', 'i', 1)   AND find(ADDL_DESCR2,'beef', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=3703 AND find(ADDL_DESCR2,'chicken', 'i', 1)  ge 1) do; 
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01);		  end;

		when (category_number2=3703 AND find(ADDL_DESCR2,'turkey', 'i', 1)  AND find(ADDL_DESCR2,'beef', 'i', 1) AND find(ADDL_DESCR2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number2=3703 AND find(ADDL_DESCR2,'turkey', 'i', 1)   AND find(ADDL_DESCR2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=3703 AND find(ADDL_DESCR2,'turkey', 'i', 1)   AND find(ADDL_DESCR2,'beef', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=3703 AND find(ADDL_DESCR2,'turkey', 'i', 1)  ge 1) do; 
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01);		  end;


	*Chicken/turkey sandwich- INGREDIENTS2;
		when (DR2I_PF_POULT=0 AND category_number2=3704 AND find(INGREDIENTS2,'chicken', 'i', 1) AND find(INGREDIENTS2,'pork', 'i', 1) ge 1)  do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 			end;

		when (DR2I_PF_POULT=0 AND category_number2=3704 AND find(INGREDIENTS2,'turkey', 'i', 1) AND find(INGREDIENTS2,'pork', 'i', 1) ge 1)  do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 			end;

		when (DR2I_PF_POULT=0 AND category_number2=3704 AND find(INGREDIENTS2,'chicken', 'i', 1) AND find(INGREDIENTS2,'beef', 'i', 1) ge 1)  do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 			end;

		when (DR2I_PF_POULT=0 AND category_number2=3704 AND find(INGREDIENTS2,'turkey', 'i', 1) AND find(INGREDIENTS2,'beef', 'i', 1) ge 1)  do;
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 			end;

		when (DR2I_PF_POULT=0 AND category_number2=3704 AND find(INGREDIENTS2,'chicken', 'i', 1) ge 1)  do;
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01); 			end;

		when (DR2I_PF_POULT=0 AND category_number2=3704 AND find(INGREDIENTS2,'turkey', 'i', 1) ge 1)  do;
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01); 			end;


	*Egg/breakfast sandwich- INGREDIENTS2;
		when (category_number2=3706 AND find(INGREDIENTS2,'turkey','i')ge 1) do;  
    		cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01); 								  end;
		
		when (category_number2=3706 AND find(INGREDIENTS2,'chicken','i')ge 1) do;
    		cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01);							 		end;

	*Other sandwiches- INGREDIENTS2;
		when (category_number2=3708 AND  find(INGREDIENTS2,'chicken', 'i', 1)  AND find(INGREDIENTS2,'beef', 'i', 1) AND find(INGREDIENTS2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number2=3708 AND find(INGREDIENTS2,'chicken', 'i', 1)   AND find(INGREDIENTS2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=3708 AND find(INGREDIENTS2,'chicken', 'i', 1)   AND find(INGREDIENTS2,'beef', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=3708 AND find(INGREDIENTS2,'chicken', 'i', 1)  ge 1) do; 
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01);		  end;

		when (category_number2=3708 AND find(INGREDIENTS2,'turkey', 'i', 1)  AND find(INGREDIENTS2,'beef', 'i', 1) AND find(INGREDIENTS2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number2=3708 AND find(INGREDIENTS2,'turkey', 'i', 1)   AND find(INGREDIENTS2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=3708 AND find(INGREDIENTS2,'turkey', 'i', 1)   AND find(INGREDIENTS2,'beef', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=3708 AND find(INGREDIENTS2,'turkey', 'i', 1)  ge 1) do; 
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01);		  end;

	*Egg/breakfast sandwich- INGREDIENTS2;
		when (category_number2=3706 AND find(INGREDIENTS2,'turkey','i')ge 1) do;  
    		cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01); 								  end;
		
		when (category_number2=3706 AND find(INGREDIENTS2,'chicken','i')ge 1) do;
    		cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01);							 		end;

	*Pretzels/snack mix- INGREDIENTS2;
		when (category_number2=5008 AND  find(INGREDIENTS2,'chicken', 'i', 1)  AND find(INGREDIENTS2,'beef', 'i', 1) AND find(INGREDIENTS2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number2=5008 AND find(INGREDIENTS2,'chicken', 'i', 1)   AND find(INGREDIENTS2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=5008 AND find(INGREDIENTS2,'chicken', 'i', 1)   AND find(INGREDIENTS2,'beef', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=5008 AND find(INGREDIENTS2,'chicken', 'i', 1)  ge 1) do; 
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01);		  end;

		when (category_number2=5008 AND find(INGREDIENTS2,'turkey', 'i', 1)  AND find(INGREDIENTS2,'beef', 'i', 1) AND find(INGREDIENTS2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number2=5008 AND find(INGREDIENTS2,'turkey', 'i', 1)   AND find(INGREDIENTS2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=5008 AND find(INGREDIENTS2,'turkey', 'i', 1)   AND find(INGREDIENTS2,'beef', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=5008 AND find(INGREDIENTS2,'turkey', 'i', 1)  ge 1) do; 
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01);		  end;

	*Mixed vegetable dishes- INGREDIENTS2;
		when (category_number2=6442 AND  find(INGREDIENTS2,'chicken', 'i', 1)  AND find(INGREDIENTS2,'beef', 'i', 1) AND find(INGREDIENTS2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number2=6442 AND find(INGREDIENTS2,'chicken', 'i', 1)   AND find(INGREDIENTS2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=6442 AND find(INGREDIENTS2,'chicken', 'i', 1)   AND find(INGREDIENTS2,'beef', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=6442 AND find(INGREDIENTS2,'chicken', 'i', 1)  ge 1) do; 
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01);		  end;

		when (category_number2=6442 AND find(INGREDIENTS2,'turkey', 'i', 1)  AND find(INGREDIENTS2,'beef', 'i', 1) AND find(INGREDIENTS2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number2=6442 AND find(INGREDIENTS2,'turkey', 'i', 1)   AND find(INGREDIENTS2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=6442 AND find(INGREDIENTS2,'turkey', 'i', 1)   AND find(INGREDIENTS2,'beef', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=6442 AND find(INGREDIENTS2,'turkey', 'i', 1)  ge 1) do; 
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01);		  end;

		*Mixed vegetable dishes- INGREDIENTS2;
		when (category_number2=6802 AND  find(INGREDIENTS2,'chicken', 'i', 1)  AND find(INGREDIENTS2,'beef', 'i', 1) AND find(INGREDIENTS2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number2=6802 AND find(INGREDIENTS2,'chicken', 'i', 1)   AND find(INGREDIENTS2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=6802 AND find(INGREDIENTS2,'chicken', 'i', 1)   AND find(INGREDIENTS2,'beef', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=6802 AND find(INGREDIENTS2,'chicken', 'i', 1)  ge 1) do; 
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01);		  end;

		when (category_number2=6802 AND find(INGREDIENTS2,'turkey', 'i', 1)  AND find(INGREDIENTS2,'beef', 'i', 1) AND find(INGREDIENTS2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.66), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.33), 0.01);		  end;	

		when (category_number2=6802 AND find(INGREDIENTS2,'turkey', 'i', 1)   AND find(INGREDIENTS2,'pork', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=6802 AND find(INGREDIENTS2,'turkey', 'i', 1)   AND find(INGREDIENTS2,'beef', 'i', 1) ge 1) do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01); 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*0.5), 0.01);		  end;	

		when (category_number2=6802 AND find(INGREDIENTS2,'turkey', 'i', 1)  ge 1) do; 
			cured_redmeat_day2 =0; 
			cured_poultry_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01);		  end;


*All other DR2I_PF_CUREDMEAT defaults to cured red meat;
		otherwise do; 
			cured_redmeat_day2 =Round((DR2I_PF_CUREDMEAT*1), 0.01); 
			cured_poultry_day2 =0;           end; 	

	end; * for the first select statement;

*Default all else (i.e. not containing cured meat) to 0;
if DR2I_PF_CUREDMEAT=0 then do;
		cured_redmeat_day2=0;
		cured_poultry_day2=0;
		end;

*To create total processed poultry category;
if DR2I_PF_POULT>0 then select;
		when (category_number2= 2204) do;
			Nug_Pat_Fil_day2 =Round((DR2I_PF_POULT*1), 0.01); 
			unproc_poultry_day2 =0; 
		end;

otherwise do;
		Nug_Pat_Fil_day2 =0; 
		unproc_poultry_day2=Round((DR2I_PF_POULT*1), 0.01);
		end;

end; *select statement;

if DR2I_PF_POULT=0 then do;
	Nug_Pat_Fil_day2 =0; 
	unproc_poultry_day2 =0; 

		end;

*To create total red meat and total poultry categories;
	total_redmeat_day2 = Round((cured_redmeat_day2  + DR2I_PF_MEAT), 0.01);
	total_poultry_day2 = Round((cured_poultry_day2  + DR2I_PF_POULT), 0.01);
	total_proc_poultry_day2= Round((cured_poultry_day2  + Nug_Pat_Fil_day2), 0.01);

*To create ‘red and processed meat’ categories;
	Red_and_cured_1_day2= Round((DR2I_PF_MEAT + DR2I_PF_CUREDMEAT), 0.01);
	Red_and_processed_2_day2= Round((DR2I_PF_MEAT + DR2I_PF_CUREDMEAT + Nug_Pat_fil_day2), 0.01);

	drop description;

	run;

*label variables;
	data out.meat_day2;
    set out.meat_day2;
    label DR2I_PF_meat             = 'Unprocessed red meat: Beef, veal, pork, lamb, and game meat; excludes organ meat and cured meat';
	label cured_redmeat_day2       = 'Processed red meat: Component disaggregated from PF_Curedmeat, i.e. red meat preserved by smoking, curing, salting, and/or the addition of chemical preservatives';
	label total_redmeat_day2       = 'Total red meat: Combination of PF_meat and cured_redmeat';
	label DR2I_PF_poult            = 'Unprocessed poultry: Chicken, turkey, Cornish hens, duck, goose, quail, and pheasant (game birds); excludes organ meat and cured meat';
	label cured_poultry_day2       = 'Processed poultry: Component disaggregated from PF_Curedmeat, i.e. poultry preserved by smoking, curing, salting, and/or the addition of chemical preservatives';
	label total_proc_poultry_day2  = 'Total processed poultry: Combination of cured_poultry and the WWEIA category of chicken patties, nuggets, and tenders';
	label unproc_poultry_day2      = 'Unprocessed poultry minus chicken nuggets, patties, and fillets: Chicken, turkey, Cornish hens, duck, goose, quail, and pheasant (game birds); excludes organ meat, cured meat, and chicken nuggets, patties, and fillets';
	label total_poultry_day2       = 'Total poultry: Combination of PF_poult and cured_poultry, includes chicken nuggets, patties, and fillets';
	label nug_pat_fil_day2         = 'Chicken nuggets, patties, and fillets:	PF_poult from WWEIA category 2204';
	label DR2I_PF_curedmeat        = 'Total processed meat: Frankfurters, sausages, corned beef, cured ham and luncheon meat that are made from beef, pork, or poultry';
	label red_and_cured_1_day2     =	'Red and cured meat: Combination of PF_meat + cured_redmeat + cured_poultry'; 
	label red_and_processed_2_day2 = 'Red and processed meat: Combination of PF_meat + cured_redmeat + cured_poultry + chicken patties, nuggets, and tenders';
run;

***********************************************
9. Proc means to total meat intakes for day 2
	file called meat_day2
***********************************************;
proc sort data=out.meat_day2;
	by seqn;
	run;

	PROC MEANS DATA=out.meat_day2 sum noprint;
	by seqn;
	where seqn>0;
	var DR2IGRMS
		DR2I_F_CITMLB
		DR2I_F_OTHER
		DR2I_F_JUICE
		DR2I_F_TOTAL
		DR2I_V_DRKGR
		DR2I_V_REDOR_TOMATO
		DR2I_V_REDOR_OTHER
		DR2I_V_REDOR_TOTAL
		DR2I_V_STARCHY_POTATO
		DR2I_V_STARCHY_OTHER
		DR2I_V_STARCHY_TOTAL
		DR2I_V_OTHER
		DR2I_V_TOTAL
		DR2I_V_LEGUMES
		DR2I_G_WHOLE
		DR2I_G_REFINED
		DR2I_G_TOTAL
		DR2I_PF_MEAT
		DR2I_PF_CUREDMEAT
		DR2I_PF_ORGAN
		DR2I_PF_POULT
		DR2I_PF_SEAFD_HI
		DR2I_PF_SEAFD_LOW
		DR2I_PF_MPS_TOTAL
		DR2I_PF_EGGS
		DR2I_PF_SOY
		DR2I_PF_NUTSDS
		DR2I_PF_LEGUMES
		DR2I_PF_TOTAL
		DR2I_D_MILK
		DR2I_D_YOGURT
		DR2I_D_CHEESE
		DR2I_D_TOTAL
		DR2I_OILS
		DR2I_SOLID_FATS
		DR2I_ADD_SUGARS
		DR2I_A_DRINKS
		cured_redmeat_day2
		cured_poultry_day2
		total_redmeat_day2
		total_poultry_day2
		unproc_poultry_day2
		Nug_Pat_Fil_day2
		total_proc_poultry_day2
		Red_and_cured_1_day2
		Red_and_processed_2_day2
		DR2IKCAL
		DR2IPROT
		DR2ICARB
		DR2ISUGR
		DR2IFIBE
		DR2ITFAT
		DR2ISFAT
		DR2IMFAT
		DR2IPFAT
		DR2ICHOL
		DR2IATOC
		DR2IATOA
		DR2IRET
		DR2IVARA
		DR2IACAR
		DR2IBCAR
		DR2ICRYP
		DR2ILYCO
		DR2ILZ
		DR2IVB1
		DR2IVB2
		DR2INIAC
		DR2IVB6
		DR2IFOLA
		DR2IFA
		DR2IFF
		DR2IFDFE
		DR2ICHL
		DR2IVB12
		DR2IB12A
		DR2IVC
		DR2IVD
		DR2IVK
		DR2ICALC
		DR2IPHOS
		DR2IMAGN
		DR2IIRON
		DR2IZINC
		DR2ICOPP
		DR2ISODI
		DR2IPOTA
		DR2ISELE
		DR2ICAFF
		DR2ITHEO
		DR2IALCO
		DR2IMOIS
		DR2IS040
		DR2IS060
		DR2IS080
		DR2IS100
		DR2IS120
		DR2IS140
		DR2IS160
		DR2IS180
		DR2IM161
		DR2IM181
		DR2IM201
		DR2IM221
		DR2IP182
		DR2IP183
		DR2IP184
		DR2IP204
		DR2IP205
		DR2IP225
		DR2IP226;

	output out=out.meat_day2_sum  

	SUM=DR2IGRMS
		DR2I_F_CITMLB
		DR2I_F_OTHER
		DR2I_F_JUICE
		DR2I_F_TOTAL
		DR2I_V_DRKGR
		DR2I_V_REDOR_TOMATO
		DR2I_V_REDOR_OTHER
		DR2I_V_REDOR_TOTAL
		DR2I_V_STARCHY_POTATO
		DR2I_V_STARCHY_OTHER
		DR2I_V_STARCHY_TOTAL
		DR2I_V_OTHER
		DR2I_V_TOTAL
		DR2I_V_LEGUMES
		DR2I_G_WHOLE
		DR2I_G_REFINED
		DR2I_G_TOTAL
		DR2I_PF_MEAT
		DR2I_PF_CUREDMEAT
		DR2I_PF_ORGAN
		DR2I_PF_POULT
		DR2I_PF_SEAFD_HI
		DR2I_PF_SEAFD_LOW
		DR2I_PF_MPS_TOTAL
		DR2I_PF_EGGS
		DR2I_PF_SOY
		DR2I_PF_NUTSDS
		DR2I_PF_LEGUMES
		DR2I_PF_TOTAL
		DR2I_D_MILK
		DR2I_D_YOGURT
		DR2I_D_CHEESE
		DR2I_D_TOTAL
		DR2I_OILS
		DR2I_SOLID_FATS
		DR2I_ADD_SUGARS
		DR2I_A_DRINKS
		cured_redmeat_day2
		cured_poultry_day2
		total_redmeat_day2
		total_poultry_day2
		unproc_poultry_day2
		Nug_Pat_Fil_day2
		total_proc_poultry_day2
		Red_and_cured_1_day2
		Red_and_processed_2_day2
		DR2IKCAL
		DR2IPROT
		DR2ICARB
		DR2ISUGR
		DR2IFIBE
		DR2ITFAT
		DR2ISFAT
		DR2IMFAT
		DR2IPFAT
		DR2ICHOL
		DR2IATOC
		DR2IATOA
		DR2IRET
		DR2IVARA
		DR2IACAR
		DR2IBCAR
		DR2ICRYP
		DR2ILYCO
		DR2ILZ
		DR2IVB1
		DR2IVB2
		DR2INIAC
		DR2IVB6
		DR2IFOLA
		DR2IFA
		DR2IFF
		DR2IFDFE
		DR2ICHL
		DR2IVB12
		DR2IB12A
		DR2IVC
		DR2IVD
		DR2IVK
		DR2ICALC
		DR2IPHOS
		DR2IMAGN
		DR2IIRON
		DR2IZINC
		DR2ICOPP
		DR2ISODI
		DR2IPOTA
		DR2ISELE
		DR2ICAFF
		DR2ITHEO
		DR2IALCO
		DR2IMOIS
		DR2IS040
		DR2IS060
		DR2IS080
		DR2IS100
		DR2IS120
		DR2IS140
		DR2IS160
		DR2IS180
		DR2IM161
		DR2IM181
		DR2IM201
		DR2IM221
		DR2IP182
		DR2IP183
		DR2IP184
		DR2IP204
		DR2IP205
		DR2IP225
		DR2IP226;

	*** CHANGED: shortened ID list. Many of the original demographic variables were dropped or renamed
	    in P_DEMO and DEMO_L, and PROC MEANS stops with an error if any ID variable is missing;
	ID RIAGENDR
		RIDAGEYR
		RIDRETH1
		RIDRETH3
		INDFMPIR
		SDMVPSU
		SDMVSTRA
		WTDRD1
		WTDR2D
		DR2DRSTZ
		DRABF
		DRDINT
		SDDSRVYR
		RIDSTATR
		DR2DAY;
run;


***********************************************
10. Append day 1 and day 2 for usual intake
	file called meat_usualintake
***********************************************;
*** CHANGED: removed the DR1TNUMF and DR2TNUMF renames below. Those variables are no longer kept in
    meat_day1_sum or meat_day2_sum (shortened ID lists), and renaming a missing variable is an error;
data meat_day1_append;
	set out.meat_day1_sum 
	(rename= (
			DR1IGRMS                =       GRMS
			DR1I_F_CITMLB	        =	    F_CITMLB
			DR1I_F_OTHER	        =	    F_OTHER
			DR1I_F_JUICE	        =	    F_JUICE
			DR1I_F_TOTAL	        =	    F_TOTAL
			DR1I_V_DRKGR	        =	    V_DRKGR
			DR1I_V_REDOR_TOMATO     =	    V_REDOR_TOMATO
			DR1I_V_REDOR_OTHER	    =	    V_REDOR_OTHER
			DR1I_V_REDOR_TOTAL	    =	    V_REDOR_TOTAL
			DR1I_V_STARCHY_POTATO	=	    V_STARCHY_POTATO
			DR1I_V_STARCHY_OTHER	=	    V_STARCHY_OTHER
			DR1I_V_STARCHY_TOTAL	=	    V_STARCHY_TOTAL
			DR1I_V_OTHER	        =	    V_OTHER
			DR1I_V_TOTAL	        =	    V_TOTAL
			DR1I_V_LEGUMES      	=	    V_LEGUMES
			DR1I_G_WHOLE        	=	    G_WHOLE
			DR1I_G_REFINED      	=	    G_REFINED
			DR1I_G_TOTAL        	=	    G_TOTAL
			DR1I_PF_MEAT        	=	    PF_MEAT
			DR1I_PF_CUREDMEAT    	=	    PF_CUREDMEAT
			DR1I_PF_ORGAN	        =	    PF_ORGAN
			DR1I_PF_POULT	        =	    PF_POULT
			DR1I_PF_SEAFD_HI    	=	    PF_SEAFD_HI
			DR1I_PF_SEAFD_LOW   	=	    PF_SEAFD_LOW
			DR1I_PF_MPS_TOTAL   	=	    PF_MPS_TOTAL
			DR1I_PF_EGGS        	=	    PF_EGGS
			DR1I_PF_SOY         	=	    PF_SOY
			DR1I_PF_NUTSDS	        =	    PF_NUTSDS
			DR1I_PF_LEGUMES     	=	    PF_LEGUMES
			DR1I_PF_TOTAL	        =	    PF_TOTAL
			DR1I_D_MILK	            =	    D_MILK
			DR1I_D_YOGURT       	=	    D_YOGURT
			DR1I_D_CHEESE       	=	    D_CHEESE
			DR1I_D_TOTAL        	=	    D_TOTAL
			DR1I_OILS	            =	    OILS
			DR1I_SOLID_FATS      	=	    SOLID_FATS
			DR1I_ADD_SUGARS     	=	    ADD_SUGARS
			DR1I_A_DRINKS	        =	    A_DRINKS

			DR1IKCAL	=	  IKCAL
			DR1IPROT	=	  IPROT
			DR1ICARB	=	  ICARB
			DR1ISUGR	=	  ISUGR
			DR1IFIBE	=	  IFIBE
			DR1ITFAT	=	  ITFAT
			DR1ISFAT	=	  ISFAT
			DR1IMFAT	=	  IMFAT
			DR1IPFAT	=	  IPFAT
			DR1ICHOL	=	  ICHOL
			DR1IATOC	=	  IATOC
			DR1IATOA	=	  IATOA
			DR1IRET		=	  IRET
			DR1IVARA	=	  IVARA
			DR1IACAR	=	  IACAR
			DR1IBCAR	=	  IBCAR
			DR1ICRYP	=	  ICRYP
			DR1ILYCO	=	  ILYCO
			DR1ILZ		=	  ILZ
			DR1IVB1		=	  IVB1
			DR1IVB2		=	  IVB2
			DR1INIAC	=	  INIAC
			DR1IVB6		=	  IVB6
			DR1IFOLA	=	  IFOLA
			DR1IFA		=	  IFA
			DR1IFF		=	  IFF
			DR1IFDFE	=	  IFDFE
			DR1ICHL		=	  ICHL
			DR1IVB12	=	  IVB12
			DR1IB12A	=	  IB12A
			DR1IVC		=	  IVC
			DR1IVD		=	  IVD
			DR1IVK		=	  IVK
			DR1ICALC	=	  ICALC
			DR1IPHOS	=	  IPHOS
			DR1IMAGN	=	  IMAGN
			DR1IIRON	=	  IIRON
			DR1IZINC	=	  IZINC
			DR1ICOPP	=	  ICOPP
			DR1ISODI	=	  ISODI
			DR1IPOTA	=	  IPOTA
			DR1ISELE	=	  ISELE
			DR1ICAFF	=	  ICAFF
			DR1ITHEO	=	  ITHEO
			DR1IALCO	=	  IALCO
			DR1IMOIS	=	  IMOIS
			DR1IS040	=	  IS040
			DR1IS060	=	  IS060
			DR1IS080	=	  IS080
			DR1IS100	=	  IS100
			DR1IS120	=	  IS120
			DR1IS140	=	  IS140
			DR1IS160	=	  IS160
			DR1IS180	=	  IS180
			DR1IM161	=	  IM161
			DR1IM181	=	  IM181
			DR1IM201	=	  IM201
			DR1IM221	=	  IM221
			DR1IP182	=	  IP182
			DR1IP183	=	  IP183
			DR1IP184	=	  IP184
			DR1IP204	=	  IP204
			DR1IP205	=	  IP205
			DR1IP225	=	  IP225
			DR1IP226	=	  IP226
			DR1DRSTZ    =     DRSTZ
			DR1DAY      =     DAY));
				report=1;
run;

data meat_day2_append;
	set out.meat_day2_sum 
	(rename= (
			DR2IGRMS                      =       GRMS
			DR2I_F_CITMLB                 =       F_CITMLB
			DR2I_F_OTHER                  =       F_OTHER
			DR2I_F_JUICE                  =       F_JUICE
			DR2I_F_TOTAL                  =       F_TOTAL
			DR2I_V_DRKGR                  =       V_DRKGR
			DR2I_V_REDOR_TOMATO           =       V_REDOR_TOMATO
			DR2I_V_REDOR_OTHER            =       V_REDOR_OTHER
			DR2I_V_REDOR_TOTAL            =       V_REDOR_TOTAL
			DR2I_V_STARCHY_POTATO         =       V_STARCHY_POTATO
			DR2I_V_STARCHY_OTHER          =        V_STARCHY_OTHER
			DR2I_V_STARCHY_TOTAL          =        V_STARCHY_TOTAL
			DR2I_V_OTHER                  =        V_OTHER
			DR2I_V_TOTAL                  =         V_TOTAL
			DR2I_V_LEGUMES                =         V_LEGUMES
			DR2I_G_WHOLE                  =         G_WHOLE
			DR2I_G_REFINED                =         G_REFINED
			DR2I_G_TOTAL                  =        G_TOTAL
			DR2I_PF_MEAT                  =         PF_MEAT
			DR2I_PF_CUREDMEAT             =         PF_CUREDMEAT
			DR2I_PF_ORGAN                 =        PF_ORGAN
			DR2I_PF_POULT                 =         PF_POULT
			DR2I_PF_SEAFD_HI              =        PF_SEAFD_HI
			DR2I_PF_SEAFD_LOW             =         PF_SEAFD_LOW
			DR2I_PF_MPS_TOTAL             =         PF_MPS_TOTAL
			DR2I_PF_EGGS                  =         PF_EGGS
			DR2I_PF_SOY                   =        PF_SOY
			DR2I_PF_NUTSDS                =         PF_NUTSDS
			DR2I_PF_LEGUMES               =         PF_LEGUMES
			DR2I_PF_TOTAL                 =         PF_TOTAL
			DR2I_D_MILK                   =        D_MILK
			DR2I_D_YOGURT                 =         D_YOGURT
			DR2I_D_CHEESE                 =         D_CHEESE
			DR2I_D_TOTAL                  =         D_TOTAL
			DR2I_OILS                     =         OILS
			DR2I_SOLID_FATS               =         SOLID_FATS
			DR2I_ADD_SUGARS               =         ADD_SUGARS
			DR2I_A_DRINKS                 =         A_DRINKS
			cured_redmeat_day2            =       cured_redmeat
			cured_poultry_day2            =       cured_poultry
			total_redmeat_day2            =       total_redmeat
			total_poultry_day2            =       total_poultry
			unproc_poultry_day2           =       unproc_poultry
			Nug_Pat_Fil_day2              =       Nug_Pat_Fil
			total_proc_poultry_day2       =       total_proc_poultry
			Red_and_cured_1_day2          =       Red_and_cured_1
			Red_and_processed_2_day2      =       Red_and_processed_2

			DR2IKCAL	=	  IKCAL
			DR2IPROT	=	  IPROT
			DR2ICARB	=	  ICARB
			DR2ISUGR	=	  ISUGR
			DR2IFIBE	=	  IFIBE
			DR2ITFAT	=	  ITFAT
			DR2ISFAT	=	  ISFAT
			DR2IMFAT	=	  IMFAT
			DR2IPFAT	=	  IPFAT
			DR2ICHOL	=	  ICHOL
			DR2IATOC	=	  IATOC
			DR2IATOA	=	  IATOA
			DR2IRET		=	  IRET
			DR2IVARA	=	  IVARA
			DR2IACAR	=	  IACAR
			DR2IBCAR	=	  IBCAR
			DR2ICRYP	=	  ICRYP
			DR2ILYCO	=	  ILYCO
			DR2ILZ		=	  ILZ
			DR2IVB1		=	  IVB1
			DR2IVB2		=	  IVB2
			DR2INIAC	=	  INIAC
			DR2IVB6		=	  IVB6
			DR2IFOLA	=	  IFOLA
			DR2IFA		=	  IFA
			DR2IFF		=	  IFF
			DR2IFDFE	=	  IFDFE
			DR2ICHL		=	  ICHL
			DR2IVB12	=	  IVB12
			DR2IB12A	=	  IB12A
			DR2IVC		=	  IVC
			DR2IVD		=	  IVD
			DR2IVK		=	  IVK
			DR2ICALC	=	  ICALC
			DR2IPHOS	=	  IPHOS
			DR2IMAGN	=	  IMAGN
			DR2IIRON	=	  IIRON
			DR2IZINC	=	  IZINC
			DR2ICOPP	=	  ICOPP
			DR2ISODI	=	  ISODI
			DR2IPOTA	=	  IPOTA
			DR2ISELE	=	  ISELE
			DR2ICAFF	=	  ICAFF
			DR2ITHEO	=	  ITHEO
			DR2IALCO	=	  IALCO
			DR2IMOIS	=	  IMOIS
			DR2IS040	=	  IS040
			DR2IS060	=	  IS060
			DR2IS080	=	  IS080
			DR2IS100	=	  IS100
			DR2IS120	=	  IS120
			DR2IS140	=	  IS140
			DR2IS160	=	  IS160
			DR2IS180	=	  IS180
			DR2IM161	=	  IM161
			DR2IM181	=	  IM181
			DR2IM201	=	  IM201
			DR2IM221	=	  IM221
			DR2IP182	=	  IP182
			DR2IP183	=	  IP183
			DR2IP184	=	  IP184
			DR2IP204	=	  IP204
			DR2IP205	=	  IP205
			DR2IP225	=	  IP225
			DR2IP226	=	  IP226
			DR2DRSTZ    =     DRSTZ
			DR2DAY      =     DAY));
				report=2;
run;

data out.meat_usual_intake;
	set meat_day1_append meat_day2_append;
run;

proc sort data= out.meat_usual_intake;
	by seqn;
run;
	



