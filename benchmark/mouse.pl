#!perl -w
use strict;
use Benchmark qw(:all);

BEGIN{
	package M;
	use Mouse;

	has foo => (
		is => 'rw',
	);
	has bar => (
		is => 'rw',
	);
	has baz => (
		is => 'rw',
	);
	__PACKAGE__->meta->make_immutable;
}
BEGIN{
	package HF;
	use Hash::FieldHash qw(:all);
	fieldhashes \my(%foo, %bar, %baz);

	sub new{ bless {}, shift }

	sub foo{
		my $self = shift;
		@_ ? ($foo{$self} = shift) : $foo{$self}
	}
	sub bar{
		my $self = shift;
		@_ ? ($bar{$self} = shift) : $bar{$self}
	}
	sub baz{
		my $self = shift;
		@_ ? ($baz{$self} = shift) : $baz{$self}
	}
}
BEGIN{
	package HUF;
	use Hash::Util::FieldHash::Compat qw(:all);
	fieldhashes \my(%foo, %bar, %baz);

	sub new{ bless {}, shift }

	sub foo{
		my $self = shift;
		@_ ? ($foo{$self} = shift) : $foo{$self}
	}
	sub bar{
		my $self = shift;
		@_ ? ($bar{$self} = shift) : $bar{$self}
	}
	sub baz{
		my $self = shift;
		@_ ? ($baz{$self} = shift) : $baz{$self}
	}
}

print "new, and access(read:write 2:4)*100\n";
cmpthese timethese -1 => {
	'H::F' => sub{
		my $o = HF->new();
		for(1 .. 100){
			$o->foo($_);
			$o->bar($o->foo + $o->foo + $o->foo + $o->foo);
		}
	},
	'H::U::F' => sub{
		my $o = HUF->new();
		for(1 .. 100){
			$o->foo($_);
			$o->bar($o->foo + $o->foo + $o->foo + $o->foo);
		}
	},
	'Mouse' => sub{
		my $o = M->new();
		for(1 .. 100){
			$o->foo($_);
			$o->bar($o->foo + $o->foo + $o->foo + $o->foo);
		}
	},
};

my $hf  = HF->new();
my $huf = HUF->new();
my $m   = M->new();
print "access(read:write 2:4)*100\n";
cmpthese timethese -1 => {
	'H::F' => sub{
		for(1 .. 100){
			$hf->foo($_);
			$hf->bar($hf->foo + $hf->foo + $hf->foo + $hf->foo);
		}
	},
	'H::U::F' => sub{
		for(1 .. 100){
			$huf->foo($_);
			$huf->bar($huf->foo + $huf->foo + $huf->foo + $huf->foo);
		}
	},
	'Mouse' => sub{
		for(1 .. 100){
			$m->foo($_);
			$m->bar($m->foo + $m->foo + $m->foo + $m->foo);
		}
	},
};
