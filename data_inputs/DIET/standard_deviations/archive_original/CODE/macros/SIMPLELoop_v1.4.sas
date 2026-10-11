/* loop for simple Macro */
%macro SIMPLELoop(
 no = , 
 inputFile =,
 );

/* import parameter */
proc transpose data = &inputFile. out = input2; id input; var simulation:; run;


proc sql noprint;
  select 
    _name_,
    selectMacro,
	folder,
	data,
	note,
	nutrientVariable,
	nutrientType,
	outputDatasetName,
	subgroup,
	EARValue,
	EARVariable,
	ULValue,
	ULVariable,
	subjectID,
	repeatRecallVariable,
	seq,
	covariates,
	covariatesProb,
	weekend,
	SECalculationMethod,
	BRRFayFactor,
	weightVariable,
	startWeight,
	endWeight,
	breastmilkData,
	breastfeedingVariable,
	breastmilkID,
	breastmilkNutrientVariable, 
	supplementData,
	supplementID,
	supplementNutrientVariable, 
	SupplementUse,
	supplementSimulation,
	supplementCoverageVariable
  into
     :_Name_1-:_name_&no.,
     :_selectMacro_1-:_selectMacro_&no.,
	 :_folder_1-:_folder_&no.,
	 :_data_1-:_data_&no.,
	 :_note_1-:_note_&no.,
     :_nutrientVariable_1-:_nutrientVariable_&no.,
	 :_nutrientType_1-:_nutrientType_&no.,
	 :_outputDatasetName_1-:_outputDatasetName_&no.,
     :_subgroup_1-:_subgroup_&no.,
	 :_EARValue_1-:_EARValue_&no.,
	 :_EARVariable_1-:_EARVariable_&no.,
	 :_ULValue_1-:_ULValue_&no.,
     :_ULVariable_1-:_ULVariable_&no.,
     :_subjectID_1-:_subjectID_&no.,
     :_repeatRecallVariable_1-:_repeatRecallVariable_&no.,
	 :_seq_1-:_seq_&no.,
	 :_covariates_1-:_covariates_&no.,
	 :_covariatesProb_1-:_covariatesProb_&no.,
	 :_weekend_1-:_weekend_&no.,
     :_SECalculationMethod_1-:_SECalculationMethod_&no.,
	 :_BRRFayFactor_1-:_BRRFayFactor_&no.,
     :_weightVariable_1-:_weightVariable_&no.,
	 :_startWeight_1-:_startWeight_&no.,
	 :_end_1-:_end_&no.,
	 :_breastmilkData_1-:_breastmilkData_&no.,
	 :_breastfeedingVariable_1-:_breastfeedingVariable_&no.,
	 :_breastmilkID_1-:_breastmilkID_&no.,
     :_BFNutrientVariable_1-:_BFNutrientVariable_&no.,
	 :_supplementData_1-:_supplementData_&no.,
     :_supplementID_1-:_supplementID_&no.,
	 :_supplementNutrientVariable_1-:_supplementNutrientVariable_&no.,
	 :_SupplementUse_1-:_SupplementUse_&no.,
	 :_supplementSimulation_1-:_supplementSimulation_&no.,
	 :_supplementCoverageVariable_1-:_supplementCoverageVariable_&no.
  from input2;
quit;



 %local m;
 %do m = 1 %to &no.;
	 **************************************************************************;
       %put &m;
       %let _selectMacro_&m.  = %upcase(&&_selectMacro_&m.);
       %put &&_selectMacro_&m.;
       %if &&_selectMacro_&m. = %str(SIMPLE) %then %do;
	   
		   DM 'clear log';
			%SIMPLE(
			 /* location to store the output files */
			 folder = &&_folder_&m.,

			 /* main dataset */
			 data= &&_data_&m., 

			 /* note for the users */
			 Note = &&_note_&m.,

			 /* nutrient */
			 nutrientVariable = &&_nutrientVariable_&m., 
			 nutrientType = &&_nutrientType_&m., 
			 outputDatasetName = &&_outputDatasetName_&m., /*name of the output documents*/

			 /* subgroup analysis */
			 subgroup = &&_subgroup_&m., 

			 /* enter EAR values */
			 EARValue = &&_EARValue_&m., 
			 EARVariable = &&_EARVariable_&m.,


			 /* Enter UL values */
			 ULValue = &&_ULValue_&m.,
			 ULVariable = &&_ULVariable_&m.,
			 
			 /* ID and covariates */
			 subjectID = &&_subjectID_&m.,  
			 repeatRecallVariable = &&_repeatRecallVariable_&m., 

			 /* SEQ must be binary variable.  */
			 seq = &&_seq_&m.,  
			 covariates = &&_covariates_&m., 
			 covariatesProb = &&_covariatesProb_&m., 
			 weekend = &&_weekend_&m., 

			 /* study design and SE calculation method  */
			 /*either Bootstrap, BRR, or noSE */
			 SECalculationMethod = &&_SECalculationMethod_&m.,
			 BRRFayFactor = &&_BRRFayFactor_&m., /* only fill in if the surveyweight is BRR */
			 weightVariable = &&_weightVariable_&m., 
			 startWeight = &&_startWeight_&m., 
			 endWeight = &&_end_&m., 

			 /* nutrients from breastmilk */
			 breastmilkData =  &&_breastmilkData_&m.,  
			 breastfeedingVariable = &&_breastfeedingVariable_&m., 
			 breastmilkID = &&_breastmilkID_&m.,
			 breastmilkNutrientVariable = &&_BFNutrientVariable_&m.,

			 /*simulating supplementation */
			 supplementData = &&_supplementData_&m., 
			 supplementID = &&_supplementID_&m.,
			 supplementNutrientVariable = &&_SupplementNutrientVariable_&m.,
			 SupplementUse = &&_SupplementUse_&m.,
			 supplementSimulation = &&_supplementSimulation_&m.
			 supplementCoverageVariable = &&_SUpplementCoverageVariable_&m.
			 );	
			%end;
    %end;
    proc delete data = input2; run; quit;
%mend SIMPLELoop;
