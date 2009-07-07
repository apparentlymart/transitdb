
package TransitDB::Creator::Source::GTFS;

use strict;
use warnings;
use base qw(TransitDB::Creator::Source);
use Carp;
use Archive::Zip;
use Archive::Zip::MemberRead;
use Text::CSV;

sub new {
    my ($class, $config) = @_;

    my $self = $class->SUPER::new($config);

    $self->{archive_url} = $config->{archive} or Carp::croak("No archive URL provided");

    return $self;
}

sub import_data {
    my ($self, $target) = @_;

    my $archive_url = $self->{archive_url};
    $target->report_status("Importing from GTFS archive at $archive_url");

    my $archive_file;
    ($archive_file, $archive_url) = $target->get_url($archive_url);

    $target->report_status("My archive file is at $archive_file");

    my $archive = Archive::Zip->new($archive_file) or die "Failed to open archive $archive_url";

    my $agencies = $self->_read_csv_from_archive($archive, 'agency.txt');
    my $routes = $self->_read_csv_from_archive($archive, 'routes.txt');
    my $stops = $self->_read_csv_from_archive($archive, 'stops.txt');

    print STDERR Data::Dumper::Dumper($agencies);

    foreach my $agency (@$agencies) {
        $target->add_agency(
            source_id => $agency->{agency_id},
            name => $agency->{agency_name},
            url => $agency->{agency_url},
        );
    }

}

sub _read_csv_from_archive {
    my ($self, $archive, $filename) = @_;

    my $archive_url = $self->{archive_url};
    my $file = Archive::Zip::MemberRead->new($archive, $filename) or die "No $filename in $archive_url";

    my $csv = Text::CSV->new({binary => 1, allow_loose_quotes => 1});
    my $header_line = $file->getline() or die "No header line in $filename in $archive_url";
    $header_line =~ s/\s+$//g;
    print STDERR "Header line is $header_line\n";
    $csv->parse($header_line) or die "Failed to parse $archive_url $filename header line";
    my @columns = $csv->fields;

    my @ret = ();

    while (my $line = $file->getline()) {
        $line =~ s/\s+$//g;
        $csv->parse($line) or die "Failed to parse $archive_url $filename data line";
        my @values = $csv->fields;

        my $row = {};
        for (my $i = 0; $i < scalar(@columns); $i++) {
            $row->{$columns[$i]} = $values[$i];
        }
        push @ret, $row;
    }

    return \@ret;
}


1;

