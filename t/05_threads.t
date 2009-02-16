#!perl -w

use strict;
use constant HAS_THREADS => eval{ require threads };
use Test::More;

BEGIN{
	if(HAS_THREADS){
		plan tests => 15*3;
	}
	else{
		plan skip_all => 'require threads';
	}
}
use threads;

#use Hash::Util::FieldHash::Compat qw(:all);
use Hash::FieldHash qw(:all);

for(1 .. 3){
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

				threads->yield();
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

		ok $thr, sprintf 'count=%d, tid=%d', $_, $thr->tid;

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
}

