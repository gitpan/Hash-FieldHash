#!perl -w

use strict;
use Test::More tests => 12;

use Scalar::Util qw(refaddr);

#use Hash::Util::FieldHash::Compat qw(fieldhash fieldhashes);
use Hash::FieldHash qw(:all);


fieldhash my %hash;
fieldhash our %ghash;

ok !scalar(%hash);

my $r = {};
$hash{$r}++;
$ghash{$r} = 'g';

ok scalar(%hash);

is_deeply \%ghash, { refaddr($r) => 'g' };

{
	my $o = bless {};
	my $x = [];

	$hash{$o} = 10;

	is $hash{$o}, 10;

	$hash{$x} = 42;

	is $hash{$o}, 10;
	is $hash{$x}, 42;

	is_deeply \%hash, {
		refaddr($r) => 1,
		refaddr($o) => 10,
		refaddr($x) => 42,
	};
}

is_deeply \%hash , {refaddr($r) => 1};

{
	my $o = bless {};

	$hash{$o} = 10;

	is $hash{$o}, 10;
}

is_deeply \%hash , {refaddr($r) => 1};

undef $r;

is_deeply \%hash, {};
is_deeply \%ghash, {};
