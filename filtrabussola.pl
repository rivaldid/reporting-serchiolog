#!/usr/bin/env perl

use feature 'say';

use strict;
use warnings;

use DBI;

my $host = "produzione";
my $user = "serchio";
my $pass = "serchiouser";
my $db = "SERCHIO";

sub doppiabadge{
	my $former = shift;
	my $latter = shift;

	my ($fh, $fm) = split /:/,$former->{ora};
	my ($lh, $lm) = split /:/,$latter->{ora};

	my $diff = ($lh-$fh)+($lm-$fm);

	# BECOME A PROGRAMMER, THEY SAID. IT WILL BE FUN, THEY SAID...
	if(
		($former->{data}||"") eq ($latter->{data}||"") &&
		($diff == 0 || $diff == 1) &&
		($former->{centrale}||"") eq ($latter->{centrale}||"") &&
		($former->{sensore}||"") eq ($latter->{sensore}||"") &&
		($former->{direzione}||"") eq ($latter->{direzione}||"") &&
		($former->{utente}||"") eq ($latter->{utente}||"")
	){
		say "Sono uguali";
	}
}

my $select_format = "SELECT data,ora,direzione,badge,utente,azione FROM passaggi_bussola WHERE data LIKE '%s%%' order by utente,data,ora";

my $dbh = DBI->connect("dbi:mysql:database=$db;host=$host", $user, $pass) or die($DBI::errstr);

print "Data: ";

my $in = $ARGV[0] || <STDIN>;
chomp $in;

say $in;

sub neat{
	my $ref = shift or die("Necessario un hash che non sta'");
	$ref->{data} ||="";
	$ref->{ora} ||="";
	$ref->{direzione} ||="";
	$ref->{badge} ||="";
	$ref->{utente} ||="";
	$ref->{azione} ||="";
	return $ref;
}

if( $in =~ /\d{4}(-\d\d(-\d\d))/ ){
	my $select = sprintf $select_format, $in;
	my $sth = $dbh->prepare($select) or die($DBI::errstr);
	$sth->execute or die($sth->errstr);

	die("Nessun risultato") if(not $sth->rows);

	my $row = $sth->fetchrow_hashref;
	my $prev = undef;
	my $current = $row->{utente};
	say "Passaggi Bussola di $row->{utente} per il $row->{data}";
	while($row){
		if($current ne $row->{utente}){
			print "\n\n";
			<STDIN>;
			say "Passaggi Bussola di $row->{utente} per il $row->{data}";
		}
		$current = $row->{utente};
		say "\t$row->{ora} - $row->{direzione}";
		$prev = $row;
		$row = $sth->fetchrow_hashref;
	}
}else{
	say "Immettere un formato data corretto";
	say "\tes. 2013-10-07 per un solo giorno";
	#say "\tes. 2013-10 per tutto un mese";
	#say "\tes. 2013 per tutto l'anno";
}

$dbh->disconnect;
