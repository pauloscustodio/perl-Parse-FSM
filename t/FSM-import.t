#!perl

# $Id: expression.t,v 1.5 2010/10/01 11:02:26 Paulo Exp $

use strict;
use warnings;

use Test::More;
use Capture::Tiny 'capture';

my($stdout, $stderr, $ok);

#------------------------------------------------------------------------------
# fails with missing arguments
unlink 'Parser.pm';
($stdout, $stderr) = capture {
	$ok = ! system $^X, qw(-Iblib/lib -MParse::FSM -);
};
is $stdout, "";
is $stderr, "Usage: perl -MParse::FSM - GRAMMAR MODULE::NAME [MODULE/NAME.pm]\n";
ok !$ok;
ok ! -f 'Parser.pm';

#------------------------------------------------------------------------------
# fails with missing arguments
unlink 'Parser.pm';
($stdout, $stderr) = capture {
	$ok = ! system $^X, qw(-Iblib/lib -MParse::FSM - t/data/calc.yp);
};
is $stdout, "";
is $stderr, "Usage: perl -MParse::FSM - GRAMMAR MODULE::NAME [MODULE/NAME.pm]\n";
ok !$ok;
ok ! -f 'Parser.pm';

#------------------------------------------------------------------------------
# fails with too many arguments
unlink 'Parser.pm';
($stdout, $stderr) = capture {
	$ok = ! system $^X, qw(-Iblib/lib -MParse::FSM - t/data/calc.yp mod file x);
};
is $stdout, "";
is $stderr, "Usage: perl -MParse::FSM - GRAMMAR MODULE::NAME [MODULE/NAME.pm]\n";
ok !$ok;
ok ! -f 'Parser.pm';

#------------------------------------------------------------------------------
# Create with default file
unlink 'Parser.pm';
($stdout, $stderr) = capture {
	$ok = ! system $^X, qw(-Iblib/lib -MParse::FSM - 
						   t/data/calc.yp Parser);
};
is $stdout, "";
is $stderr, "";
ok $ok;
ok -f 'Parser.pm';

# use the generated parser
($stdout, $stderr) = capture {
	$ok = ! system $^X, qw(-Iblib/lib Parser.pm 1+2;2+3*4);
};
is $stdout, "[3, 14]\n";
is $stderr, "";
ok $ok;

# use the generated parser
($stdout, $stderr) = capture {
	$ok = ! system $^X, qw(-Iblib/lib -MParser -e),
						'$x=Parser->new->run(shift);print(join(q/,/,@$x))',
						'1+2;2+3*4';
};
is $stdout, "3,14";
is $stderr, "";
ok $ok;
ok unlink 'Parser.pm';

#------------------------------------------------------------------------------
# Create with default file in subdir
unlink 't/data/Parser.pm';
($stdout, $stderr) = capture {
	$ok = ! system $^X, qw(-Iblib/lib -MParse::FSM - 
						   t/data/calc.yp t::data::Parser);
};
is $stdout, "";
is $stderr, "";
ok $ok;
ok -f 't/data/Parser.pm';

# use the generated parser
($stdout, $stderr) = capture {
	$ok = ! system $^X, qw(-Iblib/lib t/data/Parser.pm 1+2;2+3*4);
};
is $stdout, "[3, 14]\n";
is $stderr, "";
ok $ok;

# use the generated parser
($stdout, $stderr) = capture {
	$ok = ! system $^X, qw(-Iblib/lib -Mt::data::Parser -e),
				'$x=t::data::Parser->new->run(shift);print(join(q/,/,@$x))',
				'1+2;2+3*4';
};
is $stdout, "3,14";
is $stderr, "";
ok $ok;
ok unlink 't/data/Parser.pm';

#------------------------------------------------------------------------------
# Create with supplied file name
unlink 't/data/Parser.pm';
($stdout, $stderr) = capture {
	$ok = ! system $^X, qw(-Iblib/lib -MParse::FSM - 
						   t/data/calc.yp Parser t/data/Parser.pm);
};
is $stdout, "";
is $stderr, "";
ok $ok;
ok -f 't/data/Parser.pm';

# use the generated parser
($stdout, $stderr) = capture {
	$ok = ! system $^X, qw(-Iblib/lib t/data/Parser.pm 1+2;2+3*4);
};
is $stdout, "[3, 14]\n";
is $stderr, "";
ok $ok;

# use the generated parser
($stdout, $stderr) = capture {
	$ok = ! system $^X, qw(-Iblib/lib -It/data -MParser -e),
				'$x=Parser->new->run(shift);print(join(q/,/,@$x))',
				'1+2;2+3*4';
};
is $stdout, "3,14";
is $stderr, "";
ok $ok;
ok unlink 't/data/Parser.pm';

#------------------------------------------------------------------------------
done_testing;
