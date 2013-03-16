package Catalyst::Plugin::Session::Store::CouchDB;
use Moose;
use MRO::Compat;
use namespace::autoclean;
use CouchDB::Client;

our $VERSION = '0.01';

BEGIN {
	with 'Catalyst::ClassData';
	with 'MooseX::Emulate::Class::Accessor::Fast';
	extends 'Catalyst::Plugin::Session::Store';
}

__PACKAGE__->mk_classdata('_cdbc');
__PACKAGE__->mk_classdata('_cdb_session_db');

sub _my_config {
	my ($c) = @_;

	return (
		$c->can('_session_plugin_config') ?
			$c->_session_plugin_config
			: (
				$c->can('config') ?
					$c->config->{'Plugin::Session'}
					: {}
			)
	);
}

sub setup_session {
	my ($c) = @_;

    $c->maybe::next::method(@_);

    my $uri = ( $c->_my_config->{'uri'} or 'http://localhost:5984' );
    my $db = ( $c->_my_config->{'database'} or 'app_session' );
    $c->_cdbc( CouchDB::Client->new( 'uri' => $uri ) );

	my $success = eval {
		$c->_cdbc->testConnection();
	};
	die 'Cannot connect to CouchDB instance at ' . $uri if ( $@ or not $success );

	my $sdb = $c->_cdbc->newDB($db);
	$sdb->create() unless ( $c->_cdbc->dbExists($db) );
    $c->_cdb_session_db($sdb);

    return;
}


sub get_session_data {
	my ( $c, $key ) = @_;

	my ( $type, $id ) = split( ':', $key );
	if ( $c->_cdb_session_db->docExists($id) ) {
		my $data = $c->_cdb_session_db->newDoc($id)->retrieve->data->{ ( $type eq 'expires' ? 'expires' : 'session_data' ) };
		return $data;
	}
	return;
}

sub store_session_data {
	my ( $c, $key, $data ) = @_;

	my ( $type, $id ) = split( ':', $key );
	my $doc = $c->_cdb_session_db->newDoc($id);
	if ( $c->_cdb_session_db->docExists($id) ) {
		$doc->retrieve();
	} else {
		$doc->create();
	}

	if ( $type eq 'expires' ) {
		$doc->data->{'expires'} = $data;
	} elsif ( $type eq 'session') {
		$doc->data->{'session_data'} = $data;
	}
	$doc->update();
	return 1;
}

sub delete_session_data {
	my ( $c, $key ) = @_;

	my ( $type, $id ) = split( ':', $key );
	if ( $type eq 'session' ) {
		if ( $c->_cdb_session_db->docExists($id) ) {
			$c->_cdb_session_db->newDoc($id)->retrieve->delete();
		}
	}
	return 1;
}

sub delete_expired_sessions {}

__PACKAGE__->meta->make_immutable();

1;

__END__

=pod

=head1 NAME

Catalyst::Plugin::Session::Store::CouchDB - Store sessions using CouchDB

=head1 SYNOPSIS

	In your application class:

	use Catalyst qw/
		Session
		Session::Store::CouchDB
	/;

	In your configuration (given values are default):
 
	<Plugin::Session>
		url http://localhost:5984
		database app_session
	</Plugin::Session>

=head1 DESCRIPTION

This plugin will store and retrieve your session data using a CouchDB store.

=head1 METHODS

See L<Catalyst::Plugin::Session::Store>.

=over 4

=item get_session_data

=item store_session_data

=item delete_session_data

=item delete_expired_sessions

=back

=head1 AUTHOR

Nicholas Melnick

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2013, Nicholas Melnick

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl 5 itself.

=cut
