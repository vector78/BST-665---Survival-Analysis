libname km "C:\Users\vector78\Documents\spring_2019_classes\BST 665";

PROC IMPORT OUT= WORK.iud
            DATAFILE= "C:\Users\vector78\Documents\spring_2019_classes\BST 665\km.xlsx" 
            DBMS=EXCEL REPLACE;
      RANGE="Sheet1$"; 
     GETNAMES=YES;
     MIXED=NO;
     SCANTEXT=YES;
     USEDATE=YES;
     SCANTIME=YES;
RUN;

proc lifetest data=iud;
	time TIME*REMOVAL(0);
run;


	data st;
		do t = 1 to 50;
   		cdf=(t**3)/((t**3)+1);
		survivorship = 1-cdf;
		hazard=-log(survivorship);
   	output;
end;
run;

proc plot data=st;
   plot cdf*t;
   plot survivorship*t;
   plot hazard*t;
run;

proc sgplot data=st noautolegend;
   x cdf;
run;

proc print data=st noobs;
run;

data rats;
	set km.rats;
run;

data km.st;
	set st;
run;

proc lifetest data=rats;
	strata STRESS;
	time WEEKS*TUMOR(0);
run;

proc lifetest data=rats;
	strata STRESS;
	time WEEKS*TUMOR(0);
	where STRESS in ("Low","Medium");
run;

proc lifetest data=rats;
	strata STRESS;
	time WEEKS*TUMOR(0);
	where STRESS in ("Low","High");
run;

proc lifetest data=rats;
	strata STRESS;
	time WEEKS*TUMOR(0);
	where STRESS in ("High","Medium");
run;

*Pairwise comparisons, low to medium p=0.04
*Low to high p=<0.0001
0.02;

options nosource;

/*Style Options*/
/*http://documentation.sas.com/?docsetId=grstatproc&docsetTarget=p1dt33l6a6epk6n1chtynsgsjgit.htm&docsetVersion=9.4&locale=en */

***************************************************************************************************
* MACROS STANDARDIZED REPORTING                                                                   *
**************************************************************************************************;
%put ----- LOADING MACRO: standard_km_calc_V2 -----;

/*Kaplan-Meier Curve Creation*/

*When calling the macro, specify FIG_NAME and change KM_TIME and KM_EVENT if needed. 
Adjust MAX_TIME to reflect the number of months/years to use for the analysis as needed.
TICK represents the interval points that can appear in the survival table (currently set at each year/month). 
   Minimum ticks are in one whole unit intervals;

*****************;
%macro standard_km_calc_V2(FIG_NAME,
            KM_TIME  = WEEKS,
            KM_EVENT = TUMOR,
			MAX_TIME = 30,
            EVENT    = Tumor Developement);
    ****
    FIG_NAME - must be less than X char
    KM_TIME  = INT_DPT,
    KM_EVENT = DEAD_PT,
    MAX_TIME - maximum number of months to project distinct months for at risk and survival calc 
    EVENT    = Deaths
	PVALFORM = pvalue6.4
    *;
	ods select none;

	proc sql noprint;
		select count(*)into :km_n from KM_&FIG_NAME._data;
	quit;

	%if &km_n ne 0 %then %do;
	ods select none;
	*determine how many groups (strata) are in the input dataset;
/*    proc sql noprint;*/
/*        select count(KM_STRATA_N) into : max_km_strata_n*/
/*            from KM_&FIG_NAME._data;*/
/*    quit;*/


    proc sql noprint;
        select count(KM_STRATA_N) into : max_km_strata_n
            from (select KM_STRATA_N, count(*) from KM_&FIG_NAME._data group by KM_STRATA_N);
    quit;




    * run life test routing output data to the specifed datasets;
    proc lifetest   data    = KM_&FIG_NAME._data             
        alpha   = 0.31731052
        outsurv = km_&FIG_NAME._est;
        time        &KM_TIME*&KM_EVENT(0);
        strata      KM_STRATA_N;
        ods output  ProductLimitEstimates = km_&FIG_NAME._ple
            CensoredSummary       = km_&FIG_NAME._cs
            %if &max_km_strata_n gt 1 %then %do;
        		homtests = km_&FIG_NAME._homtests
       	 	%end;
        ;
    run;

    *remove CI around steps that drop to zero;
    data km_&FIG_NAME._est;
        set km_&FIG_NAME._est;

        if SURVIVAL = 0 then
            do;
                SDF_LCL = 0;
                SDF_UCL = 0;
            end;
    run;

    *create an at risk table based on the desired tick marks and limited to data for each strata;
    data km_&FIG_NAME._atrisk;
        set km_&FIG_NAME._ple (keep=STRATUM KM_STRATA_N &KM_TIME);
        by KM_STRATA_N;

        if last.KM_STRATA_N then
            do;
                do &KM_TIME = 1 to min(&MAX_TIME,&KM_TIME+1) by 1;
                    output;
                end;
            end;
    run;

    *merge back in the number at risk at each event ocurance;
    data km_&FIG_NAME._ple_atrisk;
        merge km_&FIG_NAME._ple km_&FIG_NAME._atrisk;
        by STRATUM &KM_TIME;
    run;

    data km_&FIG_NAME._analysis_data (drop = i);
        merge km_&FIG_NAME._est km_&FIG_NAME._ple_atrisk(keep = STRATUM KM_STRATA_N &KM_TIME LEFT);
        by STRATUM &KM_TIME;
        retain SURV UCL LCL ATRISK;

        if first.STRATUM then
            do;
                SURV = .;
                UCL  = .;
                LCL  = .;
                ATRISK = .;
            end;

        if SURVIVAL ne . then
            SURV = SURVIVAL;

        if SDF_LCL ne . then
            LCL = SDF_LCL;

        if SDF_UCL ne . then
            UCL = SDF_UCL;

        if LEFT ne . then
            ATRISK = LEFT;
        KM_BAND_TIME = &KM_TIME;
        output;

        if last.STRATUM and &KM_TIME < &MAX_TIME then
            do;
                do i=&KM_TIME to &MAX_TIME+1 by 1;
                    &KM_TIME = .;
                    KM_BAND_TIME=i;
                    KM_FILL_TIME=i;
                    output;
                end;
            end;
    run;

    proc sort data=km_&FIG_NAME._analysis_data out=km_&FIG_NAME._analysis_data2;
        by KM_STRATA_N &KM_TIME;
    run;

    * requires m_&FIG_NAME._analysis_data;
    data km_&FIG_NAME._analysis_data2;
        set km_&FIG_NAME._analysis_data2;
        by KM_STRATA_N &KM_TIME;

        if first.&KM_TIME;
    run;

    * create formats using KM_STRATA_NAME and n and number of events;
    proc sort data=km_&FIG_NAME._data;
        by KM_STRATA_N;
    run;

    proc sort data=km_&FIG_NAME._cs;
        by KM_STRATA_N;
    run;

    data km_&FIG_NAME._cs_label (keep = FMTNAME START LABEL);
        length FMTNAME $20;
        merge km_&FIG_NAME._cs(where=(control_var = "")) km_&FIG_NAME._data(keep=KM_STRATA_N KM_STRATA_NAME);
        by KM_STRATA_N;

        if last.KM_STRATA_N;
        FMTNAME="KM_&FIG_NAME._FORMAT";
        START = KM_STRATA_N;
        LABEL = strip(KM_STRATA_NAME)||" (n = "||strip(TOTAL)||", &EVENT = "||strip(FAILED)||")";
        output;
        FMTNAME="KM_&FIG_NAME._FORMAT_SHORT";
        START = KM_STRATA_N;
        LABEL = strip(KM_STRATA_NAME);
        output;
    run;

    proc sort data=km_&FIG_NAME._cs_label;
        by FMTNAME START;
    run;

    proc format cntlin=km_&FIG_NAME._cs_label;
    run;

	ods select all;
	%end;
%mend;
/**/
/*%macro standard_km_calc_V2(FIG_NAME,*/
/*            KM_TIME  = INT_DPT,*/
/*            KM_EVENT = DEAD_PT,*/
/*			MAX_TIME = 200,*/
/*            EVENT    = Deaths);*/
/*    *****/
/*    FIG_NAME - must be less than X char*/
/*    KM_TIME  = INT_DPT,*/
/*    KM_EVENT = DEAD_PT,*/
/*    MAX_TIME - maximum number of months to project distinct months for at risk and survival calc */
/*    EVENT    = Deaths*/
/*    *;*/
/*	ods select none;*/
/**/
/*	proc sql noprint;*/
/*		select count(*)into :km_n from KM_&FIG_NAME._data;*/
/*	quit;*/
/**/
/*	%if &km_n ne 0 %then %do;*/
/*	ods select none;*/
/*	*determine how many groups (strata) are in the input dataset;*/
/*/*    proc sql noprint;*/*/
/*/*        select count(KM_STRATA_N) into : max_km_strata_n*/*/
/*/*            from KM_&FIG_NAME._data;*/*/
/*/*    quit;*/*/
/*    proc sql noprint;*/
/*        select count(KM_STRATA_N) into : max_km_strata_n*/
/*            from (select KM_STRATA_N, count(*) from KM_&FIG_NAME._data group by KM_STRATA_N);*/
/*    quit;*/
/**/
/**/
/**/
/**/
/*    * run life test routing output data to the specifed datasets;*/
/*    proc lifetest   data    = KM_&FIG_NAME._data             */
/*        alpha   = 0.31731052*/
/*        outsurv = km_&FIG_NAME._est;*/
/*        time        &KM_TIME*&KM_EVENT(0);*/
/*        strata      KM_STRATA_N;*/
/*        ods output  ProductLimitEstimates = km_&FIG_NAME._ple*/
/*            CensoredSummary       = km_&FIG_NAME._cs*/
/*            %if &max_km_strata_n gt 1 %then %do;*/
/*        		homtests = km_&FIG_NAME._homtests*/
/*       	 	%end;*/
/*        ;*/
/*    run;*/
/**/
/*    *remove CI around steps that drop to zero;*/
/*    data km_&FIG_NAME._est;*/
/*        set km_&FIG_NAME._est;*/
/**/
/*        if SURVIVAL = 0 then*/
/*            do;*/
/*                SDF_LCL = 0;*/
/*                SDF_UCL = 0;*/
/*            end;*/
/*    run;*/
/**/
/*    *create an at risk table based on the desired tick marks and limited to data for each strata;*/
/*    data km_&FIG_NAME._atrisk;*/
/*        set km_&FIG_NAME._ple (keep=STRATUM KM_STRATA_N &KM_TIME);*/
/*        by KM_STRATA_N;*/
/**/
/*        if last.KM_STRATA_N then*/
/*            do;*/
/*                do &KM_TIME = 1 to min(&MAX_TIME,&KM_TIME+1) by 1;*/
/*                    output;*/
/*                end;*/
/*            end;*/
/*    run;*/
/**/
/*    *merge back in the number at risk at each event ocurance;*/
/*    data km_&FIG_NAME._ple_atrisk;*/
/*        merge km_&FIG_NAME._ple km_&FIG_NAME._atrisk;*/
/*        by STRATUM &KM_TIME;*/
/*    run;*/
/**/
/*    data km_&FIG_NAME._analysis_data (drop = i);*/
/*        merge km_&FIG_NAME._est km_&FIG_NAME._ple_atrisk(keep = STRATUM KM_STRATA_N &KM_TIME LEFT);*/
/*        by STRATUM &KM_TIME;*/
/*        retain SURV UCL LCL ATRISK;*/
/**/
/*        if first.STRATUM then*/
/*            do;*/
/*                SURV = .;*/
/*                UCL  = .;*/
/*                LCL  = .;*/
/*                ATRISK = .;*/
/*            end;*/
/**/
/*        if SURVIVAL ne . then*/
/*            SURV = SURVIVAL;*/
/**/
/*        if SDF_LCL ne . then*/
/*            LCL = SDF_LCL;*/
/**/
/*        if SDF_UCL ne . then*/
/*            UCL = SDF_UCL;*/
/**/
/*        if LEFT ne . then*/
/*            ATRISK = LEFT;*/
/*        KM_BAND_TIME = &KM_TIME;*/
/*        output;*/
/**/
/*        if last.STRATUM and &KM_TIME < &MAX_TIME then*/
/*            do;*/
/*                do i=&KM_TIME to &MAX_TIME+1 by 1;*/
/*                    &KM_TIME = .;*/
/*                    KM_BAND_TIME=i;*/
/*                    KM_FILL_TIME=i;*/
/*                    output;*/
/*                end;*/
/*            end;*/
/*    run;*/
/**/
/*    proc sort data=km_&FIG_NAME._analysis_data out=km_&FIG_NAME._analysis_data2;*/
/*        by KM_STRATA_N &KM_TIME;*/
/*    run;*/
/**/
/*    * requires m_&FIG_NAME._analysis_data;*/
/*    data km_&FIG_NAME._analysis_data2;*/
/*        set km_&FIG_NAME._analysis_data2;*/
/*        by KM_STRATA_N &KM_TIME;*/
/**/
/*        if first.&KM_TIME;*/
/*    run;*/
/**/
/*    * create formats using KM_STRATA_NAME and n and number of events;*/
/*    proc sort data=km_&FIG_NAME._data;*/
/*        by KM_STRATA_N;*/
/*    run;*/
/**/
/*    proc sort data=km_&FIG_NAME._cs;*/
/*        by KM_STRATA_N;*/
/*    run;*/
/**/
/*    data km_&FIG_NAME._cs_label (keep = FMTNAME START LABEL);*/
/*        length FMTNAME $20;*/
/*        merge km_&FIG_NAME._cs(where=(control_var = "")) km_&FIG_NAME._data(keep=KM_STRATA_N KM_STRATA_NAME);*/
/*        by KM_STRATA_N;*/
/**/
/*        if last.KM_STRATA_N;*/
/*        FMTNAME="KM_&FIG_NAME._FORMAT";*/
/*        START = KM_STRATA_N;*/
/*        LABEL = strip(KM_STRATA_NAME)||" (n = "||strip(TOTAL)||", &EVENT = "||strip(FAILED)||")";*/
/*        output;*/
/*        FMTNAME="KM_&FIG_NAME._FORMAT_SHORT";*/
/*        START = KM_STRATA_N;*/
/*        LABEL = strip(KM_STRATA_NAME);*/
/*        output;*/
/*    run;*/
/**/
/*    proc sort data=km_&FIG_NAME._cs_label;*/
/*        by FMTNAME START;*/
/*    run;*/
/**/
/*    proc format cntlin=km_&FIG_NAME._cs_label;*/
/*    run;*/
/**/
/*	ods select all;*/
/*	%end;*/
/*%mend;*/

%put ----- LOADING MACRO: standard_km_plot_V2 -----;


*Plot K-M Curve (To remove at risk times set variable to -1);
%macro standard_km_plot_V2(FIG_NAME, 
            KM_TIME=INT_DPT,
            MAX_TIME=48, 
            AT_RISK_TIMES = %str(0,6,12,18,24,30,36,42,48),
            TITLE_1 = ,
            TITLE_2 = ,
			TITLE_3 = ,
            X_INTERVAL = 1,
            X_LABEL = Months After Device Implant,
            Y_LABEL = % Survival,
            LEGEND_TITLE = ,
            LOCATION = outside,
            POSITION = bottomright,
            FOOTNOTE_3 = %bquote(Event: Death (censored at transplant or recovery)),
            LOGO_LOCATION = %bquote(I:\SAS Macros\INTERMACS_logo.jpg),
            SUPRESS_LEGEND = 0,
            COLOR_LIST = blue red green orange purple brown,
            LINE_LIST = 1 2 3 4 5 6 7 8  9 10,
			MSG = 1,
			RPT_TY = pdf,
			PVALFORM = pvalue6.4
            );

	%if %sysfunc(exist(km_&FIG_NAME._analysis_data2)) %then %do;

	    * create an annotation dataset with the logo;
	    data km_&FIG_NAME._anno_logo;
	        JUSTIFY = "RIGHT";
	        FUNCTION = "IMAGE";
	        IMAGE = "&LOGO_LOCATION";
	        X1 = 99;
	        Y1 = 1;
	        ANCHOR = "BOTTOMRIGHT";
	        DRAWSPACE = "GRAPHPERCENT";
			HEIGHT=12;
	        output;
	    run;

	    * create an annotation dataset with the atrisk data;
	    data km_&FIG_NAME._anno_atrisk;
	        length label $20 TEXTCOLOR $20 ANCHOR $20 JUSTIFY $20 FUNCTION $20 DRAWSPACE $20;
	        set km_&FIG_NAME._analysis_data2 (keep=&KM_TIME STRATUM KM_STRATA_N ATRISK) end=last;
	        where &KM_TIME in (&AT_RISK_TIMES);

	        * places text on the graph output;
	        FUNCTION = "TEXT";

	        * specifies the text label;
	        LABEL = strip(put(ATRISK,f5.));

	        * specifies the drawing space and units for the annotation;
	        DRAWSPACE = "DATAVALUE";

	        * specify the first cordinates of the annotation;
	        X1 = &KM_TIME;
	        Y1 = STRATUM * 0.06;

	        if STRATUM = 1 then TEXTCOLOR = "GraphData1:color";
	        if STRATUM = 2 then TEXTCOLOR = "GraphData2:color";
	        if STRATUM = 3 then TEXTCOLOR = "GraphData3:color";
	        if STRATUM = 4 then TEXTCOLOR = "GraphData4:color";
	        if STRATUM = 5 then TEXTCOLOR = "GraphData5:color";
	        if STRATUM = 6 then TEXTCOLOR = "GraphData6:color";
	        if STRATUM = 7 then TEXTCOLOR = "GraphData7:color";
	        if STRATUM = 8 then TEXTCOLOR = "GraphData8:color";
	        if STRATUM = 9 then TEXTCOLOR = "GraphData9:color";
	        if STRATUM = 10 then TEXTCOLOR = "GraphData10:color";

	        * left justify at risk at 0;
	        if &KM_TIME = 0 then
	            do;
	                ANCHOR = "LEFT";
	                JUSTIFY = "LEFT";
	            end;

	        * right justify at risk at max time;
	        if &KM_TIME = &MAX_TIME then
	            do;
	                ANCHOR =  "RIGHT";
	                JUSTIFY = "RIGHT";
	            end;

	        output;

	        * create at risk: text;
	        if last then
	            do;
	                X1 = 0;
	                Y1 = (STRATUM +1) * 0.06;
	                LABEL = "At Risk:";
	                TEXTCOLOR = "Black";
	                TEXTSIZE = 8;
	                WIDTH = 10;
	                ANCHOR = "LEFT";
	                JUSTIFY = "LEFT";
	                output;
	            end;
	    run;

	    * combine the desired annotation data sets;
	    * here is where to implement options;
	    data km_&FIG_NAME._anno;
	        set km_&FIG_NAME._anno_atrisk
	            km_&FIG_NAME._anno_logo;
	    run;

	    * p-values were calculated create a macro variable for the log rank p-value;
	    %if %sysfunc(exist(km_&FIG_NAME._homtests)) %then %do;
			data _null_;
				set km_&FIG_NAME._homtests;
				where test = 'Log-Rank';
				call symput("KM_&FIG_NAME._logrank",compress(put(probchisq,&pvalform)));
			run;
	    %end;
	    %else %do; 
			data _null_;
				call symputx("KM_&FIG_NAME._logrank",'N/A');
			run;
		%end;
			
	    * create plot;
	    proc sgplot data=km_&FIG_NAME._analysis_data sganno=km_&FIG_NAME._anno %if &SUPRESS_LEGEND = 1 %then %do; noautolegend %end; ;

			%if &TITLE_1 ne " " %then %do;   
				TITLE &TITLE_1; 
			%end;

	        %if &TITLE_2 ne " " %then %do; 
				TITLE2 &TITLE_2;
			%end;

			%if &TITLE_3 ne " " %then %do; 
				TITLE3 &TITLE_3; 
			%end; 

	        styleattrs
				DATACOLORS =(&COLOR_LIST)
	            datacontrastcolors=(&COLOR_LIST)
	            datalinepatterns=(&LINE_LIST);  

	        *band x = KM_BAND_TIME upper=UCL lower=LCL/ modelname="myname" group=KM_STRATA_N transparency=0.75 /*lineattrs=(pattern=dash)*/;
			band x = &KM_TIME upper=UCL lower=LCL/ modelname="myname" group=KM_STRATA_N transparency=0.75 /*lineattrs=(pattern=dash)*/;
	        step x = &KM_TIME y = SURV/ NAME="myname" group=KM_STRATA_N lineattrs=(thickness=2);
	        *step x = KM_FILL_TIME y = SURV/ group=KM_STRATA_N NAME="test" lineattrs=(thickness=2 pattern=dash);
	        xaxis values=(0 to &MAX_TIME by &X_INTERVAL)  label="&x_label";
	        yaxis values=(0 to 1 by 0.1) label="&y_label" display=all;
	        format SURV percent9.0 KM_STRATA_N KM_&FIG_NAME._FORMAT.;

	        /*inset "Event: Death (censored at transplantation or recovery)" /position=topright;*/
	        footnote  justify=left "Shaded areas indicate 70% confidence limits";
	        footnote2  justify=left "p (log-rank) = &&KM_&FIG_NAME._LOGRANK";
	        footnote3 justify=left "&FOOTNOTE_3";
	        %if &SUPRESS_LEGEND = 0 %then %do;
	        keylegend "myname" / across=1 border location=&LOCATION position=&POSITION title="&LEGEND_TITLE";
	        %end;
	    run;

	    title;
	    footnote;
	%end;
	%else %if &msg = 1 %then %do;
		ods &RPT_TY text = "Not enough patients or events to produce exhibit";
	%end;
%mend;



%put ----- LOADING MACRO: standard_surv_table_V2 -----; 

%macro standard_surv_table_V2(FIG_NAME, 
            KM_TIME=INT_DPT,
            SURV_TIMES = %str(1,3,6,12,24,36,48),
            BOX_LABEL=%bquote(Months after Device Implant),
            TABLE_LABEL=%str(Percent Survival [% (70% CI)]),
            TIME_FORMAT=f3.,
            PCT_FORMAT=percent9.1,
			RPT_TY = pdf);

	%if %sysfunc(exist(km_&FIG_NAME._analysis_data2)) %then %do;

		ods pdf text="^{newline}^{style[just=c]&TABLE_LABEL}";


	    data km_&FIG_NAME._surv(keep=&KM_TIME PCT_CI KM_STRATA_N);
	        set km_&FIG_NAME._analysis_data2;
	        pct_ci = put(SURV,&PCT_FORMAT)||" ("||compress(put(LCL,&PCT_FORMAT)||"-"||put(UCL,&PCT_FORMAT)||")");
	        format KM_STRATA_N KM_&FIG_NAME._FORMAT_SHORT. &KM_TIME &TIME_FORMAT;;
	        label &KM_TIME = "&BOX_LABEL";
	        where &KM_TIME in (&SURV_TIMES);
	    run;

	    proc sort data=km_&FIG_NAME._surv;
	        by &KM_TIME;
	    run;

	    proc transpose data=km_&FIG_NAME._surv out=km_&FIG_NAME._surv_t (drop=_name_);
	        id KM_STRATA_N;
	        by &KM_TIME;
	        var PCT_CI;
	        idlabel KM_STRATA_N;
	    run;

	    proc print label noobs;
	        var _all_ / style=[just=center];
	    run;
	%end;

%mend;

/*NEED TO MAKE THIS AN OPTION*/
/**Plot K-M Curve (To remove at risk times set variable to -1);*/
/*%macro standard_km_plot_nolegend(FIG_NAME, */
/*            KM_TIME=INT_DPT,*/
/*            MAX_TIME=48, */
/*            AT_RISK_TIMES = %str(0,6,12,18,24,30,36,42,48),*/
/*            TITLE_1 = ,*/
/*            TITLE_2 = ,*/
/*            X_INTERVAL = 1,*/
/*            X_LABEL = Months After Device Implant,*/
/*            Y_LABEL = % Survival,*/
/*            FOOTNOTE_3 = %bquote(Event: Death (censored at transplant or recovery)),*/
/*            LOGO_LOCATION = %bquote(M:\INTERMACS 2011-2015\10 Statistical Reports\INTERMACS\Quarterly Report Macros Formats and Template\2016 Q2\INTERMACS_logo.jpg)*/
/*            );*/
/*    * create an annotation dataset with the logo;*/
/*    data km_&FIG_NAME._anno_logo;*/
/*        JUSTIFY = "RIGHT";*/
/*        FUNCTION = "IMAGE";*/
/*        IMAGE = "&LOGO_LOCATION";*/
/*        X1 = 99;*/
/*        Y1 = 1;*/
/*        ANCHOR = "BOTTOMRIGHT";*/
/*        DRAWSPACE = "GRAPHPERCENT";*/
/*        output;*/
/*    run;*/
/**/
/*    * create an annotation dataset with the atrisk data;*/
/*    data km_&FIG_NAME._anno_atrisk;*/
/*        length label $20 TEXTCOLOR $20 ANCHOR $20 JUSTIFY $20 FUNCTION $20 DRAWSPACE $20;*/
/*        set km_&FIG_NAME._analysis_data2 (keep=&KM_TIME STRATUM KM_STRATA_N ATRISK) end=last;*/
/*        where &KM_TIME in (&AT_RISK_TIMES);*/
/**/
/*        * places text on the graph output;*/
/*        FUNCTION = "TEXT";*/
/**/
/*        * specifies the text label;*/
/*        LABEL = strip(put(ATRISK,f5.));*/
/**/
/*        * specifies the drawing space and units for the annotation;*/
/*        DRAWSPACE = "DATAVALUE";*/
/**/
/*        * specify the first cordinates of the annotation;*/
/*        X1 = &KM_TIME;*/
/*        Y1 = STRATUM * 0.06;*/
/**/
/*        /**/
/*        if STRATUM = 1 then TEXTCOLOR = "B";*/
/*        if STRATUM = 2 then TEXTCOLOR = "R";*/
/*        if STRATUM = 3 then TEXTCOLOR = "G";*/
/*        if STRATUM = 4 then TEXTCOLOR = "brown";*/
/*        if STRATUM = 5 then TEXTCOLOR = "magenta";*/
/*            */*/
/*        if STRATUM = 1 then*/
/*            TEXTCOLOR = "GraphData1:color";*/
/**/
/*        if STRATUM = 2 then*/
/*            TEXTCOLOR = "GraphData2:color";*/
/**/
/*        if STRATUM = 3 then*/
/*            TEXTCOLOR = "GraphData3:color";*/
/**/
/*        if STRATUM = 4 then*/
/*            TEXTCOLOR = "GraphData4:color";*/
/**/
/*        if STRATUM = 5 then*/
/*            TEXTCOLOR = "GraphData5:color";*/
/**/
/*        if STRATUM = 6 then*/
/*            TEXTCOLOR = "GraphData6:color";*/
/**/
/*        if STRATUM = 7 then*/
/*            TEXTCOLOR = "GraphData7:color";*/
/**/
/*        if STRATUM = 8 then*/
/*            TEXTCOLOR = "GraphData8:color";*/
/**/
/*        if STRATUM = 9 then*/
/*            TEXTCOLOR = "GraphData9:color";*/
/**/
/*        if STRATUM = 10 then*/
/*            TEXTCOLOR = "GraphData10:color";*/
/**/
/*        * left justify at risk at 0;*/
/*        if &KM_TIME = 0 then*/
/*            do;*/
/*                ANCHOR = "LEFT";*/
/*                JUSTIFY = "LEFT";*/
/*            end;*/
/**/
/*        * right justify at risk at max time;*/
/*        if &KM_TIME = &MAX_TIME then*/
/*            do;*/
/*                ANCHOR =  "RIGHT";*/
/*                JUSTIFY = "RIGHT";*/
/*            end;*/
/**/
/*        output;*/
/**/
/*        * create at risk: text;*/
/*        if last then*/
/*            do;*/
/*                X1 = 0;*/
/*                Y1 = (STRATUM +1) * 0.06;*/
/*                LABEL = "At Risk:";*/
/*                TEXTCOLOR = "Black";*/
/*                TEXTSIZE = 8;*/
/*                WIDTH = 10;*/
/*                ANCHOR = "LEFT";*/
/*                JUSTIFY = "LEFT";*/
/*                output;*/
/*            end;*/
/*    run;*/
/**/
/*    * combine the desired annotation data sets;*/
/*    * here is where to implement options;*/
/*    data km_&FIG_NAME._anno;*/
/*        set km_&FIG_NAME._anno_atrisk*/
/*            km_&FIG_NAME._anno_logo;*/
/*    run;*/
/**/
/*    * create plot;*/
/*    proc sgplot data=km_&FIG_NAME._analysis_data sganno=km_&FIG_NAME._anno noautolegend;*/
/*        title  "&TITLE_1";*/
/*        title2 "&TITLE_2";*/
/*        band x = KM_BAND_TIME upper=UCL lower=LCL/ modelname="myname" group=KM_STRATA_N transparency=0.75 lineattrs=(pattern=dash);*/
/*        step x = &KM_TIME y = SURV/ group=KM_STRATA_N NAME="test" lineattrs=(thickness=2 pattern=solid);*/
/*        step x = KM_FILL_TIME y = SURV/ group=KM_STRATA_N NAME="myname" lineattrs=(thickness=2 pattern=dash);*/
/*        xaxis values=(0 to &MAX_TIME by &X_INTERVAL)  label="&x_label";*/
/*        yaxis values=(0 to 1 by 0.1) label="&y_label" display=all;*/
/*        format SURV percent9.0 KM_STRATA_N KM_&FIG_NAME._FORMAT.;*/
/**/
/*        /*inset "Event: Death (censored at transplantation or recovery)" /position=topright;*/*/
/*        footnote  justify=left "Shaded areas indicate 70% confidence limits";*/
/*        footnote2  justify=left "p (log-rank) = &&KM_&FIG_NAME._LOGRANK";*/
/*        footnote3 justify=left "&FOOTNOTE_3";*/
/*        *keylegend "test" / across=1 border location=&LOCATION position=&POSITION title="&LEGEND_TITLE";*/
/*    run;*/
/**/
/*    title;*/
/*    footnote;*/
/*%mend;*/









/*%put ----- LOADING MACRO: standard_co_calc  -----;*/
/*%macro standard_co_calc_V0_1(FIG_NAME, MAX_TIME = 0);*/
/*    *determinine the number of events;*/
/*    proc sql noprint;*/
/*    select sum(EVENT) into : co_&FIG_NAME._n_events*/
/*    from co_&FIG_NAME._data;*/
/*    quit;*/
/**/
/*    *determine the number of patients;*/
/*    proc sql noprint;*/
/*    select count(distinct patient_id) into :co_&FIG_NAME._n_pts from co_&FIG_NAME._data;*/
/*    quit;*/
/**/
/*    %KAPLAN(IN=co_&FIG_NAME._data,OUT=co_&FIG_NAME._kaplan,INTERVAL=INT_EVNT,EVENT=EVENT,PEVENT=0,OTHSUMS=dead_pt txpl_pt trec_pt,*/
/*        ELABEL=Event,HLABEL=Months after Implant);*/
/**/
/*data co_&FIG_NAME._figure(keep=int_evnt NUMBER cum_surv sumdead sumtxpl sumrec)/* co_&FIG_NAME._kaplan*/;*/
/*    set co_&FIG_NAME._kaplan;*/
/*    retain SUMDEAD 0 SUMTXPL 0 SUMREC 0 FREE 1;*/
/**/
/*    * Define a summer for EACH mutually exclusive event, here just two of them;*/
/*    SUMDEAD = SUMDEAD + FREE*dead_pt/NUMBER;*/
/*    SUMTXPL = SUMTXPL + FREE*txpl_pt/NUMBER;*/
/*    SUMREC  = SUMREC  + FREE*trec_pt/NUMBER;*/
/**/
/*    * The sum of all events MUST be 1 (except for roundoff error);*/
/*    CHECK = CUM_SURV + SUMDEAD + SUMtxpl + SUMREC;*/
/**/
/*    * Retain last value in FREE, that is, freedom from all events.  It is set to;*/
/*    * 1 for the first evaluation, assuming 100% freedom at time zero.;*/
/*    FREE=CUM_SURV;*/
/*    call symput("co_&FIG_NAME._max",INT_EVNT);*/
/*run;*/
/**/
/*data co_&FIG_NAME._atriskshell;*/
/*    do INT_EVNT = 0 to max(&MAX_TIME,&&co_&FIG_NAME._max)  by 1;*/
/*        output;*/
/*    end;*/
/*run;*/
/**/
/*data co_&FIG_NAME._figure;*/
/*    merge co_&FIG_NAME._figure co_&FIG_NAME._atriskshell;*/
/*    by INT_EVNT;*/
/*run;*/
/**/
/*data co_&FIG_NAME._figure;*/
/*    set co_&FIG_NAME._figure(rename=(NUMBER=T_NUMBER */
/*        CUM_SURV=T_CUM_SURV*/
/*        SUMDEAD=T_SUMDEAD*/
/*        SUMTXPL=T_SUMTXPL*/
/*        SUMREC=T_SUMREC));*/
/*    retain NUMBER &&co_&FIG_NAME._n_pts CUM_SURV 1 SUMDEAD 0 SUMTXPL 0 SUMREC 0;*/
/**/
/*    if T_NUMBER   ne . then*/
/*        NUMBER=T_NUMBER;*/
/**/
/*    if T_CUM_SURV ne . then*/
/*        CUM_SURV=T_CUM_SURV;*/
/**/
/*    if T_SUMDEAD  ne . then*/
/*        SUMDEAD=T_SUMDEAD;*/
/**/
/*    if T_SUMTXPL  ne . then*/
/*        SUMTXPL=T_SUMTXPL;*/
/**/
/*    if T_SUMREC   ne . then*/
/*        SUMREC=T_SUMREC;*/
/*run;*/
/**/
/*%mend;*/
;

options source;


*Project Path;
option nofmterr;
ods graphics on;
ods listing style=mystyle image_dpi=300
gpath="C:\Users\vector78\Documents\spring_2019_classes\BST 665";


*Lets compare, shall we? How much does censoring vs counting them as death change the results?;
 %let FIG_NAME = rat;
    data km_&FIG_NAME._data;
        length KM_STRATA_NAME $40;
        set rats;

        if STRESS = "Low" then do;
            KM_STRATA_N    = 1;
            KM_STRATA_NAME = '1. Low';
        end;

		if STRESS = "Medium" then do;
            KM_STRATA_N    = 2;
            KM_STRATA_NAME = '2. Low';
        end;

		if STRESS = "High" then do;
            KM_STRATA_N    = 3;
            KM_STRATA_NAME = '3. High';
        end;



    run;
    %standard_km_calc(FIG_NAME=&FIG_NAME);

		
ods graphics / reset imagename='CensorDeath-' height=4in width=6.5in;

     %standard_km_plot_V2(FIG_NAME = CENSOR, MAX_TIME = 12,SUPRESS_LEGEND = 0,
	   
        TITLE_1 = %bquote(Kaplan-Meier Survival on a Device for Pedimacs Population (n=423)),
        LOGO_LOCATION = %bquote(I:\SAS Macros\pedimacs_logo.jpg),
        TITLE_2 = %bquote(Coverage: &COVERAGE_START to &COVERAGE_STOP),
		COLOR_LIST = blue red, line_list= 1 2 3);
    %standard_surv_table_V2(FIG_NAME=CENSOR, SURV_TIMES = %str(1,3,6,12));

ods graphics / reset;

