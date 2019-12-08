/* Example 1: Fit an Andersen-Gill model.  

   Use the 'covs(aggregate)' option in the PROC PHREG statement to request the robust 
   variance estimator (see p. 266-269 of Survival Analysis using SAS). You will also need 
   to include an ID statement to tell SAS which variable in the dataset contains the ID 
   number for each subject. */

proc contents data=BST665.Aches;
run;

proc phreg data=BST665.Aches covs(aggregate);
class Treatment(ref='Old');
model (Start,Stop)*Censor(0) = Age Treatment / risklimits covb;
id Participant;
run;


/* Example 2: Fit the Prentice-Williams-Peterson model.   

   Time scale 1: PWP counting process (PWP-CP) model. This model only differs from Andersen-
   Gill in that we will stratify by event number. */    

proc phreg data=BST665.Aches covs(aggregate);
strata Episode;
class Treatment(ref='Old');
model (Start,Stop)*Censor(0) = Age Treatment / risklimits;
id Participant;
run;


/* Time scale 2: PWP gap time (PWP-GT) model. In order to fit the PWP-GT model we need to 
   calculate the gap time, i.e. the time between events. */      

data AchesPWP;
set BST665.Aches;
GapTime = Stop - Start;
run;

proc phreg data=AchesPWP covs(aggregate);
strata Episode;
class Treatment(ref='Old');
model GapTime*Censor(0) = Age Treatment / risklimits;
id Participant;
run; 


/* Example 3: Fit the Wei-Lin-Weissfeld model.     

   In order to fit this model, we need to add rows to the dataset for any subjects who had 
   less than four events.  */                          

data AchesWLW (drop=i );
set BST665.Aches;
by Participant;
output;
if last.Participant = 1 and Episode < 4 then do;
    do i=1 to (4-Episode);
      Episode = Episode+1;
      Censor = 0;
      output;
    end;
end;
run;

proc phreg data=AchesWLW covs(aggregate);
strata Episode;
class Treatment(ref='Old');
model Stop*Censor(0) = Age Treatment / risklimits;
id Participant;
run;


/* Example 4: Using the PWP-CP model, test whether the treatment effect is constant across 
   episodes. */

proc phreg data=BST665.Aches covs(aggregate);
strata Episode;
class Treatment(ref='Old') Episode(ref='1');
model (Start,Stop)*Censor(0) = Age Treatment Treatment*Episode/ risklimits;
id Participant;
hazardratio Treatment;
contrast 'Test for Treatment Effect for 1st Episode' 
                     treatment 1 treatment*episode 0 0 0 / e;
contrast 'Test for Treatment Effect for 2nd Episode' 
                     treatment 1 treatment*episode 1 0 0 / e;
contrast 'Test for Treatment Effect for 3rd Episode' 
                     treatment 1 treatment*episode 0 1 0 / e;
contrast 'Test for Treatment Effect for 4th Episode' 
                     treatment 1 treatment*episode 0 0 1 / e;
run;


/* Example 5A: Fit the PWP counting process (PWP-CP) model to tumor recurrence data in 
   bladder cancer patients. */

proc contents data=BST665.Bladder;
run;

proc phreg data=BST665.Bladder covs(aggregate);
strata Visit;
class Treatment(ref='Placebo');
model (Start,Stop)*Status(0) = Treatment Baseline_Count / risklimits;
id Participant;
run; 

/* Example 5B: Using the PWP-CP model, test whether the predictive value of the baseline
   tumor count changes with recurrences. */

proc phreg data=BST665.Bladder covs(aggregate);
strata Visit;
class Treatment(ref='Placebo') Visit(ref="1");
model (Start,Stop)*Status(0) = Treatment Baseline_Count Baseline_Count*Visit/ risklimits;
id Participant;
run; 


