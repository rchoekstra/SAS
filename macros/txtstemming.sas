/** \macro txtstemming
 * txtstemming
 *
 * @author René Hoekstra
 */
%macro txtstemming(ds,out,var,stem);
	/* Deze macro is een implementatie van het stemmings algortime dat is beschreven op"
	 * http://snowball.tartarus.org/algorithms/dutch/stemmer.html
	 */
	%put Start stemming macro (%sysfunc(strip(%sysfunc(time(),time8.))));

	%let _error = 0;
	%let _notes = %sysfunc(getoption(notes));
	options nonotes;

	%if %sysfunc(exist(&ds.)) eq 0 %then %do;
		%let _error = 1;
		%let _error_msg = Dataset (&ds.) bestaat niet;
	%end;

	/* Submacros */	
	%macro undouble(v);
		/*if prxmatch('/(bb|dd|gg|kk|ll|mm|nn|pp|rr|ss|tt|zz)$/', strip(&v.)) then */
		if prxmatch('/(dd|kk|tt)$/', strip(&v.)) then 
			&v. = substr(&v., 1, length(strip(&v.))-1);
	%mend undouble;

	%macro r1;
		strip(substr(&stem.,r1_start))
	%mend r1;

	%macro r2;
		strip(substr(&stem.,r2_start+r1_start-1))
	%mend r2;

	%if &_error=0 %then %do;
		data &out.;
			set &ds.;
			call prxdebug(0);

			_tmp_ = lowcase(&var.);

			/* Remove accents */
			_tmp_ = translate(_tmp_, "aeiouaeuoi","äëïöüáéíóú");

			/* Put initial y, y after a vowel, and i between vowels into upper case (treat as consonants). */
			/* Zet de eerste y, y na een klinker, en i tussen de klinkers in hoofdletters (behandelen als medeklinkers). */

			/* Eerste letter y in hoofdletter */    
			_tmp_ = prxchange('s/^y/Y/',-1,_tmp_);

			/* Y na een klinker in hoofdletter */
			_tmp_ = prxchange('s/(?<=[aeiouyè])y/Y/',-1,_tmp_);

			/* i tussen klinkers in hoofdletter */
			_tmp_ = prxchange('s/(?<=[aeiouyè])i(?=[aeiouyè])/I/',-1,_tmp_);

			stem = strip(_tmp_);

			/* R1 is the region after the first non-vowel following a vowel (1), or is the
			   null region at the end of the word if there is no such non-vowel. */
			r1_start     = prxmatch('/[aeiouyè][^aeiouyè]/',_tmp_) + 2;
			/*r1 = %r1;*/
			/*r1_2 = substr(_tmp_,prxmatch('/[aeiouyè][^aeiouyè]/',_tmp_)+2);*/
			
			/* R2 is the region after the first non-vowel following a vowel in R1, or is
			   the null region at the end of the word if there is no such non-vowel. */
			
			r2_start =     prxmatch('/[aeiouyè][^aeiouyè]/',%r1)+2;
			/*r2 = %r2;*/
			/*r2_2 = substr(r1,prxmatch('/[aeiouyè][^aeiouyè]/',r1)+2);*/

			/************** Step 1 **************/
			/* Search for the longest among the following suffixes, and perform the action indicated 
			   (a) heden		replace with heid if in r1
			   (b) en(e)		delete if in r1 and preceded by a valid en-ending, and then unboudble the ending
			   (c) s, se		delete if in R1 and preced by a valid s-ending*/

			/* a: -heden*/ 
			if prxmatch('/heden$/',%r1) then do;
				&stem. = prxchange('s/heden$/heid/',-1,strip(&stem.));
			end;

			/* b: -en(e) */
			else if prxmatch('/ene$/',%r1) 
					and not index(&stem.,'gemene')
					and not prxmatch('/(?<=[aeiouyè])ene/',strip(&var.)) then do;
				&stem. = prxchange('s/ene$//',-1,strip(&stem.));
				%undouble(stem);
			end;

			*if prxmatch('/en$/',%r1) then do;
			else if prxmatch('/(?<=[^aeiouyè])en$|^en$/',%r1)  then do;
				&stem. = prxchange('s/en$//',-1,strip(&stem.));

				%undouble(stem);
			end;

			/* c: -s(e) */
			else if prxmatch('/(?<=[^jaeiouyè])se$|^se$/',%r1) then do;
				&stem. = prxchange('s/se$//',-1,strip(&stem.));
			end;
			else if prxmatch('/(?<=[^jaeiouyè])s$|^s$/',%r1) then do;
				&stem. = prxchange('s/s$//',-1,strip(&stem.));
			end;

			/************** Step 2 **************/
			/* Delete suffix e if in R1 and preceded by a non-vowel, and then undouble the ending */
			if prxmatch('/[^aeiouyè]*e$/',%r1) then do;
				&stem. = prxchange('s/(?<=[^aeiouyè])e$//',-1,strip(&stem.));
				%undouble(&stem.);
			end;

			/************** Step 3a **************/
			/* delete heid if in R2 and not preceded by c, and treat a preceding en as in step 1(b) */ 

			/*if prxmatch('/(?<=[^c])heid$/',%r2) then do;*/
			if prxmatch('/heid$/',%r2) and not prxmatch('/cheid$/',%r2) then do;
				if prxmatch('/enheid$/',%r2) then do;
					&stem. = prxchange('s/enheid$//',-1,strip(&stem.));
					%undouble(&stem.);
				end;
				else do;
					&stem. = prxchange('s/heid$//',-1,strip(&stem.));
				end;
			end;
			
			/************** Step 3b **************/
			/* d-suffixes */

			/* -end, -ing */
			if prxmatch('/(end|ing)$/',%r2) then do;
				&stem. = prxchange('s/(end|ing)$//',-1,strip(&stem.));
				%undouble(stem);

				/* if preceded by ig then delete */
				if prxmatch('/(?<!e)ig$/',%r2) then do;
					&stem. = prxchange('s/ig$//',-1,strip(&stem.));
				end;
			end;
			
			/* -ig */
			else if prxmatch('/(?<!e)ig$/',%r2) then do;
				&stem. = prxchange('s/ig$//',-1,strip(&stem.));
			end;

			/* -lijk */
			else if prxmatch('/lijk$/',%r2)  then do;
				&stem. = prxchange('s/lijk$//',-1,strip(&stem.));

				/* Repeat step 2 */;
				if prxmatch('/[^aeiouyè]e$/',%r1) then do;
					&stem. = prxchange('s/(?<=[^aeiouyè])e$//',-1,strip(&stem.));
					%undouble(&stem.);
				end;
			end;

			/* -baar */
			else if prxmatch('/baar$/',%r2) then do;
				&stem. = prxchange('s/baar$//',-1,strip(&stem.));
			end;
			
			/* -bar */
			else if prxmatch('/bar$/',%r2) then do;
				&stem. = prxchange('s/bar$//',-1,strip(&stem.));
			end;


			/************** Step 4 **************/
			/* undouble vowel  */
			/* If the words ends CVD, where C is a non-vowel, D is a non-vowel other than I, 
			   and V is double a, e, o or u, remove one of the vowels from V */
			if prxmatch('/[^aeiouyè](aa|ee|oo|uu)[^aeiouyèI]$/',strip(&stem.)) then do;
				&stem. = cats(substr(strip(&stem.),1,length(strip(&stem.))-2),substr(strip(&stem.),length(strip(&stem.))));
			end;
			
			&stem. = lowcase(&stem.);

			drop _tmp_  r1_start r2_start;
		run;
	%end;
	%else %do;
		%put ERROR: &_error_msg.;
	%end;

	options &_notes.;
	%put Einde stemming macro (%sysfunc(strip(%sysfunc(time(),time8.))));
%mend txtstemming;
