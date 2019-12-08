/* Example 1: Interpret a dichotomous covariate. Interpret the effect of margin on risk of 
   death following surgery in ovarian cancer patients. */

libname BST665 "K:\Devin.Class BST 621\BST 665";

proc contents data=BST665.Ovarian;
run;

proc phreg data=BST665.Ovarian;
class Margins (ref='Negative');
model Months*Died(0) = Margins / risklimits;
run;

proc phreg data=BST665.Ovarian;
class Margins (ref='Positive');
model Months*Died(0) = Margins / risklimits;
run;

/* Example 2A: Compare levels of a categorical covariate. Calculate a 95% confidence 
   interval to compare the effect of Stage 3 to Stage 4. */

proc phreg data=BST665.Ovarian;
class Stage (ref="1") ;
model Months*Died(0)= Stage / risklimits covb;
run;

/* Use the HAZARDRATIO statement to request custom hazard ratios (see p. 195-197 of Survival
   Analysis using SAS).                     

   Estimate hazard ratios for all six possible pairwise comparisons of cancer stage. */

proc phreg data=BST665.Ovarian;
class Stage (ref="1") ;
model Months*Died(0)= Stage / risklimits covb;
hazardratio Stage;
run;


/* Example 2B: Use linear contrasts to test whether the effects of Stage 3 and Stage 4 
   significantly differ.                              

   Use the TEST statement to test H0: beta_3 = beta_4 or the CONTRAST statement (p. 192-194)
   to test H0: 0*beta_2 - 1*beta_3 + 1*beta_4 = 0. */                                                 

proc phreg data=BST665.Ovarian;
class Stage (ref="1") ;
model Months*Died(0)= Stage / risklimits covb;
Stage3_vs_Stage4: test Stage3 = Stage4;
contrast 'Stage3 vs Stage4' Stage 0 1 -1 / estimate=parm;
run;


/* Example 3: Test whether the average effect of Stages 1 and 2 is equivalent to the average
   effect of Stages 3 and 4. */          

data subgroup;
input Stage;
datalines;
1
2
3
4
run;

proc phreg data=BST665.Ovarian plot(overlay)=survival;
class Stage (ref="1") ;
model Months*Died(0)= Stage / risklimits covb;
Stage2_vs_Stages3and4: test Stage2 - Stage3 - Stage4 = 0;
contrast 'Stage2 vs Stages3and4' Stage 1 -1 -1 / estimate=parm;
baseline covariates=subgroup ;
run;


/* Example 4: Test the effects of Stage 3 and Stage 4. 

   The TEST and CONTRAST statements can be used to test multiple hypotheses 
   simultaneously. Use a comma to separate hypotheses (in the TEST statement) or rows 
   of the contrast matrix (in the CONTRAST statement). */

proc phreg data=BST665.Ovarian;
class Stage (ref="1") ;
model Months*Died(0)= Stage / risklimits;
Stages_3_and_4: test Stage3 = 0, Stage4 = 0 ;
contrast 'Stages 3 & 4' Stage 0 1 0, Stage 0 0 1 / test(all);
run;


/* Example 5: Interpret a continuous covariate. Estimate and interpret the effect of age on 
   risk of death following surgery in ovarian cancer patients. */                            

proc contents data=BST665.Ovarian;
run;

proc phreg data=BST665.Ovarian;
model Months*Died(0)= Age / risklimits; 
run;

/* For custom hazard ratios for a continuous covariate, need to specify the increase in units.
   Use the 'units=' option in the HAZARDRATIO statement. */                                

proc phreg data=BST665.Ovarian;
model Months*Died(0)= Age / risklimits; 
hazardratio age / units=10;
run;



/* Example 6: Determine whether cancer stage is a confounder of the effect of age. Fit models
   with and without stage and compare the estimates for the effect of age. */              

proc phreg data=BST665.Ovarian;
model Months*Died(0)= Age / risklimits; 
run;

proc phreg data=BST665.Ovarian;
class stage;
model Months*Died(0)= Age Stage / risklimits; 
run;



/* Example 7: Fit a model with an interaction between two categorical covariates. */

proc phreg data=BST665.Leukemia;
class Treatment Gender;
model Weeks*Relapse(0)= Treatment Gender Treatment*Gender / risklimits;
run;

proc phreg data=BST665.Leukemia;
class Treatment Gender;
model Weeks*Relapse(0)= Treatment Gender Treatment*Gender / risklimits;
hazardratio 'HR for Treatment' Treatment;
hazardratio 'HR for Gender' Gender;
run;

proc phreg data=BST665.Leukemia;
class Treatment Gender;
model Weeks*Relapse(0)= Treatment|Gender / risklimits;
run;



/* Example 8: Fit a model with an interaction between stage (four levels) and margins (two 
   levels). */

proc phreg data=BST665.Ovarian;
class Margins(ref='Negative') Stage(ref='1');
model Months*Died(0) = Stage|Margins / risklimits;
run;

/* Test the interaction effect using the partial likelihood ratio test. */

proc phreg data=BST665.Ovarian;
class Margins(ref='Negative') Stage(ref='1');
model Months*Died(0) = Stage Margins / risklimits;
run;

data PLRT;
Full = 545.238; * -2*log(partial likelihood of full model);
Reduced = 553.341; * -2*log(partial likelihood of reduced model);
DF = 3; * degrees of freedom;
G = -Full + Reduced;
pvalue = 1-cdf('chisquare',G,DF);
run;

proc print data=PLRT;
run;

/* Test the interaction effect using a linear contrast. */

proc phreg data=BST665.Ovarian;
class Margins(ref='Negative') Stage(ref='1');
model Months*Died(0) = Stage|Margins / risklimits;
contrast "Interaction" Stage*Margins 1 0 0 , Stage*Margins 0 1 0 , Stage*Margins 0 0 1  / E test(all);
Interaction: test MarginsPositiveStage2 = MarginsPositiveStage3 = MarginsPositiveStage4 = 0;
run;

ods rtf file="out2.rtf";



/* Example 9: Fit a model with an interaction between continuous (log WBC) and categorical 
   (gender) variables. */

proc phreg data=BST665.Leukemia;
class Gender(ref="Male");
model Weeks*Relapse(0)= LogWBC Gender Gender*LogWBC / risklimits;
output out=loghaz xbeta=xb;
hazardratio 'HR for Gender at LogWBC = 3' Gender / at(LogWBC=3);
hazardratio 'HR for Gender at Mean LogWBC' Gender  ;
run;

/* To better visualize the interaction effect, plot the log hazard against log WBC by 
   gender. Use the 'xbeta' option in an OUTPUT statement to save the estimate of beta*x 
   for each subject in the data set.                                            

   Plot the log hazard against log WBC by gender. */        

proc sort data=loghaz;
by gender logwbc;
run;

proc gplot data=loghaz;
plot xb*logwbc=gender;
symbol interpol=join;
run;
quit;

/* Can also plot the hazard ratio (not on the log scale) and its confidence interval
   to visualize the interaction effect. */

ods exclude all;
proc phreg data=BST665.Leukemia;
class Gender(ref="Male");
model Weeks*Relapse(0)= LogWBC Gender Gender*LogWBC / risklimits;
output out=loghaz xbeta=xb;
hazardratio Gender / at(LogWBC=1.5 to 4.5 by .1); /* Use values for log WBC seen in both
                                                    men and women. */
ods output hazardratios = hr;
run;
ods select all;

data hr (drop = description);
set hr;
LogWBC = 1*scan(description,2,"=");
run;

goptions reset=all;

symbol1 ci=red interpol=join; /* Line definition for HR */
symbol2 ci=red interpol=join line=3; /* Line definition for confidence intervals */

/* Use a logarithmic scale to make the plot easier to interpret. */
axis1 label=("Hazard Ratio") logbase=e logstyle=power 
   order=(-2.08 -1.39 -0.69 0 0.69 1.39 2.08) 
   value=("0.125" "0.25" "0.5" "1" "2" "4" "8")  minor=none;

proc gplot data=hr;
plot hazardratio*logwbc (waldlower waldupper)*logwbc=2 / overlay vaxis=axis1 vref=0 lvref=2;
run;
quit;

goptions reset=all;



/* Example 10: Fit a model with an interaction between continuous (age) and categorical 
   (margins) variables. */

proc phreg data=BST665.Ovarian;
class Margins(ref='Negative') ;
model Months*Died(0) = Age Margins Age*Margins  / risklimits;
hazardratio "HR for Margins at Age = 70" Margins / at(Age=70);
hazardratio "HR for Margins at Age = 60" Margins / at(Age=60);
hazardratio "HR for Margins at Mean Age" Margins ;
run;


/* To better visualize the interaction effect, plot the log hazard against age. */                                                                          ;

proc phreg data=BST665.Ovarian;
class Margins(ref='Negative') ;
model Months*Died(0) = Age Margins Age*Margins  / risklimits;
output out=loghaz xbeta=xb;
run;

proc sort data=loghaz;
by margins age;
run;

proc gplot data=loghaz;
plot xb*Age=Margins;
symbol interpol=join;
run; quit;


/* Plot the hazard ratio against age. */

ods exclude all;
proc phreg data=BST665.Ovarian;
class Margins(ref='Negative') ;
model Months*Died(0) = Age Margins Age*Margins  / risklimits;
hazardratio Margins / at(Age=53 to 84 by 1);
ods output hazardratios = hr;
run;
ods select all;

data hr (drop = description);
set hr;
Age = 1*scan(description,2,"=");
run;

goptions reset=all;

symbol1 ci=blue interpol=join;
symbol2 ci=blue interpol=join line=3;

axis1 label=("Hazard Ratio") logbase=e logstyle=power 
   order=(-2.08 -1.39 -0.69 0 0.69 1.39 2.08) 
   value=("0.125" "0.25" "0.5" "1" "2" "4" "8")  minor=none;

proc gplot data=hr;
plot hazardratio*age (waldlower waldupper)*age=2 / overlay vaxis=axis1 vref=0 lvref=2;
run;
quit;

goptions reset=all;
ods rtf close;
