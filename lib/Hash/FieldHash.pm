package Hash::FieldHash;

use 5.008_001;
use strict;

our $VERSION = '0.06';

use Exporter qw(import);
our @EXPORT_OK   = qw(fieldhash fieldhashes);
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

=for stopwords uvar CPAN

=head1 NAME

Hash::FieldHash - A lightweight field hash implementation

=head1 VERSION

This document describes Hash::FieldHash version 0.06.

=head1 SYNOPSIS

	use Hash::FieldHash qw(:all);

	fieldhash my %foo;

	fieldhashes \my(%bar, %baz);

	{
		my $o = Something->new();

		$foo{$o} = 42;

		print $foo{$o}; # => 42
	}
	# when $o is released, $foo{$o} is also deleted,
	# so %foo is empty in here.

=head1 DESCRIPTION

C<Hash::FieldHash> provides the field hash mechanism which supports
the inside-out technique.

You may know C<Hash::Util::FieldHash>. It's a very useful module,
but too complex to understand all the functions and only available in 5.10.
C<H::U::F::Compat> is available for pre-5.10, but it seems too slow to use.

This is an alternative to C<H::U::F> with following features:

=over 4

=item Simpler interface

C<Hash::FieldHash> provides a few functions:  C<fieldhash()> and C<fieldhashes()>.
That's enough.

=item Higher performance

C<Hash::FieldHash> is faster than C<Hash::Util::FieldHash>, because
its internals use simpler structures.

=item Relic support

Although C<Hash::FieldHash> uses a new feature introduced in Perl 5.10,
I<the uvar magic for hashes> described in L<Hash::Util::Fieldhash/"GUTS">,
it supports Perl 5.8 using the traditional tie-hash layer.

=back

=head1 INTERFACE

=head2 Exportable functions

=over 4

=item C<< fieldhash(%hash, ?$name, ?$package) >>

Creates a field hash. The first argument must be a hash.

Optional I<$name> and I<$package> indicate the name of the field, which will
create rw-accessors, using the same name as I<$name>.

Returns nothing.

=item C<< fieldhashes(@hash_refs) >>

Creates a number of field hashes. All the arguments must be hash references.

Returns nothing.

=back

=head2 Non-exportable functions

=over 4

=item C<< Hash::FieldHash::from_hash($object, \%fields) >>

Fills the named fields associated with I<$object> with I<%fields>.

Returns I<$object>.

=item C<< Hash::FieldHash::to_hash($object) >>

Serializes I<$object> into a hash reference.

=back

=head1 ROBUSTNESS

=head2 Thread support

As C<Hash::Util::FieldHash> does, C<Hash::FieldHash> fully supports threading
using the C<CLONE> method.

=head2 Memory leaks

C<Hash::FieldHash> itself does not leak memory, but it may leak memory when
you uses hash references as field hash keys because of an issue of perl 5.10.0.

=head1 NOTES

=head2 The type of field hash keys

C<Hash::FieldHash> accepts only references and registered addresses as its
keys, whereas C<Hash::Util::FieldHash> accepts any type of scalars.

According to L<Hash::Util::FieldHash/"The Generic Object">,
Non-reference keys in C<H::U::F> are used for class fields. That is,
all the fields defined by C<H::U::F> act as both object fields and class fields
by default. It seems confusing; if you do not want them to be class fields,
you must check the type of I<$self> explicitly. In addition,
these class fields are never inherited.
This behavior seems problematic, so C<Hash::FieldHash>
restricts the type of keys.

=head2 The ID of field hash keys

While C<Hash::Util::FieldHash> uses C<refaddr> as the IDs of field
hash keys, C<Hash::FieldHash> allocates arbitrary integers as the
IDs.

=head1 DEPENDENCIES

Perl 5.8.1 or later, and a C compiler.

=head1 BUGS

No bugs have been reported.

Please report any bugs or feature requests to the author.

=head1 SEE ALSO

L<Hash::Util::FieldHash>.

L<Hash::Util::FieldHash::Compat>.

L<perlguts/"Magic Virtual Tables">.

L<Class::Std> describes the inside-out technique.

=head1 AUTHOR

Goro Fuji E<lt>gfuji(at)cpan.orgE<gt>.

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2009, Goro Fuji. Some rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
