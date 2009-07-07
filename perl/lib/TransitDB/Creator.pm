
=head1 NAME

TransitDB::Creator - Create a TransitDB database from source data in various formats

=cut

package TransitDB::Creator;

use strict;
use warnings;
use YAML ();
use URI;
use LWP::UserAgent;
use File::Temp ();
use Cwd qw(cwd);
use Carp ();
use Data::Dumper;
use DBI;
use TransitDB::Creator::Target;
use TransitDB::Creator::Source;

sub new {
    my ($class, %opts) = @_;

    my $config_file = delete $opts{config} or Carp::croak("config is required");
    my $status_cb = delete $opts{status_cb} || sub {};
    my $show_download_progress = delete $opts{show_download_progress} ? 1 : 0;
    Carp::croak("Unrecognized option(s): ".join(',', keys %opts)) if %opts;

    my $self = bless {}, $class;

    $self->{config_file} = $config_file;
    $self->{status_cb} = $status_cb;

    $self->{ua} = LWP::UserAgent->new();
    $self->{ua}->show_progress($show_download_progress) if $self->{ua}->can('show_progress');

    $self->{ids} = {};
    $self->{next_ids} = {};

    return $self;

    system("cat $config_file");
}

sub create_db {
    my ($self, $db_filename) = @_;

    unlink($db_filename) or Carp::croak("Failed to remove existing file $db_filename") if -f $db_filename;
    my $dbh = DBI->connect('dbi:SQLite:'.$db_filename) or Carp::croak "Failed to open SQLite database $db_filename";
    $self->{dbh} = $dbh;

    $self->_create_tables();

    my $config_file;
    my $config_url;
    ($config_file, $config_url) = $self->get_url($self->{config_file}, "file://".cwd()."/");
    $self->{config_url} = $config_url;

    my $config = YAML::LoadFile($config_file) || {};

    my $db_name = $config->{db_name} or Carp::croak("No db_name specified");

    my $sources = $config->{sources} || {};
    my $fixups = $config->{fixups} || {};

    foreach my $source_name (keys %$sources) {
        my $target = TransitDB::Creator::Target->new($self, $source_name);
        my $source = TransitDB::Creator::Source->new($sources->{$source_name});

        $source->import_data($target);
    }

    $self->_create_indices();

}

sub add_agency {
    my ($self, %params) = @_;

    my $id = $self->get_id_for_agency($params{source}, $params{source_id});

    $self->_dbh->do('INSERT INTO agency (agency_id, name, url) VALUES (?, ?, ?)', undef, $id, $params{name}, $params{url});
}

sub get_id_for_agency {
    my $self = shift;
    return $self->_get_id('agency', @_);
}

sub _get_id {
    my ($self, $table, $source, $source_id) = @_;

    my $id_key = join("\t", $source, $source_id);

    return $self->{ids}{$id_key} if defined($self->{ids}{$id_key});

    my $next_id = $self->{next_ids}{$table} || 1;
    $self->{next_ids}{$table} = $next_id + 1;

    return $self->{ids}{$id_key} = $next_id;
}

sub _create_tables {
    my ($self) = @_;

    $self->report_status("Creating database tables...");

    $self->_dbh->do(<<EOT) or die "Failed to create database tables";
CREATE TABLE route (
    route_id INTEGER PRIMARY KEY,
    agency_id REFERENCES agency (agency_id),
    short_name TEXT,
    long_name TEXT,
    description,
    url,
    bg_color,
    fg_color
);
EOT

    $self->_dbh->do(<<EOT) or die "Failed to create database tables";
CREATE TABLE agency (
    agency_id INTEGER PRIMARY KEY,
    name TEXT,
    url
);

EOT

    $self->_dbh->do(<<EOT) or die "Failed to create database tables";
CREATE TABLE stop (
    stop_id INTEGER PRIMARY KEY,
    name TEXT,
    description,
    lat INTEGER,
    lon INTEGER
);

EOT

    $self->_dbh->do(<<EOT) or die "Failed to create database tables";
CREATE TABLE property (
    name,
    value
);
EOT

}

sub _create_indices {
    my ($self) = @_;

    $self->report_status("Creating indices...");
    $self->_dbh->do(<<EOT) or die "Failed to create indices";
CREATE INDEX route_agency_id ON route (agency_id);
EOT

    $self->_dbh->do(<<EOT) or die "Failed to create indices";
CREATE INDEX route_short_name ON route (short_name);
EOT

    $self->_dbh->do(<<EOT) or die "Failed to create indices";
CREATE INDEX route_long_name ON route (long_name);
EOT

    $self->_dbh->do(<<EOT) or die "Failed to create indices";
CREATE INDEX stop_name ON stop (name);
EOT

    $self->_dbh->do(<<EOT) or die "Failed to create indices";
CREATE INDEX agency_name ON agency (name);
EOT

    $self->_dbh->do(<<EOT) or die "Failed to create indices";
CREATE INDEX property_name ON property (name);
EOT

}

sub _ua {
    return $_[0]->{ua};
}

sub _dbh {
    return $_[0]->{dbh};
}

sub report_status {
    my $self = shift;
    $self->{status_cb}->(@_);
}

sub config_url {
    return $_[0]->{config_url};
}

sub get_url {
    my ($self, $url, $base_url) = @_;

    my $is_file = 0;
    $base_url ||= $self->{config_url} if defined($self->{config_url});
    if ($base_url) {
        $url = URI->new_abs($url, $base_url);
        $is_file = 1 if $url->scheme eq 'file';
        $url = $url->canonical;
    }

    my ($fh, $filename) = File::Temp::tempfile();

    $self->report_status("Retrieving $url...") unless $is_file;
    my $res = $self->_ua->get($url, ':content_cb' => sub {
        # Bail out early if this is not a successful response.
        die "Not successful" unless $_[1]->is_success;

        print $fh $_[0];
    });

    die "Failed to fetch $url: ".$res->status_line."\n" unless $res->is_success;

    return ($filename, $url);
}

1;
