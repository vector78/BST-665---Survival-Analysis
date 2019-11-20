/* Example 1: Time to rearrest following parole. Want to test whether the risk of 
   rearrest is higher for younger parolees. */       

libname bst665 "K:\Devin.Class BST 621\BST 665";

proc contents data=bst665.rearrest;
run;

/* Use PROC PHReg to fit the Cox proportional hazards model (see p. 125 - 136 of Survival
   Analysis using SAS). The MODEL statement uses time_variable*censor_variable() as in the 
   TIME statement of PROC LIFETEST. With PROC PHREG, we can now estimate the effects of 
   covariates. */

proc phreg data=bst665.rearrest;
   model Weeks*Arrest(0)= Age;
run;

/* Use the 'risklimits' option to get confidence intervals for the hazard ratio. */ 

proc phreg data=bst665.rearrest;
   model Weeks*Arrest(0)= Age / risklimits;
run;




/* Example 2: Consider the effect of both age and number of priors on risk of rearrest.
   Can use the partial likelihood ratio test to determine whether the model is 
   statistically significant. That is, test the global null hypothesis H0: Beta = 0, where 
   Beta = (Beta_Age, Beta_Priors). */                    
 
proc phreg data=bst665.rearrest;
    model Weeks*Arrest(0)= Age Priors / risklimits;
run;




/* Example 3: Test whether age is still significantly related to risk of rearrest once number 
   of priors has been accounted for. That is, the the null hypothesis H0: Beta_Age = 0. */                                                                                 ;


/* Example 3A: Use the Wald test to test an individual covariates separately.

   Use a TEST statement or the standard SAS output. */                                                                       

proc phreg data=bst665.rearrest;
    model Weeks*Arrest(0)= Age Priors / risklimits;
    Age: test Age = 0;
run;


/* Example 3B: Use the partial likelihood ratio test to answer the same question as above. 

   Need the log-likelihood of both the full model (accounts for both age and number of priors) 
   and the reduced model (accounts only for number of priors). */

proc phreg data=bst665.rearrest;
    model Weeks*Arrest(0)= Priors / risklimits;
run;

/* Compare the test statistic, G, to a Chi-square distribution. */

data PLRT;
Full = 1325.826;
Reduced = 1339.423;
G = -Full + Reduced;
pvalue = 1-cdf('chisquare',G,1);
run;

proc print data=PLRT;
run;




/* Example 4: Is the number of prior arrests a significant predictor of rearrest, after
   accounting for age, financial aid, marital status, and race? */                     

proc format;
value aid 0="No Aid" 1="Aid";
value married 0="Unmarried" 1 = "Married";
value race 0="Caucasian" 1="African-American";
run;

/* Categorical covariates should be specified in a class statement. 

   Use the 'covb' option to display the estimated covariance matrix for beta. */

proc phreg data=bst665.rearrest;
class PriorGroup(ref="0") Aid Married Race;
model Weeks*Arrest(0)= Age PriorGroup Aid Married Race/ risklimits covb;
format Aid aid. Race race. Married married.;
run;
 
/* Can also use a TEST statement to test this hypothesis. 

   Note that for categorical covariates, you refer to the coefficients by appending the variable 
   value to the variable name (see p. 193 of Survival Analysis using SAS). If the variable values 
   include symbols (+ and -), SAS may replace them with another character. */

proc phreg data=bst665.rearrest;
class PriorGroup(ref="0") Aid Married Race;
model Weeks*Arrest(0)= Age PriorGroup Aid Married Race/ risklimits;
format Aid aid. Race race. Married married.;
Priors: test PriorGroup1N2 = 0, PriorGroup3P = 0;
run;

proc freq data=bst665.rearrest;
	table PriorGroup;
run;


/* Example 5: Use the rearrest data set to compare estimation using varying methods of  
   handling ties. */                                   


/* Example 5A: Breslow's approximation. 

   SAS's default is to use Breslow's approximation to handle ties. You can also use the
   'ties=Breslow' option (see p. 142-153 of Survival Analysis using SAS).*/

proc phreg data=bst665.rearrest;
model weeks*arrest(0) = age priors / risklimits;
run;


/* Example 5B: Efron's approximation. 

   Change the 'ties=Efron' option to use Efron's approximation  */                                       

proc phreg data=bst665.rearrest;
model weeks*arrest(0) = age priors / risklimits ties=Efron;
run;


/* Example 5C: Exact partial likelihood. 

   Use the 'ties=Exact' option to use the exact partial likelihood. */

proc phreg data=bst665.rearrest;
model weeks*arrest(0) = age priors / risklimits ties=exact;
run;




/* Example 6: Compare estimation with the three ties methods using a smaller 
   data set.  */                                                             

proc contents data=bst665.leukemia;
run;


/* Example 6A: Breslow's approximation. */

proc phreg data=bst665.leukemia;
class Treatment Gender;
model Weeks*Relapse(0)= Treatment LogWBC Gender / risklimits ties=Breslow;
run;


/* Example 6B: Efron's approximation. */

proc phreg data=bst665.leukemia;
class Treatment Gender;
model Weeks*Relapse(0)= Treatment LogWBC Gender / risklimits ties=Efron;
run;


/* Example 6C: Exact partial likelihood. */

proc phreg data=bst665.leukemia;
class Treatment Gender;
model Weeks*Relapse(0)= Treatment LogWBC Gender / risklimits ties=Exact;
run;




/* Example 7: Estimate the baseline survival curve using the BASELINE statement (see 
   p. 186-192 of Survival Analysis using SAS).                                    

   Include the 'plot=survival' option to plot the survival curve. The 'out=' option 
   will save the estimated survival function. */         

proc phreg data=bst665.leukemia plot=survival;
class Treatment Gender;
model Weeks*Relapse(0)= Treatment Gender / risklimits;
baseline out=basesurv survival=S0 lower=LCL upper=UCL;
run;

proc print data=basesurv;
run;


proc freq data=bst665.leukemia ;
	table Treatment Gender;
run;

/* Example 8: Examine how survival curves vary by treatment assignment and gender.    

   By default, SAS will set value of covariates at the mean (for continuous variables)  
   or at the reference level (for categorical). To choose covariates yourself, create 
   a new data set. */                                                          
 
data subgroup;
input Label $1-10 Treatment $ Gender $;
datalines;
New/Female New Female
New/Male   New Male
Old/Female Old Female
Old/Male   Old Male
run;

/* Use the 'covariates=' option to specify the data set with the covariate values.

   Include the 'plot(overlay=stratum)=survival' option to plot the survival curves on the
   same graph. */         

proc phreg data=bst665.leukemia plot(overlay=stratum)=survival;
class Treatment Gender;
model Weeks*Relapse(0)= Treatment Gender / risklimits;
baseline covariates=subgroup out=surv survival=S lower=LCL upper=UCL / rowid=label;
run;

/* Can also use PROC GPLOT to plot the survival curves. */

proc gplot data=surv;
   plot S*Weeks=Label;
   symbol interpol=steplj;
run; quit;




/* Example 9: Examine how survival curves vary by treatment assignment, gender, and WBC. */    

data subgroup;
input Label $1-21 Treatment $ Gender $ LogWBC;
datalines;
New/Female/LogWBC=3   New Female 3
New/Male/LogWBC=3     New Male   3
Old/Female/LogWBC=3.2 Old Female 3.2
Old/Male/LogWBC=3.2   Old Male   3.2
run;

proc phreg data=bst665.leukemia plot(overlay=stratum)=survival;
class Treatment Gender;
model Weeks*Relapse(0)= Treatment Gender LogWBC / risklimits;
baseline covariates=subgroup out=surv survival=S lower=LCL upper=UCL / rowid=Label;
run;

proc phreg data=bst665.leukemia plot(overlay=group)=survival;
class Treatment Gender;
model Weeks*Relapse(0)= Treatment Gender LogWBC / risklimits;
baseline covariates=subgroup out=surv survival=S lower=LCL upper=UCL / group=LogWBC rowid=Label;
run;
