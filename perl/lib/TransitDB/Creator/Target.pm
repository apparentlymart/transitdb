
package TransitDB::Creator::Target;

use strict;
use warnings;

sub new {
    my ($class, $creator, $source_name) = @_;

    my $self = bless {}, $class;

    $self->{creator} = $creator;
    $self->{source_name} = $source_name;

    return $self;
}

sub _create_kwargs_method {
    my ($class, $name) = @_;

    my $real_name = __PACKAGE__.'::'.$name;
    no strict 'refs';
    *{$real_name} = sub {
        my $self = shift;
        $self->{creator}->$name(source => $self->{source_name}, @_);
    };
}

sub _create_normal_method {
    my ($class, $name) = @_;

    my $real_name = __PACKAGE__.'::'.$name;
    no strict 'refs';
    *{$real_name} = sub {
        my $self = shift;
        $self->{creator}->$name(shift, @_);
    };
}

sub _create_passthru_method {
    my ($class, $name) = @_;

    my $real_name = __PACKAGE__.'::'.$name;
    no strict 'refs';
    *{$real_name} = sub {
        my $self = shift;
        $self->{creator}->$name(@_);
    };
}

__PACKAGE__->_create_kwargs_method('add_agency');
__PACKAGE__->_create_kwargs_method('add_route');
__PACKAGE__->_create_kwargs_method('add_stop');
__PACKAGE__->_create_normal_method('get_id_for_agency');
__PACKAGE__->_create_normal_method('get_id_for_route');
__PACKAGE__->_create_normal_method('get_id_for_stop');
__PACKAGE__->_create_passthru_method('report_status');
__PACKAGE__->_create_passthru_method('get_url');
__PACKAGE__->_create_passthru_method('config_url');



1;
