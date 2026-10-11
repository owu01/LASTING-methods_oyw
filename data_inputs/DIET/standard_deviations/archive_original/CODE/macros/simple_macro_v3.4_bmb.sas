/************************************************************************************
The SIMPLE macro is a ‘wrapper’ for the MIXTRAN, DISTRIB, and BOXCOX_SURVEY macros to 
facilitate estimation of usual intake distributions for food and nutrients consumed ‘nearly-daily’. 
The SIMPLE macro supports a variety of analyses, including estimating usual nutrient intake and modelling 
nutrition-related interventions that may be of interest to policy advocates and researchers, while 
remaining robust and easy-to-use.

Macro parameters	Required or optional	Description
Folder						Required	Directory to save the SIMPLE macro result files.
Data						Required	The name of the 24HR dataset.
Note						Optional	Users can enter a note for themselves that will appear in the final SAS dataset and excel spreadsheet.
nutrientVariable			Required	Variable name of the nutrient intake from the 24HR
outputDatasetName			Required	The suffix of the SIMPLE macro result files
Subgroup					Optional	Variable name of the subgroup if users want subgroup-analysis.
										The subgroup variable must be either categorical or binary and be in the numeric format.
EARValue					Optional	If all participants in the dataset have the same EAR value, enter a numeric EAR value, such as “800”.
										Note: User cannot enter parameters for EARValue and EARVariable at the same time.
EARVariable					Optional	If there is an EAR variable specifying individual-appropriate EAR, enter the EAR variable name. 
										Note: User cannot enter parameters for EARValue and EARVariable at the same time.
ULValue						Optional	If all participants in the dataset have the same UL value, enter a numeric UL value, such as “800”.
										Note: User cannot enter parameters for ULValue and ULVariable at the same time.
ULVariable					Optional	If there is an UL variable specifying individual-appropriate UL, enter the UL variable name. 
										Note: User cannot enter parameters for ULValue and ULVariable at the same time.
subjectID					Required	Respondent ID
RepeatRecallVariable		Required	A variable indicating that a 24HR is the 1st or 2nd or 3rd 24HRs for a participant.
										This input is a categorical variable
Seq							Optional	Specifying one or more sequence of recall administration indicator variables to account for effects due to the order in which the days of data were collected
Covariates					Optional	Names of covariate variables.
										The variable of subgroup analysis must be entered as one of the covariates. Covariates can be either Binary variable or continuous variable. Categorical variables need to be first converted into multiple binary variables.
Weekend						Optional	Weekend binary variable
SECalculationMethod			Optional	Either Bootstrap, BRR, or noSE
BRRFayFactor				Optional	Only fill in if the survey weight method is BRR. For NHANES, BRRFayFactor is 0.3.
weightVariable				Optional	If users do not want SE, weightVariable should be the actual survey weight variable name.
										If users want SE, weightVariable will be the prefix of the variable names of the Balanced Repeated Replicates or bootstrap replicates.
startWeight					Optional	The start weight number of the BRR/bootstrap replicates variables.
endWeight					Optional	The end weight number of the BRR/bootstrap weight variables.
supplementData				Optional	The name of the Dietary Supplement (DS) dataset.
supplementID				Optional	Respondent ID of the DS dataset.
										If the DS data is simulated rather than the actual recall data, this variable indicates how information between the simulated DS data and the 24HR data are related. 
supplementNutrientVariable	Optional	The variable name of nutrient intake from the DS.
										Nutrient intake from the DS cannot have the same variable name as that of the 24HR dataset.
supplementUSE				Optional	A binary variable indicating dietary supplement use. If the DS dataset is the actual recalls, this input is required.
supplementSimulation		Optional	If the DS dataset is the actual recall, users should leave this parameter blank;
										If the DS dataset is simulated, users should enter “Yes”. 
supplementCoverageVariable	Optional	If the DS dataset is simulated, this variable indicates the supplement coverage.
BreastmilkData				Optional	Name of the breast milk (BM) dataset.
BreastfeedingVariable		Optional	 A binary variable indicating if a respondent consumes breast milk or not.
BreastmilkID				Optional	Respondent ID.
										If the BM data is simulated rather than the actual recall data, this variable indicates how information between the simulated BM data and the 24HR data are related.
BreastmilkNutrientVariable	Optional	The variable name of the nutrient intake from breast milk.Nutrient intake from the BM dataset cannot have the same variable name as that of the 24HR dataset
ByBreastfeedingStatus	    Optional	Enter Yes if you need results by breastfeeding status
************************************************************************************************/


%macro SIMPLE(
 data= , 
 byBreastfeedingStatus = ,
 nutrientVariable = , 
 nutrientTYpe =,
 Note = ,
 subjectID =,
 repeatRecallVariable = , 
 outlib =,
 corr = ,
 seq =,  /* The value of zero needs to be used for prediction in the Distrib Macro*/
 covariates = , 
 covariatesProb = ,
 outputDatasetName = , 
 weightVariable =, 
 startWeight = , 
 endWeight = , 
 weekend =, 
 EARValue =, 
 EARVariable =,
 ULValue =,
 ULVariable =, 
 subgroup = , 
 SECalculationMethod = ,
 BRRFayFactor = ,
 breastmilkData= ,  
 breastfeedingVariable = , 
 breastmilkID = ,
 breastmilkNutrientVariable = ,
 supplementData = , 
 supplementID =,
 supplementNutrientVariable = ,
 SupplementUse = ,
 supplementSimulation = ,
 supplementCoverageVariable = ,
 folder =);


 /* Setting */
 ods html close;
 ods listing close;
 ods noresults;
 ods exclude all;
 ods graphics off;
 OPTION SPOOL;


/* format */
proc format; 
   value nationalFormat
       -255 = "Overall";
run;


data _data0;
   set &data;
run;

/* check if variables exist */
%macro VarExist(ds, var);
    %local rc dsid result;
    %let dsid = %sysfunc(open(&ds));
 
    %if %sysfunc(varnum(&dsid, &var)) > 0 %then %do;
        %let result = 1;
        /*%put Good: Variable &var exists in &ds ***************************************;*/
    %end;

    %else %do;
        %let result = 0;
		%put "** ERROR *******************************************************************"; 
        %put "** Variable (&var) does not exist in dataset (&ds)";
	    %put "** Processing of the SIMPLE macro will be stopped.";
        %put "****************************************************************************";
    %end;
 
    %let rc = %sysfunc(close(&dsid));
    %if &result = 0 %then %abort cancel;
%mend VarExist;


%macro VarShouldNotExist(ds, var, ds2);
    %local rc dsid result;
    %let dsid = %sysfunc(open(&ds));
 
    %if %sysfunc(varnum(&dsid, &var)) = 0 %then %do;
        %let result = 1;
    %end;

    %else %do;
        %let result = 0;
		%put "** ERROR *******************************************************************"; 
        %put "** datasets &ds. and &ds2. both have variable &var.";
		%put "** dataset &ds. should not have variable &var. because dataset &ds2 already has variable name &var";
        %put "** Please rename variable &var. in dataset &ds. **********************************************";
	    %put "** Processing of the SIMPLE macro will be stopped.";
        %put "****************************************************************************";
    %end;
 
    %let rc = %sysfunc(close(&dsid));
	%if &result = 0 %then %abort cancel;
%mend;



%let byBreastfeedingStatus = %upcase(&byBreastfeedingStatus);
%let supplementSimulation  = %upcase(&supplementSimulation);
%let SECalculationMethod   = %upcase(&SECalculationMethod);
%let covariates            = %upcase(&covariates);
%let breastfeedingVariable = %upcase(&breastfeedingVariable);
%let data                  = %upcase(&data);
%let supplementData        = %upcase(&supplementData);
%let breastmilkData        = %upcase(&breastmilkData);
%let supplementUse         = %upcase(&supplementUse);
%let nutrientType          = %upcase(&nutrientType);
%let corr                  = %upcase(&corr);




/*************************************************************
** check dataset *********************************************
**************************************************************/
/*
** 24-hr dietary recalls **
*/
%if &data = %str() %then %do; 
   %put "****************************************************************************";
   %put "** ERROR *******************************************************************"; 
   %put "** You must specify a 24HR dietary data after (data = )*********************";
   %put "** Processing of the SIMPLE macro will be stopped.**************************";
   %put "****************************************************************************";
   %return;
%end;


%if %sysfunc(exist(&data)) = 0 %then %do;
   %put "****************************************************************************";
   %put "** ERROR *******************************************************************"; 
   %put "** Dietary recall Data (&data) does not exist   ****************************";
   %put "** Processing of the SIMPLE macro will be stopped.  ************************";
   %put "****************************************************************************";
   %return;
%end; 

/*
* If the location of the folder exist
*
%if &folder. = %str() %then %do; 
   %put "****************************************************************************";
   %put "** ERROR *******************************************************************"; 
   %put "** You must specify a directory to save the result files after (folder = )*****";
   %put "** Processing of the SIMPLE macro will be stopped.**************************";
   %put "****************************************************************************";
   %return;
%end;
*/

libname out "&folder.";
/*
%if %sysfunc(libref(out)) ^= 0 %then %do;
   %put "****************************************************************************";
   %put "** ERROR *******************************************************************" ; 
   %put "** Directory (&folder) does not exist.**";
   %put "** Processing of the SIMPLE macro will be stopped.  ************************";
   %put "****************************************************************************";; 
   %return;
%end; 
*/
/* subject ID */
%if &subjectID = %str() %then %do; 
   %put "****************************************************************************";
   %put "** ERROR *******************************************************************"; 
   %put "** You must specify an observation ID variable after (subjectID = )*****";
   %put "** Processing of the SIMPLE macro will be stopped.**************************";
   %put "****************************************************************************";
   %return;
%end;

%put %VarExist(&data, &subjectID);

data subjectData;
   set &data (keep = &subjectID.);
       if &subjectID. =  abs(int(&subjectID.)) then subjectDecimal = 0;
       if &subjectID. ^= abs(int(&subjectID.)) then subjectDecimal = 1;
run;

proc means data = subjectData max noprint;
  var subjectDecimal;
  output out = subjectDecimal min = subjectDecimal;
run;

data _null_;
   set subjectDecimal;
     call symput("subjectDecimal", subjectDecimal);
run;

proc delete data = subjectData subjectDecimal; run; quit;

%if &subjectDecimal ^= 0 %then %do;
   %put "**********************************************************";
   %put "** ERROR *************************************************"; 
   %put "** Values in subjectID (&subjectID) must be positive integers **";
   %put "** You have invalid values in subjectID (&subjectID) **";
   %put "** Processing of the SIMPLE macro will be stopped.  ******";
   %put "**********************************************************"; 
   %return;
%end; 

/* day variable */
%if &repeatRecallVariable = %str() %then %do; 
   %put "****************************************************************************";
   %put "** ERROR *******************************************************************"; 
   %put "** You must specify a variable indicating a dietary recall is the 1st or 2nd day 
        recalls for a participant after (repeatRecallVariable = ) **";
   %put "** Processing of the SIMPLE macro will be stopped.**************************";
   %put "****************************************************************************";
   %return;
%end;

%put %VarExist(&data, &repeatRecallVariable);

data repeatRecallVariableData;
   set &data (keep = &repeatRecallVariable.);
       if &repeatRecallVariable. =  abs(int(&repeatRecallVariable.)) then repeatRecallVariableDecimal = 0;
       if &repeatRecallVariable. ^= abs(int(&repeatRecallVariable.)) then repeatRecallVariableDecimal = 1;
run;

proc means data = repeatRecallVariableData max noprint;
  var repeatRecallVariableDecimal;
  output out = repeatRecallVariableDecimal min = repeatRecallVariableDecimal;
run;

data _null_;
   set repeatRecallVariableDecimal;
     call symput("repeatRecallVariableDecimal", repeatRecallVariableDecimal);
run;

proc delete data = repeatRecallVariableData repeatRecallVariableDecimal; run; quit;

%if &repeatRecallVariableDecimal ^= 0 %then %do;
   %put "**********************************************************";
   %put "** ERROR *************************************************"; 
   %put "** Values in repeatRecallVariable (&repeatRecallVariable) must be positive integers **";
   %put "** You have invalid values in repeatRecallVariable (&repeatRecallVariable) **";
   %put "** Processing of the SIMPLE macro will be stopped.  ******";
   %put "**********************************************************"; 
   %return;
%end; 

/* check if nutrient intake variable exist */
%if &nutrientVariable = %str() %then %do; 
   %put "****************************************************************************";
   %put "** ERROR *******************************************************************"; 
   %put "** You must specify a nutrient intake variable after (nutrientVariable = )*****";
   %put "** Processing of the SIMPLE macro will be stopped.**************************";
   %put "****************************************************************************";
   %return;
%end;

%put %VarExist(&data, &nutrientVariable);

/*
data _nutrientVariable; 
   set &data (keep = &nutrientVariable);
      if &nutrientVariable > 0 then nutrientYes = 1; else nutrientYes = 0;
run;

proc means data = _nutrientVariable mean noprint;
  var nutrientYes;
  output out = nutrientYes mean = nutrientYes;
run;

data _null_;
   set nutrientYes;
     call symput("nutrientYes", nutrientYes);
run;

proc delete data = _nutrientVariable NutrientYes; run; quit;


%if &nutrientYes < 0.9 %then %do;
   %put "**********************************************************";
   %put "** ERROR *************************************************"; 
   %put "** You nutrient variable (&nutrientVariable) is not a daily consumed nutrient/food **";
   %put "** More than 10% of people do not consume this nutrient/food **";
   %put "** SIMPLE macro can only be applied to daily consumed nutrient/food **";
   %put "** Processing of the SIMPLE macro will be stopped.  ******";
   %put "**********************************************************"; 
   %return;
%end;
*/

/* subgroup */
%if &subgroup NE %str() %then %do;
    %put %VarExist(&data, &subgroup);
%end;

/* seq variables */
%if &seq NE %str() %then %do;
	%let nSeq = %sysfunc(countw(&seq));
	%do SeqNo = 1 %to &nSeq;
	    %put %VarExist(&data, %scan(&seq, &nSeq));
	%end;
%end;

/* weekend */
%if &weekend NE %str() %then %do;
    %put %VarExist(&data, &weekend);
    
	data _weekendData;
	   set &data (keep = &weekend);
	   if NOT(&weekend in (0, 1)) then weekendOutside = 1; else weekendOutside = 0;
	 run;

	proc means data = _weekendData max noprint;
	  var weekendOutside;
	  output out = weekendOutside max = weekendOutside;
	run;

	data _null_;
	   set weekendOutside;
	     call symput("weekendOutside", weekendOutside);
	run;

    proc delete data = _weekendData weekendOutside; run;

	%if &weekendOutside ^= 0 %then %do;
	   %put "**********************************************************";
	   %put "** ERROR *************************************************"; 
	   %put "** The weekend variable can only have two levels: 1 = weekend; 0 = weekdays **";
	   %put "** Your weekend variable (&weekend) has values that are neither 0 nor 1 ***";
	   %put "** Processing of the SIMPLE macro will be stopped.  ******";
	   %put "**********************************************************"; 
	   %return;
	%end; 
%end;

/* outputDataName */
%if &outputDatasetName. = %str() %then %do; 
   %put "****************************************************************************";
   %put "** ERROR *******************************************************************"; 
   %put "** You must specify the suffix of the SIMPLE macro result files after (outputDatasetName. = ) **";
   %put "** Processing of the SIMPLE macro will be stopped.**************************";
   %put "****************************************************************************";
   %return;
%end;

%if %length(&outputDatasetName.) >= 17 %then %do;
   %put "****************************************************************************";
   %put "** ERROR *******************************************************************"; 
   %put "** Output Dataset Name (&outputDatasetName) is too long. *******************";
   %put "** Please keep the output dataset name to less than 15 characters ***********";
   %put "** Processing of the SIMPLE macro will be stopped.  ************************";
   %put "****************************************************************************";; 
   %return;
%end; 

/* check covariates */
%if &covariates NE %str() %then %do;
	%let ncovariates=%sysfunc(countw(&covariates));
	%do covarNo = 1 %to &ncovariates;
	    %put %VarExist(&data, %scan(&covariates, &covarNo.));
	%end;
%end;


/* EAR */
%if &EARVariable NE %str() %then %do;
    %put %VarExist(&data, &EARVariable);
%end;

/*EAR number */
%if &EARValue NE %str() %then %do;
    %if %SYSEVALF(&EARValue < 0) OR (%sysfunc(verify(&EARValue, 0123456789)) = 1) %then %do;
      %put "**********************************************************";
      %put "** ERROR *************************************************" ; 
      %put "** EAR number must be a positive number  *****************";
      %put "** Processing of the SIMPLE macro will be stopped.  ******";
      %put "**********************************************************";
      %return;
    %end;
%end;

%if (&EARValue NE %str() & &EARVariable NE %str()) %then %do;
      %put "**********************************************************";
      %put "** ERROR *************************************************" ; 
      %put "** You cannot specify an EAR number and an EAR variable at the same time";
      %put "** Processing of the SIMPLE macro will be stopped.  ******";
      %put "**********************************************************";
      %return;
%end;

%if &EARVariable EQ %str() AND &EARValue NE %str() %then %do;
    data _data0;
	    set _data0;
		   EARVariable = &EARValue;
	run;
    
	/* given the string value to &EAV variable */
	%let EARVariable = EARVariable;
%end;

%if &EARVariable EQ %str() AND &EARValue EQ %str() %then %do;
    %let inadqDataset = %str();
    %let inadequate_percent =  %str();
	%let inadequate_percent_SE = %str();
%end;

%if &EARVariable NE %str() %then %do;
    %let inadequate_percent =  inadequate_percent;
	%let inadequate_percent_SE = inadequate_percent_SE;
%end;


/* UL */
%if &ULVariable NE %str() %then %do;
    %put %VarExist(&data, &ULVariable);
%end;


%if &ULValue NE %str() %then %do;
    %if %SYSEVALF(&ULValue < 0) OR (%sysfunc(verify(&ULValue, 0123456789)) = 1) %then %do;
      %put "**********************************************************";
      %put "** ERROR *************************************************" ; 
      %put "** The UL number must be a positive number  **************";
      %put "** Processing of the SIMPLE macro will be stopped.  ******";
      %put "**********************************************************";
      %return;
    %end;
%end;

%if (&ULValue NE %str() & &ULVariable NE %str()) %then %do;
      %put "***********************************************************";
      %put "** ERROR **************************************************" ; 
      %put "** You cannot have an UL number and an UL variable at the same time";
      %put "** Processing of the SIMPLE macro will be stopped.  ******";
      %put "**********************************************************";
      %return;
%end;

%if &ULVariable EQ %str() AND &ULValue NE %str() %then %do;
    data _data0;
	    set _data0;
		   ULVariable = &ULValue;
	run;
    
	/* given the string value to &EAV variable */
	%let ULVariable = ULVariable;
	%put &ULVariable;
%end;

%if &ULVariable EQ %str() AND &ULValue EQ %str() %then %do;
    %let ExcessiveDataset = %str();
    %let excessive_percent =  %str();
	%let excessive_percent_SE = %str();
%end;

%if &ULVariable NE %str() %then %do;
    %let excessive_percent =  excessive_percent;
	%let excessive_percent_SE = excessive_percent_SE;
%end;


/****************************************************************
** dietary supplement check *************************************
*****************************************************************/

/* dietary supplement data */
%if &supplementData NE %str() %then %do;
    %if %sysfunc(exist(&supplementData)) = 0 %then %do;
	   %put "****************************************************************************";
	   %put "** ERROR *******************************************************************"; 
	   %put "** Dietary Supplement Data (&supplementData) does not exist*****************";
	   %put "** Processing of the SIMPLE macro will be stopped.**************************";
	   %put "****************************************************************************";
	   %return;
	%end; 

	%if &supplementID EQ %str() %then %do;
	   %put "**********************************************************";
	   %put "** ERROR *************************************************"; 
	   %put "** You must enter the name of the supplement ID variable";
	   %put "** Processing of the SIMPLE macro will be stopped. *******";
	   %put "**********************************************************";; 
	   %return;
	%end; 

    %put %VarExist(&supplementData, &supplementID);
	%put %VarExist(&Data, &supplementID);
    
	%if &supplementNutrientVariable EQ %str() %then %do;
	   %put "**********************************************************";
	   %put "** ERROR *************************************************"; 
	   %put "** You must enter the name of the supplement nutrient variable";
	   %put "** Processing of the SIMPLE macro will be stopped. *******";
	   %put "**********************************************************";; 
	   %return;
	%end; 

    %put %VarExist(&supplementData, &supplementNutrientVariable);
	
	%if &data NE &supplementData %then %do;
        %put %VarShouldNotExist(&data., &supplementNutrientVariable., &supplementData.);
    %end;

    %if &supplementSimulation NE %str(YES) AND &supplementUse EQ %str() %then %do;
		%put "**********************************************************";
		%put "** ERROR *************************************************" ; 
		%put "** You must include a binary variable indicating if participants use dietary supplements";
		%put "** Processing of the SIMPLE macro will be stopped.  ******";
		%put "**********************************************************";; 
		%return;
    %end;

	%if &supplementUSE NE %str() %then %do;
	   %put %VarExist(&supplementData, &supplementUse);

	   data _supplementUseData;
	       set &supplementData (keep = &supplementUse);
	       if NOT(&supplementUse in (0, 1)) then supplementUseOutside = 1; else supplementUseOutside = 0;
	   run;

		proc means data = _supplementUseData max noprint;
		  var supplementUseOutside;
		  output out = supplementUseOutside max = supplementUseOutside;
		run;

		data _null_;
		   set supplementUseOutside;
		     call symput("supplementUseOutside", supplementUseOutside);
		run;

	    /*proc delete data = _supplementUseData outside; run;*/

		%if &supplementUseOutside ^= 0 %then %do;
		   %put "**********************************************************";
		   %put "** ERROR *************************************************"; 
		   %put "** The supplementUse variable can only have two levels: 1 = supplement Use; 0 = Non-supplement Use **";
		   %put "** Your supplementUse variable (&supplementUse) has values that are neither 0 nor 1 ***";
		   %put "** Processing of the SIMPLE macro will be stopped.  ******";
		   %put "**********************************************************"; 
		   %return;
		%end; 

		proc delete data = _supplementUseData supplementUseOutside; run; quit;

       %macro checkcontrol / minoperator;
           %if not(&supplementUSE in &covariates) %then %let covariates = &covariates &supplementUSE.;
	   %mend;

	   %checkcontrol;

        %if &data NE &supplementData %then %do; 
            %put %VarShouldNotExist(&data., &supplementUse, &supplementData.);
        
		    proc sort data = &data; by &supplementID; run;
		    proc sort data = &supplementData; by &supplementID; run;

			data _data0;
			   merge _data0(in = main) &supplementData (keep = &supplementID &supplementUse);
			     by &supplementID;
				 if main;
			run;
        %end;
	%end;
%end;



/********************************************************
** Breastmilk Nutrient Data check ***********************
*********************************************************/
/* breastmilk data */
%if &breastmilkData NE %str() %then %do;
    /* breastmilk */
	%if %sysfunc(exist(&breastmilkData)) = 0 %then %do;
	   %put "****************************************************************************";
	   %put "** ERROR *******************************************************************"; 
	   %put "** Breastmilk Nutrient Data (&breastmilkData) does not exist*****************";
	   %put "** Processing of the SIMPLE macro will be stopped.**************************";
	   %put "****************************************************************************";
	   %return;
	%end;
    
	/* breastmilkNutrientVariable */
    %if &breastmilkNutrientVariable = %str() %then %do;
	    %put "****************************************************************************";
        %put "** ERROR *******************************************************************"; 
        %put "** You must specify the name of breastmilk nutrient intake variable after (breastmilkNutrientVariable = ) **";
        %put "** Processing of the SIMPLE macro will be stopped.**************************";
        %put "****************************************************************************";
        %return;
    %end;

    %put %VarExist(&breastmilkData, &breastmilkNutrientVariable);
    
	
	%if &data. NE &breastmilkData. %then %do; 
       %put %VarShouldNotExist(&data., &breastmilkNutrientVariable., &breastmilkData.);
    %end;


    %if &supplementData NE &breastmilkData AND &supplementData NE %str() %then %do;
       %put %VarShouldNotExist(&supplementData., &breastmilkNutrientVariable., &breastmilkData.);
    %end;
    
	/* breastmilk ID */
    %if &breastmilkID = %str() %then %do;
	    %put "****************************************************************************";
        %put "** ERROR *******************************************************************"; 
        %put "** You must specify the ID of breastmilk nutrient dataset after (breastmilkID = ) **";
        %put "** Processing of the SIMPLE macro will be stopped.**************************";
        %put "****************************************************************************";
        %return;
    %end;

    %put %VarExist(&breastmilkData, &breastmilkID);
	%put %VarExist(&data, &breastmilkID);

    /*breastfeeding variable */
    %if &breastfeedingVariable = %str() %then %do;
	    %put "****************************************************************************";
        %put "** ERROR *******************************************************************"; 
        %put "** You must specify a binary variable in 24HRs indicating if the child is breastfed or not after (breastfeedingVariable = ) **";
        %put "** Processing of the SIMPLE macro will be stopped.**************************";
        %put "****************************************************************************";
        %return;
    %end;

	%put %VarExist(&data, &breastfeedingVariable);

    %if &supplementData NE &breastmilkData AND &supplementData NE %str() %then %do;
       %put %VarShouldNotExist(&supplementData., &breastfeedingVariable., &breastmilkData.);
    %end;

	data _breastfeedingVariableData;
	   set &data (keep = &breastfeedingVariable);
	   if NOT(&breastfeedingVariable in (0, 1)) then breastfeedingVariableOutside = 1; else breastfeedingVariableOutside = 0;
	 run;

	proc means data = _breastfeedingVariableData max noprint;
	  var breastfeedingVariableOutside;
	  output out = breastfeedingVariableOutside max = breastfeedingVariableOutside;
	run;

	data _null_;
	   set breastfeedingVariableOutside;
	     call symput("breastfeedingVariableOutside", breastfeedingVariableOutside);
	run;

    proc delete data = _breastfeedingVariableData Breastfeedingvariableoutside; run;

	%if &breastfeedingVariableOutside ^= 0 %then %do;
	   %put "**********************************************************";
	   %put "** ERROR *************************************************"; 
       %put "** The breastfeedingVariable variable can only have two levels: 1 = children being breastfed; 0 = children not being breastfed **";
	   %put "** Your breastfeedingVariable variable (&breastfeedingVariable) has values that are neither 0 nor 1 ***";
	   %put "** Processing of the SIMPLE macro will be stopped.  ******";
	   %put "**********************************************************"; 
	   %return;
	%end; 

   %macro checkcontrol / minoperator;
       %if not(&breastfeedingVariable. in &covariates) %then %let covariates = &covariates &breastfeedingVariable.;
   %mend;
   %checkcontrol;

%end;

/* ******************************************************
** Weight variable check ********************************
*********************************************************/

%if &SECalculationMethod = %str(BOOTSTRAP) %then %do;
   %let BRRFayFactor = 0; 
%end; 

/* check fayfactor */
%if (&SECalculationMethod NE %str(BRR)) AND (&SECalculationMethod NE %str(BOOTSTRAP)) AND (&SECalculationMethod NE %str(NOSE)) AND (&SECalculationMethod NE %str()) %then %do;
   %put "************************************************************************";
   %put "** ERROR ***************************************************************"; 
   %put "** You selected the SE calculation method to be &SECalculationMethod ***";
   %put "** SE calculation method must be one of 1) No SE; 2) BRR; 3) Bootstrap *";
   %put "** Please select a valid SE calculation method *************************";
   %put "** Processing of the SIMPLE macro will be stopped.**********************";
   %put "************************************************************************"; 
   %return;
%end; 


%if %upcase(&SECalculationMethod) = %str(BRR) AND &BRRFayFactor = %str() %then %do;
   %put "**********************************************************";
   %put "** ERROR *************************************************" ; 
   %put "**You must enter a Fay Factor when using BRR weights";
   %put "** Processing of the SIMPLE macro will be stopped.";
   %put "**********************************************************";
   %return;
%end; 

%if (&startWeight ^= &endWeight) AND (&SECalculationMethod = %str()) %then %do;
   %put "**********************************************************";
   %put "** ERROR *************************************************"; 
   %put "** You must enter a SE calculation method when you have repeated weights";
   %put "** Processing of the SIMPLE macro will be stopped.";
   %put "**********************************************************"; 
   %return;
%end; 

%if &startWeight ^= &endWeight AND  %upcase(&SECalculationMethod) = %str(NoSE) %then %do;
   %put "**********************************************************";
   %put "** ERROR *************************************************"; 
   %put "**You must enter a SE calculation method when you have repeated weights";
   %put "** Processing of the SIMPLE macro will be stopped.";
   %put "**********************************************************"; 
   %return;
%end; 


%if &startWeight ^= &endWeight AND  %upcase(&SECalculationMethod) = %str(BRR) AND &BRRFayFactor = %str() %then %do;
   %put "**********************************************************";
   %put "** ERROR *************************************************"; 
   %put "**You must enter a BRR Fay factor when you calculate BRR SE";
   %put "** Processing of the SIMPLE macro will be stopped.";
   %put "**********************************************************";
   %return;
%end; 

%if &startWeight ^= &endWeight AND  %upcase(&SECalculationMethod) = %str(BRR) AND ((&BRRFayFactor < 0 OR &BRRFayFactor > 2) OR (%sysfunc(verify(&BRRFayFactor, 0123456789)) = 1)) %then %do;
   %put "**********************************************************";
   %put "** ERROR *************************************************"; 
   %put "** BRR Fay facotor should be between 0 and 2 *************";
   %put "** Please enter a valid BRR Fay factor value *************";
   %put "** Processing of the SIMPLE macro will be stopped. *******";
   %put "**********************************************************";
   %return;
%end; 


%if &startWeight ^= &endWeight AND  &SECalculationMethod NE %str() %then %do;
    
	%do Wtno = &startWeight. %to  &endWeight.;
	     %let WTCheck =  &weightVariable.&WTno.; 

		 /* check if startweight is smaller than the endweight */
		 %if %SYSEVALF(&EndWeight. > &startWeight.) = 0 %then %do;
		   %put "**********************************************************";
		   %put "** ERROR *************************************************"; 
		   %put "** Starting weight must be smaller than the end weight ***";
		   %put "** Processing of the SIMPLE macro will be stopped.  ******";
		   %put "**********************************************************"; 
		   %return;
		%end; 
        
		 /* check if the weight exist */
		 %put %VarExist(&data, &WtCheck.);

         /* check if the weight is a positive number */
		 data WTdata;
		   set &data (keep = &WTCheck.);
               if &WTCheck. = abs(int(&WTCheck.)) then decimal = 0;
               if &WTCheck. ^= abs(int(&WTCheck.)) then decimal = 1;
		 run;

		proc means data = WTdata max noprint;
		  var decimal;
		  output out = decimal min = decimal;
		run;

		data _null_;
		   set decimal;
		     call symput("decimal", decimal);
		run;

		%put &decimal;

		%if &decimal ^= 0 %then %do;
		   %put "**********************************************************";
		   %put "** ERROR *************************************************"; 
		   %put "** Values in weight variable (&WTCheck) must be integers **";
		   %put "** Processing of the SIMPLE macro will be stopped.  ******";
		   %put "**********************************************************"; 
		   %return;
		%end; 

		proc delete data = WTData decimal; run; quit;
	%end;
    /* loope ends */
%end;

%if (&startWeight = &endWeight) AND  ((%upcase(&SECalculationMethod) EQ %str(BRR)) OR (%upcase(&SECalculationMethod) EQ %str(BOOTSTRAP))) %then %do;
   %put "**********************************************************";
   %put "** ERROR *************************************************" ; 
   %put "**You cannot calculate SE when you don't have repeated weights";
   %put "** Processing of the SIMPLE macro will be stopped.";
   %put "**********************************************************";; 
   %return;
%end;

%if &weightVariable = %str() %then %do ;       /* if no replicate variable */
   /* assign dummy weight if user  did not supply a surveyweight variable.  A value of 1 will be supplied */ 
   data _data0;
      set _data0;
	     dummywt0 = 1;
	run;

	%let weightVariable = dummywt;
	%let startWeight = 0;
	%let endweight = 0;
%end; /* no replicate variable */


/* single weight without repeated weight */
%if (&SECalculationMethod NE %str(BRR) AND &SECalculationMethod NE %str(BOOTSTRAP)) AND (&weightVariable NE %str()) %then %do;
   %let startWeight = 0;
   %let endWeight   = 0; 
 
   %put %VarExist(&data, &weightVariable);

	data _data0;
	   set _data0;
	        wt0 = &weightVariable;
	run;
%let weightVariable = wt;
%put "Weight is " &weightVariable;
%end; 

/***************************************************
** SIMPLE macro input parameter summary ************
***************************************************/
%put "***********************************************************";
%put "** SIMPLE MACRO Parameters****************************"; 
%put "** 24-hr dietary recall information ***********************"; 
%put "** folder = &folder **"; 
%put "** Note = &note **";
%put "** data= &data **"; 
%put "** nutrientVariable = &nutrientVariable **";
%put "** subjectID = &subjectID  **";
%put "** repeatRecallVariable = &repeatRecallVariable **";
%put "** seq = &seq **";
%put "** covariates = &covariates **";
%put "** outputDatasetName = &outputDatasetName **";
%put "** weekend = &weekend **";
%put "** subgroup = &subgroup **";
%put "** SECalculationMethod = &SECalculationMethod **";
%put "** BRRFayFactor = &BRRFayFactor **";
%put "** weightVariable = &weightVariable **";
%put "** startWeight = &startWeight **";
%put "** endWeight = &endWeight **";
%put "** EARValue = &EARValue **";
%put "** EARVariable = &EARVariable **";
%put "** ULValue = &ULValue **";
%put "** ULVariable = &ULVariable **";
%put "                                                           ";
%put "***********************************************************";
%put "** Dietary supplement information *************************"; 
%put "** supplementData  = &supplementData  **";
%put "** supplementID = &supplementID   **";
%put "** supplementNutrientVariable =  &supplementNutrientVariable **";
%put "** SupplementUse =  &SupplementUse**";
%put "** supplementSimulation  = &supplementSimulation  **";
%put "** supplementCoverageVariable = &supplementCoverageVariable  **";
%put "                                                           ";
%put "***********************************************************";
%put "** Breastfeeding information ******************************"; 
%put "** breastmilkData = &breastmilkData  **";
%put "** breastmilkID = &breastmilkID  **";
%put "** breastmilkNutrientVariable = &breastmilkNutrientVariable  **";
%put "** byBreastfeedingStatus = &byBreastfeedingStatus **";
%put "**********************************************************"; 



/***************************************************
** Clean work environment **************************
****************************************************/
/** clean work environment **/
%if %sysfunc(exist(out._parameter_&outputDatasetName.)) ^= 0 %then %do;
	proc delete data = out._parameter_&outputDatasetName. (gennum=all);
	run; quit; 
%end;

%if %sysfunc(exist(out._int_&outputDatasetName.)) ^= 0 %then %do;
	proc delete data = out._int_&outputDatasetName. (gennum=all);
	run; quit; 
%end;

%if %sysfunc(exist(out._final_&outputDatasetName. )) ^= 0 %then %do;
	proc delete data = out._final_&outputDatasetName. (gennum=all);
	run; quit; 
%end;

%if %sysfunc(exist(_parameter_&outputDatasetName. )) ^= 0 %then %do;
	proc delete data = _parameter_&outputDatasetName. (gennum=all);
	run; quit; 
%end;

%if %sysfunc(exist(_int_&outputDatasetName.)) ^= 0 %then %do;
	proc delete data = _int_&outputDatasetName. (gennum=all);
	run; quit; 
%end;


%if %sysfunc(exist(_final_&outputDatasetName.)) ^= 0 %then %do;
	proc delete data = _final_&outputDatasetName. (gennum=all);
	run; quit; 
%end;

%if %sysfunc(exist(_pred_unc_&outputDatasetName. )) ^= 0 %then %do;
	proc delete data = _pred_unc_&outputDatasetName.  (gennum=all);
	run; quit; 
%end;

%if %sysfunc(exist(_param_unc_&outputDatasetName.)) ^= 0 %then %do;
	proc delete data = _param_unc_&outputDatasetName. (gennum=all);
	run; quit; 
%end;

%if %sysfunc(exist(etas_&outputDatasetName. )) ^= 0 %then %do;
	proc delete data = etas_&outputDatasetName.  (gennum=all);
	run; quit; 
%end;

%if %sysfunc(exist(_parmsf2_&outputDatasetName. )) ^= 0 %then %do;
	proc delete data = _parmsf2_&outputDatasetName.  (gennum=all);
	run; quit; 
%end;

%if %sysfunc(exist(_int_all_&outputDatasetName. )) ^= 0 %then %do;
	proc delete data = _int_all_&outputDatasetName.  (gennum=all);
	run; quit; 
%end;

/*************************************************** 
a sub macro to calculate the parameter of interest 
***************************************************/
%macro results(mcsimData = , colname = , outputData =, parameterCalculation =);
	/*****************************
	** Parameter calculation *****
	*****************************/
	%if &parameterCalculation = %str(YES)& &nutrientType = %str(DAILY) %then %do;

		/* calculate parameters */
		** calculate the ratio of within/between person **;
		** Calculate total variance **;
		Data _param_unc_&outputDatasetName.; 
		    set _param_unc_&outputDatasetName.;
			    totalVariance = A_VAR_E + A_VAR_U2;
			    withToBetweenRatio = A_VAR_E / A_VAR_U2;
				withToTotal = A_VAR_E / totalVariance;
		run;

		** organize the dataset to be useful later **;
		proc transpose data = _param_unc_&outputDatasetName. 
		               out =  _param_unc_&outputDatasetName. (drop =_label_ rename = (col1 = &wt.));
		run;

		data _param_unc_&outputDatasetName.;
		  length _name_ $50.;
		  set _param_unc_&outputDatasetName.; 
		     if _name_ = "numvargrps" then delete;
		     if _name_ = "weekendflag" then delete;
		     if _name_ = "A_LOGSDE" then delete;
		     if _name_ = "A_LOGSDU2" then delete;
			 if _name_ = "min_amt" then _name_ = "Minimum Amount";
			 if _name_ = "A_VAR_U2" then _name_ = "Between-Person Variance";
			 if _name_ = "A_VAR_E" then _name_ = "Within-Person Variance";
			 if _name_ = "totalVariance"      then _name_ = "Total Variance";
			 if _name_ = "withToBetweenRatio" then _name_ = "Within- to Between-person Ratio";
			 if _name_ = "withToTotal"        then _name_ = "Within-person to Total variance ratio";
		run;


		proc delete data = _parmsf2_&outputDatasetName. etas_&outputDatasetName. _pred_unc_&outputDatasetName.; run; quit;

		%if &count. = 0 %then %do;
			data _parameter_&outputDatasetName.;
	            set _param_unc_&outputDatasetName.;
			run;
		%end;

		%if &count. ^= 0 %then %do;
			data _parameter_&outputDatasetName.;
		        set _parameter_&outputDatasetName.;
		        set _param_unc_&outputDatasetName.;
			run;
		%end;

		proc delete data =  _param_unc_&outputDatasetName. 
                            _param_&outputDatasetName. (gennum=all);run; quit; 

	%end;

    /* uncorrelated */
	%if &parameterCalculation = %str(YES) & &nutrientType = %str(EPISODICALLY) & &corr NE %str(YES) %then %do;

		/* calculate parameters */
		** calculate the ratio of within/between person **;
		** Calculate total variance **;
        /*
        Data _param_&outputDatasetName.; 
		    set _param_&outputDatasetName.;
			    totalVariance = A_VAR_E + A_VAR_U2;
			    withToBetweenRatio = A_VAR_E / A_VAR_U2;
				withToTotal = A_VAR_E / totalVariance;
		run;
        */

		** organize the dataset to be useful later **;
		proc transpose data = _param_unc_&outputDatasetName. 
		               out =  _param_unc_&outputDatasetName. (drop =_label_ rename = (col1 = &wt.));
		run;

		data _param_unc_&outputDatasetName.;
		  length _name_ $50.;
		  set _param_unc_&outputDatasetName.; 
		     if _name_ = "numvargrps" then delete;
		     if _name_ = "weekendflag" then delete;
		     if _name_ = "A_LOGSDE" then delete;
		     if _name_ = "A_LOGSDU2" then delete;
			 if _name_ = "P_LOGSDU1" then delete;
			 if _name_ = "Z_U" then delete;
			 if _name_ = "min_amt" then _name_ = "Minimum Amount";
			 *if _name_ = "A_VAR_U2" then _name_ = "Between-Person Variance";
			 *if _name_ = "A_VAR_E" then _name_ = "Within-Person Variance";
			 *if _name_ = "totalVariance"      then _name_ = "Total Variance";
			 *if _name_ = "withToBetweenRatio" then _name_ = "Within- to Between-person Ratio";
			 *if _name_ = "withToTotal"        then _name_ = "Within-person to Total variance ratio";
		run;


		proc delete data = _parmsf1_&outputDatasetName. _parmsf2_&outputDatasetName.
                           _parmsf3_&outputDatasetName. etas_&outputDatasetName. 
                           _pred_unc_&outputDatasetName. _pred_&outputDatasetName.
                           _param_unc _param; run; quit;

		%if &count. = 0 %then %do;
			data _parameter_&outputDatasetName.;
	            set _param_unc_&outputDatasetName.;
			run;
		%end;

		%if &count. ^= 0 %then %do;
			data _parameter_&outputDatasetName.;
		        set _parameter_&outputDatasetName.;
		        set _param_unc_&outputDatasetName.;
			run;
		%end;

		proc delete data =  _param_unc_&outputDatasetName.; run; quit; 

	%end;


	/* correlated */
	%if &parameterCalculation = %str(YES)& &nutrientType = %str(EPISODICALLY) & &corr = %str(YES) %then %do;

		/* calculate parameters */
		** calculate the ratio of within/between person **;
		** Calculate total variance **;
        /*
        Data _param_&outputDatasetName.; 
		    set _param_&outputDatasetName.;
			    totalVariance = A_VAR_E + A_VAR_U2;
			    withToBetweenRatio = A_VAR_E / A_VAR_U2;
				withToTotal = A_VAR_E / totalVariance;
		run;
        */

		** organize the dataset to be useful later **;
		proc transpose data = _param_&outputDatasetName. 
		               out =  _param_&outputDatasetName. (drop =_label_ rename = (col1 = &wt.));
		run;

		data _param_&outputDatasetName.;
		  length _name_ $50.;
		  set _param_&outputDatasetName.; 
		     if _name_ = "numvargrps" then delete;
		     if _name_ = "weekendflag" then delete;
		     if _name_ = "A_LOGSDE" then delete;
		     if _name_ = "A_LOGSDU2" then delete;
			 if _name_ = "P_LOGSDU1" then delete;
			 if _name_ = "Z_U" then delete;
			 if _name_ = "min_amt" then _name_ = "Minimum Amount";
			 *if _name_ = "A_VAR_U2" then _name_ = "Between-Person Variance";
			 *if _name_ = "A_VAR_E" then _name_ = "Within-Person Variance";
			 *if _name_ = "totalVariance"      then _name_ = "Total Variance";
			 *if _name_ = "withToBetweenRatio" then _name_ = "Within- to Between-person Ratio";
			 *if _name_ = "withToTotal"        then _name_ = "Within-person to Total variance ratio";
		run;


		proc delete data = _parmsf1_&outputDatasetName. _parmsf2_&outputDatasetName.
                           _parmsf3_&outputDatasetName. etas_&outputDatasetName. 
                           _pred_unc_&outputDatasetName. _pred_&outputDatasetName.; run; quit;

		%if &count. = 0 %then %do;
			data _parameter_&outputDatasetName.;
	            set _param_&outputDatasetName.;
			run;
		%end;

		%if &count. ^= 0 %then %do;
			data _parameter_&outputDatasetName.;
		        set _parameter_&outputDatasetName.;
		        set _param_&outputDatasetName.;
			run;
		%end;

		proc delete data =  _param_unc_&outputDatasetName. (gennum=all);run; quit; 

	%end;

	/* calculating the national average */
	** calculate the percent of inadequate intake **;
	%if &EARVariable NE %str() %then %do;

		proc surveymeans data = &mcsimData.; 
			var inadq;
			weight mcsim_wt;
			ods output Statistics = _inadq;
		run;

		data _inadq;
		    set _inadq (keep = mean rename = (mean = inadequate_percent));
			   inadequate_percent = inadequate_percent * 100;
		run;

		%let inadqDataset = _inadq;

	%end;

	** calculate excessive intake **;
	%if &ULVariable NE %str() %then %do;

		proc surveymeans data = &mcsimData.; 
			var excessive;
			weight mcsim_wt;
			ods output Statistics = _excessive;
		run;

		data _excessive;
		    set _excessive (keep = mean rename = (mean = excessive_percent));
			   excessive_percent = excessive_percent * 100;
		run;

		%let excessiveDataset = _excessive;

	%end;

	** 25, 50, and 75 percentile **;
	proc univariate data = &mcsimData. noprint; 
	    var mc_t;
	    weight mcsim_wt;
	    output out = _pctile pctlpre = P_ pctlpts = 25 50 75;
	run;

	data _pctile;
	    set _pctile;
		  P_25 = P_25;
		  P_75 = P_75;
		  median = P_50;
		  *IQR = cat("(", put(P_25, f5.1-L), ", ", put(P_75, f5.1-L), ")");
		  *drop P_25;
		  *drop P_75;
		  drop P_50;
	run;


	** calculate the mean **;
	proc surveymeans data = &mcsimData.; 
		var mc_t;
		weight mcsim_wt;
		ods output Statistics = _mean;
	run;

	** calculate the sample size as the number of psedo person/ 100 **;
	data _mean;
	    set _mean (keep = N mean);
	    n = n / 100;
		mean = mean;
	run;

/**************************************************************************************
** NOTE TO BROOKE: THIS IS WHERE YOU ADD CODE TO CALCULATE STANDARD DEVIATION *********
**************************************************************************************/

	** calculate the standard deviation **;

	/*Step 1: Computed y and N;*/

	proc surveymeans data=&mcsimData. mean stacking;
		var mc_t;
		weight mcsim_wt;
	   ods output Statistics = Statistics
	              Summary = Summary;
	run;

	* The following DATA step saves the sample mean of the variable mc_t 
	in a macro variable named mc_t_Mean:;

	data _null_;
	   set Statistics;
	   call symput("mc_t_Mean", mc_t_Mean);
	run;

	* The next DATA step saves the sum of the sampling weights in a 
	macro variable named N, the number of strata in a macro variable 
	named H, and the number of clusters in a macro variable named C:;

	data Summary;
	   set Summary;
	   if Label1="Sum of Weights" then call symput("N",cValue1);
	   if Label1="Number of Strata" then call symput("H",cValue1);
	   if Label1="Number of Clusters" then call symput("C",cValue1);
	run;

	/*Step 2: Construct the Variable z*/

	* Construct the variable z in a DATA step by using the macro variables 
	Spending_Mean and N:;

	data Working;
	   set &mcsimData.;
	   z=(1/(&N-1))*(mc_t-&mc_t_Mean)**2;
	run;

	/*Step 3: Estimate the Total of z and Take the Square Root of the Total*/

	* Use PROC SURVEYMEANS to estimate the weighted total of the variable z. 
	Specify the SUM and STACKING options in the PROC SURVEYMEANS statement. 
	The ODS OUTPUT statement saves the statistics table to a data set named 
	Result.;

	proc surveymeans data = Working sum stacking;
	   weight mcsim_wt;
	   var z;
	   ods output Statistics = Result;
	run;

	* The following DATA step retrieves the estimated total of z and stores 
	it in a macro variable named Variance. The total of z is equal to s^2. 
	Take the square root of the estimated total and store it in a macro 
	variable named StdDev. The square root of the estimated total is the 
	finite population standard deviation s.;

	data Result;
	   set Result;
	   StdDev=sqrt(z_Sum);
	run;

*** END SD CALCULATION ****************************************************************;

	%if &subgroup NE %str() %then %do;
		** merge the data together **;
		data &outputData;
		    &subgroup = -255;
		    merge _mean &inadqDataset &excessiveDataset _pctile Result;
		run;
	%end;

	%if &subgroup EQ %str() %then %do;
		** merge the data together **;
		data &outputData;
		    merge _mean &inadqDataset &excessiveDataset _pctile Result;
		run;
	%end;

	/* clean the environment*/
	proc delete data = &inadqDataset &excessiveDataset  _mean  _pctile Result (gennum=all); run; quit;


	/* calculating the subgroup */
	/**** choose if continue the loop */
	%if &subgroup NE %str() %then %do; 

		proc sort data = &mcsimData.; by &subgroup; run;


		%if &EARVariable NE %str() %then %do;
			proc surveymeans data = &mcsimData.; 
			    var inadq;
				weight mcsim_wt;
				by &subgroup;
			    ods output Statistics = _inadq;
			run;

			data _inadq; 
			   set _inadq (keep = &subgroup mean rename = (mean = inadequate_percent));
			   inadequate_percent = inadequate_percent * 100;
			run;
	        
			%let inadqDataset = _inadq;

		%end; 

		** calculate excessive intake **;
		%if &ULVariable NE %str() %then %do;

			proc surveymeans data = &mcsimData.; 
				var excessive;
				weight mcsim_wt;
				by &subgroup;
				ods output Statistics = _excessive;
			run;

			data _excessive;
			    set _excessive (keep = mean rename = (mean = excessive_percent));
				   excessive_percent = excessive_percent * 100;
			run;

			%let excessiveDataset = _excessive;

		%end;

		** 25, 50, and 75 percentile **;
		proc univariate data = &mcsimData. noprint; 
		    var mc_t;
			weight mcsim_wt;
			by &subgroup;
			output out = _pctile pctlpre = P_ pctlpts = 25 50 75;
		run;

		data _pctile;
		   set _pctile;
		      P_25 = P_25;
			  P_75 = P_75;
			  median = P_50;
		      *IQR = cat("(", put(P_25, f5.1-L), ", ", put(P_75, f5.1-L), ")");
			  *drop P_25;
			  *drop P_75;
			  drop P_50; 
		run;


		** calculate the mean **;
		proc surveymeans data = &mcsimData.; 
		    var mc_t;
			weight mcsim_wt;
			by &subgroup;
		    ods output Statistics = _mean;
		run;

		** calculate the sample size as the number of psedo person/ 100 **;
		data _mean;
		    set _mean (keep = &subgroup N mean);
			    n = n / 100;
				mean = mean;
		run;

/**************************************************************************************
** NOTE TO BROOKE: THIS IS WHERE YOU ADD CODE TO CALCULATE STANDARD DEVIATION *********
**************************************************************************************/

		** calculate the standard deviation **;

		/*Step 1: Computed y and N;*/

		proc sort data=&mcsimData.;
		by &subgroup;
		run;

		proc surveymeans data=&mcsimData. mean stacking;
			var mc_t;
			weight mcsim_wt;
			by &subgroup;
		   ods output Statistics = Statistics
		              Summary = Summary;
		run;

		* The following DATA step saves the sample mean of the variable Spending 
		in a macro variable named Spending_Mean:;

		*data _null_;
		*   set Statistics;
		*   call symput("mc_t_Mean",mc_t_Mean);
		*run;

		* Instead of code above, just merge Statistics dataset with mcsimdata;

		data Statistics;
		set Statistics;
		keep &subgroup mc_t_mean;
		run;

		* merge;
		data &mcsimData.;
		merge &mcsimData. Statistics;
		by &subgroup;
		run;

		* The next DATA step saves the sum of the sampling weights in a 
		macro variable named N, the number of strata in a macro variable 
		named H, and the number of clusters in a macro variable named C:;

		data Summary1;
		   set Summary;
		   where Label1="Sum of Weights";
		   n = nvalue1;
		   keep &subgroup n;
		run;

		* merge with nhanes;
		data &mcsimData.;
		merge &mcsimData. summary1;
		by &subgroup;
		run;

		/*Step 2: Construct the Variable z*/

		* Construct the variable z in a DATA step by using the macro variables 
		Spending_Mean and N:;

		data Working;
		   set &mcsimData.;
		   z=(1/(N-1))*(mc_t-mc_t_Mean)**2;
		run;

		/*Step 3: Estimate the Total of z and Take the Square Root of the Total*/

		* Use PROC SURVEYMEANS to estimate the weighted total of the variable z. 
		Specify the SUM and STACKING options in the PROC SURVEYMEANS statement. 
		The ODS OUTPUT statement saves the statistics table to a data set named 
		Result.;

		proc sort data=Working;
		by &subgroup;
		run;

		proc surveymeans data = Working sum stacking;
		   weight mcsim_wt;
		   var z;
		   by &subgroup;
		   ods output Statistics = Result;
		run;

		* The following DATA step retrieves the estimated total of z and stores 
		it in a macro variable named Variance. The total of z is equal to s^2. 
		Take the square root of the estimated total and store it in a macro 
		variable named StdDev. The square root of the estimated total is the 
		finite population standard deviation s.;

		data Result;
		   set Result;
		   StdDev=sqrt(z_Sum);
		   keep &subgroup stddev;
		run;

*** END SD CALCULATION ****************************************************************;

		** merge the data together **;
		data &outputData._&subgroup.;
		    merge _mean &inadqDataset &excessiveDataset  _pctile Result;
		run;


		/* clean the environment*/
		proc delete data = &inadqDataset &excessiveDataset  _mean  _pctile Result (gennum=all); run; quit;

		* merge all data together;
		data &outputData.;
		   set &outputData &outputData._&subgroup.;
		run;

		proc delete data = &outputData._&subgroup.; run; quit;

	%end;

	%if &subgroup EQ %str() %then %do;
		proc transpose data = &outputData. out = &outputData. (drop =_label_ rename = (col1 = %str(&colname)));  run;
	%end;

	%if &subgroup NE %str() %then %do;
	/* transpose data */
		proc sort data = &outputData.; by &subgroup; run;
		proc transpose data = &outputData. out = &outputData. (drop =_label_ rename = (col1 = %str(&colname))); by &subgroup; run;
	%end;

	/* merge all data together */
	    %if &count EQ 0 %then %do;
	        /* save dataset */
		    data &outputData._&outputDatasetName.;
			    set &outputData.;
		    run;  
	    %end;
	    
		%if &count NE 0 %then %do;
		    data &outputData._&outputDatasetName.;
			    set &outputData._&outputDatasetName.; 
		        set &outputData.;
			run;
	   %end;

	data &outputData._&outputDatasetName.;
	    length note $100;
	    note = "&note";
	    set &outputData._&outputDatasetName.; 
	run;

	proc delete data = &outputData.; run; quit;

%mend results;
/******************************************************
************end of the results macro ******************
*******************************************************/

/******************************************************
** calculating SE macro *******************************
*******************************************************/

%macro SECalculation(inputData = , outputData =);

%let var_begin = &weightVariable.%sysfunc(sum(&startWeight, 1));
%let var_end = &weightVariable.&endWeight;
%let number = %sysfunc(sum(&endWeight - &startWeight));


data &outputData;
    set &inputData;
        array brr (&number) &var_begin-&var_end;
           do i = 1 to &number;
     brr(i) = brr(i) - &weightVariable.&startWeight.;
      end;
    SE = sqrt(uss(of &var_begin-&var_end)/(&number *((1 - &BRRFayFactor) ** 2)));
    drop &var_begin-&var_end i;
	rename &weightVariable.&startWeight. = value;
run;

%mend SECalculation;
/*****************************************************
**calculating SE macro ends **************************
******************************************************/




/*********************************************************
** start loop ********************************************
**********************************************************/
%do count = &startWeight %to &endWeight;
	** assign weight **;
	%let wt = &weightVariable.&count;

    %put &count;
    %put weight is equal to &wt;
    
    
	** sort data before analyzing **;
	proc sort data = _data0;
	   by &subjectID &repeatRecallVariable;
	run;

    /*********************************
	** Daily consumed nutrients ******
	**********************************/
	%if &nutrientType = %str(DAILY) %then %do;
	%mixtran  (data = _data0,
		      response = &nutrientVariable,
	          modeltype = AMOUNT,	        
	          subject = &subjectID,
	          repeat = &repeatRecallVariable,
	          outlib = work, 
	          covars_amt= &covariates,                   
	          covars_prob=, 																 /* probability covariates are not used in an amount model */
		      foodtype = &outputDatasetName, 
	          seq = &seq,	                 
	          lambda = ,																			 /* allow the macro to calculate lambda     */
	          replicate_var = &wt,
	          weekend = &weekend,
	          vargroup=,numvargroups=,  									   /* no separate residual variance requested */
	          vcontrol=,start_val1=,start_val2=,start_val3=, /* this is a base run, no starting values  */
	          nloptions=qmax=61,
	          titles=4,
	          printlevel=2);                

	**** note: The parameters with null values can be omitted from this call.  ***
	****       They are included in the example purely for documentation.      ***;
    



 
	/* execute the DISTRIB macro using the parameter and predicted data sets prepared by the MIXTRAN macro*/
	/*  additional data from the analysis file will also be used for the subgroup and recommended amounts  */

	
	    
	   	%Distrib  (call_type = MC, 
	   	          modeltype = AMOUNT,
	   	          outlib = work,
	    	      subject = &subjectID,
	    	      mcsimda = work._mcsim_&outputDatasetName.&count,     	      	
	              pred =    work._pred_unc_&outputDatasetName., 
	              param =   work._param_unc_&outputDatasetName.,
	   	          seed = %SYSEVALF(1234 + &count.),            	    	      	      	      		          
	   	          nsim_mc=100,
	   	          food= &outputDatasetName.,															  
	    	      byvar=,   	                               /* MIXTRAN was not fit separately for by groups */                   	                            
	  	      	  cutpoints= 600 625 650,
	  	      	  ncutpnt=3,
	  	      	  wkend_prop=3/7,
	    	      add_da= _data0,  	      	   
	    	      subgroup= , /* NOT going to disaggregate by agegrp*/
	  		      recamt =,
	  		      recamt_co = ,
	  		      recamt_hi=, 															/* comparison is not a range */
	    	      titles=5);
    
	%end;


	/**********************************************************
	** EPISODICALLY consumed nutrients /correlated ******
	***********************************************************/
	%if &nutrientType = %str(EPISODICALLY) & &corr = %str(YES) %then %do;
	%mixtran  (data = _data0,
		      response = &nutrientVariable,
	          modeltype = corr,	        
	          subject = &subjectID,
	          repeat = &repeatRecallVariable,
	          outlib = work, 
	          covars_amt= &covariates,                   
	          covars_prob= &covariatesProb, 																 /* probability covariates are not used in an amount model */
		      foodtype = &outputDatasetName, 
	          seq = &seq,	                 
	          lambda = ,																			 /* allow the macro to calculate lambda     */
	          replicate_var = &wt,
	          weekend = &weekend,
	          vargroup=,numvargroups=,  									   /* no separate residual variance requested */
	          vcontrol=,start_val1=,start_val2=,start_val3=, /* this is a base run, no starting values  */
	          nloptions=qmax=61,
	          titles=4,
	          printlevel=2);                

	**** note: The parameters with null values can be omitted from this call.  ***
	****       They are included in the example purely for documentation.      ***;
   
 
	/* execute the DISTRIB macro using the parameter and predicted data sets prepared by the MIXTRAN macro*/
	/*  additional data from the analysis file will also be used for the subgroup and recommended amounts  */
	   	%Distrib  (call_type = MC, 
	   	          modeltype = corr,
	   	          outlib = work,
	    	      subject = &subjectID,
	    	      mcsimda = work._mcsim_&outputDatasetName.&count,     	      	
	              pred =    work._pred_&outputDatasetName., 
	              param =   work._param_&outputDatasetName.,
	   	          seed = %SYSEVALF(1234 + &count.),            	    	      	      	      		          
	   	          nsim_mc=100,
	   	          food= &outputDatasetName.,															  
	    	      byvar=,   	                               /* MIXTRAN was not fit separately for by groups */                   	                            
	  	      	  cutpoints= 600 625 650,
	  	      	  ncutpnt=3,
	  	      	  wkend_prop=3/7,
	    	      add_da= _data0,  	      	   
	    	      subgroup= , /* NOT going to disaggregate by agegrp*/
	  		      recamt =,
	  		      recamt_co = ,
	  		      recamt_hi=, 															/* comparison is not a range */
	    	      titles=5);
    
	%end;


	
	/**********************************************************
	** EPISODICALLY consumed nutrients /nocorrelated ******
	***********************************************************/
	%if &nutrientType = %str(EPISODICALLY) & &corr NE %str(YES) %then %do;
	%mixtran  (data = _data0,
		      response = &nutrientVariable,
	          modeltype = nocorr,	        
	          subject = &subjectID,
	          repeat = &repeatRecallVariable,
	          outlib = work, 
	          covars_amt= &covariates,                   
	          covars_prob= &covariatesProb, 																 /* probability covariates are not used in an amount model */
		      foodtype = &outputDatasetName, 
	          seq = &seq,	                 
	          lambda = ,																			 /* allow the macro to calculate lambda     */
	          replicate_var = &wt,
	          weekend = &weekend,
	          vargroup=,numvargroups=,  									   /* no separate residual variance requested */
	          vcontrol=,start_val1=,start_val2=,start_val3=, /* this is a base run, no starting values  */
	          nloptions=qmax=61,
	          titles=4,
	          printlevel=2);                

	**** note: The parameters with null values can be omitted from this call.  ***
	****       They are included in the example purely for documentation.      ***;
   
 
	/* execute the DISTRIB macro using the parameter and predicted data sets prepared by the MIXTRAN macro*/
	/*  additional data from the analysis file will also be used for the subgroup and recommended amounts  */
	   	%Distrib  (call_type = MC, 
	   	          modeltype = corr,
	   	          outlib = work,
	    	      subject = &subjectID,
	    	      mcsimda = work._mcsim_&outputDatasetName.&count,     	      	
	              pred =    work._pred_unc_&outputDatasetName., 
	              param =   work._param_unc_&outputDatasetName.,
	   	          seed = %SYSEVALF(1234 + &count.),            	    	      	      	      		          
	   	          nsim_mc=100,
	   	          food= &outputDatasetName.,															  
	    	      byvar=,   	                               /* MIXTRAN was not fit separately for by groups */                   	                            
	  	      	  cutpoints= 600 625 650,
	  	      	  ncutpnt=3,
	  	      	  wkend_prop=3/7,
	    	      add_da= _data0,  	      	   
	    	      subgroup= , /* NOT going to disaggregate by agegrp*/
	  		      recamt =,
	  		      recamt_co = ,
	  		      recamt_hi=, 															/* comparison is not a range */
	    	      titles=5);
    
	%end;

    /* delete useless results generated by Distrib Macro */
    proc delete data = _param _predicted2; run; quit;

	**** note: The parameters byvar and recamt_hi can be omitted in this call since they will not be used.  ***
	****       They are in the example only for the sake of documentation.                                  ***;

	/********************************************************************************* 
	*** Add breastmilk content, supplementation, calculate inadequate intake *********
	*********************************************************************************/
    /* find the first day of recalls */
	proc sort data = _data0;
	   by &subjectID &repeatRecallVariable;
	run;

	data dataCovariate;
	   set _data0;
	     by &subjectID;
		 if first.&subjectID.;
	run;

    /* subset the original dataset with covariates and hh/repeat */
    data dataCovariate; 
        set dataCovariate (keep = &subjectID &covariates &subgroup &repeatRecallVariable &breastmilkID &EARVariable &ULVariable);
    run;

  /* merge the data with MC data with the subsetted original data */
    data _mcsim_&outputDatasetName.&count;
	    merge _mcsim_&outputDatasetName.&count dataCovariate;
		by &subjectID;
	run;

	/* add breast milk concentration */
	%if &breastmilkData NE %str() %then %do ; 
		proc sort data = _mcsim_&outputDatasetName.&count; by &breastmilkID; run;
		proc sort data = &breastmilkData; by &breastmilkID; run;

		/* merge data with VAS */
		data _mcsim_&outputDatasetName.&count;
		   merge _mcsim_&outputDatasetName.&count &breastmilkData.;
		     by &breastmilkID;
		run;

		data _mcsim_&outputDatasetName.&count.;
	       set _mcsim_&outputDatasetName.&count.;
	            mc_t = mc_t +  &breastfeedingVariable. * &breastmilkNutrientVariable.;
	    run;

	%end;

	/* calculating supplementation coverage */
	%if &supplementData NE %str() %then %do; 

		proc sort data = _mcsim_&outputDatasetName.&count.; by &supplementID; run;
		proc sort data = &supplementData; by &supplementID; run;

        data supplementData2;
	      set &supplementData;
		     if &supplementNutrientVariable = . then &supplementNutrientVariable = 0;
		run;

		data _mcsim_&outputDatasetName.&count;
		   merge _mcsim_&outputDatasetName.&count (in = main) supplementData2;
		     by &supplementID;
			 if main;
		run;

		proc delete data = supplementData2; run; quit;

		 %if &supplementSimulation NE %str(YES) %then %do;
           data _mcsim_&outputDatasetName.&count;
			   set _mcsim_&outputDatasetName.&count;
				   mc_t = mc_t + &supplementNutrientVariable;
		  run;
		%end;
        
		%if &supplementSimulation EQ %str(YES) %then %do;
           %put "stop inside";
           data _mcsim_&outputDatasetName.&count;
			   set _mcsim_&outputDatasetName.&count;
			       randomNumber = rand('Uniform');
			       if randomNumber <= &supplementCoverageVariable. then supplementYes = 1;
			       if randomNumber >  &supplementCoverageVariable. then supplementYes = 0;
				   if randomNumber = . then supplementYes = .;
				   &supplementNutrientVariable = supplementYes * &supplementNutrientVariable;
				   mc_t = mc_t + &supplementNutrientVariable ;
		  run;
		%end;
	%end;


	%if &EARVariable NE %str() %then %do;
		/** inadquate intake by EAR cut off **/
		data _mcsim_&outputDatasetName.&count;
			    set _mcsim_&outputDatasetName.&count;
				    if mc_t >= &EARVariable >. then inadq = 0; 
					if .< mc_t <  &EARVariable then inadq = 1;
					if mc_t =. then inadq = .;
		run; 
	%end;


	%if &ULVariable NE %str() %then %do;
		/** EXCESSIVE INTAKE by UL cut off **/
		data _mcsim_&outputDatasetName.&count;
			    set _mcsim_&outputDatasetName.&count;
				    if mc_t >= &ULVariable >. then  excessive = 1; 
					if . < mc_t <  &ULVariable then  excessive = 0;
					if mc_t =. then excessive = .;
		run; 
	%end;

	/********************************************************************************* 
	*** Add breastmilk content, supplementation, calculate inadequate intake *********
	*********************************************************************************/


    /********************************************************************************* 
	*** Calculate the results  *******************************************************
	*********************************************************************************/
    %results(mcsimData = _mcsim_&outputDatasetName.&count, outputData = _int, colname = &wt, parameterCalculation = YES);

	%if &byBreastfeedingStatus = %str(YES) %then %do;
		/* breastfed children */
		data _mcsim_&outputDatasetName.&count._bf;
		   set _mcsim_&outputDatasetName.&count;
		      where &breastfeedingVariable = 1;
		run;

		/* non-breastfed children */
		data _mcsim_&outputDatasetName.&count._nonbf;
		   set _mcsim_&outputDatasetName.&count.;
		      where &breastfeedingVariable = 0;
		run;

		%results(mcsimData = _mcsim_&outputDatasetName.&count._bf, outputData = _int_bf, colname = &wt)
		%results(mcsimData = _mcsim_&outputDatasetName.&count._nonbf, outputData = _int_nonbf, colname = &wt);

		/*proc delete data = out._mcsim_&outputDatasetName.&count._bf out._mcsim_&outputDatasetName.&count._nonbf; run; */

		data _int_&outputDatasetName.;
		      people = "all children";
		      set _int_&outputDatasetName.;
		run;

		proc delete data = _mcsim_&outputDatasetName.&count._bf _mcsim_&outputDatasetName.&count._nonbf; run;

		/*proc delete data = _int_bf _int_nonbf; run;*/
        /* breastfeeding status end */  
    %end; 


	%if &byBreastfeedingStatus NE %str(YES) %then %do;
	    data _int_&outputDatasetName.;
		  length people $25.;
		  people = "population";
		      set _int_&outputDatasetName.;
		run;
	%end;

%if &count ^= &startweight. %then %do;
    proc delete data = _mcsim_&outputDatasetName.&count.;
%end;

%end;
/****************************************
****	count loop ends *****************
*****************************************/

%if &byBreastfeedingStatus = %str(YES) %then %do;
   data _int_bf_&outputDatasetName.;
      people = "breastfed children";
	  set _int_bf_&outputDatasetName.;
	run;

	data _int_nonbf_&outputDatasetName.;
	   people = "non-breastfed children";
	   set _int_nonbf_&outputDatasetName.;
	run;

	data _int_&outputDatasetName.;
	   length people $25.;
	   set _int_&outputDatasetName. _int_bf_&outputDatasetName. _int_nonbf_&outputDatasetName.;
	run;

    proc delete data = _int_nonbf_&outputDatasetName. _int_bf_&outputDatasetName.; run; quit;
%end;





/***************************************************
** CALCULATE the SE *********************************
****************************************************/
%if &startWeight ^= &endWeight %then %do;

    
	%SECalculation(inputData = _int_&outputDatasetName.,       outputData = _final_&outputDatasetName.);
	%SECalculation(inputData = _parameter_&outputDatasetName., outputData = _parameter_&outputDatasetName.);

    /* organize the final results */
	proc sort data = _final_&outputDatasetName.;
	    by  people &subgroup _name_ ;
	run;
    
	/* value */
    data value;
	   format _name_ $100. value f12.2;
	   set _final_&outputDatasetName. (keep = _name_ people &subgroup value);
	run;
    
    proc transpose data = value out = value; by people &subgroup; run;

    /* SE */
	data SE;
	   format _name_ $100. SE f12.2;
	   set _final_&outputDatasetName. (keep = _name_ people &subgroup SE);
	       _name_ = catt(_name_, "_SE");
	run; 
    
	proc transpose data = SE out = SE; by people &subgroup; run;
    
	/* merge data together */
	data _final_&outputDatasetName.;
	   length Note $100.;
	   Note = "&Note";
	   retain Note people N;
	   format Note $100. N f12.0;
	   merge value SE;
	   by people &subgroup;
	   drop _name_;
	run;


    data _final_&outputDatasetName.;
	   retain Note people &subgroup N  mean mean_SE 
              &inadequate_percent &inadequate_percent_SE 
	          &excessive_percent &excessive_percent_SE
              P_25 P_25_SE median median_SE P_75 P_75_SE;
       set _final_&outputDatasetName.;
	       drop N_SE;
	run;

    proc delete data = value se datacovariate; run; quit;
	
%end;


/* just point estimate*/
%if &startWeight = &endWeight %then %do;   
    proc sort data = _int_&outputDatasetName.;
	    by  people &subgroup _name_ ;
	run;
    
    /* read proper data */
    data _parameter_&outputDatasetName.;
	    set _parameter_&outputDatasetName. (rename = (&wt. = value));
	run;


    data _int_&outputDatasetName.;
	    set _int_&outputDatasetName. (rename = (&wt. = value));
	run;

	data _final_&outputDatasetName.;
	    set _int_&outputDatasetName.;
	run;
    

    /* value */
    data value;
	   format _name_ $100. value f12.2;
	   set _final_&outputDatasetName. (keep = _name_ &subgroup value people);
	run;
    
    proc transpose data = value out = value; by people &subgroup; run;
    
	/* merge data together */
	data _final_&outputDatasetName.;
	   length Note $100.;
	   Note = "&Note";
	   retain Note people N;
	   format Note $100. N f12.0;
       set value;
	   drop _name_;
	run;

    /* sort column*/
    data _final_&outputDatasetName.;
	   retain Note people &subgroup N  mean &inadequate_percent &excessive_percent
              P_25  median  P_75;
       set _final_&outputDatasetName.;
	run;    

    proc delete data = value se datacovariate; run; quit;

    
	/*
	proc delete data = out._int_&outputDatasetName.;run;
   */


%end;



/*******************************************************
** Supplement Nutrient Data ****************************
********************************************************/
%if &supplementData NE %str() /*AND &supplementSimulation NE %str(YES)*/%then %do;

	   proc surveymeans data = _mcsim_&outputDatasetName.&startWeight.;
	      var &supplementNutrientVariable.;
	      weight mcsim_wt;
		  ods output Statistics = _nutrient_supp;
	   run;

	    data _nutrient_supp;
		    set _nutrient_supp (keep = mean StdErr rename = (mean = supplement_mean StdErr = supplement_mean_SE));
	    run;

      %if &subgroup NE %str() %then %do;
	    * assign the overall -255;
	    data _nutrient_supp;
	      set _nutrient_supp;
		      &subgroup = -255;
	    run;

	    * calculate mean nutrition intake from supplements by subgroup;
	    proc surveymeans data = _mcsim_&outputDatasetName.&startWeight.;
		  var &supplementNutrientVariable.;
		  weight mcsim_wt;
		  ods output Statistics = _nutrient_supp_sub;
		  by &subgroup;
		run;
	    
	    data _nutrient_supp_sub;
		  set _nutrient_supp_sub (keep = &subgroup mean StdErr rename = (mean = supplement_mean StdErr = supplement_mean_SE));
	    run;
	 
		* merge subgroup with the overall data ;
		data _nutrient_supp;
	        set _nutrient_supp _nutrient_supp_sub;
		run;
		
		*delete the subgroup data;
		proc delete data = _nutrient_supp_sub; run; quit;

		proc sort data = _nutrient_supp; by &subgroup; run;
	  %end;
      
	  %put &byBreastfeedingStatus;
	  %if &byBreastfeedingStatus = %str(YES) %then %do;
	  %put "all children";
		  data _nutrient_supp;
		     set _nutrient_supp;
			    people = "all children";
		  run;
	  %end;

	  %if &byBreastfeedingStatus NE %str(YES) %then %do;
	  %put "population";
		  data _nutrient_supp;
		     set _nutrient_supp;
			    people = "population";
		  run;
	  %end;
%end;


%if &byBreastfeedingStatus = %str(YES) AND &supplementData NE %str() %then %do;
    %do bfStatus = 0 %to 1;
	   data _mcsim_&outputDatasetName.&startWeight._&bfStatus.;
	      set _mcsim_&outputDatasetName.&startWeight.;
		  where &breastfeedingVariable = &bfStatus.;
	   run;

       proc surveymeans data = _mcsim_&outputDatasetName.&startWeight._&bfStatus.;
	      var &supplementNutrientVariable.;
	      weight mcsim_wt;
		  ods output Statistics = _nutrient_supp_&bfStatus.;
	   run;

	    data _nutrient_supp_&bfStatus.;
		    set _nutrient_supp_&bfStatus. (keep = mean StdErr rename = (mean = supplement_mean StdErr = supplement_mean_SE));
	    run;

      %if &subgroup NE %str() %then %do;
	    * assign the overall -255;
	    data _nutrient_supp_&bfStatus.;
	      set _nutrient_supp_&bfStatus.;
		      &subgroup = -255;
	    run;

	    * calculate mean nutrition intake from supplements by subgroup;
	    proc surveymeans data = _mcsim_&outputDatasetName.&startWeight._&bfStatus.;
		  var &supplementNutrientVariable.;
		  weight mcsim_wt;
		  ods output Statistics = _nutrient_supp_sub_&bfStatus.;
		  by &subgroup;
		run;
	    
	    data _nutrient_supp_sub_&bfStatus.;
		  set _nutrient_supp_sub_&bfStatus. (keep = &subgroup mean StdErr rename = (mean = supplement_mean StdErr = supplement_mean_SE));
	    run;
	 
		* merge subgroup with the overall data ;
		data _nutrient_supp_&bfStatus.;
	        set _nutrient_supp_&bfStatus. _nutrient_supp_sub_&bfStatus.;
		run;
		
		*delete the subgroup data;
		proc delete data = _nutrient_supp_sub_&bfStatus.; run; quit;

		proc sort data = _nutrient_supp_&bfStatus.; by &subgroup; run;
       %end;
	%end;

    data _nutrient_supp_0;
	   set _nutrient_supp_0;
	      people = "non-breastfed children";
	run;

    data _nutrient_supp_1;
	   length people $25.;
	   set _nutrient_supp_1;
	      people = "breastfed children";
	run;

    data _nutrient_supp;
	   length people $25.; 
	   set _nutrient_supp _nutrient_supp_0 _nutrient_supp_1;
	run;

	proc delete data = _nutrient_supp_0 _nutrient_supp_1 _mcsim_&outputDatasetName.&startWeight._0 _mcsim_&outputDatasetName.&startWeight._1;
%end;



%if &supplementData NE %str()  %then %do;
    proc sort data = _final_&outputDatasetName.; by people &subgroup; run;
	proc sort data = _nutrient_supp; by people &subgroup; run;

    data _final_&outputDatasetName.;
	  merge _final_&outputDatasetName. _nutrient_supp;
	  by people &subgroup;
	run;

	proc delete data = _nutrient_supp; run; quit;

  	data _final_&outputDatasetName.;
	      retain Note people &subgroup N  mean mean_SE      
              supplement_mean supplement_mean_SE
	          &inadequate_percent &inadequate_percent_SE 
	          &excessive_percent &excessive_percent_SE
              P_25 P_25_SE median median_SE P_75 P_75_SE;
	     format supplement_mean f12.2 supplement_mean_SE f12.2;
         set _final_&outputDatasetName.;
     run;
%end;

%if &bybreastfeedingStatus EQ %str() %then %do;
      data _final_&outputDatasetName.;
         set _final_&outputDatasetName.;
		 drop people;
      run;

	  data _int_&outputDatasetName.;
         set _int_&outputDatasetName.;
		 drop people;
      run;
%end;

/***********************************
** format the subgroup *************
************************************/
%if &subgroup NE %str() %then %do;
	data _int_&outputDatasetName.; 
	  set _int_&outputDatasetName.;
	      &subgroup.2 = put(&subgroup, nationalFormat.);
		  drop &subgroup;
		  rename &subgroup.2 = &subgroup;
	run;

	data _int_&outputDatasetName.;
	    retain note &subgroup;
	    set _int_&outputDatasetName.;
	run;


	data _final_&outputDatasetName.;
	  set _final_&outputDatasetName.;
	      &subgroup.2 = put(&subgroup, nationalFormat.);
		  drop &subgroup;
		  rename &subgroup.2 = &subgroup;
	run;

    data _final_&outputDatasetName.;
	    retain note &subgroup;
	    set _final_&outputDatasetName.;
	run;
%end;


/*********************************************
** save dataset ****************************** 
**********************************************/
proc datasets lib = work memtype = data;
     modify _int_&outputDatasetName.;
     attrib _all_ label=' ';
     attrib _all_ format=;
contents data= _int_&outputDatasetName.;
run;
quit;

proc datasets lib = work memtype = data;
     modify _parameter_&outputDatasetName.;
     attrib _all_ label=' ';
     attrib _all_ format=;
contents data= _parameter_&outputDatasetName.;
run;
quit;


data out._final_&outputDatasetName.;
    set _final_&outputDatasetName.;
	No_replicates = &endWeight. - &startweight.;
run;

* BROOKE ADDED 01-12-24;
proc export data = out._final_&outputDatasetName.
    outfile="&folder/final_&outputDatasetName..csv"
    dbms=csv
    replace;
run;

data out._int_&outputDatasetName.;
    set _int_&outputDatasetName.;
run;

data out._parameter_&outputDatasetName.;
    set _parameter_&outputDatasetName.;
run;

 /* save the zipped file 
data out._mcsim_&outputDatasetName.&STARTWEIGHT.;
   set _mcsim_&outputDatasetName.&STARTWEIGHT.;
run;

ods package(mcsimData) open nopf;
ods package(mcsimData) add file= "&folder\_mcsim_&outputDatasetName.&STARTWEIGHT..sas7bdat";
ods package(mcsimData) publish archive 
  properties(
   archive_name="_mcsimData_&outputDatasetName..zip" 
   archive_path="&folder."
 );
ods package(mcsimData) close;
quit;
*/

proc delete data =  _mcsim_&outputDatasetName.&STARTWEIGHT.; run; quit;
proc delete data = _data0; run; quit;


proc delete data = _final_&outputDatasetName. _int_&outputDatasetName. _parameter_&outputDatasetName.;run; quit;

/*********************************************
** END ****************************************
** save dataset ******************************* 
**********************************************/

ods results on;
ods html;
ods listing close;

/* export data */
ods excel file = "&folder/final_&outputDatasetName..xls"
	options(sheet_name = "Usual intake" 
		orientation = "landscape"
		row_heights = "0,0"
		frozen_headers = "Yes" 
		frozen_rowheaders = "No" 
		index = "No" 
		);
%if &byBreastfeedingStatus = %str(YES) %then %do;
	proc report data = out._final_&outputDatasetName.;
	   columns _all_;
	   define note / style(column) = {width = 50% Tagattr = "wraptext:no"};
	   define people / style(column) = {width = 25% Tagattr = "wraptext:no"};
	   define _all_ /center;
	run;
%end;

%if &byBreastfeedingStatus NE %str(YES) %then %do;
	proc report data = out._final_&outputDatasetName.;
	   columns _all_;
	   define note / style(column) = {width = 50% Tagattr = "wraptext:no"};
	   define _all_ /center;
	run;
%end;

ods excel close;
 
* remove libname *;
LIBNAME out CLEAR;

/* put back setting*/
 ods listing;
 ods exclude none;

 /*
proc catalog c=work.formats force kill;
quit;
*/

%put ;
%put "**********************************************************";
%put "** SIMPLE MACRO COMPLETED*********************************"; 
%put "**********************************************************";
%put ;

%mend SIMPLE;
