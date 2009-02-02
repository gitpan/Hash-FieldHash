#!perl -w

use strict;
use Test::More tests => 10;
use Scalar::Util qw(refaddr);

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

ok !delete $hash{refaddr $r};
ok !exists $hash{refaddr $r};
ok !$hash{refaddr $r};
