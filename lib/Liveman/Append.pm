package Liveman::Append;
use common::sense;

use File::Slurper qw/read_text write_text/;
use Term::ANSIColor qw/colored/;
use Text::Trim qw/trim/;

# Конструктор
sub new {
    my $cls = shift;
    my $self = bless {@_}, $cls;
    delete $self->{files} if $self->{files} && !scalar @{$self->{files}};
    $self
}

# Пакет из пути
sub _pkg($) {
    ( shift =~ s!^lib/(.*)\.\w+$!$1!r ) =~ s!/!::!gr
}

# Переменная из пакета
sub _var($) {
    '$' . lcfirst( shift =~ s!::(\w)?!_${\lc $1}!gr )
}

# Для метода для вставки
sub _md_method(@) {
    my ($pkg, $sub, $args, $remark) = @_;
    my $sub_args = "$sub ($args)";
    $args = "($args)" if $args;

    $remark = "." unless defined $remark;
    my $var = _var $pkg;
    << "END";
## $sub_args

$remark

```perl
my $var = $pkg->new;
${var}->$sub$args  # -> .3
```

END
}

# Для фичи для вставки
sub _md_feature(@) {
    my ($pkg, $has, $remark) = @_;

    $remark = "." unless defined $remark;
    my $var = _var $pkg;
    << "END";
## $has

$remark

```perl
my $var = $pkg->new;

${var}->$has\t# -> .5
```

END
}


# Добавить разделы функций в *.md из *.pm
sub appends {
    my ($self) = @_;
    my $files = $self->{files} // [split /\n/, `find lib -name '*.pm' -a -type f`];
    $self->append($_) for @$files;
    $self
}

# Добавить разделы функций в *.md из *.pm
sub append {
    my ($self, $pm) = @_;

    my $md = $pm =~ s!(\.\w+)?$!.md!r;

    die "Not file $pm!" if !-f $pm;
    $self->mkmd($md) if !-f $md;

    local $_ = read_text $pm;
    my %sub; my %has;
    while(m! (^\# [\ \t]* (?<remark> .*?) [\ \t]* )? \n (
        sub \s+ (?<sub> (\w+|::)+ ) .* 
            ( \s* my \s* \( \s* (\$self,? \s* )? (?<args>.*?) \s* \) \s* = \s* \@_; )?
        | has \s+ (?<has> (\w+|'\w+'|"\w+"|\[ \s* ([^\[\]]*?) \s* \])+ )
    ) !mgxn) {
        $sub{$+{sub}} = {%+} if exists $+{sub} and "_" ne substr $+{sub}, 0, 1;
        $has{$+{has}} = {%+} if exists $+{has} and "_" ne substr $+{has}, 0, 1;
    }

    return $self if !keys %sub && !keys %has;

    $_ = read_text $md;

    my $pkg = _pkg $md;

    my $added = 0;

    s{^\#[\ \t]+( (?<is>METHODS|SUBROUTINES) | DESCRIPTION )
        (^```.*?^```|.)*? (?= ^\#\s)
    }{
        my $x = $&; my $is = $+{is};
        if($is) {
            while($x =~ /^\#\#[\ \t]+(\w+)/gm) {
                delete $sub{$1};
            }
        }
        $added += keys %sub;
        join "", $x, $is? (): "# SUBROUTINES/METHODS\n\n", map { _md_method $pkg, $_, $sub{$_}{args}, $sub{$_}{remark} } sort keys %sub;
    }emsx or die "Нет секции DESCRIPTION!" if keys %sub;

    s{^\#[\ \t]+((?<is>FEATURES) | DESCRIPTION) 
        (^```.*?^```|.)*? (?= ^\#\s)
    }{
        my $x = $&; my $is = $+{is};
        if($is) {
            while($x =~ /^\#\#[\ \t]+([^\n]+?)[\ \t]*/gm) {
                delete $has{$1};
            }
        }
        $added += keys %has;
        join "", $x, $is? (): "# FEATURES\n\n", map { _md_feature $pkg, $_, $sub{$_}{remark} } sort keys %has;
    }emsx or die "Нет секции DESCRIPTION!" if keys %has;


    if ($added) {
        write_text $md, $_;
        print "🔖 $pm ", colored("⊂", "BRIGHT_GREEN"), " $md ", "\n",
            "  ", scalar keys %has? (colored("FEATURES ", "BRIGHT_WHITE"), join(colored(", ", "red"), sort keys %has), "\n"): (),
            "  ", scalar keys %sub? (colored("SUBROUTINES ", "BRIGHT_WHITE"), join(colored(", ", "red"), sort keys %sub), "\n"): (),
        ;
    } else {
        print "🔖 $pm\n";
    }

    $self->{count}++;
    $self->{added} = $added;
    $self
}

sub _git_user_name { shift->{_git_user_name} //= trim(`git config user.name`) }
sub _git_user_email { shift->{_git_user_email} //= trim(`git config user.email`) }
sub _year { shift->{_year} //= trim(`date +%Y`) }
sub _license { shift->{_license} //= -r "minil.toml" && read_text("minil.toml") =~ /^\s*license\s*=\s*"([^"\n]*)"/m ? ($1 eq "perl_5"? "Perl5": uc($1) =~ s/_/v/r): "Perl5" }
sub _land { shift->{_land} //= `curl "https://ipapi.co/\$(curl https://2ip.ru --connect-timeout 3 --max-time 3 -Ss)/json/" --connect-timeout 3 --max-time 3 -Ss` =~ /country_name": "([^"\n]*)"/ ? ($1 eq "Russia" ? "Rusland" : $1) : 'Rusland' }

# Добавить разделы функций в *.md из *.pm
sub mkmd {
    my ($self, $md) = @_;

    my $pkg = _pkg $md;

    my $author = $self->_git_user_name;
    my $email = $self->_git_user_email;
    my $year = $self->_year;
    my $license = $self->_license;
    my $land = $self->_land;

    write_text $md, << "END";
# NAME

$pkg - 

# SYNOPSIS

```perl
use $pkg;

my ${\_var $pkg} = $pkg->new;
```

# DESCRIPION

.

# SUBROUTINES

# INSTALL

For install this module in your system run next [command](https://metacpan.org/pod/App::cpm):

```sh
sudo cpm install -gvv $pkg
```

# AUTHOR

$author [$email](mailto:$email)

# LICENSE

⚖ **$license**

# COPYRIGHT

The $pkg module is copyright © $year $author. $land. All rights reserved.
END
}

1;

__END__

=encoding utf-8

=head1 NAME

Liveman::Append - append manual by methods from C<lib/**.pm> to C<lib/**.md>

=head1 SYNOPSIS

	use Liveman::Append;
	
	my $liveman_append = Liveman::Append->new;
	
	ref $liveman_append     # => Liveman::Append

=head1 DESCRIPION

It append manual by methods and features from modules (C<lib/**.pm>) to their manuals (C<lib/**.md>).

=over

=item 1. Methods is perl-subroutine starting with keyword C<sub>.

=item 2. Features is class property maked OOP-frameworks as C<Aion>, C<Moose>, C<Moo>, C<Mo>, and starting with keyword C<has>.

=back

=head1 SUBROUTINES

=head2 mkmd ($md)

It make md-file.

=head2 appends ()

Append to C<lib/**.md> from C<lib/**.pm> subroutines and features.

=head2 append ($path)

Append subroutines and features from the module with C<$path> into its documentation in the its sections.

File lib/Alt/The/Plan.pm:

	package Alt::The::Plan;
	
	sub planner {
		my ($self) = @_;
	}
	
	# This is first!
	sub miting {
		my ($self, $meet, $man, $woman) = @_;
	}
	
	sub _exquise_me {
		my ($self, $meet, $man, $woman) = @_;
	}
	
	1;



	-e "lib/Alt/The/Plan.md" # -> undef
	
	# Set the mocks:
	*Liveman::Append::_git_user_name = sub {'Yaroslav O. Kosmina'};
	*Liveman::Append::_git_user_email = sub {'dart@cpan.org'};
	*Liveman::Append::_year = sub {2023};
	*Liveman::Append::_license = sub {"Perl5"};
	*Liveman::Append::_land = sub {"Rusland"};
	
	my $liveman_append = Liveman::Append->new->append("lib/Alt/The/Plan.pm");
	$liveman_append->{count}	# -> 1
	$liveman_append->{added}	# -> 2
	
	-e "lib/Alt/The/Plan.md" # -> 1
	
	# And again:
	$liveman_append = Liveman::Append->new->append("lib/Alt/The/Plan.pm");
	$liveman_append->{count}	# -> 1
	$liveman_append->{added}	# -> 0

File lib/Alt/The/Plan.md is:

	# NAME
	
	Alt::The::Plan - 
	
	# SYNOPSIS
	
	\```perl
	use Alt::The::Plan;
	
	my $alt_the_plan = Alt::The::Plan->new;
	\```
	
	# DESCRIPION
	
	.
	
	# SUBROUTINES
	
	## miting ($meet, $man, $woman)
	
	This is first!
	
	\```perl
	my $alt_the_plan = Alt::The::Plan->new;
	$alt_the_plan->miting($meet, $man, $woman)  # -> .3
	\```
	
	## planner ()
	
	.
	
	\```perl
	my $alt_the_plan = Alt::The::Plan->new;
	$alt_the_plan->planner  # -> .3
	\```
	
	# INSTALL
	
	For install this module in your system run next [command](https://metacpan.org/pod/App::cpm):
	
	\```sh
	sudo cpm install -gvv Alt::The::Plan
	\```
	
	# AUTHOR
	
	Yaroslav O. Kosmina [dart@cpan.org](mailto:dart@cpan.org)
	
	# LICENSE
	
	⚖ **Perl5**
	
	# COPYRIGHT
	
	The Alt::The::Plan module is copyright © 2023 Yaroslav O. Kosmina. Rusland. All rights reserved.

=head1 AUTHOR

Yaroslav O. Kosmina LL<mailto:dart@cpan.org>

=head1 LICENSE

⚖ B<GPLv3>

=head1 COPYRIGHT

The Liveman::Append module is copyright © 2023 Yaroslav O. Kosmina. Rusland. All rights reserved.
