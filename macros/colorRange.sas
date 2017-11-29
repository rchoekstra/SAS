/** \macro colorrange
 * Genereert pattern statement met meerdere kleuren. De kleuren vormen een gradient van </i>rgb1</i> naar <i>rgb2</i>.
 *
 * @param rgb1 Hexadecimale waarde voor start van gradient (CXRRGGBB of RRGGBB)
 * @param rgb2 Hexadecimale waarde voor eind van gradient (CXRRGGBB of RRGGBB)
 * @param steps Aantal stappen van de gradient
 * @param start Startwaarde van pattern&lt;n&gt;
 * @author René Hoekstra
 */
%macro colorrange(rgb1,rgb2,steps,start);
	%let notes=%sysfunc(getoption(notes)) ; 

	%if %sysfunc(lowcase(%substr(&rgb1.,1,2)))=cx %then %let rgb1=%substr(&rgb1.,3,6);
	%if %sysfunc(lowcase(%substr(&rgb2.,1,2)))=cx %then %let rgb2=%substr(&rgb2.,3,6);

	%let r1=%sysfunc(inputn(%substr(&rgb1.,1,2),hex2.));
	%let g1=%sysfunc(inputn(%substr(&rgb1.,3,2),hex2.));
	%let b1=%sysfunc(inputn(%substr(&rgb1.,5,2),hex2.));
	%let r2=%sysfunc(inputn(%substr(&rgb2.,1,2),hex2.));
	%let g2=%sysfunc(inputn(%substr(&rgb2.,3,2),hex2.));
	%let b2=%sysfunc(inputn(%substr(&rgb2.,5,2),hex2.));

	option nonotes;
	data _null_;
		format n best.;
		retain n;

		%if &start.>0 %then %do; n=&start.-1; %end;
		%else %do; n=0; %end;

		do i = 0 to &steps.-1;
			n=n+1;
			r   = round(&r1.+(&r2.-&r1.)/(&steps.-1)*i,1);
			g   = round(&g1.+(&g2.-&g1.)/(&steps.-1)*i,1);
			b   = round(&b1.+(&b2.-&b1.)/(&steps.-1)*i,1);

			if r > 255 then r = 255;
			if r < 0   then r = 0;
			if g > 255 then g = 255;
			if g < 0   then g = 0;
			if b > 255 then b = 255;
			if b < 0   then b = 0;

			rgb = cats('CX',put(r,hex2.),put(g,hex2.),put(b,hex2.));
			pattern=cats('pattern',put(n,best.)) || ' v=s ' || cats('c=',rgb,';');
			call execute(pattern);
			put pattern;
			output;
		end;
	run;
	option &notes.;
%mend colorrange;
