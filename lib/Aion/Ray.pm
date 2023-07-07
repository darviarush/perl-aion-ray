package Aion::Ray;
use 5.008001;
use strict;
use warnings;

our $VERSION = "0.01";

use Devel::Cover;
use Term::ANSIColor qw/colored/;


# Конструктор
sub new {
    my $cls = shift;
    bless {@_}, $cls
}

# Трансформирует md-файлы
sub transforms {
    my ($self) = @_;
    my $mds = $self->{files} // [split /\n/, `find lib -name '*.md'`];
    for my $md (@$mds) {
        my $test = ($md =~ s/\.md$/.t/r) =~ s/^lib/t/r;
        my $mdmtime = (stat $md)[9];
        die "Нет файла $md" if !$mdmtime;
        $self->transform($md, $test) if !-e $test || $mdmtime > (stat $test)[9];
    }
    $self
}

# Эскейпинг для строки в двойных кавычках
sub _qq_esc {
    $_[0] =~ s!"!\\"!gr
}

# Эскейпинг для строки в одинарных кавычках
sub _q_esc {
    $_[0] =~ s!'!\\'!gr
}

# Трансформирует md-файл в тест и документацию
sub transform {
    my ($self, $md, $test) = @_;

    print "🔖 $md ", colored("↦", "white"), " $test ", colored("...", "white"), " ";

    open my $f, "<:utf8", $md or die "$md: $!";
    open my $t, ">:utf8", $test or die "$test: $!";

    my $subtests = 0;
    my $in_code; my $lang;

    while(<$f>) {

        if(in_code) {
            if(/^```/) { # Закрываем код
                $in_code = 0;
                print "\n";
            }
            elsif(/#\s*((?<is_deeply>-->|⟶)|(?<is>->|→)|(?<qqis>=>|⇒)|(?<qis>\|=>|↦)\s*(.*?)\s*$/) {
                my ($code, $expected) = ($`, $+{expected});
                my $q = _q_esc($_);
                if(exists $+{is_deeply}) { print "is_deeply ($code), ($expected), '$q';\n" }
                elsif(exists $+{is})   { print "is ($code), ($expected), '$q';\n" }
                elsif(exists $+{qqis}) { my $ex = _qq_esc($expected); print "is ($code), \"$ex\", '$q';\n" }
                elsif(exists $+{qis})  { my $ex = _q_esc($expected);  print "is ($code), '$ex', '$q';\n" }
            }
            else { # Обычная строка кода
                print "$_\n";
            }
        } else {

            if(/^(#+)\s*/) {
                my $title = $`;
                my $level = length $1;

                $title =~ s!'!\\$&!g;

                my $close = my $open = 0;

                if($level > $subtests) {
                    $open = $level - $subtests;
                } else {
                    $open = 1;
                    $close = $subtests - $level;
                }

                $subtests -= $close; $subtests += $open;

                print $t "done_testing() };" for 1..$close;
                print $t "subtest '$title' => sub {" for 1..$open;

                print $t "\n";
            }
            elsif(/^```(\w*)/) {
                $in_code = 1;
                $lang = $1;
                print $t "\n";
            }
            else {
                print $t "# $_\n";
            }
        }
    }

    close $f;
    close $t;

    print colored("ok", "bright_green"), "\n";

    $self
}

# Запустить тесты
sub tests {
    my ($self) = @_;
    
    if($self->{files}) {
        my $ = $self->{files};
        `prove `
    } else {

    }
}

1;
__END__

=encoding utf-8

=head1 NAME

Aion::Ray - It's new $module

=head1 SYNOPSIS

    use Aion::Ray;

=head1 DESCRIPTION

Aion::Ray is ...

=head1 LICENSE

Copyright (C) Yaroslav O. Kosmina.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Yaroslav O. Kosmina E<lt>darviarush@mail.ruE<gt>

=cut

