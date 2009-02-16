#!perl -w

use strict;
use Devel::LeakTrace::Fast;
use Hash::FieldHash qw(:all);

{
	fieldhash my %foo;
	fieldhash my %bar;

	{
		my $x = [];
		my $y = [];
		$foo{$x} = 10;
		$foo{$y} = 20;
	}
}

print "done.\n";
