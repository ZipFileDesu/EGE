# Copyright © 2014 Darya D. Gornak 
# Licensed under GPL version 2 or later.
# http://github.com/dahin/EGE
package EGE::SQL::Table;

use strict;
use warnings;
use EGE::Html;
use EGE::Prog qw(make_expr);
use EGE::Random;

sub new {
    my ($class, $fields) = @_;
    $fields or die;
    my $self = {
        fields => $fields,
        data => [],
        field_index => {},
    };
    my $i = 0;
    $self->{field_index}->{$_} = $i++ for @$fields;
    bless $self, $class;
    $self;
}

sub insert_row {
    my $self = shift;
    @_ == @{$self->{fields}}
        or die sprintf "Wrong column count %d != %d", scalar @_, scalar @{$self->{fields}};
    push @{$self->{data}}, [ @_ ];
    $self;
}

sub insert_rows {
    my $self = shift;
    $self->insert_row(@$_) for @_;
    $self;
}

sub print_row { print join("\t", @{$_[0]}), "\n"; }

sub print {
    my $self = shift;
    print_row $_ for $self->{fields}, @{$self->{data}};
}
sub count {
    @{$_[0]->{data}};
}

sub _expr {
    my ($self, $fields) = @_;
    my (@result, @ans);
    my $k = 0;
    for my $i (@$fields){
        if (!ref($i)) {
            my $indexes = $self->{field_index}->{$i} // die("Unknown field $i");
            push @result , sub {
                my @value = @_;
                $value[$indexes];
            };
            push @ans, $i;
        } elsif (ref($i) eq "CODE") {
            push @result, $i;
            push @ans, "function_".$k++;
        } elsif ($i->can('run')) {
            push @result, sub {
                    my @value = @_;
                    my $hash = {};
                    $hash->{$_} = $value[$self->{field_index}->{$_}] for @{$self->{fields}};
                    $i->run($hash);
                };
            push @ans, "expression_".$k++;
        }
    }
    ( sub { map $_->(@_), @result; }, [ @ans ]  );
}

sub select {
    my ($self, $fields, $where, $ref) = @_;
    my ($value, $field)  = $self->_expr($fields);
    my $result = EGE::SQL::Table->new([ @$field ]);
    my $tab_where = $self->where($where, $ref);
    $result->{data} = [ map [ $value->(@$_) ], @{$tab_where->{data}} ];
    $result;
}


sub where {
    my ($self, $where, $ref) = @_;
    $where or return $self;
    my $table = EGE::SQL::Table->new($self->{fields});
    for my $data (@{$self->{data}}) {
        my $hash = {};
        $hash->{$_} = $data->[$self->{field_index}->{$_}] for @{$self->{fields}};
        push @{$table->{data}}, $ref ? $data : [ @$data ] if $where->run($hash);
    }
    $table;
}

sub update {
    my ($self, $assigns, $where) = @_;
    my @data = $where ? @{$self->where($where, 1)->{data}} : @{$self->{data}};
    for my $row (@data) {
        my $hash = {};
        $hash->{$_} = $row->[$self->{field_index}->{$_}] for @{$self->{fields}};
        $assigns->run($hash);
        $row->[$self->{field_index}->{$_}] = $hash->{$_} for @{$self->{fields}};
    }
    $self;
}

sub delete {
    my ($self, $where) = @_; 
    $self->{data} = $self->select( [ @{$self->{fields}} ], make_expr(['!', $where]), 1)->{data};
    $self;
}
sub between {
    my ($self, $exp, $l, $r) = @_;
    return [ '&&', ['>=', $exp, $l] , ['<=', $exp, $r] ]
}

sub inner_join {
    my ($self, $table2, $field1, $field2) = @_;
    my $result =  EGE::SQL::Table->new([@{$self->{fields}}, @{$table2->{fields}}]);
    my @indexe = $self->{field_index}->{$field1} // die("Unknown field $field1");
    my @indexe2 = $table2->{field_index}->{$field2} // die("Unknown field $field2");
    for my $data (@{$self->{data}}) {
        for (@{$table2->{data}}) {
            $result->insert_row(@$data, @$_) if (@$data[@indexe] == @$_[@indexe2]); 
        }
    }
    $result;
}

sub table_html { 
    my ($self) = @_;
    my $table_text = html->row_n('th', @{$self->{fields}});
    $table_text .= html->row_n('td', @$_) for @{$self->{data}}; 
    $table_text = html->table($table_text, { border => 1 });
}

sub random_val {
   my ($self, @array) = @_;
   rnd->pick(@{rnd->pick(@array)}) + rnd->pick(0, -50, 50);
}

1;