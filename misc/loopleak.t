#!perl -w

use strict;
use Hash::FieldHash qw(:all);

{
	fieldhash my %foo;

	for(1 .. 100_000_000){
		my $x = [];
		$foo{$x} = 10;

	}
}

print "done.\n";
