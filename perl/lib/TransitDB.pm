
=head1 NAME

TransitDB - Perl interface to TransitDB databases

=cut

package TransitDB;

use strict;
use warnings;



=head1 DESCRIPTION

TransitDB is a pseudo-standard schema for storing information about
public transit networks in an SQLite database. The information stored
in this version is limited to agencies, routes and stops as a starting
point, but it is hoped that future versions will include more interesting
information such as schedule information and bridges to real-time
prediction services like NextBus and BART real-time predictions.

=cut


1;
