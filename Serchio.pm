package Serchio;

use DBI;
use Data::Dumper;
use Data::Compare;
use Storable qw(nstore_fd fd_retrieve);

use warnings;
use strict;

my $config;
my $dbh;
my $sth;
my $data = undef;


# DEFINIZIONI REGOLARI

my $DATA = 	qr!\d{2}/\d{2}/\d{4}!;
my $ORA =	qr!\d{2}:\d{2}!;
my $PULSAR =	qr!PULSAR 1|PULSAR 2!;
my $CONCEN =	qr!\(000\)|\(001\)!;
my $NOME =	qr![[:alpha:][:space:]]{10}!;
my $COGNOME =	qr![[:alpha:][:space:]]{16}!;
my $VARCO =	qr!H\(\d\d\)!;
my $VERSO =	qr!USCITA|ENTRATA!;
my $TESSERA =	qr!\d{8}!;

my $PREAMBLE = qr!(?<giorno>$DATA)\s(?<ore>$ORA)\s(?<pulsar>$PULSAR)\s{12}(?<concen>$CONCEN)!;

my $EV_TAAB = qr!(?<giorno>$DATA)\s(?<ore>$ORA)\s(?<operatore>\w{6})\s+(?<evento>Tastiera Abilitata)!;
my $EV_ALL = qr!$PREAMBLE\s+(?<evento>Allarmi Acquisiti)(?<varchi>(?:\(H\s\d\d\))|(?:\(H:\d-\d\d\)))!;
my $EV_TAMPER = qr!$PREAMBLE\s+(?<evento>Allarme Tamper)\s(?<varco>$VARCO)!;
my $EV_CSTATO = qr!$PREAMBLE\s+(?<evento>Comando Cambio Stato Lettore)\s$VARCO\sABILITATO\s\.\s\[\s(?<operatore>\w{6})\s\]!;
my $EV_CADUTA = qr!$PREAMBLE\s+(?<evento>Caduta Linea)!;
my $EV_RICPROG = qr!$PREAMBLE\s+(?<evento>Richiesta Invio Programmazione)\s\.\s\[\s(?<operatore>\w+)\s\]!;
my $EV_FINEPROG = qr!$PREAMBLE\s+(?<evento>Fine invio dati di programmazione)!;
my $EV_MINPULSAR = qr!$PREAMBLE\s+(?<evento>Linea Mini Pulsar)!;
my $EV_TESANON = qr!$PREAMBLE\s\*{8}\s(?<evento>Transito effettuato)\s\s(?<varco>$VARCO)(?<verso>$VERSO)\s(?<nominativo>.+)!;
my $EV_LINEA = qr!(?<evento>LINEA (?:ON|OFF))!;


my $EV_TRANS =	qr!$PREAMBLE\s(?<tessera>$TESSERA)\s(?<evento>Transito effettuato)\s\s(?<varco>$VARCO)(?<verso>$VERSO)\s(?<nominativo>.+)!;
my $EV_NCONS =	qr!$PREAMBLE\s(?<tessera>$TESSERA)\s(?<evento>Transito non consentito)\s(?<varco>$VARCO)!;

my $EV_VARNAP =	qr!$PREAMBLE\s{10}(?<evento>Varco non aperto)\s(?<varco>$VARCO)!;
my $EV_VARNCH =	qr!$PREAMBLE\s{10}(?<evento>Varco non chiuso)\s(?<varco>$VARCO)!;
my $EV_SCASSO =	qr!$PREAMBLE\s{10}(?<evento>Scasso varco)\s(?<varco>$VARCO)!;
my $EV_VARCHI =	qr!$PREAMBLE\s{10}(?<evento>Varco chiuso)\s(?<varco>$VARCO)!;

my $EV_TESSO =	qr!$PREAMBLE\s(?<tessera>$TESSERA)\s(?<evento>Tessera sospesa)\s(?<varco>$VARCO)!;
my $EV_TESOR =	qr!$PREAMBLE\s(?<tessera>$TESSERA)\s(?<evento>Tessera fuori orario)\s(?<varco>$VARCO)!;
my $EV_TESIN =	qr!$PREAMBLE\s(?<tessera>$TESSERA)\s(?<evento>Tessera inesistente)\s(?<varco>$VARCO)!;

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

BEGIN {
	require Exporter;
	our $VERSION = 1.00;
	our @ISA = qw(Exporter);
	our @EXPORT = qw(setdata feed same);
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

1;
