#!perl -w

use strict;
use Test::More tests => 1;

use Hash::FieldHash ();

my $content = do{
	local $/;
	open my $in, '<', $INC{'Hash/FieldHash.pm'};
	<$in>;
};

my($synopsis) = $content =~ m{
	^=head1 \s+ SYNOPSIS
	(.+)
	^=head1 \s+ DESCRIPTION
}xms;

ok eval("sub{ $synopsis }"), 'syntax ok' or diag $@;
