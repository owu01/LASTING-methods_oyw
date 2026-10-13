# Title: Part 1 - Run PIF analysis
# Authors: Fred Cudhea & Brooke Bell
# Last Updated: 09-15-2025

############################################################################

### Documentation for R script ###

# PIF_analysis_part_1.r estimates the PIFs for all diet-disease pairs 
# of interest, using probabilistic sensitivity analysis to propagate uncertainty 
# (Which just means we use monte carlo simulations to calculate the PIFs multiple 
# times). The general idea for this script is we traverse through each 
# diet-disease pair and each subgroup, and calculate the PIF 1000 times. Inputs 
# are drawn randomly from a distribution and that uncertainty propagates into the 
# results. 

# Please review text on methods (this code is just implementation of methods) to 
# better understand what is going on (e.g. appendix of this paper: 
# https://pmc.ncbi.nlm.nih.gov/articles/PMC5702980/), but any PIF paper where 
# Fred is co-author should have similar description.

############################################################################

# First, we create various R objects where we store final output, as well as 
# intermediate outputs needed to calculate the PIFs.

# HUSS EDIT (sensitivity analysis): by default, negative PIFs are set to 0, as in
# LASTING. If the batch file sets ALLOW_NEGATIVE_PIF=TRUE, negative PIFs are kept,
# so a counterfactual that is LESS favourable than current intake (e.g. more red
# meat) counts as added disease instead of zero benefit.
allow_negative_pif <- isTRUE(as.logical(Sys.getenv("ALLOW_NEGATIVE_PIF", "FALSE")))
if (allow_negative_pif) print("SENSITIVITY ANALYSIS: negative PIFs are kept (not set to 0)")

# list of diseases draws, one element per dietary factor
disease.list <- list()

# a list of lists, giving the calculated PAFs by riskfactor, disease, strata, and iteration
PIF.list <- list() 

# above, a list of dataframes
PIFs <- list() 

samp_beta <- list()
data <- c()
q <- c()
qsx <- c()
qsx.alt <- c()
mtc <- c()
mtc.alt <- c()
x <- c()
x.alt <- c()
qsy <- c()
tmmtc <- c()
y <- c()
delat <- c()
delat.alt <- c()
p <- c()
p.alt <- c()
p.pp <- c()
p.pp.alt <- c()
delat <- list()
delat.alt <- list()
rr.list <- list()
rr.list.alt <- list()
p.rr <- list()
p.rr.alt <- c()
p <- list()
p.alt <- list()

pif <- replicate(num.diseases, matrix(NA, nsim2, nsim1), simplify = FALSE)
disease <- replicate(num.diseases, matrix(NA, nsim2, nsim1), simplify = FALSE)
observed.disease <- replicate(num.diseases, matrix(NA, nsim2, nsim1), simplify = FALSE)

final_mat_pif <-  matrix (NA, nsim2, 12)
final_mat_disease <-  matrix (NA, nsim2, 12) # matrix with final incidence/mortality estimates

m <- list()
s <- list()
m_disease <- list()
s_disease <- list()

# We are going to be using nested for-loops to traverse through everything we need.

# The highest level of the nested for-loop is for looping through the risk factors 
# of interest. We'll call it the r loop.

# First Loop for Each Risk Factor 
# this loop runs for each risk factor in the vector `rfvec`

# r=1

for (r in 1:length(rfvec_cra)) {  # Start risk factor loop
  
  # Within the r loop, first extract inputs specific to risk factor r, which 
  # includes RRs, risk factor to BMI and risk factor to SBP effects, and the 
  # TMRED. Recall that the data below are read in / extracted in run_models.rmd 
  # in the CRA-SPECIFIC INPUTS section. 
  
  # vector of age-sex-race specific files to be read in; for dietary risks 
  # only one file is in the vector
  
  # subset the relative risks dataset to the risk factor of interest
  rr = subset(rrtotal, RF == rfvec_cra[r]) 
  
  print(rfvec_cra[r])
  
  food.to.BMI <- subset(Food.to.BMI.effects, food_group == rfvec_cra[r])
  food.to.SBP <- subset(Food.to.SBP.effects, food_group == rfvec_cra[r])
  
  # theoretical minimums
  # iterate here to go through all the risk factors
  theominsub = subset(theomin, Risk_factor == rfvec_cra[r])
  mu_tmrd = theominsub$TMRED
  sd_tmrd = theominsub$SD
  
  # Within the r loop, we are going to start another for loop, which we'll 
  # call the l loop. This is a bit of obsolete legacy code, because it's for 
  # looping through multiple data sets, which we never do (we always have one 
  # exposure dataset, and opt to rerun the script if we have multiple datasets.
  # That's why code to read in the exposure data is within this loop.
  
  # Start file loop: loop through exposure datasets (there is usually just 1 
  # exposure file so in that case this is redundant)
  
  # l=1
  
  for (l in 1:nsim3) {   
    
    # expos3 is the exposure file 
    data <- expos3
    
    data1 <- data %>% 
      # subset to dietary factor
      filter(riskfactor == rfvec_cra[r]) %>% 
      # make sure that the rf data is in the same order as the rr data
      arrange(subgroup)
    
    # data01 <- subset(data0, diet == rfvec_cra[r]) 
    # data1 <- data01[order(data01$subgroup),] 
    # data1 will be the ordered data01 
    
    # The purpose of the ordering is to make the risk factor / disease burden data input 
    # file consistent with the rr file. Turns out, the rr file is not ordered 
    # by sex, age, race (looks like it's ordered by age, sex, race?). In any 
    # case, since rr file is ordered by subgroup, I am just going to change 
    # the code to order the rf data to be ordered by subgroup (which it already is)

    # It's possible for the intake means used to calculate PIFs to be negative 
    # (If we are drawing from a normal distribution and the estimate for mean 
    # intake is very low). Should be rare but given how many times we draw sims 
    # (1000 times for each riskfactor-subgroup combo) for mean intake, it's 
    # very possible that it happens once in a while. The following is creating 
    # a place to store how often this happens (this is internal info for 
    # debugging purposes, not output that you'd want to report). 
    
    count.mm.tozero <- 0
    count.mm.alt.tozero <- 0
    total.count <- 0
    
    # Within the r-l loop, we are starting a new loop, which we will call the i 
    # loop. Here, we are traversing through each subgroup (for each dietary factor, 
    # since we are nested within the r-l loop). 
    
    # i=1
  
    # This loop will be repeated for the length of age/sex subgroups for each risk factor
    for (i in 1:nsim2) {
      
      # We can't compute PIFs unless we have a SD value for the risk factor. 
      # Therefore we skip a subgroup if SD value is NA by having all the PIF 
      # calculations done with this this if statement.
      
      if(!is.na(data1$sd[i])) {
        
        # Still within the i-loop: Extract RR for subgroup i. (Within an if 
        # statement to ensure subgroup is defined in rr file)
        
        if(!is.null(rr$subgroup)) {
          
          subset.rr = rr %>% filter(subgroup == data1$subgroup[i])
            
          # subset(rr, rr$subgroup == data1$subgroup[i])
          
        }                                                                                  
        
        # Still within the i-loop: create some lists to store some intermediate 
        # inputs and outputs.
        
        beta <- list()
        samp_beta <- list()
        disease.samp <- list()
        
        # Still within the i-loop: create draws (from normal distribution) for 
        # current and counterfactual mean intake.
        
        mm1 = rnorm(n = nsim1, 
                    mean = data1$mean[i], 
                    sd = data1$se[i])
        
        mm2 = rnorm(n = nsim1, 
                    mean = data1$CF_mean_intake[i], 
                    sd = data1$CF_se_intake[i])
        
        # Still within the i-loop: we recode some variables (age and sex) and 
        # simulate draws for certain inputs relevant for mediated effects.
        
        # get prevalence of BMI > 25
        overweight.prev <- rnorm(n = nsim1, 
                                 mean = data1$overweight_rate[i], 
                                 sd = data1$overweight_rate_se[i]) / 100
        
        # if overweight.prev is < 0, then set to 0
        overweight.prev[overweight.prev < 0] <- 0
        
        # if overweight.prev is > 1, then set to 1
        overweight.prev[overweight.prev > 1] <- 1
        
        # define the variables necessary for modifying the linear effect of sodium on blood pressure (age, rage, htn..)
        
        gender <- data1$female[i] + 1 # gender = female + 1 in this hypertension model
        agemid <- data1$age.mid[i] # agemid predefined in input data
        
        htn.prev <- rnorm(n = nsim1, 
                          mean = data1$hbp[i], 
                          sd = data1$hbp_se[i])
        
        # if hypertension prevalence (htn.prev) is < 0, then set to 0
        htn.prev[htn.prev < 0] <- 0
        
        # if hypertension prevalence (htn.prev) is > 1, then set to 1
        htn.prev[htn.prev > 1] <- 1
        
        # similarly, we use 'Black' prevalence obtained from NHANES
        black <- rnorm(n = nsim1, 
                       mean = data1$nhb[i], 
                       sd = data1$nhb_se[i])
        
        # if black proportion is < 0, then set to 0
        black[black < 0] <- 0
        
        # if black proportion is > 1, then set to 1
        black[black > 1] <- 1
        
        # use proportion of high sbp (over 115) to get overall sodium to sbp 
        # effect for each subpopulation
        high.SBP.prev <- rnorm(n = nsim1, 
                               mean = data1$highSBP_rate[i], 
                               sd = data1$highSBP_rate_se[i]) / 100
        
        # if high.SBP is < 0, then set to 0
        high.SBP.prev[overweight.prev < 0] <- 0
        
        # if high.SBP is > 1, then set to 1
        high.SBP.prev[overweight.prev > 1] <- 1
        
        # Nested within the r,l,i loop, we are now starting the j-loop, looping 
        # through the diseases/pathways (for subgroup i and exposure r).
        
        # j=1
        
        for(j in 1:num.diseases){
          
          # Within the j-loop: Simulate draws for the RRs (per unit increase in 
          # log(RR) to be precise).
          
          beta[[j]] <- rnorm(n = nsim1, 
                             mean = subset.rr[[diseases.vec[j]]], 
                             sd = subset.rr[[diseases.vec.se[j]]])
          
          samp_beta[[j]] <- sample(beta[[j]], nsim1)
          
          # Within the j-loop: Simulate draws for effect of risk factor on BMI 
          # for normal weight and overweight. Use these, plus draws for 
          # overweight prevalence to get draws for overall effect of riskfactor 
          # on BMI for the subgroup.
          
          beta.lin.low = rnorm (n = nsim1, 
                                mean = food.to.BMI$effect_normal_mean, 
                                sd = food.to.BMI$effect_normal_mean_se)
          
          samp.beta.lin.low = sample (beta.lin.low, nsim1)
          
          beta.lin.high = rnorm (n = nsim1, 
                                 mean = food.to.BMI$effect_overweight_mean, 
                                 sd = food.to.BMI$effect_overweight_mean_se)
          
          samp.beta.lin.high = sample(beta.lin.high, nsim1)
          
          food.to.bmi.effect <- 
            beta.lin.high * overweight.prev + beta.lin.low * (1 - overweight.prev)
          
          # Within the j-loop: Simulate draws for main and interaction effects 
          # of dietary factor on SBP. Use these, and the draws for the proportion 
          # of Black people and prevalence of hypertension simulated earlier, to 
          # create draws for the overall effect of dietary factor r on SBP for subgroup i.
          
          # Sodium effects on blood pressure:
          
          # Main effects
          maineffect =  rnorm(n = nsim1, 
                               mean = food.to.SBP$main.effect.mean, 
                               sd = food.to.SBP$main.effect.se)
          
          # Interaction by age
          age_effect =  rnorm(n = nsim1, 
                              mean = food.to.SBP$age.effect.mean, 
                              sd = food.to.SBP$age.effect.se)
          
          # Interaction by race 
          race_effect =  rnorm (n = nsim1, 
                                mean = food.to.SBP$race.effect.mean, 
                                sd = food.to.SBP$race.effect.se)
          
          # Interaction by hypertensive status
          htneffect = rnorm (n = nsim1, 
                             mean = food.to.SBP$htn.effect.mean, 
                             sd = food.to.SBP$htn.effect.se)
          
          # here assign a value to the linear effect of sodium on BP, depending 
          # on age, region and htn status
          
          # age effect
          if(agemid > 70) {
            
            # for people over age 70, we use the same effect as people at age 70
            # In other words, the relationship between age and linear effect of 
            # Na on BP is assumed to be flat after age 70. 
            adjeffect.a[agemid > 70] <- (70 - 50) * age_effect 
            
          } else {
            
            adjeffect.a <- maineffect + (agemid - 50) * age_effect
            
          }
          
          # race effect 
          adjeffect.a.r = adjeffect.a + race_effect * black
          
          # effect of hypertension (weight by proportion hypertensive)
          adjeffect.a.r.h = 
            htn.prev * (adjeffect.a.r + htneffect) + (1 - htn.prev) * (adjeffect.a.r)
          
          food.to.sbp.effect <- adjeffect.a.r.h * high.SBP.prev #+0 * (1-high.sbp.prev)
          
          # Still within the j-loop: extract mortality/incidence draws for 
          # disease j (and subgroup i) and store them into the observed.disease 
          # list created earlier. 
          
          subset.observed.disease.draws <- observed.disease.draws %>% 
            filter(disease == diseases.vec[j] & subgroup == data1$subgroup[i])
            
            # subset(observed.disease.draws, 
            #        observed.disease.draws$disease == diseases.vec[j] & 
            #          observed.disease.draws$subgroup == data1$subgroup[i])
          
          observed.disease.draws.start.point <- 
            which(names(subset.observed.disease.draws) == "X1")
          
          observed.disease.draws.end.point <- 
            which(names(subset.observed.disease.draws) == paste0("X", nsim1))
          
          observed.disease[[j]][i,] <- 
            t(subset.observed.disease.draws[, observed.disease.draws.start.point:
                                           observed.disease.draws.end.point])
          
          # Now, still within the j-loop, we start the k-loop, which loops 
          # through all simulated draws (for a given disease/pathway and risk 
          # factor) to calculate the PIF nsim1 times (Recall nsim1 is set to 
          # 1000 in run_models.rmd, but you can set it whatever you want. For 
          # testing purposes, you'll probably want to set it to something 
          # much smaller initially). 
          
          # k=1
          
          for (k in 1:nsim1){ # Start Simulation Loop
            
            # Within the k-loop, extract k-th mean and standard deviation for 
            # both current and counterfactual intake (making sure to set them 
            # to slightly above zero for the rare instances that they end up 
            # being at or below zero). Derive gamma parameters based on 
            # extracted means and standard deviation. Recall that the model 
            # assumes the usual intake distribution for all food groups follow 
            # a gamma distribution, defined by two parameters: shape and rate. 
            
            mm <- (mm1[k]) # the mean for each age/sex group
            mm.alt <- (mm2[k])
            
            # Specific for each RF: data from mean to sd regression based on 
            # all global veg. data (see file "mean to sd reg coeff.xls"
            
            sdd = data1$sd[i]             
            sdd.alt = data1$CF_sd_intake[i]
            
            total.count <- total.count + 1
            
            if(mm <= 0) {
              
              # can't have negative values or 0 values for shape and rate so in 
              # this situation we set mean to near 0
              mm <- 0.001   
              count.mm.tozero <- count.mm.tozero + 1
              
            }   
            
            if(mm.alt <= 0) {
              
              # can't have negative values or 0 values for shape and rate so in 
              # this situation we set mean to near 0
              mm.alt <- 0.001 
              sdd.alt = sdd * mm.alt / mm
              count.mm.alt.tozero <- count.mm.alt.tozero + 1
              
            }  
            
            shape <- mm^2 / sdd^2
            rate <- mm / sdd^2
            shape.alt <- mm.alt^2 / sdd.alt^2
            rate.alt <- mm.alt / sdd.alt^2
            
            # Still within the k-loop:
            # we are going to calculate the PIFs using Reimann sums, meaning we 
            # are going to slice up the gamma distribution into small slices, 
            # multiply each slice by RR(x), and then sum them all up. First step 
            # then, is to generate quantile values to mark up where to slice up 
            # the exposure distributions. Note that that these values will be used 
            # for RR(x) as well. Essentially, we are  determining the values for 
            # "x" and "y" in our PIF formula.
            
            # First, we generate "q" which is just slicing up a standard normal 
            # 121 times in .1 size increments The smaller the width of your slice, 
            # the more precise Reimman integration is going to be. We are 
            # basically saying .1 is thin enough for us, and -6 to 6 is a wide 
            # enough range to cover the standard normal (which it most certainly 
            # is, covering more than 99.999999% of the probability mass). From 
            # there, we derive "y", the quantiles for the TMRED. "x" the quantiles 
            # for the current exposure distribution following a gamma, and "x.alt" 
            # the quantiles for the counterfactual exposure distribution. 
            
            # generate the "slices" of standard normal distribution between -6 
            # and 6 by 0.1 increments -- there are 121
            q <- seq(-6, 6, by = .1)
            
            # vector with 121 repetitions of mean for the age/sex group of 
            # interest (121 = length of q)
            mtc <- rep(mm, times = 121)            
            
            # vector with 121 repetitions of the theoretical minimum for mean
            tmmtc <- rep(mu_tmrd, times = 121)     
            
            # vector multiplying theoretical minimum sd by slices
            qsy <- sd_tmrd * q             
            
            # vector summing 121 repetitions of theoretical minimum mean 
            # with the "sliced" t.m. sd
            y <- (tmmtc + (qsy))
            
            x <- qgamma(pnorm(q, mean = 0, sd = 1), 
                        shape = shape, rate = rate)
            
            x.alt <- qgamma(pnorm(q, mean = 0, sd = 1), 
                            shape = shape.alt, rate = rate.alt)
            
            if(is.na(sum(x.alt))) {
              
              print(mm)
              print(sdd)
              print(mm.alt)
              print(sdd.alt)
              
            }
            
            # Still within the k-loop: Get the area under the curve for each slice. 
            # We can calculate this by taking the cumulative distribution function 
            # (that's what the pgamma function does) at q-th quantile and the 
            # (q-1)th quantile and taking the difference. Note that x.shifted 
            # vector is just x but shifted to the right one space, and having the 
            # first element be zero. Likewise for x.shifted.alt. So the q-th 
            # element in x.shifted is the (q-1)-th element in x. Using x.shifted 
            # lets us easily calculate the area under the curve for each slice 
            # in one line. 
            
            # same as x but lowest value is 0 and highest value of x is omitted
            x.shifted <- c(0, x[-length(x)])
            
            # same as x but lowest value is 0 and highest value of x is omitted
            x.shifted.alt <- c(0, x.alt[-length(x.alt)])
            
            # this is used to get probability between points in x-values
            p.pp <- pgamma(x, 
                           shape = shape, 
                           rate = rate) - pgamma(x.shifted, 
                                             shape = shape, 
                                             rate = rate)
            
            # determine the prevalence for each slice of each age-sex group: 
            # multiply the density of a normal distribution for each "slice"*sd
            p.pp.alt <- pgamma(x.alt, 
                               shape = shape.alt, 
                               rate = rate.alt) - pgamma(x.shifted.alt, 
                                                     shape = shape.alt, 
                                                     rate = rate.alt)
            
            # Still within the k-loop: Next we compute RR(x) for each slice. 
            # What the RR function is depends on which pathway we are on (direct, 
            # BMI-mediated, SBP-mediated), hence the ifelse statements. Recall 
            # that we essentially treat each foodgroup-pathway combination as its 
            # own exposure, since they have different relative risks. Note that 
            # the food to bmi/sbp effect units are baked into the code (That's 
            # where the 5 and 10 come in). If RR(x) ever ends up being less than 1 
            # (meaning the shift becomes harmful rather than helpful for health. 
            # Possible in tail ends of skewed distribution where P(x) might exceed 
            # tail end of normally distributed TMRED), we set it to 1. TMRED 
            # means minimum risk, so there should be no increase in moving to TMRED. 
            
            if(j %in% grep(diseases.vec, pattern = "medBMI")) {
              
              # defining delat and defining rr.list[[j]] are the two things that 
              # are different for mediated effects and direct effects.
              
              # for delat, the key difference is that  RRunit is not the same, 
              # since this is the effect on risk per unit of BMI, in this case 5 kg/m^2
              # Actually, the way we do it now, the food.to.bmi.effect does 
              #not have a fixed unit, so we divide by RRunit, as well as 5kg/m^2. 
              # e.g: if food.to.BMI effect is 100(g/d)(kg/m^2), and delta is in g,
              # then you want have (g/d)/(5kg/m^2)*(kg/m^2 / 100 g/d)
              
              delat[[j]] <- (x - y) / 5 / subset.rr$RRunit
              delat.alt[[j]] <- (x.alt - y) / 5 / subset.rr$RRunit
              
              # for rr.list[[j]], the key difference is that we must multiply by 
              # beta.lin.low or beta.lin.high, depending on what the BMI
              # is for that group. beta.lin is how much BMI increases per 
              # one unit of increase in dietary factor intake. 
              
              rr.list[[j]] <- 
                exp(delat[[j]] * samp_beta[[j]][k] * food.to.bmi.effect[k]) 
              
              rr.list.alt[[j]] <- 
                exp(delat.alt[[j]] * samp_beta[[j]][k] * food.to.bmi.effect[k]) 
              
            } else if(j %in% grep(diseases.vec, pattern = "medSBP")) {
              
              delat[[j]] <- (x - y) / 10 / subset.rr$RRunit
              delat.alt[[j]] <- (x.alt - y) / 10 / subset.rr$RRunit
              
              rr.list[[j]] <- 
                exp(delat[[j]] * samp_beta[[j]][k] * food.to.sbp.effect[k]) 
              
              rr.list.alt[[j]] <- 
                exp(delat.alt[[j]] * samp_beta[[j]][k] * food.to.sbp.effect[k]) 
              
            } else {
              
              # delta is the difference between the actual and theoretical 
              # minimum distributions
              
              delat[[j]] <- (x - y) / subset.rr$RRunit 
              
              delat.alt[[j]] <- (x.alt - y) / subset.rr$RRunit
              
              rr.list[[j]] <- exp(delat[[j]] * samp_beta[[j]][k])
              
              rr.list.alt[[j]] <- exp(delat.alt[[j]] * samp_beta[[j]][k])
              
            }
            
            rr.list[[j]][rr.list[[j]] < 1] <- 1
            rr.list.alt[[j]][rr.list.alt[[j]] < 1] <- 1
            
            # Still within the k-loop: Multiply RR by the area of the slices 
            # and sum up. Calculate the PIF! Store the value in list of data 
            # frames created earlier.
            
            p.rr[[j]] <- p.pp * rr.list[[j]]
            p.rr.alt[[j]] <- p.pp.alt * rr.list.alt[[j]]
            p[[j]] <- sum(p.rr[[j]], na.rm = TRUE) 
            p.alt[[j]] <- sum(p.rr.alt[[j]], na.rm = TRUE) 
            pif[[j]][i, k] <- (p[[j]] - p.alt[[j]]) / p[[j]]
            
            # Still within the k-loop: There are various scenarios where the 
            # PIF must be zero theoretically, but because of computational issues, 
            # you many not get exactly zero when computing it. In these cases, we 
            # set the PIF to zero manually. Meaning, if conditions below are met 
            # (relative risk for this simulation is 0, or risk profile for 
            # counterfactual distribution somehow being greater than risk profile 
            # for current distribution, for example), we replace whatever was 
            # calculated above with zero. 
            
            if(p[[j]] == 0)
              pif[[j]][i, k] <- 0
            
            # samp_beta is the effect of food on risk per dose for this particular 
            # iteration of the simulation. if it's zero, that means there is no 
            # effect in changing food distribution, so the PIF is 0. By just just 
            # setting it to 0, we can avoid complications.
            
            if(samp_beta[[j]][k] == 0) 
              pif[[j]][i, k] <- 0
            
            # If counterfactual is more harmful than current exposure 
            # distribution, then we can get negative numbers for PIF. 
            # Just set it to zero in that case
            # HUSS EDIT: unless the sensitivity analysis keeps negative PIFs
            
            if(!allow_negative_pif && pif[[j]][i, k] < 0)
              pif[[j]][i, k] <- 0
            
            # Still within the k-loop: Print various inputs and outptus for 
            # debugging purposes if PIF is NA
            
            if(is.na(pif[[j]][i, k])) {
              
              print(r)
              print(i)
              print(j)
              print(k)
              cat("pif[[j]][i,k]", pif[[j]][i,k], "\n")
              cat("p[j]", "\n")
              print(p[j])
              cat("p.alt[j]", "\n")
              print(p.alt[j])
              cat("mm", mm, "\n")
              cat("sdd", sdd, "\n")
              cat("mm.alt", mm.alt, "\n")
              cat("sdd.alt", sdd.alt, "\n")
              cat("rr.list[[j]]", rr.list[[j]], "\n")
              cat("rr.list.alt[[j]]", rr.list.alt[[j]], "\n")
              cat("delat[[j]]", delat[[j]], "\n")
              cat("delat.alt[[j]]", delat.alt[[j]], "\n")
              cat("subset.rr$RRunit", subset.rr$RRunit, "\n")
              cat("x", x, "\n")
              cat("x.alt", x.alt, "\n")
              cat("y", y, "\n")
              
            }
            
            # Still within the k-loop: Final step: Multiply the PIF to your 
            # observed mortality/incidence to attributable mortality/incidence.  
            
            # multiply by the corresponding ith sampled mortality here
            disease[[j]][i, k] = pif[[j]][i, k] * observed.disease[[j]][i, k]
            
          } # Close the k-loop.
          
        } # Close the j-loop.
        
        # End Simulation Loop  (nsim1)
        
      } # Close the if statement for making sure SD estimate exists.
      
    } # Close the i-loop.
    
    # We haven't closed all the loops yet. We are still in the l-loop. Recall 
    # that pif is a list of data frames we created within the r-loop. Each element 
    # in the list is a dataframe (one data frame for each disease/pathway, each 
    # dataframe has simulated PIFs for each subgroup (subgroups are rows, number 
    # of simulations is columns)). Here, we are simply storing this list as the 
    # r-th element of PIF.list. So PIF.list stores the entirety of all the PIF 
    # simulations generated, with each element of the list being filled in as we 
    # loop through the r loop. 
    
    PIF.list[[r]] <- pif
    
  } # close the l-loop
  
  # We are now still in the r-loop. The rest of the code within the r-loop is 
  # about creating two sets of dataframes for each riskfactor with all simulations 
  # (for all disease/pathways and all subgroups) and making sure all rows are 
  # properly labeled. First set of data frames is for attributable 
  # mortality/incidence, second set of data frames is for PIFs (both calculated 
  # within the k-loop).
  
  # First extract subgroup info (subgroup + current and counterfactual exposure).
  # Then create lists to store intermediate output.
  
  a = paste("diseasedraw.", seq(1, nsim1, by = 1), sep = '')
  
  if(identical(covar.vec, c("Age", "Sex", "Race"))) {
    
    id <- data1 %>% select("age", "female", "race", "mean", "se", "sd", 
                         "CF_mean_intake", "CF_se_intake", "CF_sd_intake")
      
      # data1[, c("age", "female", "race", "mean", "se", "sd", 
      #             "CF_mean_intake", "CF_se_intake", "CF_sd_intake")]
    
    }
  
  disease.df <- list()
  disease.df2 <- list()
  
  PIF.df <- list()
  PIF.df2 <- list()
  
  # Next, we will loop through disease.df and pif.df (both lists where each element 
  # is a matrix that contains the attributable mortality/incidence (the 
  # mortality/incidence attributed to the population being at the current exposure 
  # distribution rather than the counterfactual exposure distribution) or PIF 
  # (potential impact fraction, aka, the proportion of mortality/incidence attributable 
  # to being at the current exposure distribution rather than the counterfactual 
  # exposure distribution) sims for a disease/pathway), turning each matrix into 
  # a data frame and outcome of interest, pathway, and disease type. We then bind 
  # the subgroup level info we extracted earlier and call the new data frame 
  # disease2 (or pif2). So disease2 and pif2 are lists where each element is a data 
  # frame containing all the simulations for risk factor r and disease/pathway ii 
  # with proper labeling of rows and info specific to the disease/pathway and 
  # risk factor.
  
  # ii=1
  
  for(ii in 1:num.diseases){
    
    # disease.df[[ii]] <- as.data.frame(disease[[ii]])
    # disease.df[[ii]]$outcome <- disease.total.vec[[ii]]
    # disease.df[[ii]]$pathway <- pathway[[ii]]
    # disease.df[[ii]]$disease_type <- disease.type.total.vec[[ii]]
    # disease.df[[ii]]$disease_type1 <- disease.type1.total.vec[[ii]]
    # disease.df[[ii]]$disease_type2 <- disease.type2.total.vec[[ii]]
    # disease.df[[ii]]$disease_type3 <- disease.type3.total.vec[[ii]]
    
    disease.df[[ii]] <- as.data.frame(disease[[ii]]) %>% 
      mutate(outcome = disease.total.vec[[ii]],
             pathway = pathway[[ii]],
             disease_type = disease.type.total.vec[[ii]],
             disease_type1 = disease.type1.total.vec[[ii]],
             disease_type2 = disease.type2.total.vec[[ii]],
             disease_type3 = disease.type3.total.vec[[ii]])
    
    disease.df2[[ii]] <- cbind(id, disease.df[[ii]])
    
    # PIF.df[[ii]] <- as.data.frame(PIF.list[[r]][[ii]])
    # PIF.df[[ii]]$outcome <- disease.total.vec[[ii]]
    # PIF.df[[ii]]$pathway <- pathway[[ii]]
    # PIF.df[[ii]]$disease_type <- disease.type.total.vec[[ii]]
    # PIF.df[[ii]]$disease_type1 <- disease.type1.total.vec[[ii]]
    # PIF.df[[ii]]$disease_type2 <- disease.type2.total.vec[[ii]]
    # PIF.df[[ii]]$disease_type3 <- disease.type3.total.vec[[ii]]
    
    PIF.df[[ii]] <- as.data.frame(PIF.list[[r]][[ii]]) %>% 
      mutate(outcome = disease.total.vec[[ii]],
             pathway = pathway[[ii]],
             disease_type = disease.type.total.vec[[ii]],
             disease_type1 = disease.type1.total.vec[[ii]],
             disease_type2 = disease.type2.total.vec[[ii]],
             disease_type3 = disease.type3.total.vec[[ii]])
    
    PIF.df2[[ii]] <- cbind(id, PIF.df[[ii]])
    
  }
  
  # We now bind all the elements for each list together so we have one giant 
  # file with all disease-pathways in one file, by looping through each element 
  # of disease.df2 / PIF.df2 and concatenating to alldisease / allPIF.
  
  alldisease <- disease.df2[[1]]
  allPIF <- PIF.df2[[1]]
  
  # jj=2
  
  for(jj in 2:num.diseases) {
    
    alldisease <- rbind(alldisease, disease.df2[[jj]])
    
    allPIF <- rbind(allPIF, PIF.df2[[jj]])
    
  }
  
  alldisease$riskfactor = rfvec_cra[r]
  
  allPIF$riskfactor = rfvec_cra[r]
  
  alldisease <- as.data.frame(alldisease)
  
  # "n" is the number disease/pathways. Used later when summarizing results 
  # but defined here
  n <- dim(alldisease)[1] / (n.mediated.effects + 1)
  
  # One last thing before we close the r-loop. Store the data frame alldisease 
  # (attributable mortality/incidence sims for all subgroups and disease/pathways 
  # for riskfactor r) and allPIF (PIF sims for all subgroups and disease/pathways 
  # for riskfactor r) as element r in lists "disease.list" and "PIFs" respectively. 
  # So we'll have all relevant output results housed in these two objects (as 
  # opposed to scattered r objects, or r*n objects, etc..). Useful because it 
  # will make code for later tasks easier to read and write.
  
  disease.list[[r]] <- alldisease
  PIFs[[r]] <- allPIF
  
} # End the r-loop.

# Bind all the data frames in "disease.list" and "PIFs" into one data frame (in a 
# cringy old-fashioned way, but it works). Also, update some column names for 
# clarity.

all.diseasedraws <- disease.list[[1]]
all.PIFs <- PIFs[[1]]

# f=1

# FYI - the way this for-loop is written means that we must include a minimum of 2 dietary 
# factors when running the CRA 
for(f in 2:length(rfvec_cra)) {
  
  all.diseasedraws <- rbind(all.diseasedraws, disease.list[[f]])
  all.PIFs <- rbind(all.PIFs, PIFs[[f]])
  
}

names(all.diseasedraws)[(1 + length(covar.vec)):(6 + length(covar.vec))] <- 
  c("mean (food)", "se (food)", "sd (food)", "mean (food, counterfactual)", 
    "se (food, counterfactual)", "sd (food, counterfactual)")

names(all.PIFs)[(1 + length(covar.vec)):(6 + length(covar.vec))] <- 
  c("mean (food)", "se (food)", "sd (food)", "mean (food, counterfactual)", 
    "se (food, counterfactual)", "sd (food, counterfactual)")

# Save the files into CSVs, and then delete them from R workspace 
# (since they are large).

# first create directories if they don't already exist
ifelse(!dir.exists(file.path(output_location)),
       dir.create(file.path(output_location)),
       "Directory Exists")

ifelse(!dir.exists(file.path(paste0(output_location, diet_pattern))),
       dir.create(file.path(paste0(output_location, diet_pattern))),
       "Directory Exists")

write.csv(x = all.diseasedraws, 
          file = paste(output_location, diet_pattern, "/all.disease.draws_", 
                     year.vec.string, "_", covar.vec.string, "_", diet_pattern, 
                     ".csv", sep = ""), row.names = FALSE)

write.csv(x = all.PIFs, 
          file = paste(output_location, diet_pattern, "/all.PIFs_", 
                     year.vec.string, "_", covar.vec.string, "_", diet_pattern, 
                     ".csv", sep = ""), row.names = FALSE)

rm(all.diseasedraws, all.PIFs)

