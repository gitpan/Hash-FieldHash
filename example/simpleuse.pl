#!perl -w
use strict;

use Hash::FieldHash qw(:all);
use Data::Dumper;

fieldhashes \my(%foo, %bar);;

{
	my $o = [42];
	my $x = {};
	$foo{$o} = 3.14;
	$bar{$o} = 1.14;

	$foo{$x} = 'x.foo';
	$bar{$x} = 'x.bar';

	print "inside the scope:\n";
	print Data::Dumper->Dump([\%foo, \%bar], [qw(*foo *bar)]);

	print Data::Dumper->Dump([Hash::FieldHash::get_associated_fieldhashes $o]);
}

print "outside the scope:\n";
print Data::Dumper->Dump([\%foo, \%bar], [qw(*foo *bar)]);

