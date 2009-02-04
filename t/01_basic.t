#!perl -w

use strict;
use Test::More tests => 15;

#use Hash::Util::FieldHash::Compat qw(fieldhash fieldhashes);
use Hash::FieldHash qw(:all);


fieldhash my %hash;
fieldhash our %ghash;

ok !scalar(%hash);

my $r = {};
$hash{$r} = 'r';
$ghash{$r} = 'g';

ok scalar(%hash);

is_deeply [values %hash],  ['r'];
is_deeply [values %ghash], ['g'];

{
	my $o = bless {};
	my $x = [];

	$hash{$o} = 10;

	is $hash{$o}, 10;

	$hash{$x} = 42;

	is $hash{$o}, 10;
	is $hash{$x}, 42;

	is_deeply [sort values %hash], [sort('r', 10, 42)];

}

is_deeply [values %hash],  ['r'];
is_deeply [values %ghash], ['g'];

{
	my $o = bless {};

	$hash{$o} = 10;

	is $hash{$o}, 10;
}

is_deeply [values %hash],  ['r'];
is_deeply [values %ghash], ['g'];

undef $r;

is_deeply \%hash, {};
is_deeply \%ghash, {};

#use Data::Dumper;
#print Dumper *{$Hash::FieldHash::{'::OBJECT_REGISTRY'}}{ARRAY};
