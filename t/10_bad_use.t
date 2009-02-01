#!perl -w

use strict;
use Test::More tests => 4;

#use Hash::Util::FieldHash::Compat qw(fieldhash fieldhashes);
use Hash::FieldHash qw(:all);
use Scalar::Util qw(refaddr);

fieldhash my %hash;

eval{
	$hash{foo}++; 
};
ok $@;

eval{
	fieldhashes [];
};
ok $@;

my $o = {foo => 'bar'};
{
	fieldhash my %hash;
	$hash{$o} = 42;
}

is_deeply $o, {foo => 'bar'};

{
	my %hash = (foo => 'bar');
	fieldhash %hash;
	fieldhash %hash;

	is_deeply \%hash, {};
}