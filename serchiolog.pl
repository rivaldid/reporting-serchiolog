#!/usr/bin/env perl
use Archive::Zip;
use DBI;

use strict;
use warnings;

# DB
my $user = "serchio";
my $pass = "serchiouser";
my $db = "SERCHIO";
my $host = "10.98.2.159";


if ( $ARGV[0] eq 'shell'){
	my $regex = qr(^(?<data>\d{4}|\d{4}-\d\d|\d{4}-\d\d-\d\d)\s+(?<utente>.*));
my $quando='';
my $chi='';
while(<STDIN>){
	chomp;
	my @values = split /\s+/;
}
exit;
}

my $LOCKFILE = "./SERCHIO.LOCK";

if( -e $LOCKFILE ){
	die("Un processo di importazione e' gia' in esecuzione");
}else{
	open RES, ">$LOCKFILE";
	close RES;
}

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

my $xps = shift or die("XPS file required\n");

my $opt = shift || "";

my $zip = Archive::Zip->new($xps);

my @names = $zip->membersMatching('Pages\/\d+.fpage');

my $dbh = DBI->connect("dbi:mysql:database=$db;host=$host", $user, $pass) or die($DBI::errstr);

my $instrans = "INSERT INTO report (data,ora,centrale,concentratore,seriale,azione,sensore,direzione,utente) VALUES(?,?,?,?,?,?,?,?,?)";
my $sttrans = $dbh->prepare($instrans);

my $insncons = "INSERT INTO report (data,ora,centrale,concentratore,seriale,azione,sensore) VALUES(?,?,?,?,?,?,?)";
my $stncons = $dbh->prepare($insncons);

my $insvarc = "INSERT INTO report (data,ora,centrale,concentratore,azione,sensore) VALUES(?,?,?,?,?,?)";
my $stvarc = $dbh->prepare($insvarc);

my $instaab = "INSERT INTO report (data,ora,azione,utente) VALUES(?,?,?,?)";
my $sttaab = $dbh->prepare($instaab);

my $insall = $insvarc;
my $stall = $dbh->prepare($insall);

my $instamper = $insvarc;
my $sttamper = $dbh->prepare($instamper);

my $inscstato = "INSERT INTO report (data,ora,centrale,concentratore,azione,sensore,utente) VALUES(?,?,?,?,?,?,?)";
my $stcstato = $dbh->prepare($inscstato);

my $inscaduta = "INSERT INTO report (data,ora,centrale,concentratore,azione) VALUES(?,?,?,?,?)";
my $stcaduta = $dbh->prepare($inscaduta);

my $insricprog = "INSERT INTO report (data,ora,centrale,concentratore,azione,utente) VALUES(?,?,?,?,?,?)";
my $stricprog = $dbh->prepare($insricprog);

my $insfineprog = $inscaduta;
my $stfineprog = $dbh->prepare($insfineprog);

my $insminipulsar = $inscaduta;
my $stminipulsar = $dbh->prepare($insminipulsar);

my $instesanon = "INSERT INTO report (data,ora,centrale,concentratore,azione,sensore,direzione,utente) VALUES(?,?,?,?,?,?,?,?)";
my $sttesanon = $dbh->prepare($instesanon);

my $instes = $insncons;
my $sttes = $dbh->prepare($instes);

my $inslinea = "INSERT INTO report (azione) VALUES(?)";
my $stlinea = $dbh->prepare($inslinea);

my $dummy = 0;

open UNMACHED, ">>unmatched.txt" or die($!);

open RES, ">report.txt" or die ("Canot open file: $!\n");
for(@names){ #per ogni fpage
	$_->extractToFileNamed("temp");
	open TEMP, "<temp" or die "Canot open file: $!\n";
	if( $opt eq "" ){
		while(<TEMP>){
			if(m/unicodestring="(.*)" \/>/i){
				my $row = $1;
				$row =~ s/&apos;/'/;

				if($row =~ $EV_TRANS){
					#print RES "$row\n";
					#print "Cognome: ".neat(substr($+{nominativo},0,16))." - Nome: ".neat(substr($+{nominativo},16))."(Tessera $+{tessera})";
					#print " - $+{evento} alle $+{ore} il $+{giorno} ($+{pulsar} $+{varco} $+{verso})\n";
					if(not $dummy){
						$sttrans->execute( (
								convdate($+{giorno}),
								$+{ore},
								$+{pulsar},
								$+{concen},
								$+{tessera},
								$+{evento},
								$+{varco},
								$+{verso},
								neat($+{nominativo})
							) ) or die($sttrans->errstr);
					}
				}elsif($row =~ $EV_NCONS ){
					#print RES "$row\n";
					#print "Tessera: $+{tessera} ore: $+{ore} - pulsar: $+{pulsar} il $+{giorno} attraverso $+{varco}\n";
					if(not $dummy){
						$stncons->execute((
								convdate($+{giorno}),
								$+{ore},
								$+{pulsar},
								$+{concen},
								$+{tessera},
								$+{evento},
								$+{varco}
							));
					}
				}elsif($row =~ $EV_VARNAP || $row =~ $EV_VARNCH || $row =~ $EV_SCASSO || $row =~ $EV_VARCHI){
					#print RES "$row\n";
					#print "$+{evento} il $+{giorno} alle $+{ore} $+{varco}\n";
					if(not $dummy){
						$stvarc->execute((
								convdate($+{giorno}),
								$+{ore},
								$+{pulsar},
								$+{concen},
								$+{evento},
								$+{varco}
							));
					}
				}elsif($row =~ $EV_TESIN || $row =~ $EV_TESSO || $row =~ $EV_TESOR){
					#print RES "$row\n";
					#print "$+{evento} ($+{tessera}) il $+{giorno} alle $+{ore} $+{varco}\n";
					if(not $dummy){
						$sttes->execute((
								convdate($+{giorno}),
								$+{ore},
								$+{pulsar},
								$+{concen},
								$+{tessera},
								$+{evento},
								$+{varco}
							));
					}
				}elsif( $row =~ $EV_TAAB ){
					if( not $dummy){
						$sttaab->execute((
								convdate($+{giorno}),
								$+{ore},
								$+{azione},
								$+{utente}
							));
					}
					
				}elsif( $row =~ $EV_ALL ){
					#print "$row\n";
					if( not $dummy ){
						$stall->execute((
								convdate($+{giorno}),
								$+{ore},
								$+{centrale},
								$+{concentratore},
								$+{evento},
								$+{varchi}
							));
					}
				}elsif( $row =~ $EV_TAMPER ){
					#print "$row\n";
					if( not $dummy ){
						$sttamper->execute((
								convdate($+{giorno}),
								$+{ore},
								$+{centrale},
								$+{concentratore},
								$+{evento},
								$+{varco}
							));
					}
				}elsif( $row =~ $EV_CSTATO ){
					#print "$row\n";	
					if(not $dummy){
						$stcstato->execute((
								convdate($+{giorno}),
								$+{ore},
								$+{centrale},
								$+{concentratore},
								$+{evento},
								$+{varco},
								$+{operatore}
							));
					}
				}elsif( $row =~ $EV_CADUTA ){
					#print "$row\n";	
					if( not $dummy ){
						$stcaduta->execute((
								convdate($+{giorno}),
								$+{ore},
								$+{centrale},
								$+{concentratore},
								$+{evento}
							));
					}
				}elsif( $row =~ $EV_RICPROG ){
					#print "$row\n";	
					if( not $dummy ){
						$stricprog->execute((
								convdate($+{giorno}),
								$+{ore},
								$+{centrale},
								$+{concentratore},
								$+{evento},
								$+{operatore}
							));
					}
				}elsif( $row =~ $EV_FINEPROG ){
					#print "$row\n";	
					if( not $dummy ){
						$stfineprog->execute((
								convdate($+{giorno}),
								$+{ore},
								$+{centrale},
								$+{concentratore},
								$+{evento}
							));
					}
				}elsif( $row =~ $EV_MINPULSAR ){
					#print "$row\n";	
					if( not $dummy ){
						$stminipulsar->execute((
								convdate($+{giorno}),
								$+{ore},
								$+{centrale},
								$+{concentratore},
								$+{evento}
							));
					}
				}elsif( $row =~ $EV_TESANON ){
					#print "--- $row\n";	
					if( not $dummy ){
						$sttesanon->execute((
								convdate($+{giorno}),
								$+{ore},
								$+{centrale},
								$+{concentratore},
								$+{evento},
								$+{varco},
								$+{verso},
								$+{utente}
							));
					}
				}elsif( $row =~ $EV_LINEA ){
					#print "$row\n";
					if( not $dummy ){
						$stlinea->execute((
								$+{evento}
							));
					}
				}else{
					print UNMACHED $row,"\n";
				}
			}
		}
	}else{
		while(<TEMP>){
			if(m/unicodestring="(.*)" \/>/i){
				my $match = $1;
				print "$match\n";
			}
		}
	}
	close TEMP;
	unlink "temp";
	}
close RES;
close UNMACHED;
$dbh->disconnect;
unlink $LOCKFILE;
