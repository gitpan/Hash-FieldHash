use strict;
use warnings;
use inc::Module::Install;

name 'Hash-FieldHash';
all_from 'lib/Hash/FieldHash.pm';

requires 'Exporter' => 5.57;

test_requires 'Test::More'      => 0.62;
test_requires 'Test::LeakTrace' => 0.07;

tests 't/*.t t/*/*.t';
author_tests 'xt';

if($Module::Install::AUTHOR){
	makemaker_args DEFINE => '-DFIELDHASH_DEBUG';
}

WriteMakefile(
	OBJECT => '$(O_FILES)',

	depend => { '$(C_FILES)' => 'compat58.xsi' },

	clean  => {FILES => q(
		Hash-FieldHash-* *.stackdump
		*.gcda *.gcno *.gcov
		nytprof *.out
		cover_db
	)},
);
