#!perl -w

use strict;

use constant HAS_LEAKTRACE => eval q{use Test::LeakTrace 0.06; 1};
use Test::More HAS_LEAKTRACE ? (tests => 3) : (skip_all => 'require Test::LeakTrace');

use Hash::FieldHash qw(:all);

fieldhash my %hash;

no_leaks_ok{
	# NOTE: weaken({}) leaks an AV in 5.10.0, so I use [] in here.
	my $x = bless ['A'];
	my $y = ['B'];

	$hash{$x} = 'Hello';
	$hash{$y} = 0.5;
	$hash{$y}++ for 1 .. 10;
};

is_deeply \%hash, {};

no_leaks_ok{
	fieldhash my %h;

	for(1){
		my $o = [42];
		my $p = [3.14];
		$h{$o} = 100;
		$h{$p} = 200;
	}
};

