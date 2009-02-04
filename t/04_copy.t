#!perl -w

use strict;
use Test::More tests => 8;

use Hash::FieldHash qw(:all);

fieldhashes \my(%a, %b);

{
	my $o = {};
	my $p = {};
	$a{$o} = 42;
	$a{$p} = 3.14;
	%b = %a;

	is_deeply [sort values %a], [sort 42, 3.14];
	is_deeply [sort values %b], [sort 42, 3.14];

	$a{$o}++;
	is_deeply [sort values %a], [sort 43, 3.14];
	is_deeply [sort values %b], [sort 42, 3.14];

	%b = %a;
	is_deeply [sort values %a], [sort 43, 3.14];
	is_deeply [sort values %b], [sort 43, 3.14];
}

is_deeply \%a, {};
is_deeply \%b, {};
