#line 1
package Test::More;

use 5.006;
use strict;
use warnings;

#---- perlcritic exemptions. ----#

# We use a lot of subroutine prototypes
## no critic (Subroutines::ProhibitSubroutinePrototypes)

# Can't use Carp because it might cause C<use_ok()> to accidentally succeed
# even though the module being used forgot to use Carp.  Yes, this
# actually happened.
sub _carp {
    my( $file, $line ) = ( caller(1) )[ 1, 2 ];
    return warn @_, " at $file line $line\n";
}

our $VERSION = '1.302162';

use Test::Builder::Module;
our @ISA    = qw(Test::Builder::Module);
our @EXPORT = qw(ok use_ok require_ok
  is isnt like unlike is_deeply
  cmp_ok
  skip todo todo_skip
  pass fail
  eq_array eq_hash eq_set
  $TODO
  plan
  done_testing
  can_ok isa_ok new_ok
  diag note explain
  subtest
  BAIL_OUT
);

#line 166

sub plan {
    my $tb = Test::More->builder;

    return $tb->plan(@_);
}

# This implements "use Test::More 'no_diag'" but the behavior is
# deprecated.
sub import_extra {
    my $class = shift;
    my $list  = shift;

    my @other = ();
    my $idx   = 0;
    my $import;
    while( $idx <= $#{$list} ) {
        my $item = $list->[$idx];

        if( defined $item and $item eq 'no_diag' ) {
            $class->builder->no_diag(1);
        }
        elsif( defined $item and $item eq 'import' ) {
            if ($import) {
                push @$import, @{$list->[ ++$idx ]};
            }
            else {
                $import = $list->[ ++$idx ];
                push @other, $item, $import;
            }
        }
        else {
            push @other, $item;
        }

        $idx++;
    }

    @$list = @other;

    if ($class eq __PACKAGE__ && (!$import || grep $_ eq '$TODO', @$import)) {
        my $to = $class->builder->exported_to;
        no strict 'refs';
        *{"$to\::TODO"} = \our $TODO;
        if ($import) {
            @$import = grep $_ ne '$TODO', @$import;
        }
        else {
            push @$list, import => [grep $_ ne '$TODO', @EXPORT];
        }
    }

    return;
}

#line 245

sub done_testing {
    my $tb = Test::More->builder;
    $tb->done_testing(@_);
}

#line 317

sub ok ($;$) {
    my( $test, $name ) = @_;
    my $tb = Test::More->builder;

    return $tb->ok( $test, $name );
}

#line 400

sub is ($$;$) {
    my $tb = Test::More->builder;

    return $tb->is_eq(@_);
}

sub isnt ($$;$) {
    my $tb = Test::More->builder;

    return $tb->isnt_eq(@_);
}

*isn't = \&isnt;
# ' to unconfuse syntax higlighters

#line 445

sub like ($$;$) {
    my $tb = Test::More->builder;

    return $tb->like(@_);
}

#line 460

sub unlike ($$;$) {
    my $tb = Test::More->builder;

    return $tb->unlike(@_);
}

#line 506

sub cmp_ok($$$;$) {
    my $tb = Test::More->builder;

    return $tb->cmp_ok(@_);
}

#line 541

sub can_ok ($@) {
    my( $proto, @methods ) = @_;
    my $class = ref $proto || $proto;
    my $tb = Test::More->builder;

    unless($class) {
        my $ok = $tb->ok( 0, "->can(...)" );
        $tb->diag('    can_ok() called with empty class or reference');
        return $ok;
    }

    unless(@methods) {
        my $ok = $tb->ok( 0, "$class->can(...)" );
        $tb->diag('    can_ok() called with no methods');
        return $ok;
    }

    my @nok = ();
    foreach my $method (@methods) {
        $tb->_try( sub { $proto->can($method) } ) or push @nok, $method;
    }

    my $name = (@methods == 1) ? "$class->can('$methods[0]')" :
                                 "$class->can(...)"           ;

    my $ok = $tb->ok( !@nok, $name );

    $tb->diag( map "    $class->can('$_') failed\n", @nok );

    return $ok;
}

#line 607

sub isa_ok ($$;$) {
    my( $thing, $class, $thing_name ) = @_;
    my $tb = Test::More->builder;

    my $whatami;
    if( !defined $thing ) {
        $whatami = 'undef';
    }
    elsif( ref $thing ) {
        $whatami = 'reference';

        local($@,$!);
        require Scalar::Util;
        if( Scalar::Util::blessed($thing) ) {
            $whatami = 'object';
        }
    }
    else {
        $whatami = 'class';
    }

    # We can't use UNIVERSAL::isa because we want to honor isa() overrides
    my( $rslt, $error ) = $tb->_try( sub { $thing->isa($class) } );

    if($error) {
        die <<WHOA unless $error =~ /^Can't (locate|call) method "isa"/;
WHOA! I tried to call ->isa on your $whatami and got some weird error.
Here's the error.
$error
WHOA
    }

    # Special case for isa_ok( [], "ARRAY" ) and like
    if( $whatami eq 'reference' ) {
        $rslt = UNIVERSAL::isa($thing, $class);
    }

    my($diag, $name);
    if( defined $thing_name ) {
        $name = "'$thing_name' isa '$class'";
        $diag = defined $thing ? "'$thing_name' isn't a '$class'" : "'$thing_name' isn't defined";
    }
    elsif( $whatami eq 'object' ) {
        my $my_class = ref $thing;
        $thing_name = qq[An object of class '$my_class'];
        $name = "$thing_name isa '$class'";
        $diag = "The object of class '$my_class' isn't a '$class'";
    }
    elsif( $whatami eq 'reference' ) {
        my $type = ref $thing;
        $thing_name = qq[A reference of type '$type'];
        $name = "$thing_name isa '$class'";
        $diag = "The reference of type '$type' isn't a '$class'";
    }
    elsif( $whatami eq 'undef' ) {
        $thing_name = 'undef';
        $name = "$thing_name isa '$class'";
        $diag = "$thing_name isn't defined";
    }
    elsif( $whatami eq 'class' ) {
        $thing_name = qq[The class (or class-like) '$thing'];
        $name = "$thing_name isa '$class'";
        $diag = "$thing_name isn't a '$class'";
    }
    else {
        die;
    }

    my $ok;
    if($rslt) {
        $ok = $tb->ok( 1, $name );
    }
    else {
        $ok = $tb->ok( 0, $name );
        $tb->diag("    $diag\n");
    }

    return $ok;
}

#line 708

sub new_ok {
    my $tb = Test::More->builder;
    $tb->croak("new_ok() must be given at least a class") unless @_;

    my( $class, $args, $object_name ) = @_;

    $args ||= [];

    my $obj;
    my( $success, $error ) = $tb->_try( sub { $obj = $class->new(@$args); 1 } );
    if($success) {
        local $Test::Builder::Level = $Test::Builder::Level + 1;
        isa_ok $obj, $class, $object_name;
    }
    else {
        $class = 'undef' if !defined $class;
        $tb->ok( 0, "$class->new() died" );
        $tb->diag("    Error was:  $error");
    }

    return $obj;
}

#line 805

sub subtest {
    my $tb = Test::More->builder;
    return $tb->subtest(@_);
}

#line 827

sub pass (;$) {
    my $tb = Test::More->builder;

    return $tb->ok( 1, @_ );
}

sub fail (;$) {
    my $tb = Test::More->builder;

    return $tb->ok( 0, @_ );
}

#line 880

sub require_ok ($) {
    my($module) = shift;
    my $tb = Test::More->builder;

    my $pack = caller;

    # Try to determine if we've been given a module name or file.
    # Module names must be barewords, files not.
    $module = qq['$module'] unless _is_module_name($module);

    my $code = <<REQUIRE;
package $pack;
require $module;
1;
REQUIRE

    my( $eval_result, $eval_error ) = _eval($code);
    my $ok = $tb->ok( $eval_result, "require $module;" );

    unless($ok) {
        chomp $eval_error;
        $tb->diag(<<DIAGNOSTIC);
    Tried to require '$module'.
    Error:  $eval_error
DIAGNOSTIC

    }

    return $ok;
}

sub _is_module_name {
    my $module = shift;

    # Module names start with a letter.
    # End with an alphanumeric.
    # The rest is an alphanumeric or ::
    $module =~ s/\b::\b//g;

    return $module =~ /^[a-zA-Z]\w*$/ ? 1 : 0;
}


#line 974

sub use_ok ($;@) {
    my( $module, @imports ) = @_;
    @imports = () unless @imports;
    my $tb = Test::More->builder;

    my %caller;
    @caller{qw/pack file line sub args want eval req strict warn/} = caller(0);

    my ($pack, $filename, $line, $warn) = @caller{qw/pack file line warn/};
    $filename =~ y/\n\r/_/; # so it doesn't run off the "#line $line $f" line

    my $code;
    if( @imports == 1 and $imports[0] =~ /^\d+(?:\.\d+)?$/ ) {
        # probably a version check.  Perl needs to see the bare number
        # for it to work with non-Exporter based modules.
        $code = <<USE;
package $pack;
BEGIN { \${^WARNING_BITS} = \$args[-1] if defined \$args[-1] }
#line $line $filename
use $module $imports[0];
1;
USE
    }
    else {
        $code = <<USE;
package $pack;
BEGIN { \${^WARNING_BITS} = \$args[-1] if defined \$args[-1] }
#line $line $filename
use $module \@{\$args[0]};
1;
USE
    }

    my ($eval_result, $eval_error) = _eval($code, \@imports, $warn);
    my $ok = $tb->ok( $eval_result, "use $module;" );

    unless($ok) {
        chomp $eval_error;
        $@ =~ s{^BEGIN failed--compilation aborted at .*$}
                {BEGIN failed--compilation aborted at $filename line $line.}m;
        $tb->diag(<<DIAGNOSTIC);
    Tried to use '$module'.
    Error:  $eval_error
DIAGNOSTIC

    }

    return $ok;
}

sub _eval {
    my( $code, @args ) = @_;

    # Work around oddities surrounding resetting of $@ by immediately
    # storing it.
    my( $sigdie, $eval_result, $eval_error );
    {
        local( $@, $!, $SIG{__DIE__} );    # isolate eval
        $eval_result = eval $code;              ## no critic (BuiltinFunctions::ProhibitStringyEval)
        $eval_error  = $@;
        $sigdie      = $SIG{__DIE__} || undef;
    }
    # make sure that $code got a chance to set $SIG{__DIE__}
    $SIG{__DIE__} = $sigdie if defined $sigdie;

    return( $eval_result, $eval_error );
}


#line 1092

our( @Data_Stack, %Refs_Seen );
my $DNE = bless [], 'Does::Not::Exist';

sub _dne {
    return ref $_[0] eq ref $DNE;
}

## no critic (Subroutines::RequireArgUnpacking)
sub is_deeply {
    my $tb = Test::More->builder;

    unless( @_ == 2 or @_ == 3 ) {
        my $msg = <<'WARNING';
is_deeply() takes two or three args, you gave %d.
This usually means you passed an array or hash instead 
of a reference to it
WARNING
        chop $msg;    # clip off newline so carp() will put in line/file

        _carp sprintf $msg, scalar @_;

        return $tb->ok(0);
    }

    my( $got, $expected, $name ) = @_;

    $tb->_unoverload_str( \$expected, \$got );

    my $ok;
    if( !ref $got and !ref $expected ) {    # neither is a reference
        $ok = $tb->is_eq( $got, $expected, $name );
    }
    elsif( !ref $got xor !ref $expected ) {    # one's a reference, one isn't
        $ok = $tb->ok( 0, $name );
        $tb->diag( _format_stack({ vals => [ $got, $expected ] }) );
    }
    else {                                     # both references
        local @Data_Stack = ();
        if( _deep_check( $got, $expected ) ) {
            $ok = $tb->ok( 1, $name );
        }
        else {
            $ok = $tb->ok( 0, $name );
            $tb->diag( _format_stack(@Data_Stack) );
        }
    }

    return $ok;
}

sub _format_stack {
    my(@Stack) = @_;

    my $var       = '$FOO';
    my $did_arrow = 0;
    foreach my $entry (@Stack) {
        my $type = $entry->{type} || '';
        my $idx = $entry->{'idx'};
        if( $type eq 'HASH' ) {
            $var .= "->" unless $did_arrow++;
            $var .= "{$idx}";
        }
        elsif( $type eq 'ARRAY' ) {
            $var .= "->" unless $did_arrow++;
            $var .= "[$idx]";
        }
        elsif( $type eq 'REF' ) {
            $var = "\${$var}";
        }
    }

    my @vals = @{ $Stack[-1]{vals} }[ 0, 1 ];
    my @vars = ();
    ( $vars[0] = $var ) =~ s/\$FOO/     \$got/;
    ( $vars[1] = $var ) =~ s/\$FOO/\$expected/;

    my $out = "Structures begin differing at:\n";
    foreach my $idx ( 0 .. $#vals ) {
        my $val = $vals[$idx];
        $vals[$idx]
          = !defined $val ? 'undef'
          : _dne($val)    ? "Does not exist"
          : ref $val      ? "$val"
          :                 "'$val'";
    }

    $out .= "$vars[0] = $vals[0]\n";
    $out .= "$vars[1] = $vals[1]\n";

    $out =~ s/^/    /msg;
    return $out;
}

sub _type {
    my $thing = shift;

    return '' if !ref $thing;

    for my $type (qw(Regexp ARRAY HASH REF SCALAR GLOB CODE VSTRING)) {
        return $type if UNIVERSAL::isa( $thing, $type );
    }

    return '';
}

#line 1252

sub diag {
    return Test::More->builder->diag(@_);
}

sub note {
    return Test::More->builder->note(@_);
}

#line 1278

sub explain {
    return Test::More->builder->explain(@_);
}

#line 1344

## no critic (Subroutines::RequireFinalReturn)
sub skip {
    my( $why, $how_many ) = @_;
    my $tb = Test::More->builder;

    # If the plan is set, and is static, then skip needs a count. If the plan
    # is 'no_plan' we are fine. As well if plan is undefined then we are
    # waiting for done_testing.
    unless (defined $how_many) {
        my $plan = $tb->has_plan;
        _carp "skip() needs to know \$how_many tests are in the block"
            if $plan && $plan =~ m/^\d+$/;
        $how_many = 1;
    }

    if( defined $how_many and $how_many =~ /\D/ ) {
        _carp
          "skip() was passed a non-numeric number of tests.  Did you get the arguments backwards?";
        $how_many = 1;
    }

    for( 1 .. $how_many ) {
        $tb->skip($why);
    }

    no warnings 'exiting';
    last SKIP;
}

#line 1431

sub todo_skip {
    my( $why, $how_many ) = @_;
    my $tb = Test::More->builder;

    unless( defined $how_many ) {
        # $how_many can only be avoided when no_plan is in use.
        _carp "todo_skip() needs to know \$how_many tests are in the block"
          unless $tb->has_plan eq 'no_plan';
        $how_many = 1;
    }

    for( 1 .. $how_many ) {
        $tb->todo_skip($why);
    }

    no warnings 'exiting';
    last TODO;
}

#line 1486

sub BAIL_OUT {
    my $reason = shift;
    my $tb     = Test::More->builder;

    $tb->BAIL_OUT($reason);
}

#line 1525

#'#
sub eq_array {
    local @Data_Stack = ();
    _deep_check(@_);
}

sub _eq_array {
    my( $a1, $a2 ) = @_;

    if( grep _type($_) ne 'ARRAY', $a1, $a2 ) {
        warn "eq_array passed a non-array ref";
        return 0;
    }

    return 1 if $a1 eq $a2;

    my $ok = 1;
    my $max = $#$a1 > $#$a2 ? $#$a1 : $#$a2;
    for( 0 .. $max ) {
        my $e1 = $_ > $#$a1 ? $DNE : $a1->[$_];
        my $e2 = $_ > $#$a2 ? $DNE : $a2->[$_];

        next if _equal_nonrefs($e1, $e2);

        push @Data_Stack, { type => 'ARRAY', idx => $_, vals => [ $e1, $e2 ] };
        $ok = _deep_check( $e1, $e2 );
        pop @Data_Stack if $ok;

        last unless $ok;
    }

    return $ok;
}

sub _equal_nonrefs {
    my( $e1, $e2 ) = @_;

    return if ref $e1 or ref $e2;

    if ( defined $e1 ) {
        return 1 if defined $e2 and $e1 eq $e2;
    }
    else {
        return 1 if !defined $e2;
    }

    return;
}

sub _deep_check {
    my( $e1, $e2 ) = @_;
    my $tb = Test::More->builder;

    my $ok = 0;

    # Effectively turn %Refs_Seen into a stack.  This avoids picking up
    # the same referenced used twice (such as [\$a, \$a]) to be considered
    # circular.
    local %Refs_Seen = %Refs_Seen;

    {
        $tb->_unoverload_str( \$e1, \$e2 );

        # Either they're both references or both not.
        my $same_ref = !( !ref $e1 xor !ref $e2 );
        my $not_ref = ( !ref $e1 and !ref $e2 );

        if( defined $e1 xor defined $e2 ) {
            $ok = 0;
        }
        elsif( !defined $e1 and !defined $e2 ) {
            # Shortcut if they're both undefined.
            $ok = 1;
        }
        elsif( _dne($e1) xor _dne($e2) ) {
            $ok = 0;
        }
        elsif( $same_ref and( $e1 eq $e2 ) ) {
            $ok = 1;
        }
        elsif($not_ref) {
            push @Data_Stack, { type => '', vals => [ $e1, $e2 ] };
            $ok = 0;
        }
        else {
            if( $Refs_Seen{$e1} ) {
                return $Refs_Seen{$e1} eq $e2;
            }
            else {
                $Refs_Seen{$e1} = "$e2";
            }

            my $type = _type($e1);
            $type = 'DIFFERENT' unless _type($e2) eq $type;

            if( $type eq 'DIFFERENT' ) {
                push @Data_Stack, { type => $type, vals => [ $e1, $e2 ] };
                $ok = 0;
            }
            elsif( $type eq 'ARRAY' ) {
                $ok = _eq_array( $e1, $e2 );
            }
            elsif( $type eq 'HASH' ) {
                $ok = _eq_hash( $e1, $e2 );
            }
            elsif( $type eq 'REF' ) {
                push @Data_Stack, { type => $type, vals => [ $e1, $e2 ] };
                $ok = _deep_check( $$e1, $$e2 );
                pop @Data_Stack if $ok;
            }
            elsif( $type eq 'SCALAR' ) {
                push @Data_Stack, { type => 'REF', vals => [ $e1, $e2 ] };
                $ok = _deep_check( $$e1, $$e2 );
                pop @Data_Stack if $ok;
            }
            elsif($type) {
                push @Data_Stack, { type => $type, vals => [ $e1, $e2 ] };
                $ok = 0;
            }
            else {
                _whoa( 1, "No type in _deep_check" );
            }
        }
    }

    return $ok;
}

sub _whoa {
    my( $check, $desc ) = @_;
    if($check) {
        die <<"WHOA";
WHOA!  $desc
This should never happen!  Please contact the author immediately!
WHOA
    }
}

#line 1672

sub eq_hash {
    local @Data_Stack = ();
    return _deep_check(@_);
}

sub _eq_hash {
    my( $a1, $a2 ) = @_;

    if( grep _type($_) ne 'HASH', $a1, $a2 ) {
        warn "eq_hash passed a non-hash ref";
        return 0;
    }

    return 1 if $a1 eq $a2;

    my $ok = 1;
    my $bigger = keys %$a1 > keys %$a2 ? $a1 : $a2;
    foreach my $k ( keys %$bigger ) {
        my $e1 = exists $a1->{$k} ? $a1->{$k} : $DNE;
        my $e2 = exists $a2->{$k} ? $a2->{$k} : $DNE;

        next if _equal_nonrefs($e1, $e2);

        push @Data_Stack, { type => 'HASH', idx => $k, vals => [ $e1, $e2 ] };
        $ok = _deep_check( $e1, $e2 );
        pop @Data_Stack if $ok;

        last unless $ok;
    }

    return $ok;
}

#line 1731

sub eq_set {
    my( $a1, $a2 ) = @_;
    return 0 unless @$a1 == @$a2;

    no warnings 'uninitialized';

    # It really doesn't matter how we sort them, as long as both arrays are
    # sorted with the same algorithm.
    #
    # Ensure that references are not accidentally treated the same as a
    # string containing the reference.
    #
    # Have to inline the sort routine due to a threading/sort bug.
    # See [rt.cpan.org 6782]
    #
    # I don't know how references would be sorted so we just don't sort
    # them.  This means eq_set doesn't really work with refs.
    return eq_array(
        [ grep( ref, @$a1 ), sort( grep( !ref, @$a1 ) ) ],
        [ grep( ref, @$a2 ), sort( grep( !ref, @$a2 ) ) ],
    );
}

#line 1995

1;
