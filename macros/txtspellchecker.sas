/** \macro txtspellchecker 
 * txtspellchecker
 *
 * @author René Hoekstra
 */
%macro txtspellchecker(ds=,attr=,radius=,measure=hhi,threshold=,out=,stat=,debug=n);
	%put Start spellchecker (%sysfunc(time(),time8.));
	%let starttime = %sysfunc(time());

	%let _notes 		= %sysfunc(getoption(notes));
	%let _fullstimer 	= %sysfunc(getoption(FULLSTIMER));
	option nonotes;

	%let debug = %sysfunc(lowcase(&debug.));
	%if &debug. eq j %then %do;
		options notes fullstimer;
	%end;

	%let measure = %sysfunc(lowcase(&measure.));
	%if &measure. ne hhi and &measure. ne ged and &measure. ne lev %then %do;
		%put WARNING: Onbekende measure, default wordt gebruikt (hhi);
		%let measure = hhi;
	%end;

	

	%put - 1/5 Voorbereiden data;
	data _fastclus_input;
		set &ds. end=eof;

		/* Initialiseer dataset variabelen */
		length _1-_26 								3.;		/* 1=a ... 26=z */
		length letter_1-letter_26 					$1.;
		length letter_rank_1 - letter_rank_26 		3.;


		/* Initialiseer arrays */
		array alfabet (26) $ _temporary_;
		do _i = 1 to 26;
			alfabet(_i)=byte(96+_i) /* ASCII (dec) 97 = a */;
		end;

		array letters(26) $ _1-_26;

		array letter(26) $ letter_1-letter_26;

		array letter_rank(26) $ letter_rank_1-letter_rank_26;

		/* Loop door iedere letter van het alfabet */
		do _i = 1 to 26;
			letters(_i) = count(&attr.,alfabet(_i));			/* Frequency van letter */

			letter_rank(_i) = index(&attr.,trim(alfabet(_i)));		/* Eerste positie waar letter voorkomt */

			/* Letters afzonderlijk in variable zetten */
			if _i <= length(&attr.) then
				letter(_i) = substr(&attr.,_i,1);
			else
				letter(_i) = '';

		end;

		if eof then call symput('nobs',put(_N_,best.));
	run;

	%put - 2/5 Clustering;
	proc fastclus data=_fastclus_input 
				  out=_fastclus_output(keep=word count cluster distance)  
				  radius=&radius.
				  maxclusters=&nobs. 
				  dist noprint;
		var _1-_26
			letter_rank_1-letter_rank_26;
	run;

	proc sort data=_fastclus_output;
		by cluster;
	run;

	/* I.p.v. clustering zou ook nearest neighbor gebruik kunnen worden
	 * Hiervoor dient een iteratieve functie gebruikt te worden die m.b.v. 
	 * een edit distance bepaald of een woord wordt vervangen door de nearest
	 * neighbor.
	 */
	/*	proc distance data=_fastclus_input out=distance;*/
	/*		id word;*/
	/*		var interval(_1-_26*/
	/*			letter_rank_1-letter_rank_26);*/
	/*	run;*/


	%put - 3/5 Woord frequenties per cluster bepalen;
	proc freq data=_fastclus_output(keep=word cluster count) noprint;
		by cluster;
		weight count;
		tables word /out=_freq_output;	
	run;

	%put - 4/5 Concentratie ratios per cluster bepalen;
	proc sql;
		create table _freq_hhi as
			select t.*
				 , sum((percent/100)**2)	as hhi	label="Herfindahl-Hirschman Index (HHI)"
			  from _freq_output t
			 group by cluster
			order by cluster, percent desc;
	quit;

	%put - 5/5 Suggestie bepalen en toetsen;
	data &out.;
		set _freq_hhi;
		retain suggestion result;
		by cluster;

		if first.cluster then suggestion=word;
		label suggestion = "Suggestion";

		/* Bepaal generalized editing distance */
		ged = compged(word,suggestion);
		label ged = "Generalized editing distance";

		lev = complev(word,suggestion);
		label lev = "Levenshtein edit distance";

		%if &measure.=hhi %then %do;
			if hhi >= &threshold. then result = suggestion;
			else 					   result = word;
		%end;
		%else %if &measure.=ged or &measure.=lev %then %do;
			if &measure. <= &threshold. then result = suggestion;
			else 					         result = word;
		%end;
		%else %do;
			%put ERROR: Mag niet voorkomen!;
		%end;

		if word ne suggestion and suggestion eq result then replaced=1;
		else												replaced=0;

		label result="Did you mean?";
	run;

	%let endtime= %sysfunc(time());

	%let duration = %sysevalf(&endtime.-&starttime.);

	%if %sysfunc(lowcase(&stat.))=j %then %do;
		title "Model information";
		data _null_;
			file print;
			put "Input dataset:		&ds.";
			put "Output dataset:	&out.";
			put "Attribute:			&attr.";
			put "Radius:			&radius";
			put "Measure:			&measure";
			put "Threshold:			&threshold";
			put "Duration:			%sysfunc(putn(&duration.,time8.))";
		run;

		proc sql;
			create table _stat_1 as
				select count(*)						as aantal_woorden				format=commax20.0	label="Aantal woorden"
					 , count(distinct cluster)		as aantal_clusters				format=commax20.0	label="Aantal clusters" 
					 , count(distinct result)		as aantal_woorden_output		format=commax20.0	label="Aantal woorden output"
					 , 1-count(distinct result) / count(*) as reductie_ratio		format=percent.		label="Reductie ratio"
					 , sum(replaced)				as aantal_vervangen				format commax20.0	label="Aantal woorden vervangen"
				  from spellchecker_output;

			create table _stat_2_tmp as
				select cluster
					 , count(*)						as aantal_woorden
					 , count(distinct result)		as aantal_woorden_output
					 , case when count(*) eq 1 then 1 else 0 end						as singleton
					 , case when count(*) ne count(distinct result) then 1 else 0 end 	as acceptatie
					 , sum(replaced)				as aantal_vervangen
				  from spellchecker_output
				 group by cluster;

			create table _stat_2 as
				select sum(singleton)			as aantal_singletons		format=commax20.0 label="Aantal singletons"
					 , sum(acceptatie)			as aantal_acceptatie		format=commax20.0 label="Aantal geaccepteerd"
					 , sum(1-acceptatie)-sum(singleton) as aantal_verworpen format=commax20.0 label="Aantal verworpen"
					 , sum(aantal_vervangen)	as aantal_vervangen			format=commax20.0 label="Aantal vervangen"
				  from _stat_2_tmp;
		quit;

		title "Summary statistics";
		proc print data=_stat_1 noobs label;
		run;

		
		title "Cluster statistics";
		proc print data=_stat_2 noobs label;
			var aantal_singletons
				%if &measure.=hhi %then %do;
					aantal_acceptatie
					aantal_verworpen
				%end;
			;
		run;
		

		title;
	%end;

	%if &debug ne j %then %do;
		proc datasets lib=work memtype=data nolist;
			delete _fastclus_input
				   _fastclus_output
				   _freq_output
				   _freq_hhi
				   _stat_1
				   _stat_2
				   _stat_2_tmp
				   ;
		run;quit;
	%end;

	%put Eind spellchecker (%sysfunc(time(),time8.));
	%put Duur: %sysfunc(putn(&duration.,time8.));
	options &_notes. &_fullstimer.;
%mend txtspellchecker;


