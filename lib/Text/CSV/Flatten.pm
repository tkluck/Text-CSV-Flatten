package Text::CSV::Flatten;

use v5.014;
use strict;
use warnings;

our $VERSION = '0.02';

use JSON qw/ encode_json /;
use Text::CSV;

my @KNOWN_ARGS= qw/ column_name /;

sub new {
    my ($class, $pattern, %args)= @_;

    my $data= delete $args{data};

    my %known_args;
    @known_args{@KNOWN_ARGS}= delete @args{@KNOWN_ARGS};
    if(keys %args) {
        my $unknown_keys= join ",", keys %args;
        die "Unknown arguments: $unknown_keys";
    }

    my $self= bless {
        %known_args,
        data_matrix => {},
    }, $class;

    $self->_set_pattern($pattern);
    $self->data($data) if $data;

    return $self;
}

sub _set_pattern {
    my ($self, $pattern_definition)= @_;

    my @pattern_def= split / /, $pattern_definition;

    my %index_column_names;
    my @pattern_parts;
    for my $pattern (@pattern_def) {
        $pattern =~ /^\.(.*)$/
            or die "invalid pattern part: <$pattern>";
        my $p= $1;
        my @pattern= split /\./, $p;

        my @index_column_names= map { /^<(.*)>$/ ? $1 : () } @pattern;
        $index_column_names{ join("\0", @index_column_names) }= 1;

        push @pattern_parts, \@pattern;
    }

    if(keys %index_column_names == 1) {
        $self->{index_column_names}= [ split "\0", (keys %index_column_names)[0] ];
    } else {
        die "Invalid pattern: the different pattern chunks have different index columns";
    }

    $self->{pattern_parts}= \@pattern_parts;
}

sub data {
    my ($self, $data)= @_;

    my $data_matrix= $self->{data_matrix};
    my $pattern_parts= $self->{pattern_parts};

    my @default_column_names;
    if(my $default_column_name= $self->{column_name}) {
        if(ref $default_column_name eq 'ARRAY') {
            @default_column_names= @$default_column_name;
        } else {
            @default_column_names= ($self->{column_name}) x @$pattern_parts;
        }
    }
    for my $pattern (@$pattern_parts) {
        my $has_column_name= scalar grep {
            $_ eq '*' || /^{(.*)}$/
        } @$pattern;
        $self->{_default_column_name}= shift @default_column_names
            if !$has_column_name;
        $self->_recurse_pattern($data, $pattern, [], []);
    }

    return $self;
}

sub csv {
    my ($self)= @_;

    my $data_matrix= $self->{data_matrix};
    my $index_column_names= $self->{index_column_names};

    my @records;
    my %column_names;
    for my $index (sort keys %$data_matrix) {
        my $data= $data_matrix->{$index};
        my %record;
        @record{@$index_column_names}= split /\0/, $index;
        @record{keys %$data}= values %$data;

        @column_names{keys %record}= (1) x keys %record;

        push @records, \%record;
    }
    my @column_names= sort keys %column_names;
    my $render_header= scalar grep $_, @column_names;

    my $csv= Text::CSV->new();

    my @result;
    if($render_header) {
        if(my $status= $csv->combine(@column_names)) {
            push @result, $csv->string();
        } else {
            my $error= $csv->error_input();
            die "Error while rendering header row: $error";
        }
    }
    for my $record (@records) {
        my @columns= @$record{@column_names};
        if(my $status= $csv->combine(@columns)) {
            push @result, $csv->string();
        } else {
            my $error= $csv->error_input();
            die "Error while rendering row: $error";
        }
    }

    return join "\n", @result;
}

sub _foreach(&$) {
    my ($codeblock, $it)= @_;

    if(!defined $it || !ref $it) {
        return;
    } elsif('ARRAY' eq ref $it) {
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
    my ($self, $cur_data, $pattern, $column_name_prefix, $index_prefix)= @_;

    if(@$pattern) {
        my ($p, @p)= @$pattern;
        eval {
            if($p eq '*') {
                _foreach {
                    my ($key, $value)= @_;
                    _recurse_pattern($self, $value, \@p, [@$column_name_prefix, $key], $index_prefix);
                } $cur_data;
            } elsif($p =~ /^{(.*)}$/) {
                my @keys= split ',', $1;
                for my $key (@keys) {
                    my $recurse_data;
                    if(ref $cur_data eq 'HASH' && exists $cur_data->{$key}) {
                        $recurse_data= $cur_data->{$key};
                    } elsif(ref $cur_data eq 'ARRAY') {
                        $recurse_data= $cur_data->[$key];
                    }
                    _recurse_pattern($self, $recurse_data, \@p, [@$column_name_prefix, $key], $index_prefix)
                        if $recurse_data;
                }
            } elsif($p =~ /^<(.*)>$/) {
                _foreach {
                    my ($key, $value)= @_;
                    _recurse_pattern($self, $value, \@p, $column_name_prefix, [@$index_prefix, $key]);
                } $cur_data;
            } else {
                my $recurse_data;
                if(ref $cur_data eq 'HASH' && exists $cur_data->{$p}) {
                    $recurse_data= $cur_data->{$p};
                } elsif(ref $cur_data eq 'ARRAY') {
                    $recurse_data= $cur_data->[$p];
                }
                _recurse_pattern($self, $recurse_data, \@p, $column_name_prefix, $index_prefix)
                    if $recurse_data;
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
        my $column_name= @$column_name_prefix
                       ? join("_", @$column_name_prefix)
                       : $self->{_default_column_name} || '';
        $self->{data_matrix}{join("\0", @$index_prefix)}{$column_name}= $cell_value;
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
    '.<index>.*',
    data    => [{ a => 1, b => 2 }, { a => 3, b => 4 }],
  )->csv();

=head1 DESCRIPTION

Some documentation wil come here.

=head1 SEE ALSO

  Text::CSV

=head1 AUTHOR

Timo Kluck, E<lt>tkluck@infty.nlE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by Timo Kluck

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.22.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
