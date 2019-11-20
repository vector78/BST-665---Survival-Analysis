libname r "K:\Devin.Class BST 621\homework4";

data dialysis;
	set r.dialysis;
run;

data renal;
	set r.renal;
run;

proc freq data=dialysis;
	table Diabetes method ;
run;

proc phreg data=dialysis covs(aggregate);
class Diabetes(ref='No') method(ref='Catheter') ;
model (Start,End)*Censor(0) = Diabetes method / risklimits;
id ID;
run;

data dialysis;
set dialysis;
GapTime = End - Start;
run;

proc phreg data=dialysis covs(aggregate);
class Diabetes(ref='No') method(ref='Catheter') ;
model GapTime*Censor(0) = Diabetes method / risklimits;
id ID;
run;

proc power;                                                                                                                             
  twosamplesurvival test=logrank                                                                                                        
    curve("New Drug")  = 1:0.70               
    refsurvival = "New Drug"                                                                                                               
    hazardratio = 0.7                                                                                                                     
    accrualtime = 4
    followuptime = 6                                                                                                                      
    power = 0.9
	alpha=0.05
    ntotal = .;                                                                                                                           
run;
