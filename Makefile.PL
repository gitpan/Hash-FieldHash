use strict;
use warnings;
use inc::Module::Install;

name 'Hash-FieldHash';
all_from 'lib/Hash/FieldHash.pm';

requires 'Exporter' => 5.57;

test_requires 'Test::More' => 0.62;

tests 't/*.t t/*/*.t';
author_tests 'xt';

WriteMakefile(
	OBJECT => '$(O_FILES)',

	depend => { '$(O_FILES)' => 'compat58.xsi' },

	clean  => {FILES => q(
		Hash-FieldHash-* *.stackdump
		*.gcda *.gcno *.gcov
		nytprof *.out
		cover_db
	)},
);
