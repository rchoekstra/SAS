/** \macro hash_agg
 * Macro om gebruik te maken van de techniek om met hash tables te aggregeren. Dit voorkomt een sortering die soms bij een proc sql wel gedaan wordt.
 *
 * @author René Hoekstra
 * @param ds Input dataset
 * @param key Kolommen waarover geaggregeerd moet worden (vergelijkbaar met group by)
 * @param sumvar Variabelen die gesommeerd moeten worden
 * @param countvar Variabelen die geteld moeten worden
 * @param avgvar Variabelen waarover het gemiddelde berekend moet worden
 * @param out Output datastep
 * @param where Filter voor input datastep
 */


/* René Hoekstra * 
 *
 * Macro doet de volgende stappen:
 * 1. Controle van alle paramaters (b.v.zijn verplichte parameters opgegeven)
 * 2. Converteren van &key paramater naar code die nodig is voor hashobj.definekey(); --> &_defineKey
 * 3. Converteren van &sumvar en &countvar parameters naar code die nodig is voor hashobj.definedata(); --> &_defineData
 * 4. Converteren van &sumvar en &countvar paramaters naar datastep code die daadwerkelijk de sum en count uitvoeren --> &_sum en &_count
 * 5. Converteren van &where parameter naar geldige SAS code --> &_where
 * 6. Datastep uitvoeren waarin alle gegenereerde code wordt uitgevoerd.
 */

%macro hash_agg(ds=,key=,sumvar=,countvar=,avgvar=, out=,where=);

	%let _notes = %sysfunc(getoption(notes));
	%let _compress = %sysfunc(getoption(compress));
	options notes compress=no;
	%let _error = 0;

	/* Controlleer of datasets bestaat */
	%if &ds.=%str() or &out.=%str() %then %do;
		%let _error = 1;
		%let _error_msg = Input (ds) of output (out) dataset ontbreekt;
		%goto exit;
	%end;

	/* Controleer of key is opgegeven*/
	%if &key.=%str() %then %do;
		%let _error = 1;
		%let _error_msg = Er zijn geen key variabele opgegeven;
		%goto exit;
	%end;

	/* Controleer of er tenminste één sum of count variabele is opgegeven */
	%if (&sumvar.=%str() and %quote(&countvar.)=%str()) %then %do;
		%let _error = 1;
		%let _error_msg = Er is geen sum of count variabele opgegeven;
		%goto exit;
	%end;

	/* Tel het aantal key variabelen */
	%let key 	= %sysfunc(compbl(&key.));
	%let num_keyvar = %eval(%sysfunc(countc(&key," "))+1);

	/* Tel het aantal sum variabelen */
	%if &sumvar. ne %str() %then %do;
		%let sumvar = %sysfunc(compbl(&sumvar.));
		%let num_sumvar = %eval(%sysfunc(countc(&sumvar," "))+1);
	%end;
	%else %do;
		%let num_sumvar = 0;
	%end;

	/* Bepaal of count(*) gebruikt moet worden */
	%if %sysfunc(index(%quote(&countvar.), %quote(*))) %then %do;
		%let countstar = 1;
		%let countvar = %sysfunc(compress(%str(&countvar.),%str(*)));
	%end;
	%else %do;
		%let countstar = 0;
	%end;

	/* Tel het aantal count variabelen */
	%if %quote(&countvar.) ne %str() %then %do;
		%let countvar	= %sysfunc(compbl(%str(&countvar.)));
		%let num_countvar = %eval(%sysfunc(countc(&countvar.," "))+1);
	%end;
	%else %do;
		%let num_countvar = 0;
	%end;

	/* Code voor defineKey function maken */
	%do i = 1 %to &num_keyvar.;
		%if &i.=1 %then %do; 
			%let _definekey = "%sysfunc(scan(&key.,&i.))";
		%end;
		%else %do;
			%let _definekey = &_definekey.,"%sysfunc(scan(&key.,&i.))";
		%end;
	%end;

	/* Code voor defineData functie maken - sumvar */
	%let _definedata =;
	%do i = 1 %to &num_sumvar.;
		%let _var = %sysfunc(scan(&sumvar.,&i.));

		/*%if &_definekey = %str() %then %do; */
		%if &i. = 1 %then %do;
			%let _definedata = "&_var._sum";
			%let _sum        = &_var._sum = coalesce(&_var._sum,0)+coalesce(&_var.,0)%str(;);
		%end;
		%else %do;
			%let _definedata = &_definedata.,"%sysfunc(scan(&sumvar.,&i.))_sum";
			%let _sum        = &_sum. &_var._sum = coalesce(&_var._sum,0)+coalesce(&_var.,0)%str(;);
		%end;
	%end;

	/* Code voor defineData functie maken - countvar */
	%let _count =;
	%do i = 1 %to &num_countvar.;
		%let _var = %sysfunc(scan(&countvar.,&i.));
		%if &_definedata. = %str() %then %do;
			%let _definedata = "&_var._count";
		%end;
		%else %do;
			%let _definedata = &_definedata.,"%sysfunc(scan(&countvar.,&i.))_count";
		%end;

		%let _count = &_count. if rc ne 0 then &_var._count = 0%str(;) if not missing(&_var.) then &_var._count + 1%str(;);
	%end;

	%if &countstar = 1 %then %do;
		%if &_definedata. = %str() %then %do;
			%let _definedata = "count";
		%end;
		%else %do;
			%let _definedata = &_definedata.,"count";
		%end;

		%let _count = &_count. if rc ne 0 then count = 0%str(;) count + 1 %str(;);
	%end;

	/* Where */
	%if %nrstr(&where.) ne %str() %then %do;
		%let _where = %str(where &where.);
	%end;
	%else %do;
		%let _where=;
	%end;

	data _null_;
		/* Definieer hash object */
		if _N_ = 1 then do;
			declare hash agg();
			agg.definekey(&_definekey.);
			agg.definedata(&_definekey.,&_definedata.);
			agg.definedone();
		end;

		/* Laad dataset */
		set &ds. (SGIO=yes BUFNO=1000) end=eof;
		&_where.;

		/* Lookup */
		rc = agg.find();

		/* Sommeer */
		%if &num_sumvar. > 0 %then %do;
			&_sum.;
		%end;

		/* Count */
		%if &num_countvar. > 0 or &countstar=1 %then %do;
			&_count.;
		%end;

		/* Add/replace */
		if rc=0 then do;		agg.replace();		end;
		else do;				agg.add();			end;

		/* Output de dataset */
		if eof then do;
			agg.output(dataset:"&out.");
		end;
	run;

	/* Options terugzetten */
	options &_notes. compress=&_compress.;

	/* Exit */
	%exit:
		%if &_error. > 0 %then %do;
			%put ERROR: &_error_msg;
			%put;
			%put Verplichte parameters:;
			%put ds=      Input dataset;
			%put key=     Variabelen waarop gegroepeerd moet worden (scheiden met spatie);
			%put sumvar=  Variabelen die gesommeerd moeten worden (scheiden met spatie);
			%put countvar=Variabelen waarvan het aantal non-missing values geteld moeten worden (scheiden met spaties);
			%put out=     Output dataset;

			%put Voorbeeld: %str(%%) hash_agg(ds=sashelp.shoes, key=region product, sumvar=sales returns stores, out=agg);
		%end;
%mend hash_agg;




