#!/usr/bin/perl -w

use DBI;

$db = "SERCHIO";
$user = "serchio";
$pass = "serchiouser";

$host = "localhost";

$query = "CALL route();";

$dbh = DBI->connect("DBI:mysql:$db:$host", $user, $pass);

$sqlQuery  = $dbh->prepare($query)
or die "Can't prepare $query: $dbh->errstr\n";

print "----------> inizio il route\n";
 
$sqlQuery->execute or die "can't execute the query: $sqlQuery->errstr";
 
print "----------> ok ho finito\n";
 
$sqlQuery->finish;
exit(0);
