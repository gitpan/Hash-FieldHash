#!perl -w

use strict;
use Test::More tests => 7;

use Hash::FieldHash qw(:all);

fieldhash my %hash;

my $r = {};

ok !delete $hash{$r};
is_deeply \%hash, {};

ok !exists $hash{$r};
is_deeply \%hash, {};

ok !$hash{$r};
is_deeply \%hash, {};

my $dummy = $hash{$r};
is_deeply \%hash, {};
