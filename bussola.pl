#!/usr/bin/env perl

use Serchio;
use Data::Dumper;

use strict;
use warnings;

setdata '2013-10-10';
my ($former, $latter) = (feed, feed);

if( $former && $latter ){
	my $current;
	do{
		if( $current ne $former->{utente}){
			$current = $former->{utente};
			<STDIN>;
		}	

		print "$former->{utente} - $former->{ora} - $former->{direzione}";
		if(same $former, $latter){
			print " | Doppia Badgiatura ($latter->{ora} - $latter->{direzione})\n";
		}else{
			print "\n";
		}
		($former, $latter) = (feed, $former);
	}while($former);
}
