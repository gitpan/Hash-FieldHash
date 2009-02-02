#!perl -w

use strict;
use Test::More tests => 2;
use Scalar::Util qw(refaddr);

#use Hash::Util::FieldHash::Compat qw(fieldhash fieldhashes);
use Hash::FieldHash qw(:all);

fieldhash my %hash;

{
	my $o = {};

	$hash{$o} = 42;

	{
		local $hash{$o} = 'localized';

		is_deeply \%hash, {refaddr($o) => 'localized'};
	}

	is $hash{$o}, 42;
}
