
/*******************************************************************          
/*                                                                  
/*  THE DISTRIB MACRO                                               
/*                                                                  
/*******************************************************************
/*                     VERSION 2.2           02/17/2017             
/*                                                                  
/* The DISTRIB macro uses results from the MIXTRAN macro and        
/* estimates the distribution of usual intake for episodically      
/* consumed foods, foods consumed every day, and nutrients (Tooze   
/* et al., 2006, Journal of the American Dietetic Association, 106, 
/* 1575-1587).  The data can then be used to calculate percentiles
/* and, optionally, the percent meeting the recommended daily 
/* intake for a population. 
/*
/* The DISTRIB macro contains two main functions.                                                
/*                                                                  
/* First, the DISTRIB macro reads data sets of parameter estimates  
/* and predicted values output by the MIXTRAN macro.  Monte Carlo   
/* simulation of the random effect(s) is used to estimate the       
/* distribution of usual intake. This data set can be saved.   
/*
/* Second, once the data containing the estimated usual intake are available,
/* percentiles and cutpoints can be calculated.  The addition of a sub group 
/* variable is accommodated, so that statistics can be calculated by
/* subgroup and for the overall data set. Optionally the percent who
/* meet recommended daily intake values can be calculated.

/* To accomplish this and allow flexibility,the DISTRIB macro 
/* contains two sub-macros and some general code to set up 
/* and call the macros as requested.
 
/* the macro MC uses monte carlo simulation of the  
/* random effect(s) to estimate the distribution of usual intake.       
/* The output data set can be saved for future use.   

/* the macro PC reads in the usual intake values calculated in the macro MC,
/* normalises the weights, calculates the percentiles of usual intake,
/* cutpoints if requested, and optionally the percent meeting 
/* recommended intake. A single subgroup variable can be accommodated
/* in the macro PC. The resulting data set can be saved for future use.
/*
/* UPDATE: This version calculates percentiles using SAS Proc Univariate,
/*         instead of using custom code to calculate the percentiles by 
/*         linear projection.
**************************************************************************;
/*
/*                                                                  
/* The syntax for calling the DISTRIB macro is:                     
/*                                                                  
/*       %DISTRIB (call_type=, seed=, nsim_mc=, modeltype=,         
/*                 pred=, param=,outlib=, cutpoints=, ncutpnt=,     
/*                 byvar=, subgroup=, add_da=, subject=,          
/*                 titles=, food=, mcsimda=, 
/*                 recamt=,recamt_co=,recamt_hi=,
/*                 wkend_prop=,wkend_mc=);                                    
/*                                                                  
/* where:                                                           
/*                                                                  
/*  "call_type" * Specifies which parts of the DISTRIB macro should 
/*                be invoked. (FULL, MC, PC). FULL is the default.
/*                A null string implies FULL.
/*                FULL = invoke both the calculation 
/*                  of the estimated intake amount (using monte carlo 
/*                  simulation) and of the percentiles (and optionally 
/*                  the percent not meeting the recommended amount of
/*                  intake).  
/*                MC = restrict the macro to calculating 
/*                  the intake amount (using monte carlo simulation).
/*                PC = use the intake estimates - calculated 
/*                  in the MC macro in DISTRIB - 
/*                  to calculate percentiles and, optionally, the 
/*                  percent meeting the recommended amount of 
/*                  intake, and/or cutpoints. 
/*
/*  "seed"      * Specifies the seed for the random number          
/*                generator used for the Monte Carlo simulation of  
/*                the random effects u1 and u2.  
/*                Required if the call_type is FULL or MC.                   
/*                Not used if call_type is PC.                      
/*                                                                  
/*  "nsim_mc"   * Specifies the number of repetitions to be used in 
/*                the Monte Carlo simulation.  For each subject,    
/*                one record will be output for each repetition. 
/*                Required if the call_type is FULL or MC.      
/*                Not used if call_type is PC.                      
/*                                                                  
/*  "modeltype" * Specifies the model that was used by the MIXTRAN  
/*                macro to prepare the data for the DISTRIB macro.  
/*                The value must be the same as the model declared  
/*                for the MIXTRAN macro. The default is correlated. 
/*                The possible values are:  
/*                  null string  = fit correlated model,             
/*                  corr         = fit correlated model,             
/*                  nocorr       = fit uncorrelated model,           
/*                  amount       = fit amount-only model.            
/*                                                                  
/*  "pred"      * Specifies the name of the data set containing     
/*                predicted values calculated in the MIXTRAN macro.                      
/*                Required.             
/*                                                                  
/*  "param"     * Specifies the name of the data set containing the 
/*                parameter estimates calculated in the MIXTRAN     
/*                macro.  
/*                Required if the call_type is FULL or MC.
/*                Not used if call_type is PC.                                            
/*                                                                  
/*  "outlib"    * Specifies the library reference to which the      
/*                output data set of distributions will be written. 
/*                                                                  
/*  "cutpoints"   Specifies a list of cutoff points separated by a  
/*                space.                                            
/*                Not used if call_type is MC.                      
/*                                                                  
/*  "ncutpnt"     Specifies the number of cutoff points.  If cutoff 
/*                points are given, ncutpnt must also be given.     
/*                Not used if call_type is MC.                      
/*                                                                  
/*  "byvar"       Specifies a list of by-variables that are in the  
/*                data sets "pred" and "param" to indicate that the 
/*                MIXTRAN model was fit separately for each         
/*                by-group. The estimates used in the calculation will 
/*                differ based on the by group, however The DISTRIB 
/*                macro will ultimately produce estimates of the entire         
/*                population (not distributions within each by group).          
/*                To obtain distributions for subpopulations, use the                          
/*                "subgroup" parameter.                             
/*                                                                  
/*  "subgroup"    Specifies one categorical variable used for the   
/*                calculation of a separate usual intake            
/*                distribution for each subgroup.  The distribution 
/*                of usual intake will also be calculated for the   
/*                overall data set. Requires that the paramater
/*                add_da be supplied. 
/*                Not used if call_type is MC.                      
/*
/*  "add_da"      The name of the data set containing the subgroup
/*                variable by which the percentiles are to be
/*                calculated, and/or the recommended amount variable.
/*                This data set must include:  
/*                the ID variable declared in the parameter SUBJECT,
/*                and one or both of the following variables: 
/*                the variable named in the parameter SUBGROUP 
/*                the variable(s) named in the parameter(s) recamt and/or recamt_hi. 
/*                This parameter is required if either of the parameters
/*                subgroup or recamt are called.
/*                Not used if call_type is MC.                      
/*                                                                  
/*  "subject" *   Specifies the variable that uniquely identifies   
/*                each subject. (The ID.)                                    
/*                                                                    
/*                                                                  
/*  "titles"      Specifies the number of title lines to be   
/*                reserved for the user's titles.      
/*                The default value is 0.                                                        
/*                                                                  
/*  "food"     *  Specifies a name for the analysis, used to name  
/*                the output data set.                              
/*                                                                  
/*  "mcsimda"  *  Specifies the name of the data set containing the 
/*                intake amount derived from the monte carlo        
/*                simulations. To read or write the data file from disk include
/*                a libname. Note: due to simulations (see parameter nsim_mc)  
/*                the data set can grow quite large.               
/*                Default value is work.mcsim in which case the data set is
/*                not saved for later use.                                 
/*                Required if call_type is PC.                                         
/*                                                                  
/*  "recamt"     The name of the variable containing the cut off level for           
/*               the recommended amount of consumption for this food.
/*               If the value of the "recamt_co" parameter is R then this
/*               variable is used as the lower limit of the range.
/*               If this parameter is used the name of the data set
/*               containing this variable must be supplied via the parameter
/*               "add_da". 
/*               Not used if the call_type is MC.
/*
/* "recamt_co"   the Comparison Operator between individual intake and
/*               the recommended amount described in the "recamt" parameter.
/*               Options are: 
/*                 LT - less than the "recamt" value,
/*                 LE - less than or equal to the "recamt" value,
/*                 GE - greater than or equal to the "recamt" value,
/*                 GT - greater than the "recamt" value,
/*                 R  - a range of values between two proportions, inclusive. 
/*               If the R option is used then the lower value will be the
/*               value of the  variable in the "recamt" paramater, and the
/*               upper value must be provided via the paramter "recamt_hi".
/*               The "recamt_co" parameter is required if the "recamt" paramter
/*               is supplied.
/*               Not used if the call type is MC.
/*  
/* "recamt_hi"   The name of the variable containing the upper limit of 
/*               of a range of inclusive values used to compare intake 
/*               to a recommended amount. This parameter is required if the
/*               value of the "recamt_co" parameter is R.  
/*               Not used if the call type is MC.               
/*
/* wkend_prop    A value between 0 and 1 (not inclusive).
/*               This parameter specifies the proportional weight for the 
/*               weekend days if "weekend" was used in the MIXTRAN macro.
/*               Either a fraction or decimal number is acceptable.     
/*               The remaining (e.g. weekday) proportion is calculated within     
/*               the macro. The default weights for weekdays  
/*               and weekend days are 4/7 and 3/7 respectively.
/*               Note: it is possible to use the "weekend" and            
/*               "wkend_prop" parameters with a binary variable     
/*               other than a weekend indicator.          
/*               Not used if the call_type is PC.
/*
/* wkend_mc      YES or a null string. 
/*               YES specifies that separate estimates of consumption day or 
/*               total amounts by weekend status be stored in the _mc_sim
/*               data files. Ohtrewise these interim variables will not be kept.
/*               This paramter is only used in a weekend run.
/*               Not used if the call_type is PC.
/*                                                                  
/* Note:  * Parameters marked with an asterisk are mandatory, a  
/*          value must be supplied in the macro call.               
/*                                                                  
/*******************************************************************/ 
;
               
%macro DISTRIB (call_type=,seed=, nsim_mc=, modeltype=, pred=, param=,
                outlib=, cutpoints=, ncutpnt=, byvar=, 
                subgroup=,add_da=,
                subject=, titles=, food=, mcsimda=, 
                recamt=, recamt_co=, recamt_hi=, 
                wkend_prop=,wkend_mc=);


**************************************************************************;

  
%macro MC;
/***************************************************************/
/* Macro to define the intake using monte carlo simulations    */
/* This macro is invoked if the call_type is FULL, MC or null  */
/***************************************************************/
 
/*  merge parameter and predicted data sets */             
data _predicted2;
  %if (&byvar = %str()) %then %do;   /* allow different estimates by by-group. */
    set &pred;
    if (_n_ = 1) then set _param;  
  %end;
  %else %do;
    merge &pred _param;
      by &byvar;
  %end;
  
  /* set up variables for one part models  in monte carlo repetitions */
  
  %if &modeltype ne CORR %then %do;
    rho = 0;
    %if &modeltype eq AMOUNT %then %do;
      cov_u1u2 = 0 ;
      z_u      = 0;
      p_var_u1 = 0;
      %if &wkendflag eq %str(1) %then %do;
        x1b1_0 = . ;
        x1b1_1 = . ;
      %end ;             /* of if weekend */
      %else %do;
        x1b1 = . ;
      %end ;             /* of not weekend */
    %end;                /* of model = AMOUNT */
  %end;                  /* of  setup for model ne CORR */
      
  
    if p_var_u1 > 0 then  stddev_u1 = sqrt(p_var_u1);
    if p_var_u1 = 0 then stddev_u1 = 0;  /* changes for amount strata to process all models in simulations */
    stddev_u2 = sqrt(a_var_u2);
    if cov_u1u2 = 0 then corr_u1u2 = 0;
    else  corr_u1u2 = COV_U1U2 / (stddev_u1 * stddev_u2);
  

run;

  
***********************************************************************;  

/* monte carlo simulations of intake.                                */;

  data &mcsimda ; 

    retain seed &seed;
    set _predicted2 end=eof;
    
    /* Keep only variables needed. Which ones depend whether this is a weekend run */
    
    /*   plus the option of keeping the intermediate weekend amounts and intake    */
    %if &wkendflag eq %str(1) %then %do ;
      %let mcta = ;
      %if %upcase(&wkend_mc) = %str(YES) %then %let mcta = %str(mc_t_0 mc_t_1 mc_a_0 mc_a_1);
      %if &modeltype ne %str(AMOUNT) %then %let mcp = %str(mc_p mc_p_0 mc_p_1);
      %else %let mcp = ;
      keep
        &subject mcsim_wt numsims 
        mc_t          
        mc_a 
        &mcp
        &mcta 
        ;
    %end ;   /* of keep for weekends */
    %else %do ;
      %if &modeltype ne %str(AMOUNT) %then %let mcp = %str( mc_p);
      %else %let mcp = ;    
      keep
        &subject mcsim_wt numsims
        mc_t &mcp mc_a
        ;
    %end ;   /* of keep for not weekends */
    
    /* arrays for 9 point approximation */
          array fbt (9) fbt1-fbt9;     /* new code from Kevin & Janet Tooze 03/16 and 3/11 2010 */
          array xbt (9) xbt1-xbt9;
          array bt  (9) bt1-bt9;
          array cj  (9) cj1-cj9 (-2.1 -1.3 -0.8 -0.5 0 0.5 0.8 1.3 2.1);
          array wj  (9) wj1-wj9 (0.063345 0.080255 0.070458 0.159698 0.252489 0.159698 0.070458 0.080255 0.063345);
          
    /* divide the individual weight by the number of repetitions */                           
    mcsim_wt=&freq_var/&nsim_mc ;
    
    /* keep the number of simulations to divide into the number of subjects in the pc macro  */
    numsims=%eval(&nsim_mc);
     
    /*  asssign variance of e here */
    %if &Numvargrps =%str(2) and &wkendflag = %str(1) %then %do;
      a_var_e_0 = a_vargrp2;
      a_var_e_1 = a_vargrp1;
    %end;
    %else %if &numvargrps gt %str(2) %then %do; 
      put "User ERROR:  The DISTRIB macro does not process more than two variance groups at this time. ";
    %end;
    
    /* generate monte carlo random effects. */
   
    do mcsim = 1 to &nsim_mc;
      /* calculate u1 and u2 */
      
        call rannor(seed,u1);               
        call rannor(seed,u2);
        u2 = corr_u1u2 * u1 + sqrt(1 - corr_u1u2**2) * u2;
        u1 = stddev_u1 * u1;	          
        u2 = stddev_u2 * u2;

     /* for weekend runs calculate intake from x1b1_0, x1b1_1 x2b2_0 & x2b2_1     */
     /* for runs with no weekend use x1b1 and x2b2                                */
     %if &wkendflag eq %str(1) %then %do;
       %let wk = _0 ;
       %let wkgr = 2 ;
       %if &numvargrps ne %str(0) %then %let ve = _0 ;
       %else %let ve = ;                             /* for variance of e */
     %end;   /* wkendflag = 1 */
     %else %do ;
       %let wk =  ;
       %let wkgr=1;
       %let ve = ;
     %end;  /* wkendflag ne 1 */
     %do i = 1 %to &wkgr;
       
       ** UPDATED 02/10. In Amount models  x1b1_0 and x1b1_1 have been set to missing. **;

               If x1b1&wk ^= . then mc_logit_p&wk = x1b1&wk + u1; /* u1 will always be nonmissing, but may be zero */
         If mc_logit_p&wk ^= . then mc_p&wk = 1 / (1 + exp(-mc_logit_p&wk));
         Else if stddev_u1 = 0 then mc_p&wk = 1;         /* make sure the missing value was on purpose for an AMOUNT run  */
  
        mc_bca&wk = x2b2&wk + u2;
        if (a_lambda = 0) then do;    /* added 06/11 */
        	min_bca&wk=(log(.5*min_amt)) ;
        end;   /* of lambda = 0 */
        else min_bca&wk=((.5*min_amt)**a_lambda-1)/a_lambda ;
    
        /* back-transform A (amount on consumption day) to original scale */
        
        /* 9 point approximation  */
        
        if (a_lambda = 0) then do;
          predcda = exp(mc_bca&wk + a_var_e&ve / 2); /* new code 3/16/10 */
        end;   /* of lambda = 0 */
        
        else if a_lambda>0 then do;                 /* new code  3/16/10 */    
          do j=1 to 9;
             xbt[j]=mc_bca&wk + cj[j]*sqrt(a_var_e&ve);
             fbt[j]=(max(0,xbt[j]*a_lambda+1))**(1/a_lambda);           
             bt[j]=wj[j]*fbt[j];
          end;  
          predcda=sum(of bt1-bt9); 
        end;   /* of lambda ne 0 */
        
        mc_a&wk = max(predcda,(.5*min_amt)) ; /* for any lambda*/  /* Corrected 09/24/12 to use untransformed minimum */
        
      *************; 
   
        mc_t&wk = mc_p&wk * mc_a&wk;
 
        %let wk=_1;
        %if &numvargrps ne %str(0) %then %let ve = _1 ;
        %else %let ve = ;                             /* for variance of e */        
     %end;   /* of i = 1 to wkgr */
     
     %if &wkendflag = %str(1) %then %do ;
       mc_t=((&wkday_prop*mc_t_0)+(&wkend_prop*mc_t_1));
       mc_a=((&wkday_prop*mc_a_0)+(&wkend_prop*mc_a_1));
       %if &modeltype ne %str(AMOUNT) %then %do;
         mc_p=((&wkday_prop*mc_p_0)+(&wkend_prop*mc_p_1));	
       %end;  /* wkendflag = 1 (not Amount) */     %end;    /* wkendflag = 1 */
          
     output ;
   
    end;       /* of monte carlo simulations through _mcsim */
  
    if (eof) then call symput("seed",trim(left(put(seed,12.))));
 
    run; 
 
%mend ;       /*end of monte carlo simulations macro mc ; */ 
***************************************************************************************;
***************************************************************************************;

/************************************************************************************** */
/* start of the percentiles macro */
/************************************************************************************** */

%macro PC ;

/****************************************************************************************/
/* the percentiles macro (PC) is invoked if the call_type is FULL, PC or null  **********/
/*
/* this macro will merge subgroup data if any to the estimated intake data 
/* saved by the macro MC. The intake data will be used to:
/*   calculate the normalised weight (by subgroup if any and for all groups combined);
/*   figure the percentiles, and cutpoints if requested;
/*   create the percentage meeting the recommended amount of intake if requested ;
/*   (all by subgroup if any and including the overall group);
/*   and write out a data set containing the percentiles and other descriptive information */
/*************************************************************************************** */

/* general setup for macro PC */

    /* if there is a subgroup or recommended amount then read in the additional data file */
    
    ** for backward compatibility the subgroup could be on the predicted data set or in add_da **;
    ** Compatibility required by Janet Tooze ** ;
    ** if a subgroup variable is specified then first check the predicted data set.
    ** if it is not in the predicted data set look for it in the additional data set. **;
    
    %let check = %str(0) ;
    %let addcheck = %str(0) ;
    %if &subgroup ne %str() %then %do ;
      %let dssub=%sysfunc(open(&pred,is)); 
      %if &dssub = 1 %then %do;
         /*data _null_;
         dset=open("&pred");
        call symput ('check',varnum(dssub,"&subgroup")); */
        %let check=%qsysfunc(varnum(&dssub,&subgroup));
        %let rcsub=%sysfunc(close(&dssub));
      %end ; /* of checking for the subgroup variable in the predicted data set */                     
run;
      
      %if &check ne 0 %then %do ;
        %let psub=%str(_predsub) ;
        proc sort data=&pred  out=&psub(keep=&subject &subgroup) nodupkey ;
      	   by &subject ;
      %end;   /* of there is a subgroup variable in the predicted data set */
    %end ;    /* of subgroup ne blank */
    
    /* if necessary read in the additional data */ 
    %if &recamt ne %str()  or (&subgroup ne %str()and &check = %str(0)) %then %do;
      %let addcheck = %str(1) ;
      %let altsubgroup = &subgroup;                ** more backward compatibility **;
      %if &check ne %str(0) %then %let altsubgroup=%str() ; ** case where the subgroup is in predicted and recamt is being called;
 
      proc sort data=&add_da out = _subs(keep = &subject &altsubgroup &recamt &recamt_hi) nodupkey;
           by &subject ;
      run;  
    %end ;      /* of reading in additional data (add_da) if needed */
 
    %if &check ne %str(0) %then %do;  
      
       %if &addcheck = 1 %then %do ; 
       	  data _subs ;
       	    merge _predsub
       	 	         _subs ;
       	 	  by &subject;
        %end;   /* of both add_da and _predSubs exist */
        %else %do ;
         proc datasets nolist library=work ;
         	 change  _predsub = _subs ;
         %end;  /* _predsubs exists but not add_da */
      %end;     /* of _predsub exists */ 	 
      run;
      
    /* set up the subgroup code for use in the percentile calculations    */
 
    %if &subgroup = %str( ) %then %do ;
      %let first_subgroup = %str( ) ;
      %let last_subgroup  = %str( ) ;
    %end;
    %if &subgroup ne %str( ) %then %do ; 
      %let first_subgroup = %str(if first.&subgroup) ;
      %let last_subgroup  = %str(or last.&subgroup)   ; 
    

     /* create a value for the overall subgroup (all records) if subgroup is used  */   
  
      *****************************************;
      /* ** if a subgroup variable is in use, the PC macro will create an
         ** overall category.  This will be coded either _overall or
         ** -255 depending on the type of the variable in the subgroup.
         ** If subgroup has been identified a second record will be output
         ** each time with the overall subgroup code and an adjusted weight 
         ** and number of subjects.
         ** Note that the intake values must have already been calculated 
         ** in the macro MC, a part of the macro DISTRIB.                                                               */
     
     /* find the variable type of the subgroup, if any, for the overall category */
      
      %let dsid=%sysfunc(open(work._subs,is)); 
         %if &dsid = 1 %then %do; 
             %let subnum=%qsysfunc(varnum(&dsid,&subgroup));
             %let subtype=%qsysfunc(vartype(&dsid,&subnum));
             %let rc=%sysfunc(close(&dsid));      
         %end;  /* of reading in variable type */
         %else %put " user error: unable to assign subgroup variable type ";
  
     run;
    
     /* end of code to find if subgroups is character or numeric    */
   %end ;   /* of if a subgroup */
   ****************;
   
  /* read in the mcsim data file                       */ 
  
  Proc sort data=&mcsimda out=_mcsim1;
       by &subject;
       
  /* subset to records in the predicted data set        */
 
  proc sort data=&pred out=_subset(keep=&subject) nodupkey ;
  	by &subject;        
  
  data _mcsim1 _notinmc(keep=&subject);
    merge _mcsim1 (in=inmc)
          _subset (in=insub);
    by &subject ;
    if inmc and insub then output _mcsim1 ;
    else if insub then output _notinmc;
  run;
  proc print data=_notinmc ; 
  title%eval(&titles+1) "records in the subset but not in the mc_sim data"; 
  run;
  
  /* If subgroup or recamt merge with supplemental file   */   
  /* and create the recommended amount flag if requested  */  
          
    %if &recamt ne %str() or &subgroup ne %str() %then %do; 
  data _mcsim1 _nomatch;
    merge _mcsim1 (in=inmc)
            _subs (in=insub);
      by &subject ;
      if inmc and insub then do;
      
        /* recommended amount: - flag success */
       
        %if &recamt ne %str() %then %do; 
          if mc_t ne . then &recamtflag = 0 ;  
          %if &recamt_co ne %str(R) %then %do;                       /* not a range. values lt, le, ge, gt) */
            if mc_t &recamt_co &recamt then &recamtflag = 1;         /* assign 1 if true*/
          %end;      
          %else %do ; 
            if &recamt le mc_t le &recamt_hi then &recamtflag = 1 ;  /* inclusive range */
          %end;  
        %end;    /* of assigning recommended amount flag  */
      
        output _mcsim1 ;
      
      end;     /* of inmc and insub */
      
      else output _nomatch ;
    
    run;
 

    proc print data=_nomatch (obs=1) ; 
    title%eval(&titles+1) 'First observation of data not matching in the intake data and the supplemental data';
    run;
  %end ;           /* of merging the supplemental data onto mcsim */ 
  
  
    /* If subgroup is used output one new record for every observation for an overall level */  
 
    %if &subgroup ne %str( ) %then %do ;    
    data _mcsim1 ;
      set _mcsim1 ;
      
      output;
        
        %if &subtype = %str(N) %then %do ; /* numeric variable */
          &subgroup = -255 ;
        %end;
        %else %if &subtype=%str(C) %then %do ; /* character variable */
          &subgroup =  "_Overall" ;
        %end;
        %else %do ;
          %put ## Error in recode of subgroups, vartype = &subtype ;
        %end; 
        output _mcsim1;    
   %end ;           /* of adding the overall record for the subgroup */ 
  
   ***************************************************;
   /* calculate group weights and total weights. */
   proc means data=_mcsim1 nway noprint;
     %if &subgroup ne %str() %then class &subgroup ; ;
     var mcsim_wt ;
     output out=_grpinfo(keep=grpwts numsubjects &subgroup) sum=grpwts n=numsubjects ;
   run;
   
 
   
   /* merge the weights onto the mcsim data */
   /* and calculate the adjusted weights by subgroup and overall */
   
   %if &subgroup ne %str() %then %do ; 
     proc sort data=_mcsim1 ;
       by &subgroup;
   %end;

   data _mcsim1 ;
     %if &subgroup ne %str() %then %do ;
       merge _mcsim1 end=eof
             _grpinfo 
           ;
       by &subgroup;
     %end ; 
     %else %do ;
       set _mcsim1 end=eof ;
       if _n_ =1 then set _grpinfo ;
     %end;
      
      /* calculate the adjusted weight */
           
      adjwt=mcsim_wt/grpwts;
      output ;  
      /* output the adjusted weight and the  intake */          
        totsum+adjwt ;      /* sum of adjwts = 1 if no subgroups, or # of subgroups +1 */
      if eof then put "the sum of the adjusted weights = " totsum ;
 

  **************************************************************************;

  ********* sort by mc_t  for calculation of percentiles *********;
proc sort data= _mcsim1;  
  by &subgroup mc_t;
run;

***************************************************************************
**  calculate the percentiles using proc univariate.
***************************************************************************;

proc univariate data=_mcsim1 noprint ;
  %if &subgroup ne %str() %then %do ;
        class &subgroup ;
      %end;
  var mc_t ;
  weight adjwt ;
  output out=outpercentiles (keep= &subgroup mean_mc_t tpercentile0-tpercentile100)
         pctlpts = 0 to 100 by 1
         pctlpre = tpercentile
         mean=mean_mc_t
         ;  
  run;
  
proc datasets library=work nolist;
  modify outpercentiles;
  attrib _all_ label='';
quit;

  ***********************************************
  **  calculate the cutpoints if requested.
  ***********************************************;

  %if &ncutpnt ne %str() %then %do ;
    
    %let cutp=%str(outcut1-outcut&ncutpnt );
   
      data _mcsim1 ;
        set _mcsim1 ;
      by &subgroup mc_t;
      
     ** create individual variables for level of cutpoints ; 
      array outone   (*) outcut1-outcut&ncutpnt ;
            
      %do cut = 1 %to &ncutpnt ;
         
         ** if first.&subgroup then initialize to 0 for each subgroup *** ;
         %if &subgroup ne %str() %then %do ;
           if first.&subgroup then outone(&cut)=0;
         %end;
         cutpt&cut=%scan(&cutpoints,&cut,%str( ));         
         if mc_t lt cutpt&cut then outone(&cut) = 1;
         else outone(&cut) = 0 ;     
      %end;    
    
     run;

    
    %end ;  /* cutpoints */


***************************************************************************
** end of percentiles and cutpoints code 
****************************************************************************;

/* combine percentiles, cutpoint probabilities, weighted mean of mc_t and number of subjects
/* and proprotion meeting recommended consumption if desired 
/* into one data file and save it.  The data set will be saved to "&outlib.". 
/* the name will be 'descript' followed by the food name in &food and if a
/* weight variable was used then also by the name of the weight variable */ ;

  proc means data=_mcsim1 noprint nway;
    %if &subgroup ne %str() %then %do ;
      class &subgroup ;
    %end;
    var mc_t &recamtflag &cutp;
    weight adjwt ;
    output out=_mean mean=mean_mc_t &proprec &cutprobs;
    
   /* sort groupinfo if subgroup,  and subset means to subgroup level data */
   %if &subgroup ne %str() %then %do ;
     proc sort data=_grpinfo ; by &subgroup ; 
   %end;     

   /* if the weight variable is named 'dummyst' then do not add the value to the output names */
   /* because it means there was no weight variable in MIXTRAN so a dummy weight of 1 was substituted */
   %if &freq_var = %str(dummywt) %then %let freq_var= %str();
   ***TEST;
     
   data _grpinfo ;
     set _grpinfo ;
     if _n_=1 then set _mcsim1(keep=numsims) ;
   run;
   
  data &outlib..descript_&food._&freq_var (keep= &subgroup numsubjects mean_mc_t &proprec
                       tpercentile0-tpercentile100 &cutprobs);                      
    merge outpercentiles
          _mean (keep=&subgroup mean_mc_t &proprec &cutprobs _type_ )
          _grpinfo 
          
          ;
    %if &subgroup ne %str() %then %do ;
      by &subgroup ;
      if first.&subgroup ;
    %end ;
    %else %do ;
      if _n_ =1 ;   /* no subgroups, only need the number of subjects overall */
    %end ;
    
    numsubjects=numsubjects/numsims ;
    %if &recamt ne %str() %then &proprec=&proprec*100; ; /* change proportion failing rec amt to percent */        
 
  run;

** CHECK;
  Proc print data=&outlib..descript_&food._&freq_var noobs uniform;
    %if (&subgroup ^= %str()) %then id &subgroup%str(;);
    var numsubjects mean_mc_t &proprec 
        tpercentile1 tpercentile5 tpercentile10 tpercentile15
        tpercentile25 tpercentile50 tpercentile75 
        tpercentile85 tpercentile90 tpercentile95 tpercentile99
        &cutprobs ;
    title%eval(&titles+1) "Selected Percentiles and Cutpoint Probabilities from the Distribution &food &freq_var";
 run;
 
 %if %eval(&syscc) = 0 %then %do;
   %put ## the data set output by DISTRIB will be &outlib..descript_&food._&freq_var ;
 %end;   /* of note to user re output data set */
 
proc datasets lib=work nolist ; 
  delete
         _mcsim1       /* to keep _mcsim1 for further analysis in this program comment it out */               
         outpercentiles
         _mean   
         _grpinfo 
         _param 
         _subset
         _notinmc    
         _subs
         ;
  %if &call_type = %str(FULL) %then %do ;
    delete _predicted2 ;
  %end; 
  %if &subgroup ne %str() %then %do;
    delete _nomatch ;
  %end;

  quit;
%mend ;    /* end of percentiles macro pc */

*********************************************************************************;
*********************************************************************************;

******************************************************************
/* general set up for all calls to the DISTRIB macro*/
******************************************************************;

%let success = 0 ;           /* successful execution flag */



  /* for backward compatibility with the tutorials, make sure there is an mcsim data set */
  %if &mcsimda=%str() %then %let mcsimda=work.mcsim ;

/* read in the parameter data set and create macro variables needed from _param */
data _param ;
  set &param ;
    if _n_ =1 then do;/* get the weight variable, the number of variance
                      /* groups and the flag indicating a weekend variable
                      /* if any of these were used in the MIXTRAN macro    */  
      call symput('freq_var',FreqName);  
      %if %upcase(&call_type) ne %str(PC) %then %do ;
        call symput('Numvargrps',left(Numvargrps));
        call symput('wkendflag',weekendflag);
      %end;
      
    end;
run;      

%let call_type=%upcase(&call_type);
%if &call_type = %str() %then %let call_type=%str(FULL);
%let modeltype=%upcase(&modeltype);
%let freq_var=%left(%trim(&freq_var));
/* If no Title lines reserved set titles to 0 */
%if &titles = %str() %then %let titles=0;
/*%if &freq_var = %str(dummywt) %then %let freq_var= %str(); */


  
/* set up a macro variable to keep the cut point probabilities if declared */
%if call_type ne %str(MC) %then %do ;

  %let cutp=%str() ;
  %if (&ncutpnt =  %str() and &cutpoints ne %str() ) or (&cutpoints =  %str() and &ncutpnt ne %str() ) %then %do ;
    %let ncutpnt = %str() ;
    %let cutpoints = %str() ;
    %put ## user warning (DISTRIB MACRO) - both cutpoints and number of cutpoints must be given. ;
    %put ##                Cutpoints will be ignored;
  %end;    /* need both cutpoints and number of cutpoints */
    
  %if &ncutpnt ne %str() %then %do ; 
    %if &ncutpnt = %eval(1) %then %do ;
      %let cutprobs=%str(cutprob1) ;
    %end;    /* only one cutpoint */
    %else %do ;
      %let cutprobs=%str(cutprob1-cutprob&ncutpnt) ;
    %end;   /* more than one cutpoint */
  %end;     /* have cutpoints */
  
  %else %do ;  /* no cutpoints */
    %let cutprobs=%str() ;
  %end ;      /* no cutpoints */

   /* if the proportion meeting the recommended amount of consumption is to be calculated */
   %if &recamt ne %str() %then %do ;
     /* check for supplemental data set with the recamt variable name */
     %if &add_da =%str() %then %do;
       %put ## USER ERROR: (DISTRIB MACRO) the data set name containing the variable &recamt must be supplied in the parameter add_da;
       %goto DISTEXIT;  
     %end ;  /* of check for supplemental data for the recamt variable */ 
     %let recamt_co=%upcase(&recamt_co);
     %if &recamt_co=%str() %then %do ;  /* need a value for recamt_co */
       %put ## USER ERROR: (DISTRIB MACRO)a comparison value is required in the recamt_co parameter for the recommend amount.;
       %put ##             Either add a value to the recamt_co parameter or remove the value from the recamt parameter.;
       %goto DISTEXIT;
     %end;  /* of recamt_co is blank */
     %else %do ;                        /* check that the value for recamt_co is valid*/
       %let validth = (LT LE GE GT R);
       %let t=%index(&validth,&recamt_co);
       %if %eval(&t) = 0 %then %do;
         %put ## USER ERROR: (DISTRIB MACRO)  The value "&recamt_co" for the parameter recamt_co is not valid. ;
         %goto DISTEXIT;
       %end;    /* of invalid value for recamt_co (other than blank) */
       %else %if &recamt_co = %str(R) and  &recamt_hi = %str() %then %do ; /* check for the upper range value */
         %put ## USER ERROR: (DISTRIB MACRO) The parameter recamt_co specified a range (value=R). ;
         %put ##             No upper value for the range is given ;
         %put ##             Please supply a variable name for the parameter recamt_hi  ;
         %put ##             or change the value of the parameter recamt_co ;
         %goto DISTEXIT;
       %end;    /* upper value for range if recamt_co = R */
     %end ;     /* recamt_co not blank */
       
     %let recamtflag = &recamt._flag ;  
     %let proprec = percent_rec_amt; 
   %end;  /* there is a recamt - set up */
   %else %do ;    
     %let recamtflag = ;
     %let proprec = ;
   %end; /* there is no recamt */
  
 %end ;   /* of if call_type ne MC t*/
 run;
 
 /* determine the proportions to be used in the case of "weekend" runs */
 %if &call_type ne %str(PC) %then %do ;
   %if &wkendflag eq %str(1) %then %do;
     %if &wkend_prop ne %str() %then %do ;
       %if %sysevalf(&wkend_prop) ge 1 %then %do ;
         %put ## USER ERROR: the weekend proportion must be less than 1. The proportion given is &wkend_prop ;
         %goto DISTEXIT ;
       %end ;    /* of wkend_prop ge 1 */
       %let wkday_prop = %sysevalf(1-&wkend_prop);
     %end;      /* of wkend_prop not blank */
     %else %do ;
       %let wkday_prop = 4/7 ;
       %let wkend_prop = 3/7 ;
     %end;   /* of default use for weekend proportions */
   %end ;    /* of wkendflag  1 */
 %end;       /* of determining the weekend proportions if not PC */ 
  
 /* notes to the log to help the user */

/*  Disabled 07/2016 
%put ## the call_type is &call_type ;
%put ## the model type is &modeltype ;
%put ## parameter data set = &param ; 
%put ## predicted data set = &pred ;
%put ## the food variable is &food ;
%if &freq_var ne %str(dummywt) %then %put ## the weight variable name is &freq_var ;
%if &byvar ne %str()  %then %put ## the by-variable is &byvar ;
%if &call_type ne %str(PC) %then %do ;
  %if &wkendflag = %str(1) %then %do ;
    %put ## coded for a weekend variable ;
    %put ## the proportional weights for the "weekend" are: &wkday_prop and &wkend_prop ;
  %end;
  %if &numvargrps ne %str(0) %then %put ## the number of variance groups is &numvargrps ; 
%end;
%if &call_type ne %str(MC) %then %do;
  %if &subgroup ne %str()  %then %put ## the subgroup variable is &subgroup ;
  %if &add_da ne %str() %then %put ## the data set containing additional information is &add_da;
  %if &ncutpnt ne %str() %then %do;
    %put ## the number of cutpoints is &ncutpnt;
    %put ## the cutpoints are &cutpoints ;
  %end ; 
%end; 
%if &recamt ne %str() %then %put ## recommended amount consumed will be tested using &recamt_co  &recamt &recamt_hi;
*/

*******************************************************************;
/* determine which parts of the DISTRIB macro to invoke           */

%if &call_type = %str(FULL) %then %do;
  %mc ;
  %pc ;
%end;
%else %if &call_type = %str(MC) %then %mc ;
%else %if &call_type = %str(PC) %then %pc ;
%else %do ;
  %put ## USER WARNING: (DISTRIB MACRO) INVALID call_type in the call to the DISTRIB macro ;
  %goto DISTEXIT ;
%end;


  %let success=1;    /* Flagging for succesful run */


%DISTEXIT:
;
%if &success ne 1 %then %do ;
  %put ## THE DISTRIB MACRO FAILED.  PLEASE CHECK THE LOG. ;
%end;
%else %put ## The DISTRIB macro completed succesfully ;

** clean up titles ** ;
  title%eval(&titles+1);

******************************************************************
/* end of general set up for all calls to the DISTRIB macro*/
******************************************************************;
%mend ;  /*   end of DISTRIB macro; */
     



  ***************************************************************************
  **  calculate the percentiles by linear interpolation.
  ***************************************************************************;
  
  **** removed 02/2017 ****;

