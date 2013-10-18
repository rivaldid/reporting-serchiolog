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

my $instes = $insncons;
my $sttes = $dbh->prepare($instes);

my $dummy = 1;

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
					$stncons->execute((
							convdate($+{giorno}),
							$+{ore},
							$+{pulsar},
							$+{concen},
							$+{tessera},
							$+{evento},
							$+{varco}
						));
				}elsif($row =~ $EV_VARNAP || $row =~ $EV_VARNCH || $row =~ $EV_SCASSO || $row =~ $EV_VARCHI){
					#print RES "$row\n";
					#print "$+{evento} il $+{giorno} alle $+{ore} $+{varco}\n";
					$stvarc->execute((
							convdate($+{giorno}),
							$+{ore},
							$+{pulsar},
							$+{concen},
							$+{evento},
							$+{varco}
						));
				}elsif($row =~ $EV_TESIN || $row =~ $EV_TESSO || $row =~ $EV_TESOR){
					#print RES "$row\n";
					#print "$+{evento} ($+{tessera}) il $+{giorno} alle $+{ore} $+{varco}\n";
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
			}
		}
	} else {
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
$dbh->disconnect;
unlink $LOCKFILE;
