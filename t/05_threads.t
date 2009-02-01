#!perl -w

use strict;
use constant HAS_THREADS => eval{ require threads };
use Test::More;

BEGIN{
	if(HAS_THREADS){
		plan tests => 11;
	}
	else{
		plan skip_all => 'require threads';
	}
}

use threads;

use Hash::FieldHash qw(:all);
use Scalar::Util qw(refaddr);

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

		async{
			is $a{$x}, 'a-x';
			$a{$x} = 3.14;
			is $a{$x}, 3.14;
		}->join();

		is $a{$x}, 'a-x';

		my $z = {};
		$a{$z} = 42;
		is $a{$z}, 42;
	};

	is_deeply \%a, {
		refaddr($x) => 'a-x',
		refaddr($y) => 'a-y',
	};

	$thr->join;
}

is_deeply \%a, {};
is_deeply \%b, {};
