/* Use PROC POWER to calculate power. You may get slightly different estimates than using 
   Schoenfeld's method because SAS uses a different formula.  

   The default is even allocation and 5% significance level.   

   The curve("control") option tells SAS your estimates of the survival function for the 
   reference group. The syntax is (time points separated by spaces):(probabilities separated by 
   spaces). If you specify one time and one probability, SAS will use an exponential model to 
   estimate the rest of the survival curve. Otherwise, SAS will use a piecewise-linear model.  

   Set ntotal equal to missing to calculate the power for a particular design. */   
 
proc power;                                                                                                                             
  twosamplesurvival test=logrank                                                                                                        
    curve("control")  = (6 9 12):(0.81 0.64 0.51)                  
    refsurvival = "control"                                                                                                               
    hazardratio = 0.3                                                                                                                     
    accrualtime = 6                                                                                                                       
    followuptime = 6                                                                                                                      
    power = 0.8                                                                                                                           
    ntotal = .;                                                                                                                           
run;

/* Change the allocation ratio using the 'groupweights' option. */  

proc power;                                                                                                                             
  twosamplesurvival test=logrank                                                                                                        
    curve("control")  = 1:0.46                  
    refsurvival = "control"                                                                                                               
    hazardratio = 0.3                                                                                                                     
    accrualtime = 1                                                                                                                       
    followuptime = 3 
    groupweights = 2 | 1 
    power = .8                                                                                                                           
    ntotal = .;                                                                                                                           
run;

/* Determine how much power we would have with a study of 300 subjects allocated with 2 control 
   subjects for every treated subject. Set power equal to missing and use the 'groupweights' 
   option. */

proc power;                                                                                                                             
  twosamplesurvival test=logrank                                                                                                        
    curve("control")  = (6 9 12):(0.81 0.64 0.51)                  
    refsurvival = "control"                                                                                                               
    hazardratio = 0.3                                                                                                                     
    accrualtime = 6                                                                                                                       
    followuptime = 6 
    groupweights = 2 | 1 
    power = .                                                                                                                           
    ntotal = 300;                                                                                                                           
run;


/* Plot power against the hazard ratio to get a sense of how the power decreases as the hazard 
   ratio gets closer to 1. Use the PLOT statement. The syntax is 'plot x = []'. You can plot 
   x = effect, x = n, or x = power.     

   Specify a range of hazard ratios we want to consider by separating with spaces. (Could also 
   use '0.3 to 0.7 by 0.2'  */                                               

proc power;                                                                                                                             
  twosamplesurvival test=logrank                                                                                                        
    curve("control")  = (6 9 12):(0.81 0.64 0.51)                  
    refsurvival = "control"                                                                                                               
    hazardratio = 0.3 0.5 0.7                                                                                                                     
    accrualtime = 6                                                                                                                       
    followuptime = 6 
    groupweights = 2 | 1 
    power = .                                                                                                                           
    ntotal = 300;  
plot x = effect; 
run;

/* Compare the power for equal vs unequal allocation. Add a reference line to indicate
   80% power. */

proc power;                                                                                                                             
  twosamplesurvival test=logrank                                                                                                        
    curve("control")  = (6 9 12):(0.81 0.64 0.51)                  
    refsurvival = "control"                                                                                                               
    hazardratio = 0.3 0.5 0.7                                                                                                                     
    accrualtime = 6                                                                                                                       
    followuptime = 6 
    groupweights = 2 1 | 1 
    power = .                                                                                                                           
    ntotal = 300;  
plot x = effect yopts=(ref=0.8) vary(color); 
run;
