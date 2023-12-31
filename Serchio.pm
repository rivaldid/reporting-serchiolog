package Serchio;

use DBI;
use Data::Dumper;
use Data::Compare;
use Archive::Zip;
use Storable qw(nstore_fd fd_retrieve);

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
	our @EXPORT = qw(setdata feed same commit);
	our @EXPORT_OK = qw();
	use Config::File qw(read_config_file);

	$config = read_config_file("./Serchio.conf");

	$dbh = DBI->connect(
		"dbi:mysql:database=$config->{database};host=$config->{host}",
		$config->{username},
		$config->{password}
	) or die($DBI::errstr);

	$sth = $dbh->prepare("SELECT data,ora,direzione,utente,badge,azione FROM passaggi_bussola WHERE data like ?") or die($DBI::errstr);
} #BEGIN

sub neat{
	my $str = shift;
	$str =~ s/\s+$//;
	$str =~ s/\s+/ /g;
	return $str;
}

sub convdate{
	my $d = shift;
	$d =~ m!(\d{2})/(\d{2})/(\d{4})!;
	return "$3-$2-$1";
}

sub setdata{
	my $d = shift;
	if ( $d =~ /\d{4}-\d\d-\d\d/ ){
		$data = $d;
	}

	my $record;
	$sth->execute($data) or die($sth->errstr);
	open CACHE, ">serchio.cache" or die($!);

	while($record = $sth->fetchrow_hashref){
		nstore_fd $record, \*CACHE;
	}

	close CACHE;
	open CACHE, "<serchio.cache" or die($!);
}

sub feed{
	my $record;
	eval{
		$record = fd_retrieve \*CACHE;
	};
	return $record;
}

sub same{
	my $former = shift;
	my $latter = shift;

	my ($fh, $fm) = split /:/,$former->{ora};
	my ($lh, $lm) = split /:/,$latter->{ora};

	my $s = ($lh+$lm) - ($fh+$fm);

	return Compare($former, $latter) || ($s == 0 || $s == 1);
}

END {

	$sth->finish;
	$dbh->disconnect;
}

1;
