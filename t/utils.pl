#!perl

use strict;
use warnings;

#------------------------------------------------------------------------------
# lexer
sub make_lexer {
	my($_) = @_;

	return sub {
		/\G[ \t]+/gc;
		return [NUM  => $1] if /\G(\d+)/gc;
		return [NAME => $1] if /\G([a-z]\w*)/gci;
		return [$1   => $1] if /\G(.)/gcs;
		return;
	};
}

1;
