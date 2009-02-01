package Hash::FieldHash;

use 5.008_001;
use strict;

our $VERSION = '0.01';

use Exporter qw(import);
our @EXPORT_OK = qw(fieldhash fieldhashes);
our %EXPORT_TAGS = (all => \@EXPORT_OK);


use XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

sub fieldhashes{
	foreach my $hash_ref(@_){
		&fieldhash($hash_ref);
	}
}

1;
__END__

=head1 NAME

Hash::FieldHash - A lightweight fieldhash implementation

=head1 VERSION

This document describes Hash::FieldHash version 0.01.

=head1 SYNOPSIS

	use Hash::FieldHash qw(:all);

	fieldhash my %foo;

	fieldhashes \my(%bar, %baz);

	{
		my $o = Something->new();

		$foo{$o} = 42;

		print $foo{$o}; # => 42
	}

	# now %foo is empty because $o is released

=head1 DESCRIPTION

C<Hash::FieldHash> provides the field hash mechanism which supports
the inside-out technique.

You may know C<Hash::Util::FieldHash>. It's very useful module,
but too complex to understand all the features and only available in 5.10.
For pre-5.10, C<Hash::Util::FieldHash::Compat> may be available, but
it's too slow to use.

This is compatible with C<H::U::F>, having simple interface
and available in pre-5.10.

=head1 INTERFACE

=head2 Exportable functions

=over 4

=item C<< fieldhash(%hash) >>

Creates a field hash. The argument must be a hash.

Returns nothing.

=item C<< fieldhashes(@hash_refs) >>

Creates any number of field hashes. All the arguments must be hash references.

Returns nothing.

=back

=head1 FEATURES

=head2 Thread support

C<Hash::FieldHash> fully supports threading using the C<CLONE> method.

=head2 Relic support

Although C<Hash::FieldHash> uses new features introduced in Perl 5.10,
it also supports Perl 5.8 using the traditional tie-hash interface.

=head1 INCOMPATIBILITY

C<Hash::FieldHash> accepts only references and registered addresses as its
keys, while C<Hash::Util::FieldHash> accepts any scalars.

According to L<Hash::Util::FieldHash/"The Generic Object">,
Non-reference keys in C<H::U::F> are used for class fields. That is,
all the fields defined by C<H::U::F> act as both object fields and class fields
by default. If you do not want a class field, you must check the type
of I<$self> explicitly. In addition, these class fields are never inherited.
This function of C<H::U::F> seems erroneous, so C<Hash::FieldHash>
refuses non-reference keys.

=head1 DEPENDENCIES

Perl 5.8.1 or later, and a C compiler.

=head1 BUGS

No bugs have been reported.

Please report any bugs or feature requests to the author.

=head1 SEE ALSO

L<Hash::Util::FieldHash>.

L<perlguts>.

=head1 AUTHOR

Goro Fuji E<lt>gfuji(at)cpan.orgE<gt>.

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2009, Goro Fuji. Some rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
