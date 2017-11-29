/** \macro chebyshev 
 * Berekent een outlier score o.b.v. Chebychev 's inequality. Dit is een outlier score die onafhankelijk van de onderliggende verdeling werkt. Chebyschev's inequality
 * stelt dat dat kans dat een variable meer dan <i>k</i> standaard deviaties van het gemiddelde is verwijderd, alleen meer afhankelijk is van <i>k</i>. Door de vergelijking
 * van Chevychev te herschrjven is een outlier score te berekenen die alleen afhankelijk is van het gemiddelde en de standaard deviatie. <br />&nbsp;<br />
 *
 * De outlier score wordt in de macro binnen een groep berekend (x) en kan tevens meerdere variabelen tegelijk (y) de score berekenen.
 *
 * @param ds Input dataset
 * @param y Variabelen waarvoor de outlier score berekend moet worden. Meerdere variabele scheiden door komma's (%str(var1,var2))
 * @param x Variabelen die de groepering bepalen. Meerdere variabelen scheiden door komma's (%str(varA,varB))
 * @param id Record id
 * @param debug Indien waarde 1 wordt er aanvullende informatie gegenereerd.
 * @author René Hoekstra
 */

/* Invoer parameters */
%macro chebyshev(ds=,y=,x=,id=,debug=);
	/* Macro parameters:
	 *	ds:	dataset
	 *	y : y variabelen gescheiden door comma's (continue)
	 *	x : x variabelen gescheiden door comma's (discreet)
	 *	id: id variabelen gescheiden door comma's
	 *
	 * Voorbeeld:
	 * %outlier(ds=work.class, y=%str(height,weight), x=sex, id=%str(name));
 	 */

	%put Dataset:	&ds.;
	%put y:			&y.;
	%put x:			&x.;
	%put id:		&id.;

	/* Comma's verwijderen uit &x voor proc sort */
	data _null_;
		x=tranwrd("&x",',',' ');
		call symput('_x',x);
	run;

	/* Sorteer dataset op x */
	proc sort data=&ds. out=&ds._sorted;
		by &_x;
	run;

	/* Bereken gemiddelde en standaard deviatie */
	proc means data=&ds._sorted noprint;
		by &_x.;
		output out=summ (drop=_TYPE_ _FREQ_ where=(_STAT_='MEAN' or _STAT_='STD'));
	run;

	/* Sla gemiddelde en standaarddeviatie op in aparte dataset */
	data mean(drop=_STAT_); set summ; where _STAT_='MEAN'; run;
	data std (drop=_STAT_); set summ; where _STAT_='STD';  run;

	/* Maak van ieder element in &y een rij */
	data ycolumns(keep=name);
		y="&y.";
		num = count(y,',')+1;
		do i = 1 to num;
			name=scan(y,i);
			output;
		end;
	run;

	/* Genereer SQL voor gemiddelde en standaarddeviatie voor iedere y variable en outlier score */
	proc sql noprint;
		create table _ytmp as
			select t1.name
				 , cats('t.',t1.name) || ',' 											as t				/* t.XXXX, */
			     , cats('m.',t1.name) || ' as avg_' || cats(t1.name) || ' label="",'	as m				/* m.XXXX as avg_XXXX */
				 , cats('s.',t1.name) || ' as std_' || cats(t1.name) || ' label="",'	as s				/* s.XXXX as std_XXXX */
				 , cats('1/(((t.',t1.name,'-m.',t1.name,')/s.',t1.name,')**2)') 		as d/* 1/(((y-u)/s)**2) as score_XXXX */
			  from (
			   select * from dictionary.columns
				where memtype='DATA'
				  and lowcase(memname)=lowcase("&ds._sorted")
				  and libname='WORK'							/* !! Library nog scheiden van uit &ds. !! */
				  and type='num') t1
		  		, ycolumns		  t2
		  where lowcase(t1.name) = lowcase(t2.name);

		select cats(t,m,s) ||
			'case when ' || cats('(t.',name,'-m.',name,')/s.',name) || '<1 then 1 else ' || cats(d) || ' end as score_' || cats(name)
			into: _ycols separated by ',' from _ytmp;

		select cats('score_',name) into: _d separated by '*' from ycolumns;
	quit;

	/* Maak van ieder element in &x een rij */
	data xcolumns(keep=name);
		x="&x.";
		num = count(x,',')+1;
		do i = 1 to num;
			name=scan(x,i);
			output;
		end;
	run;

	proc sql noprint;
		/* Genereer SQL voor x kolommen */
		select cats('t.',name) into :_xcols separated by ',' from xcolumns;

		/* Genereer SQL voor joins */
		select cats('s.',name,'=t.',name) into :_stjoin separated by ' and ' from xcolumns;
		select cats('m.',name,'=t.',name) into :_mtjoin separated by ' and ' from xcolumns;
	quit;


	data idcolumns(keep=name);
		id="&id.";
		num = count(id,',')+1;
		do i = 1 to num;
			name=scan(id,i);
			output;
		end;
	run;

	proc sql noprint;
		select cats('t.',name) into: _id separated by ',' from idcolumns;
	quit;


	/* Voer SQL uit die output tabel maakt */
	proc sql;
		create table &ds._score as
			select &_id.
				 , &_xcols.
				 , &_ycols.
			  from &ds._sorted	t
			  inner join std	s on (&_stjoin.)
			  inner join mean	m on (&_mtjoin.);
	quit;

	data &ds._score;
		set &ds._score;
		score = &_d.;
		lscore = log(&_d.);

		proc sort;
			by score;
	run;

	%if "&debug." = "1" %then %do;
		%put Debug informatie:;
		%put Macro variable _ycols;
		%put &_ycols.;
		%put ;
		%put Macro variable _xcols;
		%put &_xcols.;
		%put ;
		%put Macro variable _x;
		%put &_x.;
		%put ;
		%put Macro variable _id;
		%put &_id.;
		%put ;
		%put Macro variable _d;
		%put &_d.;
		%put ;
		%put Macro variable _stjoin;
		%put &_stjoin.;
		%put ;
		%put Macro variable _mtjoin;
		%put &_mtjoin.;
		%put;
	%end;
	%else %do;
		proc datasets memtype=data lib=work nolist;
			delete &ds._sorted;
			delete mean;
			delete std;
			delete summ;
			delete xcolumns;
			delete ycolumns;
			delete _ytmp;
			delete idcolumns;
		run;quit;
	%end;
%mend chebyshev;
