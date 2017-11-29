/** \macro dcreate
 * Maakt directories aan inclusief alle bovenliggende paden als deze niet bestaan.
 *
 * @param p Volledige pad
 * @author René Hoekstra
 */
%macro dcreate(p);
	%let _ERR = 0;
	%let _dcreate_debug = 0;

	%if "&p." eq "%str()" %then %do;
		%let _ERR = 1;
		%let _ERR_MSG = Geen directory opgegeven;
		%goto error;
	%end;
	/* _OS:			WINDOWS/UNIX
	 * _dirsep:		/(UNIX) of \(WINDOWS)
	 * _root:		root directory (/ voor UNIX, driveletter voor Windows, \\host\share voor UNC)
	 * _p: 			Path exclusief root
	 */
	%if "%sysfunc(substr(&p.,1,1))" eq "/" %then %do; /* UNIX Filesystem */
		%if &_dcreate_debug=1 %then %put UNIX Filesystem;
		%let _OS 		= UNIX;
		%let _dirsep 	=/;
		%let _root 		=/;
		%let _p 		= %sysfunc(substr(&p.,2));
	%end;
	%else %if "%sysfunc(substr(&p.,2,1))" eq ":" %then %do; /* Windows filesystem */
		%if &_dcreate_debug=1 %then %put Windows filesystem (driveletter);
		%let _OS 		= WINDOWS;
		%let _dirsep 	=\;	
		%let _root 		= %sysfunc(substr(&p.,1,3));	/* Driveletter met trailing \ */
		%let _p 		= %sysfunc(substr(&p.,4));		/* Path na eerste  \ */
	%end;
	%else %if "%sysfunc(substr(&p.,1,2))" eq "\\" %then %do; /* UNC Path */
		%if &_dcreate_debug=1 %then %put UNC path;
		%let _OS 		= WINDOWS;
		%let _dirsep 	=\;	

		data _null_;
			p = trim("&p.");
			patternID = prxparse('/[\\]{2}[a-zA-Z]+(\\)[a-zA-Z]+(\\)/');
			call prxsubstr(patternID,p, pos,len);

			_root = substr(p,pos,len);
			_p    = substr(p,len+1);

			call symput('_root', _root);
			call symput('_p'   , _p);
		run;
	%end;
	%else %do;
		%let _ERR 		= 1;
		%let _ERR_MSG 	= Onbekend OS;
		%goto error;
	%end;

	%if &_dcreate_debug=1 %then %do;
		%put OS:     &_OS.;
		%put dirsep: &_dirsep.;
		%put root:   &_root.;
		%put p:      &_p.;
	%end;

	/* Bepaal aantal directories, hou rekening met eventuele trailing slash */
	%if "%sysfunc( substr(&p,%sysfunc(length(&p)),1))"  eq "&_dirsep." %then %do;
		%if &_dcreate_debug=1 %then %put Trailing slash;
		%let numdir = %sysfunc(count(&_p.,&_dirsep.));
	%end;
	%else %do;
		%if &_dcreate_debug=1 %then %put Geen trailing slash;
		%let numdir = %eval(%sysfunc(count(&_p.,&_dirsep.))+1);
	%end;

	/* Macro vars voor eerste iteratie */
	%let parent = &_root.;

	/* Itereer door alle mappen */
	%do _i = 1 %to &numdir.;
		%if &_dcreate_debug. = 1 %then %put _i = &_i.;
		%if &_i. = &numdir. %then %do;								/* Uitzondering voor laatste iteratie */
			%if &_dcreate_debug. = 1 %then %put _i = numdir;
			%let cur_dir = &_p.;
		%end;
		%else %do;
			%if &_dcreate_debug. = 1 %then %put _i <> numdir;
			%let next_sep = %sysfunc(index(&_p.,&_dirsep));			/* Bepaal eerste volgende dir sep */
			%let cur_dir  = %sysfunc(substr(&_p.,1,&next_sep.));	/* Bepaal eerste directory */
		%end;

		%if &_dcreate_debug. = 1 %then %put cur_dir = &cur_dir.;

		%if %sysfunc(fileexist(&parent.&cur_dir.))=0 %then %do; 	/* Bepaal of directory reeds bestaat */
			%if &_dcreate_debug. = 1 %then %put Directory bestaat niet;
			%if %sysfunc(fileexist(&parent.))=1 %then %do;			/* Bepaal of parent bestaat */
				%if &_dcreate_debug. = 1 %then %put Parent bestaat;
				%let rc = %sysfunc(dcreate(&cur_dir.,&parent.));
				%put &rc. is aangemaakt;
			%end;
		%end;

		%if &_i. ne &numdir. %then %do;								/* Vervang parent en tijdelijke _p voor volgende iteratie */
			%let _p = %sysfunc(substr(&_p.,%eval(&next_sep.+1)));
			%let parent = &parent.&cur_dir.;
		%end;
	%end;

	%error:
		%if &_ERR=1 %then %do;
			%put ERROR: &_ERR_MSG.;
		%end;
%mend dcreate;