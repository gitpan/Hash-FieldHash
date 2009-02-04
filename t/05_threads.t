#!perl -w

use strict;
use constant HAS_THREADS => eval{ require threads };
use Test::More;

BEGIN{
	if(HAS_THREADS){
		plan tests => 14;
	}
	else{
		plan skip_all => 'require threads';
	}
}

use threads;

use Hash::FieldHash qw(:all);

fieldhashes \my(%a, %b);

{
	my $x = {};
	my $y = {};

	$a{$x} = 'a-x';
	$a{$y} = 'a-y';
	$b{$x} = 'b-x';
	$b{$y} = 'b-y';

	my $thr = async {
		is $a{$x}, 'a-x';
		is $a{$y}, 'a-y';
		is $b{$x}, 'b-x';
		is $b{$y}, 'b-y';

		my $thr = async{
			is $a{$x}, 'a-x';
			$a{$x} = 3.14;

			threads->yield();
			is $a{$x}, 3.14;
		};

		is $a{$x}, 'a-x';

		my $z = {};

		threads->yield();

		is $a{$x}, 'a-x';

		$a{$z} = 42;
		is $a{$z}, 42;

		$thr->join();
	};

	is_deeply [sort values %a], [sort 'a-x', 'a-y'];

	threads->yield();

	{
		my $z = {};
		$a{$z} = 'a-z';

		is_deeply [sort values %a], [sort 'a-x', 'a-y', 'a-z'];
	}

	$thr->join;

	is_deeply [sort values %a], [sort 'a-x', 'a-y'];
}

is_deeply \%a, {};
is_deeply \%b, {};
