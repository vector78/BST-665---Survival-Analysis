libname MI "K:\Devin.Class BST 621\BST 665 HW";

proc format;
	value GROUP 1 = "Normal BP/Afib No"
	            2 = "Normal BP/Afib Yes"
				3 = "High BP/Afib No"
				4 = "High BP/Afib Yes";
run;

data mi;
	set mi.mi;
	
	if BP = "Normal" and Afib = "No" then GROUP = 1;
	if BP = "Normal" and Afib = "Yes" then GROUP = 2;
	if BP = "High" and Afib = "No" then GROUP = 3;
	if BP = "High" and Afib = "Yes" then GROUP = 4;

	format GROUP group.;

run;

proc lifetest data=mi;
	time Days*MI(0) ;
	strata GROUP;
run;

data mi_group;
input Label $ BP $ AFib $;
datalines;
Norm/No Normal No
High/No High No
Norm/Yes Normal Yes
High/Yes High Yes
;

proc freq data=mi;
	table MI BP Afib; 
	format _all_;
run;

proc means data=mi min max;
	var days;
run;


proc phreg data=mi plot(overlay=stratum)=survival;
	class BP Afib(ref="No") /order=internal;
	model Days*MI(0)= BP Afib BP*Afib/ risklimits covb;
	baseline out=surv survival=S lower=LCL upper=UCL / rowid=Label;
	contrast 'High BP and Afib vs No BP and Afib' BP 1 0 Afib 1 0/estimate=parm;
run;

proc phreg data=mi plot(overlay=stratum)=survival;
	class BP(ref="Normal") Afib(ref="No") /order=internal;
	model Days*MI(0)= BP Afib/ risklimits covb;
	baseline covariates=mi_group out=surv survival=S lower=LCL upper=UCL / rowid=Label;
	contrast 'High BP and Afib vs No BP and Afib' BP 1 0 Afib 1 0/estimate=parm;
run;

proc phreg data=mi plot(overlay=stratum)=survival;
	class BP Afib(ref="No") /order=internal;
	model Days*MI(0)= BP Afib/ risklimits covb;
	baseline covariates=mi_group out=surv survival=S lower=LCL upper=UCL / rowid=Label;
	contrast 'BP and Afib' BP 1 Afib 1 /estimate=parm;
run;


Stages_3_and_4: test Stage3 = 0, Stage4 = 0 ;
contrast 'Stages 3 & 4' Stage 0 1 0, Stage 0 0 1 / test(all);

proc freq data=mi;
	table BP AFIB;
run;

proc phreg data=mi plot(overlay=stratum)=survival;
	class BP Afib(ref="No");
	model Days*MI(0)= BP Afib BMI BMI*Afib/ risklimits;
	hazardratio BMI/units=5;
	baseline out=surv survival=S lower=LCL upper=UCL / rowid=Label;
run;

data PLRT;
Full = 1531.255;
Reduced = 1640.165;
G = -Full + Reduced;
pvalue = 1-cdf('chisquare',G,1);
run;

proc print data=PLRT;
run;

