package Serchio;

use DBI;
use Data::Dumper;

use warnings;
use strict;

my $config;
my $dbh;
my $sth;
my $data = undef;

BEGIN {
	require Exporter;
	our $VERSION = 1.00;
	our @ISA = qw(Exporter);
	our @EXPORT = qw(setdata feed storeall unstoreall);
	our @EXPORT_OK = qw();
	use Config::File qw(read_config_file);

	$config = read_config_file("./Serchio.conf");

	$dbh = DBI->connect(
		"dbi:mysql:database=$config->{database};host=$config->{host}",
		$config->{username},
		$config->{password}
	) or die($DBI::errstr);

	$sth = $dbh->prepare("SELECT data,ora,direzione,utente,badge,azione FROM passaggi_bussola WHERE data like ?") or die($sth->errstr);
}

END {

	$sth->finish;
	$dbh->disconnect;
}

sub setdata{
	my $d = shift;
	if ( $d =~ /\d{4}-\d\d-\d\d/ ){
		$data = $d;
	}
}

sub storeall{
	if($data){
		use Storable qw(nstore_fd);
		my $file = shift or die("Filename required");
		open STORE, ">>$file" or die($!);
		$sth->execute($data) or die($sth->errstr);

		my $hashref = $sth->fetchrow_hashref;
		while($hashref){
			nstore_fd $hashref, \*STORE;
			$hashref = $sth->fetchrow_hashref;
		}

		close STORE;


	}else{
		print "Date is already set\n";
		return 0;
	}
}

sub unstoreall{
	use Storable qw(fd_retrieve);
	my $file = shift or die("Filename needed");
	my $hashref;

	open STORE, "<$file" or die($1);
	$hashref = fd_retrieve(\*STORE);

	while($hashref){
		print Dumper($hashref);
		$hashref = fd_retrieve(\*STORE);
	}
	close STORE;
}

1;










