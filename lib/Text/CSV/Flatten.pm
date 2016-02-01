package Text::CSV::Flatten;

use v5.014;
use strict;
use warnings;

our $VERSION = '0.01';

use JSON qw/ encode_json /;
use Text::CSV::Slurp;

sub new {
    my ($class, $pattern, %args)= @_;

    $pattern =~ /^\.(.*)$/
        or die "invalid pattern: <$pattern>";
    my $p= $1;

    $pattern= [ split /\./, $p ];

    my $data= delete $args{data};
    my $self= bless {
        pattern     => $pattern,
        data_matrix => {},
        %args,
    }, $class;

    $self->data($data) if $data;

    return $self;
}

sub data {
    my ($self, $data)= @_;

    my $data_matrix= $self->{data_matrix};

    my @pattern= @{ $self->{pattern} };

    _recurse_pattern($data, \@pattern, [], [], $data_matrix);

    return $self;
}

sub records {
    my ($self)= @_;

    my @pattern= @{ $self->{pattern} };
    my $data_matrix= $self->{data_matrix};
    my @index_column_names= map { /^<(.*)>$/ ? $1 : () } @pattern;

    my @records;
    for my $index (sort keys %$data_matrix) {
        my $data= $data_matrix->{$index};
        my %record;
        @record{@index_column_names}= split /\0/, $index;
        @record{keys %$data}= values %$data;
        push @records, \%record;
    }
    return \@records;
}

sub csv {
    my ($self)= @_;

    return Text::CSV::Slurp->create( input => $self->records );
}

sub _foreach(&$) {
    my ($codeblock, $it)= @_;
    if('ARRAY' eq ref $it) {
        for my $i (0 .. @$it - 1) {
            $codeblock->($i, $it->[$i]);
        }
    } elsif('HASH' eq ref $it) {
        for my $i (keys %$it) {
            $codeblock->($i, $it->{$i});
        }
    } elsif($it->can('TO_JSON')) {
        no warnings 'prototype';            # avoid "_foreach() called too early to check prototype"
        _foreach($codeblock, $it->TO_JSON);
    } else {
        die "Can't iterate over item";
    }
}

sub _recurse_pattern {
    my ($cur_data, $pattern, $column_name_prefix, $index_prefix, $data_matrix)= @_;

    if(@$pattern) {
        my ($p, @p)= @$pattern;
        eval {
            if($p eq '*') {
                _foreach {
                    my ($key, $value)= @_;
                    _recurse_pattern($value, \@p, [@$column_name_prefix, $key], $index_prefix, $data_matrix);
                } $cur_data;
            } elsif($p =~ /^<(.*)>$/) {
                _foreach {
                    my ($key, $value)= @_;
                    _recurse_pattern($value, \@p, $column_name_prefix, [@$index_prefix, $key], $data_matrix);
                } $cur_data;
            } else {
                _recurse_pattern($cur_data->{$p}, \@p, $column_name_prefix, $index_prefix, $data_matrix);
            }
            1;
        } or do {
            my $error= $@ || "Zombie error";
            my $debugstr= join(".", "-->$p<--", @p);
            die "Error while applying pattern chunk $debugstr: $error";
        }
    } else {
        my $cell_value= ref $cur_data
                      ? encode_json($cur_data)
                      : $cur_data;
        $data_matrix->{join("\0", @$index_prefix)}{join("_", @$column_name_prefix)}= $cell_value;
    }
}


1;
__END__

=head1 NAME

Text::CSV::Flatten - Perl extension for transforming hierarchical data (nested
arrays/hashes) to comma-separated value (csv) output according to a compact,
readable, user-specified pattern.


=head1 SYNOPSIS

  use Text::CSV::Flatten;
  Text::CSV::Flatten->new(
    pattern => '<index>.*',
    data    => [{ a => 1, b => 2 }, { a => 3, b => 4 }],
  )->csv();

=head1 DESCRIPTION

Some documentation wil come here.

=head1 SEE ALSO

  Text::CSV::Slurp

=head1 AUTHOR

Timo Kluck, E<lt>tkluck@infty.nlE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by Timo Kluck

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.22.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
