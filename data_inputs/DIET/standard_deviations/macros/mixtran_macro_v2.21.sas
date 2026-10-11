/*******************************************************************************/
/*******************************************************************************/
/*                                                                             */
/*  THE MIXTRAN MACRO                                                          */
/*                                                                             */
/*******************************************************************************/
/*                     VERSION 2.21        11/02/2016                          */
/*                                                                             */
/* The MIXTRAN macro is used for the analysis of episodically                  */
/* consumed foods, foods consumed every day, and nutrients, and                */
/* output from the MIXTRAN macro is used by the DISTRIB macro for              */
/* estimation of the distribution of usual intake.                             */
/*                                                                             */
/* For episodically consumed foods, the MIXTRAN macro fits a two-              */
/* part nonlinear mixed model where the first part considers the               */
/* probability of consumption and the second part considers the                */
/* consumption-day amount.  The model allows for covariates and                */
/* includes a random effect in both parts and allows for correlation           */
/* between the random effects (Tooze et al., 2006, Journal of the              */
/* American Dietetic Association, 106, 1575-1587).                             */
/*                                                                             */
/* To fit this nonlinear mixed model with correlated random effects            */
/* (i.e. the correlated model), starting values for the two parts of           */
/* the model are obtained by first using the GENMOD procedure to fit           */
/* a probability model and an amount model.  Then a nonlinear mixed            */
/* model with uncorrelated random effects (i.e. the uncorrelated               */
/* model) is fit using two calls to the NLMIXED procedure, and the             */
/* parameter estimates from this model are used as starting values             */
/* for the correlated model.                                                   */
/*                                                                             */
/* For foods consumed every day and nutrients, the MIXTRAN macro               */
/* uses the GENMOD procedure to calculate starting values and uses             */
/* the NLMIXED procedure to fit an amount-only model.                          */
/*                                                                   
/* The syntax for calling the macro is:                                        */
/*                                                                             */
/* %MIXTRAN                                                                    */
/* (data=, response=, foodtype=, subject=, repeat=,                            */
/*  covars_prob=, covars_amt=, outlib=, modeltype=,                            */
/*  lambda=, replicate_var=, seq=,                                             */
/*  weekend=, vargroup=, numvargroups=,                                        */
/*  start_val1=, start_val2=, start_val3=, vcontrol=,                          */
/*  nloptions=, titles=, printlevel=,subgroup=)                                          */ 
/*                                                                             */
/*  where                                                                      */
/*                                                                             */
/*   "data"         * Specifies the dataset to be used.                        */
/*                                                                             */
/*   "response"     * Specifies the 24 hour recall variable.                   */
/*                                                                             */
/*   "foodtype"     * Specifies a name for the analysis, used to               */
/*                    identify the output data sets.  This value can           */
/*                    be the same as the response variable.                    */
/*                                                                             */
/*   "subject"      * Specifies the variable that uniquely                     */
/*                    identifies each subject.                                 */
/*                                                                             */
/*   "repeat"       * Specifies the variable that indexes repeated             */
/*                    observations for each subject.                           */
/*                                                                             */
/*   "covars_prob"    Specifies a list of covariates for the first             */
/*                    part of the model that models the probability            */
/*                    of consumption.  Covariates must be separated            */
/*                    by spaces.  Interactions must be in the order            */
/*                    specified by PROC GENMOD.  If the model type             */
/*                    is "amount" then covars_prob should be left as           */
/*                    a null string.                                           */
/*                                                                             */
/*   "covars_amt"   * Specifies a list of covariates for the second            */
/*                    part of the model that models the consumption-           */
/*                    day amount.  Covariates must be separated by             */
/*                    spaces.  Interactions must be in the order               */
/*                    specified by PROC GENMOD.                                */
/*                                                                             */
/*   "outlib"       * Specifies a directory where output data sets             */
/*                    are stored.  Outlib can not be null.                     */
/*                                                                             */
/*   "modeltype"    * Specifies the model.  The possible values are:           */
/*                    "null string" = fit correlated model,                    */
/*                    "corr"        = fit correlated model,                    */
/*                    "nocorr"      = fit uncorrelated model,                  */
/*                    "amount"      = fit amount-only model.                   */
/*                                                                             */
/*   "lambda"         Specifies a user supplied value for the                  */
/*                    Box-Cox transformation parameter, lambda.  If            */
/*                    a value is not supplied, the macro will                  */
/*                    calculate a value for lambda.                            */
/*                                                                             */
/*   "replicate_var"  Specifies the variable to be used in the                 */
/*                    replicate statement of PROC NLMIXED or the               */
/*                    freq statement of PROC UNIVARIATE.  The                  */
/*                    specified variable must be integer valued.               */
/*                                                                             */
/*   "seq"            Specifies one or more sequence indicator                 */
/*                    variables to account for effects due to the              */
/*                    sequence number of a subject's records.  This            */
/*                    variable can NOT also appear in covars_prob              */
/*                    or covars_amt.                                           */
/*                                                                             */
/*   "weekend"        Specifies the weekend (Fri.-Sun.) indicator              */
/*                    variable to account for a weekend effect.  A             */
/*                    value of 1 represents a Fri.-Sun. record, and            */
/*                    a value of 0 represents a Mon.-Thurs. record.            */
/*                    This variable can NOT also appear in                     */
/*                    covars_prob or covars_amt.                               */
/*                                                                             */
/*   "vargroup"       Specifies a variable that groups observations            */
/*                    to allow the model to incorporate a separate             */
/*                    residual variance parameter for each of these            */
/*                    groups of observations.  If the output from              */
/*                    this macro is to be used in the DISTRIB macro,           */
/*                    then only the weekend variable can be used.              */
/*                                                                             */
/*   "numvargroups"   Specifies the number of groups defined by the            */
/*                    vargroup variable.  If the output from this              */
/*                    macro is to be used in the DISTRIB macro and             */
/*                    weekend is the "vargroup" variable, then the             */
/*                    number of groups is 2.                                   */
/*                                                                             */
/*   "start_val1"     Starting values for probability model (nocorr).          */
/*                    Use only when vcontrol is called and parameter           */
/*                    estimates (i.e. _parmsf1_"foodtype") from a              */
/*                    previous execution of an analogous model are desired.    */
/*                    Specifies the starting values data set for the           */
/*                    1st PROC NLMIXED (i.e. NLMIXED for probability           */
/*                    model).                                                  */
/*                                                                             */
/*   "start_val2"     Starting values for the amount model.                    */
/*                    Use only when vcontrol is called and parameter           */
/*                    estimates (i.e. _parmsf2_"foodtype") from a              */
/*                    previous execution of an analogous model are desired.    */
/*                    Specifies the starting values data set for the           */
/*                    2nd PROC NLMIXED (i.e. NLMIXED for amount                */
/*                    model).                                                  */
/*                                                                             */
/*   "start_val3"     Starting values for correllated model (corr).            */
/*                    Use only when vcontrol and parameter                     */
/*                    estimates (i.e. _parmsf3_"foodtype") from a              */
/*                    previous execution of an analogous model are desired.    */ 
/*                    Specifies the starting values data set for the           */
/*                    3rd PROC NLMIXED (i.e. NLMIXED for correlated            */
/*                    model).                                                  */
/*                                                                             */
/*   "vcontrol"       Use only when starting values from a previous            */
/*                    execution of the same model are also used.               */
/*                    Specifies a 1 to 6 character name to                     */
/*                    differentiate output data sets for runs using            */
/*                    the same food.  See the parameters start_val1,           */
/*                    start_val2, and start_val3.  The default is              */
/*                    null.                                                    */
/*                                                                             */
/*   "nloptions"      Specifies a list of options to be added to all           */
/*                    calls to PROC NLMIXED, for example:                      */
/*                       nloptions=qpoints=1 gconv=1e-12 itdetails.            */
/*                                                                             */
/*   "titles"         Specifies the number of title lines (0-4) to             */
/*                    be reserved for the user's titles.  Up to 4              */
/*                    title lines may be reserved for the user's               */
/*                    titles.  The remaining title lines are used by           */
/*                    the macro.  The default value is 0.                      */
/*                                                                             */
/*   "printlevel"     Specifies 1, 2, or 3 to control the amount of            */
/*                    information printed in the list file.                    */
/*                    Printlevel=1 prints only the summary reports.            */
/*                    Printlevel=2 prints summary reports and output           */
/*                    from the NLMIXED procedures.  Printlevel=2 is            */
/*                    the default value.  Printlevel=3 prints                  */
/*                    summary reports amd output from all of the               */
/*                    statistical prodecures.                                  */
/*                                                                             */
/*   "subgroup"       Specifies one categorical variable used for              */
/*                    the calculation of a separate usual intake               */
/*                    distribution for each subgroup.  This variable           */
/*                    can be created from a combination of other               */
/*                    variables (e.g. age and sex) but all variables           */
/*                    used to define the subgroup variable must also           */
/*                    be among the covariates in the model.  The               */
/*                    subgroup variable is used in the DISTRIB                 */
/*                    macro; however it can optionally be included             */
/*                    in the call to the MIXTRAN macro to achieve              */
/*                    backward compatibility with version 1.1                  */
/*                    Calling a subgroup variable in MIXTRAN does not limit    */
/*                    users to only the named subgroup in DISTRIB.             */
/*                    A different subgroup variable can be called in DISTRIB   */
/*                    but see documentation for DISTRIB on how to do this.     */
/*                    The subgroup parameter can now be called in DISTRIB.        */  
/*                                                                             */
/*                                                                             */
/* Note:  * Parameters marked with an asterisk are mandatory, so a             */
/*          value must be supplied in the macro call.                          */
/*                                                                             */
/* Caution:  variable name "YN" is reserved for this macro.                    */
/*                                                                             */
/* Caution:  data set names "data" and "data0" and "misc_info" are             */
/*           reserved for this macro.                                          */
/*                                                                             */
/*******************************************************************************/
;

**** Global macro variables are declared. ********;
%global foodtype vcontrol ;


%macro MIXTRAN
(data=, response=, foodtype=, subject=, repeat=, covars_prob=, covars_amt=,
 outlib=, modeltype=, lambda=, replicate_var=, seq=, weekend=, vargroup=,
 numvargroups=, start_val1=, start_val2=, start_val3=, vcontrol=,
 nloptions=, titles=, printlevel=,subgroup=);

********************************************************;


%let var_u1start=1;  /* Updated 07/20/2017 per Kevin Dodd e-mail */

*************************************************************************;
**    setup         ;
*************************************************************************;
%let success = 0 ;           /* successful execution flag */
%let Convflag = 0 ;          /* flags convergence errors from Proc NLMIXED */

** IMS Specific ;
%let failed = 0 ;
**  END OF IMS SPECIFIC;

%let modeltype=%upcase(&modeltype); 

%let numvgminus1 = %eval(&numvargroups - 1);  
%if &numvargroups = %str() %then %let numvargroups=%str(0);



%if %length(&vcontrol) >6 %then %do;         /* capture version control     */
  %let vcontrol=%substr(&vcontrol,1,6);
  %put ## vcontrol reduced to 6 characters ;
%end;

%if &vcontrol = %str(1) %then %do;           /* version control in effect   */

  %if (&modeltype=%str(AMOUNT) and  &start_val2=%str())  
   or (&modeltype=%str(NOCORR) and (&start_val1=%str() or &start_val2=%str()))
   or (&modeltype=%str(CORR)   and  &start_val3=%str()) 
   %then %do ;          
      %put ## WARNING: if the parameter vcontrol is not blank, the user must provide starting values;
      %put        in the parameters start_val1-start_val3 as appropriate ;
      %put        MIXTRAN will not execute properly;                                   
  %end;                                      /* of missing start values */
%end ;                                       /* of version control in effect   */

%else %if &vcontrol = %str() %then %do ;     /* version control not in effect  */
  %if (&start_val1 ne %str() or &start_val2 ne %str() or &start_val3 ne %str())
   %then %do ;          
    %put ## WARNING: if the parameter vcontrol is null the user can NOT provide starting values;
    %put        in any of the parameters start_val1-start_val3;
    %put        MIXTRAN will not execute properly;
  %end;                                      /* of unwanted start values */
%end;                                        /*of version control not in effect */
                                            

%if &start_val1  =%str() %then %let start_val1=start1vargrp;
%if &start_val2  =%str() %then %let start_val2=start2vargrp;
%if &start_val3=%str() %then %let start_val3=startm;

/* set up code for printing output */
%let print_on = %str() ;
%let print_off = %str(ods exclude all ;) ;
%if &printlevel=%str(2) %then %let print_on = %str(ods select all ;) ;
%else %if &printlevel=%str(3) %then %let print_off = %str() ;
    
/*---turn off printing if printlevel ne 3---*/
&print_off ; ** ods exclude all;

/*---read in macro variables---*/

/* the replicate variable  */
%if &replicate_var = %str() %then %do ;       /* if no replicate variable */
  %let Freqing = %str(**unreplicated;); 
  %let replicate = %str(**unreplicated;) ;
  %let replicate_var = %str(dummywt) ;        /* assign dummy weight if user */
                                              /* did not supply a replicate  */
                                              /* variable.  A value of 1 will*/
                                              /* be supplied */    
%end; /* no replicate variable */
%else %do ;                                  /* replicate variable supplied */
  %let Freqing = FREQ &replicate_var ;       /* for the unvariate */
  %let Replicate = replicate &replicate_var; /* for the nlmixed */
%end;  /* of replicate variable supplied */
  
/* If no Title lines reserved set titles to 0 */
%if &titles = %str() %then %let titles=0;
%else %if %eval(&titles) gt 4 %then %do ;   /* too many titles reserved */
   %let titles = 4;
   %put ## Number of title lines reserved for user changed to the maximum of 4 ;
%end ;          /* of too many title lines reserved */

    
/*  Note whether or not correlations will be run */

%if &modeltype=%str() %then %let modeltype=%str(CORR);
%if &modeltype eq %str(NOCORR) %then %put ## Code for uncorrelated model will be executed;
%else %if &modeltype eq %str(AMOUNT) %then %put ## Code for amount-only model will be executed;
%else %if &modeltype eq %str(CORR) %then %put ## Code for correlated model will be executed;
%else %do ; 
  %put ## Error -- invalid modeltype  -- this execution of MIXTRAN will STOP -- ;
  %goto convexit;
%end;
     
/* If user supplies lambda value set the bounds statement to     */
/* null in the nlmixed for amount model.  Otherwise set bounds   */
/* for amtlambda.                                                */
%if &lambda eq %str() %then %let 
  lambdabounds = %str(bounds A_LAMBDA>0.01;) ;
%else %let lambdabounds = %str() ;


/* the covariates */ 
***** Probability covars *******;

%if &modeltype ne AMOUNT %then %do; /* models with prob portion*/
 
  %let vars_prob=%upcase(%quote(&covars_prob &weekend &seq ));          
  %let Ivar=1;
  %do %until(%qscan(&vars_prob,&Ivar,%str( ))=%str());
    %let varb&Ivar=%qscan(&vars_prob,&Ivar,%str( ));
    
    %let Ivar=%eval(&Ivar+1);
  %end; /* do %until(%qscan(&vars_prob... */
  %let cnt_prob=%eval(&Ivar-1);
  %if &vars_prob=%str() %then %let cnt_prob=0;
%end;  /* models with prob portion */


******** Amount covars *********;
%let vars_amt=%upcase(%quote(&covars_amt &weekend &seq));
  
%let Ivar=1;
%do %until(%qscan(&vars_amt,&Ivar,%str( ))=%str());
  %let varl&Ivar=%qscan(&vars_amt,&Ivar,%str( ));

  %let Ivar=%eval(&Ivar+1);
%end; /* do %until(%qscan(&vars_amt... */

%let cnt_amt=%eval(&Ivar-1);
%if &vars_amt=%str() %then %let cnt_amt=0;

%let weekend=%upcase(&weekend); 
%let seq=%upcase(&seq) ; 

%if &weekend ne %STR() %then %let predxb = %str(x1b1_0 x2b2_0 x1b1_1 x2b2_1 ) ;
%else %let predxb = %str(x1b1 x2b2 );

******************************************************************;
/*---make datasets---*/

data data (drop=wtflag) ;
  set &data;
  
  if &response=0 then YN=0;
  else if &response>0 then YN=1;

  *** check that the replicate variable, if supplied, is an integer;
  *** If none supplied, then assign the value of 1 to the dummy weight variable;
  wtflag = '0';
  %let wtch = 0 ;
  %If &replicate_var ne %str(dummywt) %then %do;
    If &replicate_var ne int(&replicate_var) then do ;
      put;
      put '**********************************************************';
      put "** ERROR **" ; 
      put "**  The replicate variable &replicate_var is not an integer.";
      put "**   Processing of the macro MIXTRAN will be stopped.";
      put '**********************************************************';
      put;
      wtflag= '1';
      call symput('wtch',wtflag);
      stop;
    end;                 ** of replicate_var ne int(replicate_var) ;
  %end ;                 /* of if replicate variable supplied */
  %else %do ;            /* assign a dummy weight variable, value =1 */
    dummywt=1;
  %end;
  run;

  %if &wtch = 1 %then %goto convexit;  
  
/* Sort data by subject, so NLMIXED detects repeated records for the same subject.  
	 For clarity, the data will be sorted by both subject and sequence number.*/
proc sort data=data;
  by &subject &repeat;
run;
 
/*---changed to response=. in order to get predictions for everyone---*/
data data0;
  set data;
  by &subject &repeat;
  if &response=0 then do; &response=.; end;
  run;  

/* for amount models change 0 intake to half the smallest amount actually eaten */
%if &modeltype = %str(AMOUNT) %then %do;  
  proc sql;
    UPDATE data0 
      Set &response=(select min(b.&response)*.5 as minFOOD from data as b where 0<&response) 
      Where &response=. ;   
  quit; 

%end;    /* of changing 0 intake to half the minimum eaten for amount models */

/* check the number of repeat observations, and the number with positive values of the response variable */
  /*Issue an error message if fewer than 2 subjects have more than 1 record (lack repeat observations) */
  %let tempda = %str() ;
  
  %if &modeltype = %str(AMOUNT) %then %do;
  
  %let tempda = repeat ;
    proc freq data=data0 noprint ;
    	where &response gt 0 ;
    	tables &subject / nopercent out=&tempda;
    run;

    proc sql noprint;                     /* this works because amount response never = 0 and only 1 or 2 recalls are allowed */
       select distinct count(count)
        into :RecallCount          
         from &tempda 
         where count > 1 
         ;
       quit;
       %put ## the number of repeat observations = &RecallCount.;
       
    %if %eval(&RecallCount)  <2 %then %do ;
      %put ## Error: There are fewer than two subjects with repeat observations.  This execution of MIXTRAN will STOP ;
      %goto convexit ;
    %end ;    /* recalls <2 for amount  */
    %else %if %eval(&RecallCount) <11 %then %do;
      #put ## Warning: There are only &RecallCount subjects with repeat observations.  Estimates might be unstable ;
    %end;     /* recalls 2-10 for amount */
  %end ;      /* recalls generally for amount */   
  run;
 
  /* For episodically consumed foods, provide the number of observed 24-hour recalls 
  /* by the number of their 24-hour recalls greater than 0. 
  /* The count is reported unweighted, the percentage is reported weighted if a replicate variable is used.
  /* There must be at least 2 positive recalls for episodic foods */ 

   %if &modeltype ne %str(AMOUNT) %then %do ; 

    data _mxt_recalls (keep=NumberRecalls NumberRecallsGT0 &repeat &response &replicate_var);
  	  set data0 (keep=&subject &repeat &response &replicate_var &subgroup);
  	  by &subject &repeat
  	  ;
  	  label
  	    NumberRecalls       = "Number of Recalls"
  	    NumberRecallsGT0 = "Number of Recalls with response greater than 0 (i.e. eaten)"
  	  ;
  	  if first.&subject then do;
  	 	  NumberRecalls = 0;
  	 	  NumberRecallsGT0 = 0;
  	  end;
  	  NumberRecalls+1 ;
  	  if &response>0 then NumberRecallsGT0+1; 
  	  if last.&subject then output;
    run;

  
    proc freq data=_mxt_recalls noprint;
  	  tables NumberRecalls*NumberRecallsGT0/ out=_mxt_Recalls_count(drop=percent) ;
  	  title%eval(&titles+1) "Number of Observed 24 Hour Recalls by Number of 24 Hour Recalls Greater Than 0";
    run;
    proc freq data=_mxt_recalls noprint;
  	  tables NumberRecalls*NumberRecallsGT0/ out=_mxt_Recalls_percent(drop=count) ;
  	  weight &replicate_var ;
  	title%eval(&titles+1) "Weighted percents of Observed 24 Hour Recalls by Number of 24 Hour Recalls Greater Than 0";
    run;
  
    /* combine the unweighted counts and the weighted percents*/
    proc sort data=_mxt_recalls_count ; 
    	by NumberRecalls NumberRecallsGT0 ;
    proc sort data=_mxt_recalls_percent ; 
    	by NumberRecalls NumberRecallsGT0 ;   
    run;
    data _mxt_recalls ;
   	  merge _mxt_recalls_count
   				  _mxt_recalls_percent;
   	  by NumberRecalls NumberRecallsGT0 ; 
  
    ods select all ;   /* temporarily turn the printing back on  */
    proc print data=_mxt_recalls noobs label  ; 
   	  ID NumberRecalls ;
   	  title%eval(&titles+1) "Subjects Grouped Into Number of Observed 24-Hour Recalls by The Number of Recalls With Positive Value";
   	  title%eval(&titles+2) "Percents Are Weighted If A Weight Is In Use. Counts Are Not Weighted" ;
    run;	
   	 
   	** There should be at least one subject with two or more positive recalls to continue. **
   	** If between 2 and 10 warn the user that estimates might be unstable                   ** ;
    proc sql noprint;
      select sum(count)
      into :Positive
      from _mxt_recalls
      where  NumberRecalls>1 and NumberRecallsGT0>1  ;
      quit;
    run;
    
    %if %eval(&positive) <11 %then %do;
      %if %eval(&positive) <2 %then %do; 
   	 	 	%put ## Error: There are &positive subjects with positive repeat observations. MIXTRAN will STOP  ;
   	 	 	%put ## Error: There must be at least one subject with two or more positive recalls to continue. ;
   	 	 	%put ## Error: This execution of MIXTRAN will STOP  ;
        %goto convexit ; 
      %end;         /* <2 positive recalls */   
      %else %do ;
	      %put ## Warning: the number of subjects with two or more positive recalls is small (&positive). Estimates might be unstable.;
	      %put ## Warning:   There should be at least 10 subjects with two or more positive recalls. ;
   	 	%end;        /* 2-10 positive recalls*/   
   	%end ;         /* positive recalls */     
   	%put The number of subjects with two or more positive responses is &positive ;  

    Proc Datasets nolist ;
      delete 
       _mxt_recalls _mxt_recalls_count _mxt_recalls_percent ;
    run;

    &print_off ;   /* reset the printing level */  
  
  %end ;           /* of checking for recalls for episodic foods */


***************************************************************;
**  Find the smallest non-zero value of the response var
**  over all subjects (min_amt). 
**  also find 
**  the model type, the name of the replicate (weight) variable 
**  and if applicable the number of var groups.
**  These will be passed to the DISTRIB macro;
****************************************************************;
 /* minimum amount of intake */ 
proc univariate data = data0 noprint; 
  var &response ;
  output out=misc_info min=min_amt ;
  run;  
 
 /* other data to pass to DISTRIB macro */  
data misc_info ;
  set misc_info(keep=min_amt);
  FreqName=symget('replicate_var');  /* the name of the weight variable */
  numvargrps=&numvargroups;          /* number of var groups */
  %if &weekend eq %str() %then %do ; /* the weekend flag */
    weekendflag=0;
  %end;
  %else %do ;
    weekendflag=1;
  %end;

/* reduce the data to one record per person */
proc sort data=data out=_persons nodupkey; 
    by &subject;  
  data _persons ;
    set _persons (keep=&subject &replicate_var &response &subgroup ) ;
    by &subject ;
    indwts=&replicate_var;


     
****************** end of general set up **********************************;

****************************************************************************;
/*        start of code for re-runs using only correlated nlmixed         */;

**RERUNS ;
%if &vcontrol ne %str()  %then %do ;

  ** reference the correct variable parameter for the correlated nlmixed **;
  %let amtlambda = %str(A_LAMBDA) ;
  %let vu1 = %str(P_VAR_U1) ;
  %let vu2 = %str(A_VAR_U2) ;

  
  
  ** read in the strings for eta1 etc. Used in the correlated nlmixed   **;
  %if &modeltype ne AMOUNT %then %do;
    data etas ;
      set &outlib..etas_&foodtype ;
      call symput('eta1',eta_1);
      call symput('eta2',eta_2);
      call symput('nonu1seq1',shorteta1);
      call symput('nonu2seq2',shorteta2); 
    run;  
  
 %end;
 %else %do ;
   data etas ;
     set &outlib..etas_&foodtype ;
     call symput('eta2',eta_2);
     call symput('nonu2seq2',shorteta2); 
   run;  
   
 %end;

%end;    /* of code for all reruns  */

*******************************************************************************;
/*    If this a re-run and the model is correlated, then skip the initial     */
/*    probability and amount parts of the macro.                              */
/*    If this is a base run, then proceed with calculation of starting values */
/*    and setting up names.                                                   */
/*    If this a re-run and the model is amount or nocorr, then skip the       */
/*    starting values and setting up names and go to the nlmixed procedures   */

%if (&vcontrol = %str()) 
or (&vcontrol  ne %str() and &modeltype ne %str(CORR))
%then %do ;

  %if &modeltype ne AMOUNT %then %do; /* models with prob portion*/
    
    %if &vcontrol = %str() %then %do ;  /*  base runs with corr or nocorr */

      /*---find starting estimates for probability model---*/
      
      ods output ParameterEstimates=parmsg1(rename=Parameter=Name) 
      modelfit=modelfitb;
      
      title%eval(&titles+1) "Starting Estimates for Probability Model";
      
      proc genmod data=data  descending namelen=30;
        model yn=&vars_prob/dist=binomial;
        &freqing;
        run;
      
      data random1;
        Format Parameter $30.;
        Parameter= Compress('P' ||'_VAR_U1');
        call symput('vu1',parameter);
        Name='Var(Rndm Effect)';
        Estimate=&var_u1start;
        run;
        
      
      data newnames1;
        format var_name $70. Parameter $30.;
        %let crd1 = P01_INTERCEPT ;
      
        %If &cnt_prob > 0 %then %do;
          %let J = 1 ; 
          %do %until (&j=(&cnt_prob+1));
            %if %eval(&j) lt 9 %then %let znum = 0;
            %else %let znum=%str() ;
            %let crd1 =  &&crd1 P&znum.%eval(&j+1)_&&varb&j ;
            %let j=%eval(&j+1);
          %end;
        %end; /* cnt_prob>0 */
      
        set parmsg1;
      
        if Name='Scale' then delete;
        %if &cnt_prob>0 %then %do;
      
          %let int=%scan(&crd1,1,%str( ));
          if Name='Intercept' then Parameter="&int";
      
          %let j=1;
          %do %until(&j=(&cnt_prob+1));
            %let up=%upcase(&&varb&j);
            %let lngth=%length(&&varb&j);
            
            %let varname=%scan(&crd1,(&j+1),%str( ));
            if UPCASE(Name)="&up" then do; 
              Parameter="&varname"; 
              var_name="&up"; 
            end; /* else if UPCASE(Name="&up"... */
            %let j=%eval(&j+1);
          %end;  /* do %until(&j=(&cn... */
        %end;  /* if &cnt_prob>0... */
      
        %if &cnt_prob=0 %then %do;        
          var_name = ' ' ; ** initialise if no covariates **;
          %let int=%scan(&crd1,1,%str( ));
          if Name='Intercept' then Parameter="&int";
        %end; /* if &cnt_prob=0... */
        run;
      
      data start1; 
        format Name $30. Parameter $30.;
        set newnames1 random1;
        if Parameter not in ('P01_INTERCEPT',"&vu1") then 
          list=trim(Parameter)||'*'||trim(Var_Name);
        else if Parameter in ('P01_INTERCEPT',"&vu1") then 
          list=trim(Parameter);
        keep Parameter Name Estimate list;
        run;
      
      data trans1;
        set start1;
        if Parameter in ("&vu1") then delete;
        run;
      
      proc transpose data=trans1 out=out1;
        var list;
        run;
      
      data eqn1 ;
        format eta1 eta_1 $2000.;
        set out1;
      
        %if &cnt_prob>0 %then %do;
          %let k=1;
          eta1=trim(col&k); 
          %if (&k ne (&cnt_prob+1)) %then %do %until(&k=(&cnt_prob+1));
            %let k=%eval(&k+1);
            eta1=trim(eta1)||'+'||trim(col&k);  
          %end; /* do %until(&k...*/
          call symput('nonu1',eta1);
          eta_1=trim(eta1)||' + u1';  
          
          /* **  delete the sequence variables from eta1 and create a */
          /* **  string to calculate x1b1 for weekend runs            */
          /* **  u1 will not be added to eta1 either.                 */
          %if &seq ne %str() %then %do ;
            %let seqname=%qscan(&seq,1,%str( ));
            
            nseq=index(eta1,"&seqname");
            
            shorteta1=substr(eta1,1,(nseq-6));
            call symput('nonu1seq1',shorteta1);
           drop nseq shorteta1;
          %end;   /* of seq ne () */
          %else %do;
            call symput('nonu1seq1',eta1);
          %end;
        %end; /* %if &cnt_prob>0...*/
      
        %if &cnt_prob=0 %then %do;
          call symput('nonu1seq1',col1);
          eta_1=trim(col1)||' + u1';
        %end; /* %if &cnt_prob=0...*/
        call symput('eta1',eta_1);
        run;

          
      data start1vargrp;
        length parameter $30.;
        set start1;
        
        if parameter = "&vu1" then do; 
          parameter = 'P_LOGSDU1';
          name = 'Reparam Var(u1)';
          estimate = log(sqrt(estimate));
          list = 'P_LOGSDU1';
          output;
        end;
        else output;
        run;
      %end ;         /* of vcontrol = '' (base) for corr or nocorr */

    
    /* want all runs with nocorr to do the nlmixed, base or re-run  */
    /* and the base corr runs ;                                     */

      ************************************************************;
      ** Run nlmixed for probability model;
      ***********************************************************;
    
      /*---turn the printing back on for level gt 1 ---*/
    
      &print_on ;    ** ods select all;
    
      ods output ParameterEstimates=parmsf1 AdditionalEstimates=adprmsf1 FitStatistics=fitf1 
      ConvergenceStatus=convf1;
    
      title%eval(&titles+1) 'Probability Model';
    
      proc nlmixed data=data &nloptions;
        parms /data=&start_val1;
        &replicate ;                     /* if replicate variable provided */
          
        &vu1 = EXP(2*P_LOGSDU1);
           
        x1b1u1=&eta1;
        p=exp(x1b1u1)/(1+exp(x1b1u1));
        x1b1=x1b1u1-u1;
        model YN ~ binomial(1,p);
        random u1 ~ normal(0,&vu1) subject=&subject out=predu1u;
        estimate "P_VAR_U1" EXP(2*P_LOGSDU1);
        predict p out=predpu;
        predict x1b1 out=predx1b1u;
        run;

          
      data _null_;
        set convf1;
        call symput('convbi',Reason);
        run;
          
      /* check for convergence error.  End processing if found */
      Data _null_ ;
        %let ccsbi=%index(&convbi,convergence criterion satisfied) ;         
        %if &ccsbi eq %str(0) %then %do ;
      
           %put ****************************************************;
           %put ##! Convergence Problem from PROC NLMIXED ;
           %put ##! Macro MIXTRAN Stopped Due to Convergence Error in Probability Model;
           %put ##! Response Variable is &response ;
           %put ##! data is &data;
           %put ##! weight variable is &replicate_var;
           %put ** ERROR** MSG: &convbi ;
           %put ****************************************************;
           %let convflag = 1 ;  
                   
        ** IMS SPECIFIC: set flags to note which strata has failed.  
        ** these will be used in selecting data for Distrib in the calling program;
          %let fail_count = %eval(&fail_count+1) ;
          %let failed = 1;
        
          data fail&fail_count ;
            fcount=&fail_count;
            food="&eaten";
            subpop="&data";            
            run_num="&replicate_var";
            reason="&convbi";
            converr=&convflag;
            output;
       ** end of IMS specific code; 
     
            Proc Datasets nolist ;
             delete
               CONVF1 DATA DATA0 EQN1 FITF1 MODELFITB NEWNAMES1 OUT1 PARMSF1   
               PARMSG1 PREDPU PREDU1U PREDX1B1U RANDOM1 START1 TRANS1    
               ; 
           %GOTO convexit;
       %end;  /* of convergence error check in convbi */
       run ;
        
       proc transpose data=adprmsf1 out=adprmsf1(drop=_name_);
        id label;
        var estimate;
        run;       
       
    %end;  /* models with prob portion */  


  %if &vcontrol = %str() %then %do;   /* base run for all models */

    ************************************************************;
    **  starting estimates for amount                           ;
    ************************************************************; 
  
 
    /*---turn off printing if printlevel lt 3---*/
    &print_off ; ** ods exclude all ;  
 
    /*---find starting estimates for amount model---*/
 
    title%eval(&titles+1) "Starting Estimates for Amount Model" ;
  
    /* if lambda not supplied by user the macro assigns a value */
    %if &lambda eq %str() %then %do ;
   
      ods graphics off ; /* prevents a system error in some SAS sytem set ups */
      %if &cnt_amt>0 %then %do;
        ods output boxcox=boxcox; 
 
        proc transreg data=data0 pboxcoxtable; 
          where &response>0;
          model BoxCox(&response / lambda=0.05 to 1 by 0.05) = identity(&vars_amt);
          run;

        data _null_;
          set boxcox;
          if ci='<';
          call symput ('lambda',lambda);
          run;        
      %end; /* %if cnt_amt>0 ... */
      %else %let lambda=0.4;
      
      ods graphics on;
      
    %end ;  /* of assigning lambda if none supplied by user */
      
    data data0;
      set data0;
      %if &lambda=%str(0) %then %do;
        boxcoxy=log(&response) ; 
      %end;                         /* deals with a lambda of 0 */
      %else %do;
        boxcoxy=(&response**&lambda-1)/&lambda;
      %end;
      run;
 option nomprint;
    *********************genmod for starting values ********************;
    ods output ParameterEstimates=parmsg2(rename=Parameter=Name);
    
    proc genmod data=data0 namelen=30;
      model boxcoxy=&vars_amt/dist=normal;
      &freqing ;  
      run; 
      
    data random2;
      Format Parameter $30.;
      Parameter= Compress('A' ||'_VAR_U2');
      call symput('vu2',parameter);
      Name='Var(Rndm Effect)';
      Estimate=1;
      run;   
 
    
    data newnames2;
      format var_name $70. parameter $30.;
      %let crd2 =A01_INTERCEPT ;
      %If &cnt_amt > 0 %then %do;
        %let J = 1 ; 
        %do %until (&j=(&cnt_amt+1));
          %if %eval(&j) lt 9 %then %let znum = 0;
          %else %let znum=%str() ;
          %let crd2 =  &&crd2 A&znum.%eval(&j+1)_&&varl&j ;
          %let j=%eval(&j+1);
        %end;       
      %end; /* cnt_amt>0 */
      
      set parmsg2;
      %if &cnt_amt>0 %then %do;
        %let int=%qscan(&crd2,1,%str( ));
        if Name='Intercept' then Parameter="&int";
        else if Name='Scale' then do;
          Parameter='A_VAR_E';
          Estimate=Estimate**2;
          Name='Residual';
        end; /* of name = 'scale' */
        %let j=1;
        %do %until(&j=(&cnt_amt+1));
          %let up=%qupcase(&&varl&j);
          %let lngth=%length(&&varl&j);
          %let varname=%qscan(&crd2,(&j+1),%str( ));
          if UPCASE(Name)="&up" then do; 
            Parameter="&varname";
            var_name="&up"; 
          end; /* else if UPCASE ... */
          %let j=%eval(&j+1);
        %end; /* do %until(&j... */
      %end; /* %if &cnt_amt>0... */
      %if &cnt_amt=0 %then %do;
        var_name = ' ' ; ** initialise if no covariates **; 
        %let int=%qscan(&crd2,1,%str( ));
        if Name='Intercept' then Parameter="&int";
        else if Name='Scale' then do;
          Parameter='A_VAR_E';
          Estimate=Estimate**2;
          Name='Residual';
        end; /* else if Name=... */
      %end; /* %if &cnt_amt=0... */
    run;
 
    data lambda;
      Format Parameter $30.;
      Parameter= Compress('A' || '_LAMBDA');
      call symput('AMTLAMBDA',parameter);
      Estimate=&lambda;
      Name='lambda';
      run;
   

    data start2; 
      format Name $30. Parameter $30.;
      set newnames2 random2 lambda(in=inlam);
      /* delete the lambda record if user supplied lambda value */
      %if &lambdabounds eq %str() %then %do ;
        if inlam then delete;
      %end;
      if Parameter not in ('A01_INTERCEPT',"&vu2") then list=
        trim(Parameter)||'*'||trim(Var_Name);
      else if Parameter in ('A01_INTERCEPT',"&vu2") then list=trim(Parameter);
      keep Parameter Name Estimate list;
      run;
 
    data trans2;
      set start2;
      if Parameter in ("&vu2",'A_VAR_E') then delete;
      run;
    
    proc transpose data=trans2 out=out2;
      var list;
      run;
    
    data eqn2 ;
      format eta2 eta_2 $2000.;
      %if &seq ne %str() %then %do ;
        format shorteta2 $2000.; 
      %end;
      set out2;
      %if &cnt_amt>0 %then %do;
        %let k=1;
        eta2=trim(col&k);
        %if (&k ne (&cnt_amt+1)) %then %do %until(&k=(&cnt_amt+1));
          %let k=%eval(&k+1);
          eta2=trim(eta2)||'+'||trim(col&k);
        %end; /* %if (&k ne... */
        call symput('nonu2',eta2);
        eta_2=trim(eta2)||' + u2';
        /* **  delete the sequence variables from eta2 and create a */
        /* **  string to calculate x2b2 for weekend runs            */
        /* **  u2 will not be added to eta2 either.                 */
        %if &seq ne %str() %then %do ;
          %let seqname=%qscan(&seq,1,%str( ));
          
          nseq2=index(eta2,"&seqname");
          put nseq2= ;
          shorteta2=substr(eta2,1,(nseq2-6));
          call symput('nonu2seq2',shorteta2);
          drop nseq2 shorteta2;
        %end;   /* of seq ne () */
        %else %do;
          call symput('nonu2seq2',eta2);
        %end;
      %end; /* %if cnt_amt>0 ... */
      %if &cnt_amt=0 %then %do;
        call symput('nonu2seq2',col1);
        eta_2=trim(col1)||' + u2';
      %end; /* %if &cnt_amt=0... */
       
      call symput('eta2',eta_2);
      run;

    data start2vargrp;
      length parameter $30.;
      set start2;
     
      %if &vargroup ne %STR() %then %do;
        if parameter='A_VAR_E' then do;
          list=' ';
          parameter = 'A_LOGSDE';
          name = 'Resid, Reparam Var Grp1';
          estimate = log(sqrt(estimate));
          output;
          do vg = 2 to &numvargroups;
            parameter = 'A_DELTAVG' || left(put(vg,2.));
            name = 'Resid, Delta for Var Grp' || left(put(vg,2.));
            estimate=0;
            output;
          end;
        end;
      %end; /* vargroup present */
      %else %do;
        if parameter='A_VAR_E' then do;
          list=' ';
          parameter = 'A_LOGSDE';
          name = 'Resid, Reparam ';
          estimate = log(sqrt(estimate));
          output;
        end;
      %end;
      else if parameter = "&vu2" then do;  
        parameter = 'A_LOGSDU2';
        name = 'Reparam Var(u2)';
        estimate = log(sqrt(estimate));
        list = 'A_LOGSDU2';
        output;
      end;
      else output;
   
  %end;   /* of using this code if a base run- vcontrol = ' '                */
          /* all base runs or re-runs with amount or nocorr use this nlmixed */
  
  ****************************************************************;
  **  nlmixed for amount                                          ;
  ****************************************************************;
  /*---turn the printing back on for level GT 1 ---*/

  &print_on ;   ** ods select all;

  ods output ParameterEstimates=parmsf2 AdditionalEstimates=adprmsf2 FitStatistics=fitf2 
  ConvergenceStatus=convf2;

  title%eval(&titles+1) 'Amount Model';

  proc nlmixed data=data0 &nloptions;
    parms / data=&start_val2;
    &replicate ;                     /* if replicate variable provided */
    &lambdabounds ;
 
    %if &vargroup ne %STR() %then %do;
      ARRAY VARGRP[&NUMVGMINUS1] A_VARGRP2-A_VARGRP&NUMVARGROUPS;
      ARRAY A_DELTAVG[&numvgminus1] A_DELTAVG2-A_DELTAVG&numvargroups;
  
      if &vargroup=1 then do;  
        A_VARGRP1 = EXP(2*A_LOGSDE);
        A_VAR_E = A_VARGRP1;
      end;
      else do vg = 2 to &numvargroups;
        if &vargroup=vg then do;
          indx=vg-1;
          vargrp[indx] = exp(2*(A_LOGSDE + A_DELTAVG[indx]));
          A_VAR_E = VARGRP[INDX];
        end;
      end;
    %end;
    %else %do;
      A_VAR_E = exp(2*A_LOGSDE);
    %end;
    &vu2 = exp(2*A_LOGSDU2);

    x2b2u2=&eta2;
    pi=arcos(-1);
  
    %if (&lambdabounds eq %str()) %then %let amtlambda = &lambda;   /* user supplied lambda */       
      %if &lambda ne %str(0) %then %do;        
        boxcoxy=(&response**&amtlambda-1)/&amtlambda;
      %end;                                   /* lambda ne 0 */     
      %else %do;
        boxcoxy=log(&response) ;
      %end;                                   /* lambda=0 */
                                 
    ll1=log(1/(sqrt(2*pi*A_VAR_E)));
    ll2=(-(boxcoxy-x2b2u2)**2)/(2*A_VAR_E)+(&amtlambda-1)*log(&response);
    ll=ll1+ll2;
    model &response ~ general(ll);
    random u2 ~ normal(0,&vu2) subject=&subject out=predu2u;
    estimate "A_VAR_U2" exp(2*A_LOGSDU2);
    %if &vargroup ne %STR() %then %do;
      estimate "A_VARGRP1" exp(2*A_LOGSDE);
      %let kvg = 2;
      %do kvg = 2 %to &numvargroups;
        estimate "A_VARGRP&kvg" exp(2*(A_LOGSDE + A_DELTAVG&kvg));
      %end;
    %end;
    %else %do;
      estimate "A_VAR_E" exp(2*A_LOGSDE);
    %end;
    e_int=x2b2u2;
    x2b2=x2b2u2-u2;
    predict e_int out=predeintu;
    predict x2b2 out=predx2b2u;
    run;

  
    ***************************************;
    data _null_;
     set convf2;
     call symput('convin',Reason);
     run;

    /* check for convergence error.  End processing if found */
    Data _null_ ;
      %let ccsin=%index(&convin,convergence criterion satisfied) ;     
      %if &ccsin eq %str(0) %then %do ;

        %put ****************************************************;
        %put ##! Convergence Problem from PROC NLMIXED ;
        %put ##! Macro MIXTRAN Stopped Due to Convergence Error in Amount Model;
        %put ##! Response Variable is &response ;
        %put ##! data is &data;
        %put ##! weight variable is &replicate_var;
        %put ##!  ERROR MSG: &convin ;
        %put ****************************************************;
        %let convflag = 2 ;  
        
        ** IMS SPECIFIC: set flags to note which strata has failed.  
        ** these will be used in selecting data for Distrib in the calling program;
          %let fail_count = %eval(&fail_count+1) ;
          %let failed = 1;
        
          data fail&fail_count ;
            fcount=&fail_count;
            food="&eaten";
            subpop="&data";            
            run_num="&replicate_var";
            reason="&convin";
            converr=&convflag;
            output;
       ** end of IMS specific code; 
     
     
       Proc Datasets nolist ;
         delete
         BOXCOX CONVF1 CONVF2 DATA DATA0 EQN1 EQN2 FITF1  FITF2 LAMBDA     
         MODELFITB  NEWNAMES1 NEWNAMES2 OUT1 OUT2       
         PARMSF1 PARMSF2 PARMSG1 PARMSG2  PREDEINTU PREDPU PREDU1U
         PREDU2U PREDX1B1U PREDX2B2U RANDOM1 RANDOM2 START1 START2 
         TRANS1 TRANS2  
         ;
         %GOTO convexit;
      %end;  /* of convergence error check in convin */
      run ;
      
      proc transpose data=adprmsf2 out=adprmsf2(drop=_name_);
      id label;
      var estimate;
      run;

  ***********************************************************************;
  **  start of covariance              ;
  ***********************************************************************;
  
   
  /*---turn off printing  if print level lt 3---*/
  &print_off ; **ods exclude all;
    
  /*---compute starting value for covariance---*/
  /*---and prepare data sets for summary reports---*/
  %if &modeltype ne AMOUNT %then %do;   /* prob part available */   
    data cov; 
      Format Parameter $30.;
      set parmsf1 parmsf2; 
      if Parameter in ("&vu1","&vu2",'P_LOGSDU1','A_LOGSDU2'); 
      keep Parameter Estimate; 
      run;
  %end; /* prob part available*/
  
  %else %do; /* no prob part */
    data cov; 
      Format Parameter $30.;
      set parmsf2; 
      if Parameter in ("&vu2",'A_LOGSDU2'); 
      keep Parameter Estimate; 
      run;
  %end;  /* no prob part */
  
  proc transpose data=cov out=outcov; 
    var Estimate; 
    id Parameter; 
    run;
  
  %if &modeltype ne AMOUNT %then %do;   /* prob part available */
    data cov2; 
      set outcov; 
      Format Parameter $30.;
      Rho=0.5;
      Parameter='Z_U'; 
      Name='Z-trans of Correlation';
      Estimate=0.5*(log(1 + Rho) - log(1-Rho));
      keep Parameter Estimate Name;
      run;
  
    data fit1;
      format Parameter $30. Name $30.;
      set fitf1;
      if Descr in ('-2 Log Likelihood','AIC (smaller is better)');
      if Descr='-2 Log Likelihood' then do;
        Parameter='ll';
        Name='-2 Log Likelihood--bi';
      end; /* if Descr='-2 Log.. */
      if Descr='AIC (smaller is better)' then do;
        Parameter='aic';
        Name='AIC--bi';
      end; /* if Descr='AIC... */

    proc sort data = fit1; 
      by Parameter; 
      run;
       
  %end;  /* prob part available*/

  /* base run only  to set up  files for printing (all models) */ 
  %if &vcontrol = %str() %then %do ;   
    data fit2;
      format Parameter $30. Name $30.;
      set fitf2;
      if Descr in ('-2 Log Likelihood','AIC (smaller is better)');
      if Descr='-2 Log Likelihood' then do;
        Parameter='ll';
        Name="-2 Log Likelihood--"||"amount";
      end; /* if Descr='-2 Log.. */
      if Descr='AIC (smaller is better)' then do;
        Parameter='aic';
        Name="AIC--"||"amount";
      end; /* if Descr='AIC... */

    proc sort data = fit2; 
      by Parameter; 
      run;

    %if &modeltype ne AMOUNT and &modeltype ne NOCORR %then %do;   /* correlated part only */
      data fitboth;
        merge fit1 (rename=Value=Valueb) fit2 (rename=Value=Valuel); 
        by Parameter;
        m2llo=Valueb + Valuel;
        run;
    %end; /* correlated part only */

    %if &modeltype ne AMOUNT %then %do;   /* prob part available */  
      data names;
        format Parameter $30. type $6. Name $30. ;
        set &start_val1 (in=a) &start_val2 (in=b) cov2 (in=c) fit1 (in=d) fit2 (in=e);
        if a=1 then type='1.pr';
        else if b=1 then type='2.am';
        else if c=1 then type='3.cov';
        else if d=1 or e=1 then type='4.fit';
        If type in ('1.pr','2.am') then Name2=trim(Name)||'--'||substr(type,3,2);
        else Name2=Name;
        keep Parameter Name type Name2 Value;
    %end;   /* prob part available */

    %else %do; /* no prob part */
      data names;
        format Parameter $30. type $6. Name $30. ;
        set &start_val2 (in=b)  fit2 (in=e);
        if b=1 then type='2.am';
        else if e=1 then type='4.fit';
        If type in ('2.am') then Name2=trim(Name)||'--'||substr(type,3,2);
        else Name2=Name;
        keep Parameter Name type Name2 Value;
    %end; /* no prob part */

    proc sort data=names; 
      by Parameter;
      run;

    data names2;
      set names;
      if type='4.fit' then delete;
      run;
    
  %end ;     /* of vcontrol = ' ' - base run  setting up files for printing*/ 

  %if &modeltype ne AMOUNT %then %do;   /* prob part available */  
    data start3 ;
      format Parameter $30.;
      set parmsf1 parmsf2 cov2  ;
    run;

    data misc_info;
      set misc_info;
      if _n_=1 then do;
        set adprmsf1;
        set adprmsf2;
      end;
      cov_u1u2=0;
      run;
            
  %end;   /* prob part available */
  
  %else %do; /* no prob part */
    data start3 ;
      format Parameter $30.;
      set parmsf2  ;
    run; 
  
    data misc_info;
      set misc_info; if _n_=1 then set adprmsf2;
      run;
  %end; /* no prob part */

  proc sort data=start3; 
    by Parameter;
    run;

  /* starting data set for 3rd nlmixed in base runs */
  %if &vcontrol = %str() %then %do ;    /* base run */
    data startm;
      merge names2 start3; 
      by Parameter;
      run;

    data estprint;
      merge names start3; 
      by Parameter;
      run;

    proc sort data=estprint; 
      by type; 
      run;
    &print_on ;  ** ods select all;
  %end ;      /* of vcontrol =  ' ' base run */

  ****************************************************************************;
  ******** Save parameter estimates and predicted values from nlmixed    *****;
  ******** procs for probability model and amount model                  *****;
  ****************************************************************************;

  /*  save parmsf1 and parmsf2 if this is a base run  */
  %if &vcontrol = %str() %then %do ;   /* base run - save parmsf1 and 2 */
      
    data &outlib..etas_&foodtype;
      set eqn2 (keep=eta_2);
      format shorteta2 $2000. ;
      shorteta2=symget('nonu2seq2');
    run;
      
      %if &modeltype ne %str(AMOUNT) %then %do ;
        data &outlib..etas_&foodtype;
          set &outlib..etas_&foodtype; if _n_=1 then set eqn1 (keep=eta_1);
          format shorteta1 $2000. ;
          shorteta1=symget('nonu1seq1');
        run;
        data &outlib.._parmsf1_&foodtype ;
          set parmsf1(keep=parameter estimate) ;
        run;
      %end ;  /* no probability part */
      data &outlib.._parmsf2_&foodtype ;
        set parmsf2(keep=parameter estimate);
      run; 
  %end ;    /* vcontrol = '  ' - base run, saving parmsf1 and parmsf2 */ 
  
    /* save parameter estimates */  
    
  data _param_unc;  /* _param data set for uncorrelated part, with version control giving date and time */
    Format Parameter $30.;
    set start3 ;
  run;
  
  proc transpose data=_param_unc out=&outlib.._param_unc_&foodtype&vcontrol(drop=_name_);
    id parameter;
    var estimate;
  run;
    
  data &outlib.._param_unc_&foodtype&vcontrol;
    set &outlib.._param_unc_&foodtype&vcontrol;
          if _n_=1 then set misc_info;                               /* adding descriptive info */

   /* if user supplied lambda, restore lambda to output data set for use in DISTRIB */
   %if &lambdabounds eq %str() %then %do ;
     a_lambda=&amtlambda;
   %end;
    
  /* save predicted data */
  
    /* add sum of weights and number of subjects to predx2b2u */ 
    
    proc sort data = predx2b2u ; by &subject ;
    data predx2b2u ;
      merge predx2b2u
            _persons ;
      by &subject ;
            
  /* _predicted data set for uncorrelated or amount */   
  %if &modeltype ne AMOUNT %then %do;
    %if &weekend ne %STR() %then %do; 
      data &outlib.._pred_unc_&foodtype&vcontrol (keep=&subject &predxb &replicate_var &weekend 
      	                                               &subgroup  );                                                          
        if (_n_=1) then set &outlib.._param_unc_&foodtype&vcontrol;
        set predx2b2u(drop=&weekend);
        by &subject &repeat;
        if (first.&subject);
            
        /* create x1b1, x2b2 for weekend/seasonal or other temporal records*/
        /* weekend=0 indicates time0   */
        /* weekend=1 indicates time1   */
        &weekend=0;
        x1b1_0=(&nonu1seq1);
        x2b2_0=(&nonu2seq2);
       
        &weekend=1;
        x1b1_1=(&nonu1seq1);
        x2b2_1=(&nonu2seq2);
        
        run;
    %end;  /* of &weekend ne %str() (i.e. have a weekend variable) */

    %else %do; 
      data &outlib.._pred_unc_&foodtype&vcontrol (keep=&subject &predxb &replicate_var 
      	                                          &subgroup );                                                       
        merge predx1b1u (keep=&subject &repeat pred &replicate_var rename=(pred=x1b1))
             predx2b2u (keep=&subject &repeat pred &subgroup  rename=(pred=x2b2));
        by &subject &repeat;
        if (first.&subject);
    
        run;
    %end;  /* &weekend is blank, i.e. no weekend variable */
  %end;    /* prob part available */

  %else %do;
    %if &weekend ne %STR() %then %do;
      data &outlib.._pred_unc_&foodtype&vcontrol (keep=&subject x2b2_0 x2b2_1 &replicate_var 
      	                                               &weekend &subgroup); 
        if (_n_=1) then set &outlib.._param_unc_&foodtype&vcontrol;
        set predx2b2u(drop=&weekend);
        by &subject &repeat;
        if (first.&subject);  
        /* create x2b2 for weekday, weekend records*/  
        /* weekend=0 indicates a weekday, Monday-Thursday */
        /* weekend=1 indicates a weekend, Friday-Sunday   */
        &weekend=0;
        x2b2_0=(&nonu2seq2);
        
        &weekend=1;
        x2b2_1=(&nonu2seq2);      
       
        run;
    %end; /* &weekend is available */
    %else %do;
      data &outlib.._pred_unc_&foodtype&vcontrol (keep=&subject x2b2 &replicate_var 
      	                                               &subgroup );
        set predx2b2u (keep=&subject &repeat &replicate_var &subgroup 
                            pred  rename=(pred=x2b2));
        by &subject &repeat;
        if (first.&subject);
      
        run;
    %end;  /* &weekend is not available */
  %end; /* prob part unavailable */
  
  %put ## the data sets &outlib.._pred_unc_&foodtype&vcontrol and &outlib.._param_unc_&foodtype&vcontrol ;
  %put ## have been output for use in the DISTRIB macro or other software using AMOUNT or NOCORR models;
 ***********************************************************************************;
 
  &print_on ;  ** ods select all; 
%END ;   /* END OF SKIPPING FIRST PART FOR CORRELATED RE_RUNS */

**********************************************************************;
/* **** run correlated part unless modeltype is 'amount' or 'nocorr' ********  */
%if &modeltype eq CORR %then %do ; 

 /*---turn the printing back on--- for level GT 1 */

  &print_on ;  ** ods select all;
   
  ****************************************************************;
  ** nlmixed for correlated     ;
  ****************************************************************;
    data &start_val3;
      set &start_val3;
      if Parameter in ('numvargroups','min_amt') then delete;
      run; 
       
    /*---Fit Correlated Model---*/

  title%eval(&titles+1) 'Correlated Model';

  ods output ParameterEstimates=parmsf3 AdditionalEstimates=adprmsf3 FitStatistics=fitf3 ConvergenceStatus=convf3;

  proc nlmixed  data=data &nloptions;
    parms / data=&start_val3 ;
    &replicate ;                      /* If replicate variable supplied */
    &lambdabounds ;

    %if &vargroup ne %STR() %then %do;
      ARRAY VARGRP[&NUMVGMINUS1] A_VARGRP2-A_VARGRP&NUMVARGROUPS;
      ARRAY A_DELTAVG[&numvgminus1] A_DELTAVG2-A_DELTAVG&numvargroups;
  
      if &vargroup=1 then do;  
        A_VARGRP1 = EXP(2*A_LOGSDE);
        A_VAR_E = A_VARGRP1;
      end;
      else do vg = 2 to &numvargroups;
        if &vargroup=vg then do;
          indx=vg-1;
          VARGRP[INDX] = EXP(2*(A_LOGSDE + A_DELTAVG[INDX]));
          A_VAR_E = VARGRP[INDX];
        end;
      end;
    %end;
    %else %do;
      A_VAR_E = EXP(2*A_LOGSDE);
    %end;

    &vu1= EXP(2*P_LOGSDU1);
    &vu2= EXP(2*A_LOGSDU2);
    RHO=(EXP(2*Z_U) - 1) / (EXP(2*Z_U) + 1);
    COV_U1U2 = RHO*EXP(P_LOGSDU1+A_LOGSDU2);
    
    x1b1u1=&eta1;
    p=exp(x1b1u1)/(1+exp(x1b1u1));
    llb=log((1-p)**(1-YN)) + log(p**(YN));
    x2b2u2=&eta2;
    pi=arcos(-1);
    E_int=x2b2u2;
    if &response>0 then do; 
      %if (&lambdabounds eq %str()) %then %let amtlambda = &lambda;   /* user supplied lambda */       
        %if &lambda ne %str(0) %then %do;        
          boxcoxy=(&response**&amtlambda-1)/&amtlambda;
        %end;                                   /* lambda ne 0 */     
      %else %do;
        boxcoxy=log(&response) ;
      %end;                                   /* lambda=0 */  	
      ll1=log(1/(sqrt(2*pi*A_VAR_E)));
      ll2=(-(boxcoxy-x2b2u2)**2)/(2*A_VAR_E)+(&amtlambda-1)*log(&response);
      ll_n=ll1+ll2; 
    end; /* if &response>0... */
    if &response=0 then ll=llb;
    else if &response>0 then ll=llb+ll_n;
    model &response ~ general(ll);
    random u1 u2 ~ normal([0,0],[&vu1,COV_U1U2,&vu2]) subject=&subject out=rndm;
    estimate "P_VAR_U1" EXP(2*P_LOGSDU1);
    estimate "A_VAR_U2" EXP(2*A_LOGSDU2);
    %if &vargroup ne %STR() %THEN %DO;
      estimate "A_VARGRP1" EXP(2*A_LOGSDE);
      %let kvg = 2;
      %do kvg = 2 %to &NUMVARGROUPS;
        estimate "A_VARGRP&KVG" EXP(2*(A_LOGSDE + A_DELTAVG&KVG));
      %end;
    %end;
    %else %do;
      estimate "A_VAR_E" EXP(2*A_LOGSDE);
    %end;
    estimate "RHO"    (EXP(2*Z_U) - 1) / (EXP(2*Z_U) + 1);
    estimate "COV_U1U2" RHO*EXP(P_LOGSDU1+A_LOGSDU2);
    x2b2=x2b2u2-u2;
    x1b1=x1b1u1-u1;
    predict p out=predp;
    predict e_int out=predeint;
    predict x2b2 out=predx2b2;
    predict x1b1 out=predx1b1;
    predict u1 out=_predu1;
    predict u2 out=_predu2;
    run;
** end of NLMIXED for correlations;

  data _null_;
    set convf3;
    call symput('convcr',Reason);
    run;
  
   /* check for convergence error.  End processing if found */
  Data _null_ ;
   %let ccscr=%index(&convcr,convergence criterion satisfied) ;  
   %if &ccscr=%str(0) %then %do ; 

     %put ****************************************************;
     %put ##! Convergence Problem from PROC NLMIXED ;
     %put ##! Macro MIXTRAN Stopped Due to Convergence Error in Correlated Model ;       
     %put ##! Response Variable is &response ;
     %put ##! data is &data;
     %put ##! weight variable is &replicate_var;
     %put **ERROR** MSG: &convcr ;
     %put ****************************************************;
     %let convflag = 3 ;  
     ** IMS SPECIFIC: set flags to note which strata has failed.  ;     
     %let fail_count = %eval(&fail_count+1) ;
     %let failed = 1;
     
       data fail&fail_count ;
         fcount=&fail_count;
         food="&eaten";
         subpop="&data";
         run_num="&replicate_var";
         reason="&convcr";
         converr=&convflag;
         output;
         
     ** end of IMS specific code; 
          
  
     ** End of IMS SPECIFIC ;  
     Proc Datasets nolist ;
       delete
       BOXCOX CONVF1 CONVF2 CONVF3 COV COV2 DATA DATA0 EQN1 EQN2 ESTPRINT  
       FIT1 FIT2 FITBOTH FITF1 FITF2 FITF3 LAMBDA MODELFITB 
       NAMES NAMES2 NEWNAMES1 NEWNAMES2 OUT1 OUT2 OUTCOV PARMSF1   
       PARMSF2 PARMSF3 PARMSG1 PARMSG2 PREDEINT PREDEINTU PREDP PREDPU    
       PREDU1 PREDU1U PREDU2 PREDU2U PREDX1B1 PREDX1B1U PREDX2B2  
       PREDX2B2U RANDOM1 RANDOM2 RNDM START1 START2 START3 STARTM    
       TRANS1 TRANS2 _PARAM  _PREDICTED _PREDU1 _PREDU2  
       ; 
     %GOTO convexit;
  %end;  /* of convergence error check in convcr */
  run ;  
  
  proc transpose data=adprmsf3 out=adprmsf3(drop=_name_);
     id label;
     var estimate;
     run;
   
  data misc_info;
    set misc_info ;
    if _n_=1 then set adprmsf3;
    run;
  
  data predu1;
    set rndm;
    if effect='u1';
    run;

  data predu2;
    set rndm;
    if effect='u2';
    run;

  data _null_;
    set convf3;
    call symput('convcr',Reason);
    run;
  

  ** IMS SPECIFIC ; 
  data _null_;

     %let origvcontrol = &vcontrol;

     %if &vcontrol = %str(0) %then %let vcontrol = %str();  /* special case, for CORR base runs per Kevin Dodd */ 

  run;
  ** END IMS SPECIFIC ;
  ************************************************************************;
  ** save parmsf3                                            ;
  ************************************************************************;
  %if &vcontrol = %str() %then %do ;
    data &outlib.._parmsf3_&foodtype&vcontrol;
      set parmsf3(keep=parameter estimate);
      run;
  %end;
  **********************************************************;
  ****   Save parameter estimates and predicted values *****;
  ****   from correlated procs                         *****;
  **********************************************************;
  data _param;  /* _param data set for correlated part, with version control giving date and time */
    Format Parameter $30.;
    set parmsf3 ;
    run;
    
  proc transpose data=_param out=&outlib.._param_&foodtype&vcontrol(drop=_name_);
    id parameter;
    var estimate;
    run;
    
  data &outlib.._param_&foodtype&vcontrol ;
    set &outlib.._param_&foodtype&vcontrol;
          if _n_=1 then set misc_info ;                 /* add minamt and other information */
          /* if user supplied lambda, restore lambda to output data set for use in DISTRIB */
   %if &lambdabounds eq %str() %then %do ;
     a_lambda=&amtlambda;
   %end;


  /* save predicted data */
  
    /* add sum of weights and number of subjects to predx2b2 */ 
    
    proc sort data =  predx2b2 ; by &subject ;
    data predx2b2 ;
      merge predx2b2
            _persons ;
      by &subject ;
/* _predicted data set for correlated part */
  %if &weekend ne %STR() %then %do;  /* weekend variable exists */
    data &outlib.._pred_&foodtype&vcontrol (keep=&subject &predxb &replicate_var &weekend &subgroup); 
      if (_n_=1) then set &outlib.._param_&foodtype&vcontrol;    
      set predx2b2(drop=&weekend);
      by &subject &repeat;
      if (first.&subject);
     
      /* create x1b1, x2b2 for weekday, weekend records*/
      &weekend=0;
      x1b1_0=(&nonu1seq1);
      x2b2_0=(&nonu2seq2);
     
      &weekend=1; 
      x1b1_1=(&nonu1seq1);
      x2b2_1=(&nonu2seq2);          
      
      run;
  %end;  /* of &weekend ne %str() */
  
  %else %do;
    data &outlib.._pred_&foodtype&vcontrol (keep=&subject &predxb &replicate_var &subgroup); 
      merge predx1b1 (keep=&subject &repeat pred &replicate_var rename=(pred=x1b1))
      predx2b2 (keep=&subject &repeat &replicate_var pred &subgroup
                     rename=(pred=x2b2));
      by &subject &repeat;
      if (first.&subject);
      
      run;
  %end;
  
    
  %put ## the data sets &outlib.._pred_&foodtype&vcontrol and &outlib.._param_&foodtype&vcontrol ;
  %put ## have been output for use in the DISTRIB macro or other software using CORR models;
 
  ** IMS SPECIFIC; 
  data _null_;
     %if &origvcontrol = %str(0) %then %let vcontrol = %str(0);  /* reinstate value of vcontrol,special case, for CORR base runs per Kevin Dodd */ 
  run;

  ** END IMS SPECIFIC;
 
  **********************************************************************;
  **  prepare data for printing summary reports;
  ***********************************************************************;
  ***Skip reports if a re-run, only write reports for a base run ****;
  %if &vcontrol=%str() %then %do;
    data fit3;
      format Parameter $30.;
      set fitf3;
      if Descr in ('-2 Log Likelihood','AIC (smaller is better)');
      if Descr='-2 Log Likelihood' then do;
        Parameter='ll';
        Name2='-2 Log Likelihood';
        type='4.fit';
      end; /* if Descr='-2 Log... */
      if Descr='AIC (smaller is better)' then do;
        Parameter='aic';
        Name2='AIC';
        type='4.fit';
      end; /* if Descr='AIC ... */
      run;   
         
    data namesf;
      set &start_val3 fit3;
      keep Parameter Name2 type Value;
      run;   
         
    proc sort data=namesf ; 
      by Parameter; 
      run;
 
    proc sort data=parmsf3; 
      by Parameter; 
      run;

    proc sort data=fitboth; 
      by Parameter; 
      run;

    data final;
      Format Parameter $30.;
      merge parmsf3 namesf fitboth; 
      by Parameter;
      if Parameter='ll' then do;
        lrtest=m2llo-Value;
        probll=1-probchi(lrtest,1);
      end; /* if parameter=... */
    
    proc sort data=final; 
      by type; 
      run;
    
    data ll(keep= ll);
      set final; 
      if parameter = 'll';
      ll = value; 

    data aic(keep=aic);
      set final; 
      if parameter = 'aic';
      aic = value; 
    
    data numparms;
      Format Parameter $30.;
      set ll ; if _n_=1 then set aic;
      pcorr = (aic - ll)/2;
      pgenmod = pcorr - 3;
      porig = pcorr - 1;
      parameter = 'aic';
      run;
  %end ;      /* of if vcontrol is blank (base run) for reports */
%end ;        /* of if modeltype eq CORR */
    ods select all;
  ** end of correlated calculations ;
  ********************************************************************;
  %if &vcontrol=%str() %then %do ;  /* write reports if a base run */
    /*---turn the printing back on---*/
    ods select all;

    /*---Report results for Uncorrelated Model---*/

    data _null_;
      title%eval(&titles+1) "Results from Fitting Uncorrelated (amount or nocorr) Model";
      title%eval(&titles+2) "Response Variable: &response";
      title%eval(&titles+3);
      title%eval(&titles+4) "Convergence Status:";
      %if &modeltype ne AMOUNT %then %do ; 
        title%eval(&titles+5) "   Probability Model -- &convbi";
        title%eval(&titles+6) "   Amount Model -- &convin";
      %end;
      %else %do;
        title%eval(&titles+5) "   Amount Model -- &convin";
      %end;
      retain aaa 1 ab 2 bb 27 c 52 d 62 e 72;
      file print header=header ll=lines ls=126 ps=80;
      set estprint end=eof; by type;
      if type in ('1.pr','2.am') then 
        put @ab Parameter 
            @bb Name2 
            @c Estimate 8.4-r 
            @;                   
        ** print SE and probt if weight variable is not used **;
        if "&replicate_var" eq "dummywt" then put
            @d StandardError 8.4-r 
            @e Probt 6.4-r;
        else put;
            
      if lines=1 then do;
        put @aaa 80*'_';
      end; /* if lines=1 ... */
      if eof then do;
        put @aaa 80*'_';
      end; /* if eof ... */
     return;
     header:
     put // @aaa 80*'_';
     put @ab 'Parameter' @bb 'Name' @c 'Estimate' 
     @;
     if "&replicate_var" eq "dummywt" then put @d '  Std Err' @e 'Prob>|t|'; 
     else put;
     put @aaa 80*'_';
     return;
     run;

    data estprint2;
      set estprint; 
      by type Parameter; 
      prevval=lag(Value);
      if last.Parameter then sum=Value+prevval;
      run;
    
    data _null_;
      title%eval(&titles+1) "Results from Fitting Uncorrelated (amount or nocorr) Model";
      title%eval(&titles+2) "Response Variable: &response";
      retain aaa 3 ab 5 bb 40 cc 56;
      file print header=header ll=lines ls=126 ps=70;
      set estprint2 end=eof; 
      by type;
      if type in ('4.fit') then put @ab Name2 @bb Value 8.2-r @cc sum 8.2-r;
      if lines=1 then do;
        put @aaa 70*'_';
      end; /* if lines =1... */
      if eof then do;
        put @aaa 70*'_';
      end; /* if eof ... */
      return;
      header:
      put // @aaa 70*'_';
      put @ab 'Name' @bb ' Value' @cc ' Sum';
      put @aaa 70*'_';
      return;
      run;
      
      title%eval(&titles+1);
      
  ************************************************************;
        
  /*---Report results for Correlated Model---*/
  
    %if &modeltype eq CORR %then %do ; 
    
      data _null_;
        title%eval(&titles+1) "Results from Fitting Correlated Model";
        title%eval(&titles+2) "Response Variable: &response";
        title%eval(&titles+3);
        title%eval(&titles+4) "Convergence Status:";
        title%eval(&titles+5) "   &convcr";
        retain aaa 1 ab 2 bb 27 c 52 d 62 e 72;
        file print header=header ll=lines ls=126 ps=80;
        set final end=eof; 
        by type;
        if type in ('1.pr','2.am','3.cov') then do;
          put @ab Parameter 
              @bb Name2 
              @c Estimate 8.4-r 
              @;                   
        ** print SE and probt if weight variable is not used **;
          if "&replicate_var" eq "dummywt" then put
            @d StandardError 8.4-r 
            @e Probt 6.4-r;
          else put;
        end;                /* if type 1.pr 2.am 3.co */
        if lines=1 then do;
          put @aaa 80*'_';
        end; /* if lines=1 then... */
        if eof then do;
          if "&replicate_var" ne "dummywt" then
          put @1 "* Standard errors not printed due to use of replicate variable &replicate_var" ;
          put @aaa 80*'_';
        end; /* if eof then... */
        return;
        header:
        put // @aaa 80*'_';
        put @ab 'Parameter' @bb 'Name' @c 'Estimate' 
        @;
        if "&replicate_var" eq "dummywt" then put@d '  Std Err' @e 'Prob>|t|';
        else put; 
        put @aaa 80*'_';
        return;
        run;

      data _null_;
        title%eval(&titles+1) "Results from Fitting Correlated Model";
        title%eval(&titles+2) "Response Variable: &response";
        retain aaa 3 ab 5 bb 25 cc 35 dd 50;
        file print header=header ll=lines ls=126 ps=70;
        set final end=eof; 
        by type;
        if type in ('4.fit') then 
          put @ab Name2 @bb Value 8.2-r @cc lrtest 8.2-r @dd probll 6.4-r;
        if lines=1 then do;
          put @aaa 70*'_';
        end; /* if lines = 1 ... */
        if eof then do;
          put @aaa 70*'_';
        end; /* if eof ... */
        return;
        header:
        put // @aaa 70*'_';
        put @ab 'Name' @bb 'Value' @cc 'Diff in -2ll' @dd 'p-value';
        put @aaa 70*'_';
        return;
        run;
      
      proc sort data=final; 
        by Parameter; 
        run;
      
      proc sort data=numparms; 
        by Parameter; 
        run;
      
      data finalll;
        set final(rename=Value=m2ll_corr); if _n_=1 then set numparms; 
        by Parameter;
        if Parameter in ('ll','aic');
        convcr = "&convcr";
        run;
    %end;        /* of if modeltype eq CORR */
  %end   ;       /* of reports etc. if a base run */    
  run;

  ** end of printing correlated reports;

****************************************************************;
***** Clean up remaining data sets created/used in macro MIXTRAN only ***** ;

proc datasets nolist;
  delete
   MISC_INFO  _PERSONS data data0 &tempda
  ;
%if &modeltype=%str(CORR) %then %do ;
  delete
    FITF3  PARMSF3 CONVF3 
    PREDEINT PREDP PREDU1 PREDU2 PREDX1B1 PREDX2B2  _PREDU1 _PREDU2
    ;
  %if &vcontrol=%str() %then %do ;
    delete 
     BOXCOX CONVF1 CONVF2 COV COV2 EQN1 EQN2 ESTPRINT 
     ESTPRINT2 FIT1 FIT2 FITBOTH FITF1 FITF2 LAMBDA 
     MODELFITB  NAMES NAMES2 NEWNAMES1 NEWNAMES2 
     OUT1 OUT2 OUTCOV PARMSF1 PARMSF2 PARMSG1 PARMSG2 
     PREDEINTU PREDPU PREDU1U PREDU2U PREDX1B1U
     PREDX2B2U RANDOM1 RANDOM2 START1 START2 START3    
      TRANS1 TRANS2 
     ADPRMSF1 ADPRMSF2  ADPRMSF3 START1VARGRP START2VARGRP
     AIC  FINAL FINALLL FIT3 LL NAMESF NUMPARMS RNDM
      _PARAM_UNC STARTM  _PARAM
      
    ;
   %end ; /* vcontrol = ' ' - base run  corr */
   %else %do ;
     delete
        ADPRMSF3 _PARAM 
     ;
   %end ;  /* re-run in corr of clean up of data sets */
 %end ;  /* CORR */
 
 %else %if &modeltype=%str(NOCORR) %then %do ;
   %if &vcontrol = %str() %then %do ;  /* base run */
     delete
     BOXCOX CONVF1 CONVF2 COV COV2  EQN1 EQN2 ESTPRINT 
     ESTPRINT2 FIT1 FIT2 FITF1 FITF2 LAMBDA 
     MODELFITB  NAMES NAMES2 NEWNAMES1 NEWNAMES2 
     OUT1 OUT2 OUTCOV PARMSF1 PARMSF2 PARMSG1 PARMSG2 
     PREDEINTU PREDPU PREDU1U PREDU2U PREDX1B1U
     PREDX2B2U RANDOM1 RANDOM2 START1 START2 START3    
     STARTM  TRANS1 TRANS2 
     ADPRMSF1 ADPRMSF2 START1VARGRP START2VARGRP
     ;
   %end ;  /*  vcontrol = ' '   base run in nocorr in clean up of data sets */
     %else %do ; /* if a re-run */
       delete
       COV COV2 OUTCOV START3 _param_unc
       PARMSF1 PARMSF2  
       PREDEINTU PREDPU PREDU1U PREDU2U PREDX1B1U PREDX2B2U
       ADPRMSF1 ADPRMSF2 FITF1 FITF2
       convf1 convf2
       ;
     %end ;  /* re-run of nocorr in clean up of data sets. */
     
 %end;  /* NOCORR */
 %else %if &modeltype=%str(AMOUNT) %then %do;
   %if &vcontrol = %str() %then %do ;
     delete
     BOXCOX CONVF2 COV EQN2 ESTPRINT 
     ESTPRINT2 FIT2 FITF2 LAMBDA 
     NAMES NAMES2 NEWNAMES2 
     OUT2 OUTCOV PARMSF2 PARMSG2 
     PREDEINTU PREDU2U 
     PREDX2B2U RANDOM2 START2 START3    
     STARTM TRANS2 ADPRMSF2 START2VARGRP _PARAM_UNC
    ;  
   %end ;   /* vcontrol = ' ' - base run amount in clean up */
   %else %do ;     /* re-run */
     delete
     cov cov2 outcov start3 _param_unc 
     parmsf2 predu2u predx2b2u
     adprmsf2 fitf2 convf2
     ;
   %end ; /* re-run in amount clean up */
     
 %end  ; /* AMOUNT */
run;

** succesful conclusion message **;
  %let Success = 1;  **Reach here only if did not exit early ; 

%convexit: 

run; 
   
*************Documenation ****************;
** clear titles generated inside the macro **;
title%eval(&titles+1) ;  

***** draw a line under the end of the macro output in the list file***;
data _null_ ;
  file print; 
  put @1 80*'*' ;
  put @1 " End of MIXTRAN Macro Call for &foodtype &modeltype &vcontrol" 
      @78 '**'
      ;
  if &success = 1 then put " Execution of MIXTRAN was successful ;";
  else put " Execution of MIXTRAN was NOT successful check the log ";
  put @1 80*'*';
  run ;
  
  ** message to the log **
   %if &success = 1 %then %put ## Execution of MIXTRAN was successful for &data &replicate_var ;
   %else %put ## Execution of MIXTRAN was NOT successful for &data &replicate_var  - check the log ;
   %put ## ___________________________________________________________________________________________ ;
   %put;
%mend MIXTRAN;  
 
/*  END OF THE MIXTRAN MACRO                                       */
/*******************************************************************/

