/** \macro nullto0
 * Vervangt missing values (null) door 0
 *
 * @param ds Dataset
 * @author René Hoekstra
 */
%macro nullto0(ds);
	data &ds.;
		modify &ds.;

		array _num_ _numeric_;

		repl = 0;

		do over _num_;
			if missing(_num_) then do;
				_num_=0;
				repl = 1;
			end;
		end;
		if repl then replace;
	run;
%mend nullto0;