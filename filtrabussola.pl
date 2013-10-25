#!/usr/bin/env perl

use feature 'say';

use strict;
use warnings;

use DBI;

my $host = "produzione";
my $user = "serchio";
my $pass = "serchiouser";
my $db = "SERCHIO";

my $select_format = "SELECT data,ora,direzione,badge,utente,azione FROM passaggi_bussola WHERE data LIKE '%s%%' order by utente,data,ora";

my $dbh = DBI->connect("dbi:mysql:database=$db;host=$host", $user, $pass) or die($DBI::errstr);

print "Data: ";


my $in = $ARGV[0] || <STDIN>;
chomp $in;

say $in;

if( $in =~ /\d{4}(-\d\d(-\d\d)?)?/ ){
	my $select = sprintf $select_format, $in;
	my $sth = $dbh->prepare($select) or die($DBI::errstr);
	$sth->execute or die($sth->errstr);

	die("Nessun risultato") if(not $sth->rows);

	my $row;
	my $current;

	$row = $sth->fetchrow_hashref;
	$current = $row->{utente};
	say "Passaggi Bussola di $current per il giorno $row->{data}";
	while($row){
		if($current ne $row->{utente}){
			print "\n\n";
			<STDIN>;
			say "Passaggi Bussola di $row->{utente} per il giorno $row->{data}";
		}
		$current = $row->{utente};
		say "\t$row->{ora} - $row->{direzione}";
		$row = $sth->fetchrow_hashref;
	}
}

$dbh->disconnect;
