/* Exercise 1 */

data IUD;
input Weeks AE;
datalines;
 10 1
 13 0
 18 0
 19 1
 23 0
 30 1
 36 1
 38 0
 54 0
 56 0
 59 1
 75 1
 93 1
 97 1
104 0
107 1
107 1
107 0
run;

proc lifetest data=IUD;
time Weeks*AE(0);
run;


/* Exercise 3 */

proc contents data=bst665.Rats;
run;

proc lifetest data=bst665.Rats;
strata Stress;
time Weeks*Tumor(0);
run;

