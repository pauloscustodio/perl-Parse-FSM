# $Id: Driver.pm,v 1.1 2011/04/16 20:20:42 Paulo Exp $

package Parse::FSM::Driver;

#------------------------------------------------------------------------------

=head1 NAME

Parse::FSM::Driver - Run-time engine for Parse::FSM parser

=cut

#------------------------------------------------------------------------------

use warnings;
use strict;

use Carp; our @CARP_NOT = ('Parse::FSM::Driver');
use Data::Dump 'dump';

our $VERSION = '1.01';

#------------------------------------------------------------------------------

=head1 SYNOPSIS

  use MyParser; # isa Parse::FSM::Driver
  
  $parser = MyParser->new;
  $parser->input( \&lexer );
  $parser->user( $user_pointer );
  
  $result = $parser->parse( $start_rule );
  $result = $parser->parse_start_rule;
  
  $token = $parser->peek_token;
  $token = $parser->get_token;
  $parser->unget_token(@tokens);

=head1 DESCRIPTION

This modules implements a deterministic top-down parser based on a 
pre-computed Finite State Machine (FSM). 

The FSM is generated by L<Parse::FSM|Parse::FSM>, by 
reading a BNF-type grammar file and generating
a run-time module that includes the state tables. The module also include 
the run-time parsing routine that follows the state tables to obtain 
a parse of the input. 

This module is not intended to be used stand alone. It is used as a base class
by the modules generated by L<Parse::FSM|Parse::FSM>.

=head1 METHODS - SETUP

=head2 new

Creates a new object.

=head2 user

Get/set of the parser user pointer. The user pointer is not used by the parser,
and is available for communication between the parser actions and the 
calling module.

It can for example point to a data structure that describes the objects 
already identified in the parse.

=cut

#------------------------------------------------------------------------------
# Parsing state machine
# Each state hash has:
# 	terminal => (state ID), for a match
# 	terminal => [ (subrule ID), (next state ID) ], for a sub-rule 
#				followed by a match
# 	terminal => [ (subrule ID), sub{} ], for a sub-rule followed by an accept
# 	terminal => sub{}, for an accept
# Each sub{} has $self and @args pre-declared
# @args is [] of all parsed elements
# $self is the Parse::FSM::Driver object

#------------------------------------------------------------------------------
use Class::XSAccessor {
	constructor => '_init',
	accessors => [
		'input',			# input iterator
		'_head',			# unget queue of tokens retrived from input
		'user',				# user pointer
		'_state_table',		# list of states
		'_start_state',		# ID of start state
	],
};

#------------------------------------------------------------------------------
sub new {
	my($class, @args) = @_;
	return $class->_init(
		input 		 => sub {}, 
		_head		 => [],
		user		 => {},
		_state_table => [], 
		_start_state => 0,
		@args);
}
#------------------------------------------------------------------------------

=head1 METHODS - INPUT STREAM

=head2 input

Get/set the parser input lexer iterator. The iterator is a code reference of
a function that returns the next token to be parsed as an array ref, 
with token type and token value C<[$type, $value]>. 
It returns C<undef> on end of input. E.g. for a simple expression lexer:

  sub make_lexer {
    my($_) = @_;
    return sub {
      /\G\s+/gc;
      return [NUM  => $1] if /\G(\d+)/gc;
      return [NAME => $1] if /\G([a-z]\w*)/gci;
      return [$1   => $1] if /\G(.)/gc;
      return;
    };
  }
  $parser->input(make_lexer("2+3*4"));

=head2 peek_token 

Returns the next token to be retrieved by the lexer, but keeps it in the input
queue. Can be used by a rule action to decide based on the input that follows.

=cut

#------------------------------------------------------------------------------
sub peek_token {
	my($self) = @_;
	@{$self->_head} or push @{$self->_head}, $self->input->();
	return $self->_head->[0];		# may be undef, if end of input
}
#------------------------------------------------------------------------------

=head2 get_token 

Extracts the next token from the lexer stream. Can be used by a rule action to
discard the following tokens.

=cut

#------------------------------------------------------------------------------
sub get_token {
	my($self) = @_;
	@{$self->_head} and return shift @{$self->_head};
	return $self->_head->[0];		# may be undef, if end of input
}
#------------------------------------------------------------------------------

=head2 unget_token

Pushes back the given list of tokens to the lexer input stream, to be retrieved
on the next calls to C<get_token>.

=cut

#------------------------------------------------------------------------------
sub unget_token {
	my($self, @tokens) = @_;
	unshift @{$self->_head}, @tokens;
	return;
}
#------------------------------------------------------------------------------

=head1 METHODS - PARSING

=head2 parse

This function receives an optional start rule name, and uses the default rule
of the grammar if not supplied.

It parses the input stream, leaving the stream at the first unparsed
token, and returns the parse value - the result of the action function for the 
start rule.

The function dies with an error message indicating the input that cannot 
be parsed in case of a parse error.

=head2 parse_XXX

For each rule C<XXX> in the grammar, L<Parse::FSM|Parse::FSM> creates a correspnding
C<parse_XXX> to start the parse at that rule. This is a short-cut to 
C<parse('XXX')>.

=cut

#------------------------------------------------------------------------------
sub parse {
	my($self, $start_rule) = @_;

	# current state
	my $state;
	if (defined($start_rule)) {
		$state = $self->_state_table->[0]{$start_rule}
					or croak "Rule $start_rule not found";
	}
	else {
		$state = $self->_start_state
					or croak "Start state not found";
	}
	return $self->_parse($state);
}

#------------------------------------------------------------------------------
sub _parse {
	my($self, $state) = @_;
	
	my @values = ();
	
	# return stack of states
	my @stack = ();					# store: [$state, @values]

	# fetch token only after drop and after calling parser rules
	my $token = $self->peek_token;
	while (1) {
		my($entry, $found_else);
		if ($entry = $self->_state_table->[$state]{($token ? $token->[0] : "")}) {
			# entry exists, found token
		}
		elsif ($entry = $self->_state_table->[$state]{__else__}) {
			$found_else++;
		}
		else {
			$self->_error_at($token, $state);
		}
		
		if (ref($entry) eq 'ARRAY') {					# call sub-rule
			my($next_state, $return_state) = @$entry;
			push(@stack, [ $return_state, @values ]);	# return data
			($state, @values) = ($next_state);			# call
		}
		else {											# accept token
			$state = $entry;
			
			if (!$found_else) {
				push(@values, $token) if $token;		# add token to values
				$self->get_token;						# drop value
				$token = $self->peek_token;				# and get next token
			}

			while (ref($state) eq 'CODE') {				# return from sub-rules 
				my $value = $self->$state(@values);
				$token = $self->peek_token;				# input may have changed

				if ( ! @stack ) {						# END OF PARSE
					return $value;
				}
				
				my $top = pop(@stack);
				($state, @values) = @$top;
				
				# keep only defined values
				push(@values, $value) if defined($value);
			}
		}
	}
	die 'not reached';
}

#------------------------------------------------------------------------------
# expected error at given stream position, die with error message
sub _error_at { 
	my($self, $token, $state) = @_;
	
	my @expected = sort map {_format_token($_)} 
							keys %{$self->_state_table->[$state]};
	die("Expected ",
		scalar(@expected) == 1 ? "@expected" : "one of (@expected)",
		" at ",
		defined($token) ? _format_token($token->[0]) : "EOF",
		"\n");
}

#------------------------------------------------------------------------------
# format a token 
sub _format_token {
	my($token) = @_;
	return "" 			if !defined($token);
	return "EOF" if $token eq "";
	return dump($token) if $token =~ /\W/;
	return $token;
}
#------------------------------------------------------------------------------

=head1 AUTHOR, BUGS, FEEDBACK, LICENSE, COPYRIGHT

See L<Parse::FSM|Parse::FSM>

=cut

#------------------------------------------------------------------------------

1;
