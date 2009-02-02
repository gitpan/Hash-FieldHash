#!perl -w

use strict;
use Test::More tests => 8;

use Hash::FieldHash qw(:all);
use Scalar::Util qw(refaddr);

fieldhashes \my(%a, %b);

{
	my $o = {};
	$a{$o} = 42;
	%b = %a;

	is_deeply \%a, {refaddr($o) => 42};
	is_deeply \%b, {refaddr($o) => 42};

	$a{$o}++;
	is_deeply \%a, {refaddr($o) => 43};
	is_deeply \%b, {refaddr($o) => 42};

	%b = %a;
	is_deeply \%a, {refaddr($o) => 43};
	is_deeply \%b, {refaddr($o) => 43};
}

is_deeply \%a, {};
is_deeply \%b, {};
