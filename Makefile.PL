use strict;
use warnings;
use inc::Module::Install;
use Config;

name 'Hash-FieldHash';
all_from 'lib/Hash/FieldHash.pm';

test_requires 'Test::More' => 0.62;

tests 't/*.t t/*/*.t';
author_tests 'xt';

#sub slink{
#	my($src, $dst) = @_;
#	if($Config{d_symlink} eq 'define'){
#		symlink $src, $dst or die $!;
#	}
#	else{
#		require File::Copy;
#		File::Copy::copy($src, $dst) or die $!;
#	}
#}
#
#if($] >= 5.010){
#	slink 'xs/FieldHash.xs' => 'FieldHash.xs';
#}
#else{
#	slink 'xs/FieldHash58.xs' => 'FieldHash58.xs';
#}

WriteMakefile(
	OBJECT => '$(O_FILES)',

	depend => { '$(BASEEXT)$(OBJEXT)' => '$(BASEEXT).xsi' },

	clean  => {FILES => q(
		Hash-FieldHash-* *.stackdump
		*.gcda *.gcno *.gcov
		nytprof *.out
		cover_db
	)},
);
