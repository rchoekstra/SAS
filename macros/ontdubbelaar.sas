/** \macro ontdubbelaar
 * Ontdubbelt dataset waar dubbele records in zitten
 *
 * @param ds Dataset die ontdubbeld moet worden
 * @param by Record id (mag in output maar één keer voorkomen)
 * @param where Filter om ontdubbele alleen op specifieke records toe te passen
 * @author René Hoekstra
 */
%macro ontdubbelaar(ds, by, where);
	/* Welke hash functie moet er gebruikt worden: MD5 of CRCXX1 	*/
	/* CRCXX1 gebruikt slechts 8 bytes, md5 gebruikt 16 bytes. 		*/
	/* De xx eigenschap van MD5 is echter veel beter, omdat bij		*/
	/* CRC voor kan komen dat verschillende input resulteren in 	*/
	/* dezelfde output (digest) 									*/
	%let hash_func = MD5;

	/* Preprocessing van &by parameter om te gebruiken in cats()-functie*/
	%let by = %sysfunc(strip(&by.));		/* Spaties voor-/ en achteraan verwijderen */
	%let by = %sysfunc(compbl(&by.));		/* Dubbele spaties verwijderen */
	%let by = %sysfunc(tranwrd(&by, %str( ), %str(,)"_"%str(,))); /* Spaties vervangen door "_" */

	%let _err     = 0;
	%let _err_msg =;

	/* Controlleer of dataset bestaat */
	%if %sysfunc(exist(&ds.))=0 %then %do;
		%let _err_msg = Dataset (&ds.) bestaat niet;
		%let _err = 1;
		%goto exit;
	%end;

	/* Datastep waar m.b.v. modify records worden verwijderd */
	data &ds.;
		%if &hash_func. = MD5 %then %do; 
			length by_digest $16.;
			format by_digest hex32.;
		%end;
		%else %do;
			length by_digest 8.;
		%end;

		/* Hash object aanmaken om de digest van het record id in op te slaan */
		if _N_ = 1 then do;
			declare hash h();
			h.definekey('by_digest');
			h.definedone();
		end;

		/* Modify */
		modify &ds.;

		by_digest = &hash_func.(cats(&by.));

		/* Lookup conditioneel maken */
		%if "&where." ne "" %then %do;
			if &where. then do;
		%end;

			/* Digest bepalen van by variabelen (record id) */
			if h.find() = 0 then remove;	/* Verwijder record als deze al voorkomt in de hash */
			else h.add();					/* Voeg by_digest toe aan hash, omdat die nog niet voorkomt */

		%if "&where." ne "" %then %do;
			end;
		%end;
	run;

	%exit:
		%if &_err. ne 0 %then %put ERROR: &_err_msg.;
%mend ontdubbelaar;

/*
* Test dataset aanmaken. Eerste twee jaar (24obs) zitten dubbel in;
data test;
	set sashelp.air
		sashelp.air (obs= 24);
run;

%ontdubbelaar(test, date, date>='01JUL1949'd);	* Alle dubbelen vanaf jul '49 worden verwijderd: 18 records;
%ontdubbelaar(test, date);						* alle resterende dubbelen worden verwijderd;

*/