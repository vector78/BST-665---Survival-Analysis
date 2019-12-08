libname bm "K:\Devin.Class BST 621\BST 665\HW3";

data bm;
	set bm.bone_marrow;
run;

proc freq data=bm;
	table center;
run;


    *intial KM to determin shape and create datasets for figures;
    proc lifetest data=bm notable 
        plots=(survival(cl test nocensor atrisk outside maxlen=20) ls h lls) alpha=0.3 outsurv=km_data_pp;       
        time Months*Died(0);
		strata CENTER;
    run;

	proc sort data=bm;
		by center;
	run;

proc phreg data=bm plots=cumhaz ;
class Center;

model Months*Died(0)= Center / risklimits;
output out=loghaz xbeta=xb;
*assess ph / resample seed=234;
ods output CumHazPlot=CHPlot;

run;

data logCumHaz;
set CHPlot;
*if cumHaz=0 then logCumHaz=.;
else logCumHaz= log(cumHaz);
label logCumHaz = "log(cumulative hazard)";
run;

title "log(cumulative hazard)";
proc sgplot data=logCumHaz;
step y=logCumHaz x=time/group=center;
run;

proc sort data=loghaz;
by Center Group;
run;

proc gplot data=loghaz;
plot xb*center=group;
symbol interpol=join;
run;
quit;

proc phreg data=bm;
class Center;
model Months*Died(0)= Center / risklimits;
output out=resid ressch = schage wtressch=sschage ;
run;

proc sort data=resid;
	by center;
run;

proc gplot data=resid;
title;
   plot  sschage*months /vref=0;
   symbol1 value=dot h=.5 interpol=sm75s ;
   by center;
run; quit;

data schoen;
set resid;
months_sq = months**2;
logmonths = log(months);
run;

proc corr data=schoen;
var schage sschage;
with months months_sq logmonths; 
run;


proc phreg data=bm;
strata Center;
class Center sex group(ref='ALL');
model Months*Died(0)= age sex group/ risklimits covb;
run;

proc phreg data=bm;
strata Center;
class Center sex group;
model Months*Died(0)= age sex group center*group/ risklimits;
run;

proc freq data=bm;
	table group;
run;

proc phreg data=bm;
strata Center;
class Center sex group(ref='ALL');
model Months*Died(0)= age sex group/ risklimits covb;
contrast 'AML High vs AML Low' Group 1 -1/ estimate=parm;
contrast 'AML High vs ALL' Group 1 0/ estimate=parm;
contrast 'AML Low vs ALL' Group 0 1/ estimate=parm;
*contrast 'High Risk vs Low Risk' Group / estimate=parm;
run;


proc phreg data=bm;
strata Center;
class Center sex group(ref='ALL');
model Months*Died(0)= age sex group center*group/ risklimits covb;
contrast 'AML High vs AML Low' Group 1 -1/ estimate=parm;
contrast 'AML High vs ALL' Group 1 0/ estimate=parm;
contrast 'AML Low vs ALL' Group 0 1/ estimate=parm;
*contrast 'High Risk vs Low Risk' Group / estimate=parm;
run;



proc corr data=bm;
	
proc lifetest data=bm;
	time MONTHS*DIED(0);
	strata CENTER GROUP;
run;

*Prepare for KMs comparing subgroups;
data test;
input Label $ Center $ Group $10-25;
datalines;
1 Alferd ALL
2 Alferd AML Low Risk
3 Alferd AML High Risk
;

proc phreg data=bm plot(overlay=stratum)=survival;
strata Center;
class Center sex group(ref='ALL');
model Months*Died(0)= group group*center/ risklimits;
contrast 'AML High vs AML Low' Group 1 -1/ estimate=parm;
contrast 'AML High vs ALL' Group 1 0/ estimate=parm;
contrast 'AML Low vs ALL' Group 0 1/ estimate=parm;
baseline covariates=test out=surv survival=S lower=LCL upper=UCL / rowid=Label;
*contrast 'High Risk vs Low Risk' Group / estimate=parm;
run;

proc phreg data=bm;
class Recovery group;
model Months*Died(0)= Recovery group /risklimits;
run;

proc phreg data=bm;
class Recovery group;
model Months*Died(0)= Recovery group group*recovery/ risklimits;
contrast 'High Risk Recovery No' Group 1 0, Recovery 1, Group*recovery 1 0 1/ estimate=parm;
contrast 'ALL Recovery No' Group 0 1, Recovery 1,Group*recovery 0 1 0/estimate=parm;
contrast 'Low Risk Recovery No' Group 0 0, Recovery 1,Group*recovery 0 0 1/estimate=parm;
run;

proc sort data=bm;
	by ID;
run;

data bm2;
set bm;
by ID;

*If the time is missing;
if RECOVERY_TIME  = . then do; 
	*We do not want zero length intervals;
	if MONTHS = 0 then months = .00001;
    START = 0; 
	STOP = MONTHS; 

	*Did not recover if they have this missing;
   	RECOVERY_STATUS = 0; 

	*Censor variable stays the same;
	CENSOR = DIED; 
	output; 
end;

*They did have a recovery time but we have to make sure they are counted as not recovery before the recovery time;
if RECOVERY_TIME ne . then do; 
	
	*Do not want zero-length intervals;
	if RECOVERY_TIME = 0 then RECOVERY_TIME = .00001; 

	*Ensure to set all those that had the event before their recovery time to zero;
	if MONTHS < RECOVERY_TIME then MONTHS = RECOVERY_TIME + .00001;
	   	START = 0; 
		STOP = RECOVERY_TIME; 
		RECOVERY_STATUS = 0; 
		CENSOR = 0; 
output; 
	
	*The rest means the event occured so the start time will be when the recovery time ocurs until censor;
	START = RECOVERY_TIME; 
	STOP = MONTHS; 
   	RECOVERY_STATUS = 1; 
	CENSOR = DIED; 
output; 
end;

label RECOVERY_STATUS = "Recovery Status";
run;

proc phreg data=bm2;
class GROUP(ref='ALL');
model (START,STOP)*CENSOR(0) = RECOVERY_STATUS GROUP;
run;

proc phreg data=bm2;
class GROUP(ref='ALL');
model (START,STOP)*CENSOR(0) = RECOVERY_STATUS GROUP RECOVERY_STATUS*GROUP;
contrast "Low AML with Platelet Recovery" Group 0 1 RECOVERY_STATUS 1 GROUP*RECOVERY_STATUS 0 1 1/ estimate=parm;
contrast "High AML with Platelet Recovery" Group 1 0 RECOVERY_STATUS 1 GROUP*RECOVERY_STATUS 1 0 1/ estimate=parm;
contrast "ALL with Platelet Recovery" Group 0 0 RECOVERY_STATUS 1 GROUP*RECOVERY_STATUS 0 0 1/ estimate=parm;
run;

proc phreg data=bm2;
class GROUP(ref='ALL');
model (START,STOP)*CENSOR(0) = RECOVERY_STATUS GROUP RECOVERY_STATUS*GROUP /covb;
contrast "High AML vs Low AML with No Platelet Recovery" Group 1 -1 RECOVERY_STATUS 0 GROUP*RECOVERY_STATUS 1 - 1 0/ estimate=parm;
run;

proc freq data=bm2;
	table RECOVERY_STATUS;
run;

proc phreg data=bm;
class GROUP;
model MONTHS*DIED(0) = RECOVERY_STATUS GROUP;
RECOVERY_STATUS=0;
if MONTHS > RECOVERY_TIME and RECOVERY_TIME ne . then RECOVERY_STATUS =1;
run;

proc phreg data=bm;
class GROUP recovery;
model MONTHS*DIED(0) = RECOVERY GROUP;
RECOVERY="No";
if MONTHS > RECOVERY_TIME and RECOVERY_TIME ne . then RECOVERY ="Yes";
run;

proc phreg data=bm2;
class GROUP;
model (START,STOP)*CENSOR(0) = RECOVERY_STATUS GROUP RECOVERY_STATUS*GROUP;
baseline out=surv;
contrast "Testing" group 1 RECOVERY_STATUS 1 group*RECOVERY_STATUS 1 1/estimate=parm;
run;

proc phreg data=bm;
class Recovery group;
model Months*Died(0)= Recovery group /risklimits;
run;
