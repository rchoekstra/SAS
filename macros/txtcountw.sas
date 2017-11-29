/** \macro txtcountw
 * txtcountw
 * @author René Hoekstra
 */
%macro txtcountw(ds,attr,out,by);
	%let _notes = %sysfunc(getoption(notes));
	options nonotes;

	%put Start wordcount macro (%sysfunc(strip(%sysfunc(time(),time8.))));

	%put WARNING: replace gaat niet goed als search aan het begin/eind van de regel staat.;
	data _translate;
		length search 	$25.
			   replace	$25.;
		search='eigen risico'; replace='eigen_risico'; output;
		search= 'e.r.'; replace='eigen_risico'; output;
		search= 'ver'; replace='eigen_risico'; output;
		search= 'zvw'; replace='bv'; output;
		search= 'basisverzekering'; replace='bv'; output;
		search= 'ai'; replace='automatische_incasso'; output;
		search= 'auto incasso'; replace='automatische_incasso'; output;
		search= 'automatische incasso'; replace='automatische_incasso'; output;
		search= 'adm.kosten'; replace='administratiekosten'; output;
		search= 'bet.reg'; replace='betalingsregeling'; output;
		search= 'bet reg'; replace='betalingsregeling'; output;
		search= 'terug gestort'; replace='teruggestort'; output;
		search= 'br'; replace='betalingsregeling'; output;
		search='uit dienst'; replace='uit_dienst'; output;
		search='nieuwe werkgever'; replace='nieuwe_werkgever'; output;
		search='mevr';		   replace='mevrouw';      output;
		search='mw';		   replace='mevrouw';	   output;
		search='dhr';		   replace='meneer';	   output;
		search='mvr';		   replace='mevrouw';	   output;
		search='eb';		   replace='eigen_bijdrage';	output;
		search='eigen bijdrage';   replace='eigen_bijdrage';	output; 
	run;

	proc sql noprint;
		select '_tmp_ = tranwrd(_tmp_," ' 
			|| strip(search) 	|| ' "," ' 
			|| strip(replace) 	|| ' ")%str(;)'
			into : tranwrd separated by ' '
		  from _translate;
	quit;

	/* Waarom werkt input i.c.m. datalines niet? */
	data _blacklist;
		length blacklist_word $25.;

		blacklist_word='de'; output;
		blacklist_word='het';output;
		blacklist_word='een';output;
		blacklist_word='of'; output;
		blacklist_word='is'; output;
		blacklist_word='van'; output;
		blacklist_word='en'; output;
		blacklist_word='dat'; output;
		blacklist_word='voor'; output;
		blacklist_word='in'; output;
		blacklist_word='met'; output;
		blacklist_word='heeft'; output;
		blacklist_word='te'; output;
		blacklist_word='dit'; output;
		blacklist_word='nog'; output;
		blacklist_word='bij'; output;
		blacklist_word='aan'; output;
		blacklist_word='gaat'; output;
		blacklist_word='naar'; output;
		blacklist_word='ze'; output;
		blacklist_word='zijn'; output;
		blacklist_word='over'; output;
		blacklist_word='maar'; output;
		blacklist_word='hij'; output;
		blacklist_word='ook'; output;
		blacklist_word='wordt'; output;
		blacklist_word='belt'; output;
		blacklist_word='worden'; output;
		blacklist_word='om'; output;
		blacklist_word='nu'; output;
		blacklist_word='per'; output;
		blacklist_word='ik'; output;
		blacklist_word='wel'; output;
		blacklist_word='dan'; output;
		blacklist_word='wil'; output;
		blacklist_word='moet'; output;
		blacklist_word='deze'; output;
		blacklist_word='die'; output;
		blacklist_word='ons'; output;
		blacklist_word='al'; output;
		blacklist_word='zij'; output;
		blacklist_word='wij'; output;
		blacklist_word='haar'; output;
		blacklist_word='dus'; output;
		blacklist_word='hebben'; output;
		blacklist_word='door'; output;
		blacklist_word='omdat'; output;
		blacklist_word='wat'; output;
		blacklist_word='ivm'; output;
		blacklist_word='heb'; output;
		blacklist_word='op'; output;
		blacklist_word='als'; output;
		blacklist_word='kan'; output;
		blacklist_word='zie'; output;
	run;

/*	data _blacklist;*/
/*		length blacklist_word $25.;*/
/*		input blacklist_word $;*/
/*		datalines;*/
/*de*/
/*het*/
/*een*/
/*of*/
/*	run;*/


	data _null_;
		/* Definieer variabelen */
		length word $25.
			   count 8.;

		if _N_ = 1 then do;
			/* Blacklist */
			length blacklist_word $25.;
			declare hash blacklist(dataset:'_blacklist');
			blacklist.defineKey('blacklist_word');
			blacklist.defineDone();

			/* Definieer hasobject voor wordcount*/
			declare hash obj();
			%if "&by." = "" %then %do; 
				%*put Key is empty;
				obj.defineKey('word');
				obj.defineData('word','count');
			%end;
			%else %do;	
				%*put Key is not empty;
				obj.defineKey('word',"&by.");
				obj.defineData('word',"&by.",'count');
			%end;

			obj.defineDone();
		end;

		/* Set de input dataset */
		set &ds. end=eof;

		/* Modificeer de tekst: lowcase, leestekens verwijderen en dubbele blanks vervangen */
		/*_tmp_ = compbl(compress(lowcase(&attr.),':.,;+-/*?€=<>','dc'));*/
		_tmp_ = compbl(																/* Dubbele blanks */
					dequote(															/* Verwijder quotes */
						translate(														/* Vergang speciale characters cijfers door spaties */
							compress(													/* Behoud(k) letters (a) en speciale tekens (incl. cijfers) (g) en spaties (' ') en optimaliseer (o) omdat argument 2 en 3 niet veranderen */
								lowcase(' '||&attr.||' ')							/* Voeg spaties toe voor tranwrd */
							    ,' '
								,'agko')
						,' ','~!@#$%^&*()_+-=[]\{}|;:,.<>/*-?0123456789`'||"'")
					)
				);

		/* Vervang woorden (niet echt efficient denk ik) */
		&tranwrd.;

		/* Bepaal het aantal woorden */
		if length(_tmp_)=0 then num_words = 0;
		else 					num_words = countc(strip(_tmp_),' ') + 1;

		/* Loop door alle woorden */
		do i = 1 to num_words;

			/* Plaats het word in de key */
			word = dequote(scan(_tmp_,i));

			/* Zoek voor woord in blacklist */
			if blacklist.find(key:word) ne 0 
			   and
			   length(word) > 1
			then do;			
				/* Als woord niet in blacklist voorkomt voeg deze dan toe aan hashobject */

				/* Verhoog counter in hashobject als key voorkomt, anders toevoegen */
				if obj.find()=0 then do;
					count = count+1;
					obj.Replace();
				end;
				else do;
					count = 1;
					obj.Add();
				end;
			end;
		end;

		/* Output het hash object */
		if eof then obj.output(dataset:"&out.");
	run;

	proc datasets lib=work memtype=data nolist;
		delete _blacklist _translate;
	run;quit;
	options &_notes;
	%put Einde wordcount macro (%sysfunc(strip(%sysfunc(time(),time8.))));
%mend txtcountw;
