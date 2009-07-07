
package TransitDB::Creator::Source;

use strict;
use warnings;
use Carp;

sub new {
    my ($class, $config) = @_;

    if ($class eq __PACKAGE__) {
        my $type = $config->{type} or Carp::croak "No source type specified";
        $class = __PACKAGE__.'::'.$type;
        eval " use $class; 1; " or Carp::croak("Failed to load source class $class: $@");
        return $class->new($config);
    }

    return bless {}, $class;
}

sub import_data {
    my ($self, $target) = @_;

    Carp::croak("import_data is not implemented for $self");

}

1;
