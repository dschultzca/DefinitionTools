#!/usr/bin/perl 
#
# Copyright (C) 2012  Dale C. Schultz
# RomRaider member ID: dschultz
#
# You are free to use this source for any purpose, but please keep
# notice of where it came from!
#
#
# Purpose
#   Reads from IDC dump file to update MySQL Logger definitions tables.
#	Version:	5
#	Update:		Sep. 4/2012	
#------------------------------------------------------------------------------------------

use File::Basename;
unless ($ARGV[0]) {
	print "Input file missing...\n";
	print "Usage: logger_update.pl <IDC dump text file>\n";
	exit 1;
}
$param_file = $ARGV[0];
if ($ARGV[1] eq "-commit") {$commit = 1};

# get the list of stat files
open (INPUT, "$param_file") || die "Could not open file $param_file : $!\n";
$param_file = basename($param_file);
$param_file =~ s/\.txt//;
$param_file = uc($param_file);
use DBI;

# create a handle and connect to the statistics database
$dbh = DBI->connect (
	'DBI:mysql:database=definitions;host=localhost',
	'root','ieee802',{AutoCommit=>1, RaiseError=>0, PrintError=>0})
	or die "$0: Couldn't connect to database";

# build arrays from the database tables, lookups in memory are faster
# than multiple queries of the database
&get_db_version;
&get_ecuparam_id;
&get_address_id;
&get_ecu_id;
&get_unique_id;
&get_unique_id_check;
#goto THE_END;
$add_ecuid = 0;
$add_addr = 0;
$change_addr = 0;
$add_entry = 0;

print "Current Database Version: $db_id ($db_version)\n";
#check if we have the ECU ID already
if (!$ecuid_id{$param_file}) {
	print "ECU ID $param_file is not defined.\n";
	if ($commit) {
		new_ecuid_entry($param_file);
		$update = "Added ECU ID: $param_file to extended parameters\n";
		print "+COMMIT: ECU ID $param_file ($ecuid_id{$param_file}) added.\n";
	}
	else {
		print "+TEST: ECU ID $param_file will be added.\n";
	}
		$add_ecuid++;
}
else {
	print "ECU ID $param_file ($ecuid_id{$param_file}) exists.\n";
	$update = "Updated ECU ID: $param_file extended parameters \n";
}
$count = 0;
$count1 = 0;
foreach $line (<INPUT>) {
	$count++;
	if ($line =~ /^\#/) {
		$count--;
		next;
	}
	@values = split(/\s+/, $line);		# line format expected: Extended Paramter ID <space> RAM Address <space> Data Length
	if ($#values != 2) {				# line should only contain three values
		print "WARNING: Line $count invalid number of parameters, line skipped.\n";
		$warn++;
		next;
	}
	@extname = split(/_/, $values[0]);	# split first argument to extract the ID from the last element
	$extid = $extname[$#extname];		# get last element
	$extid =~ s/^E//;					# clean last element up so we have digits only
	if (length($values[1]) > 6) {
		$values[1] =~ s/^..//;			# remove first two bytes to make the address six bytes long
	}
	if (($values[2] != 1) &&
		($values[2] != 2) &&
		($values[2] != 4) ) {
		print "WARNING: Invalid data length ($values[2]) at line $count\n";
		$warn++;
		next;
	}
	
	# check if we have the Extended Parameter id already
	if (!$ecuparam_id{$extid}) {
		print "WARNING: Extended parameter $extid is not a known ID.\n";
		$warn++;
		next;
	}
	# check if we have the RAM address/length id already
	if (!$address_id{$values[1]}{$values[2]}) {
		print "Address $values[1]/$values[2] is not defined.\n";
		if ($commit) {
			new_addr_entry($values[1], $values[2]);
			print "+COMMIT: Address $values[1]/$values[2] ($address_id{$values[1]}{$values[2]}) added.\n";
		}
		else {
			print "+TEST: Address $values[1]/$values[2] will be added.\n";
		}
		$add_addr++;
	}
	else {
		# print "Address $values[1]/$values[2] ($address_id{$values[1]}{$values[2]}) exists.\n";
	}
	# check to see if the parameter entry exists and if the address and data length match or not
	# if they do not match then UPDATE rather than INSERT the entry
	if (defined($unique_id_check{$param_file.$extid}) &&
		($unique_id_check{$param_file.$extid} != $address_id{$values[1]}{$values[2]})) {
		$current_addr = $db_address{$unique_id_check{$param_file.$extid}};		# hex addr value
		$current_len = $db_address_len{$unique_id_check{$param_file.$extid}};	# data length
		$current_addr_id = $address_id{$current_addr}{$current_len};			# address serial number
		$new_addr = $values[1];
		$new_len = $values[2];
		$new_addr_id = $address_id{$new_addr}{$new_len};
		if ($commit) {
			update_unique_entry($unique_id_check_sn{$param_file.$extid}, $new_addr_id);
			print "*  COMMIT: Address entry $current_addr/$current_len ($current_addr_id) ";
			print "for $param_file/E${extid} - changed to $new_addr/$new_len ($new_addr_id).\n";
			$update = $update."Changed address/length entry for ECU ID $param_file for extended parameter E${extid}\n";
		}
		else {
			print "*  INFO: Address entry $current_addr/$current_len ($current_addr_id) ";
			print "for $param_file/E${extid} - will change to $new_addr/$new_len ($new_addr_id).\n";
		}
		$change_addr++;
	}
	else {
		# finally check to see if the ECU ID is already defined in the database for this Extended Parameter
		if (!$unique_id{$param_file.$extid.$values[1].$values[2]}) {
			print "  E${extid} - Parameter combination is not defined.\n";
			if ($commit) {
				new_unique_entry($extid, $param_file, $values[1], $values[2]);
				print "+  COMMIT: E${extid} - unique entry ($unique_id{$param_file.$extid.$values[1].$values[2]}) added.\n";
			}
			else {
				print "+  TEST: E${extid} - will be added.\n";
			}
			$add_entry++;
		}
		else {
			print "   ECU ID $param_file ($ecuid_id{$param_file}) exists for extended parameter E${extid} ($unique_id{$param_file.$extid.$values[1].$values[2]}).\n";
		}
	}
	$count1++;
}
print "\n$count1 of $count lines evaluated.\n";
if ($warn) {
	print "$warn WARNING(S)\n";
}
if ($commit) {
	&update_version;
	&get_db_version;
	print "COMMIT: New Database version is $db_id ($db_version)\n";
	print "Changes:\n$update\n";
}
elsif ($warn) {
	print "!--> Correct input file and test again <--!\n";
}
else {
	print "TEST complete, run with commit to add entries to database.\n";
}
print "Summary:\n";
print "\tECU ID added: $add_ecuid\n" if ($add_ecuid);
print "\tAddresses added: $add_addr\n" if ($add_addr);
print "\tAddresses changed: $change_addr\n" if ($change_addr);
print "\tEntries added: $add_entry\n" if ($add_entry);

THE_END:
$dbh->do("FLUSH TABLES");
$dbh->disconnect;
exit;

# --- SUBROIUTINES ---

sub get_db_version {
	# get database version
	my $id, $version;
	my $sql = qq(SELECT id, version FROM version ORDER BY id DESC LIMIT 1);
	my $sth = $dbh->prepare($sql);
	$sth->execute;
	$sth->bind_columns(\$id, \$version);
	while ($sth->fetch) {
		$db_id=$id;
		$db_version=$version;
	}
	$sth->finish;
}

sub get_ecuparam_id {
	# create an array for all of the extended parameters
	my $serial, $id, $name;
	my $sql = qq(SELECT serial, id, name FROM ecuparam);
	my $sth = $dbh->prepare($sql);
	$sth->execute;
	$sth->bind_columns(\$serial, \$id, \$name);
	while ($sth->fetch) {
		$ecuparam_id{$id}=$serial;
		$ecuparamd_id{$serial}=$name;
	}
	# for $key (keys %ecuparam_id) {
		# print "Key: $key Value: $ecuparam_id{$key}\n";
	# }
	$sth->finish;
}

sub get_address_id {
	# create an array for all of the addresses
	my $serial, $address, $length;
	my $sql = qq(SELECT * FROM address);
	my $sth = $dbh->prepare($sql);
	$sth->execute;
	$sth->bind_columns(\$serial, \$address, \$length);
	while ($sth->fetch) {
		$address_id{$address}{$length}=$serial;
		$db_address{$serial} = $address;
		$db_address_len{$serial} = $length;
	}
	#for $key (keys %db_address) {
		#print "Key: $key Value: $db_address{$key}\n";
	#}
	$sth->finish;
}

sub get_ecu_id {
	# create an array for all of the ECU IDs
	my $serial, $ecuid;
	my $sql = qq(SELECT * FROM ecuid);
	my $sth = $dbh->prepare($sql);
	$sth->execute;
	$sth->bind_columns(\$serial, \$ecuid);
	while ($sth->fetch) {
		$ecuid_id{$ecuid}=$serial;
	}
	# for $key (keys %ecuid_id) {
		# print "Key: $key Value: $ecuid_id{$key}\n";
	# }
	$sth->finish;
}

sub get_unique_id_check {
	# create an array for all of the ECU ID, Extended Parameters, Address and length 
	my $component, $addr_id, $id;
	my $sql = qq[SELECT 
		CONCAT(ecuid.ecuid, ecuparam.id) AS component, ecuparam_rel.addressid AS addr_id, ecuparam_rel.serial AS id
		FROM ecuparam_rel
		LEFT JOIN ecuid ON ecuparam_rel.ecuidid = ecuid.serial
		LEFT JOIN ecuparam ON ecuparam_rel.ecuparamid = ecuparam.serial
		];
	my $sth = $dbh->prepare($sql);
	$sth->execute;
	$sth->bind_columns(\$component, \$addr_id, \$id);

	# get the returned rows and create the array
	while ($sth->fetch) {
		$unique_id_check{$component}=$addr_id;
		$unique_id_check_sn{$component}=$id;
	}

	#debug print out array
	#for $key (keys %unique_id_check) {
		#print "Key: $key Value: $unique_id_check{$key}\n";
	#}
	$sth->finish;
}
	
sub get_unique_id {
	# create an array for all of the ECU ID, Extended Parameters, Address and length 
	my $component, $id;
	my $sql = qq[SELECT 
		CONCAT(ecuid.ecuid,ecuparam.id,address.address,address.length) AS component,
		ecuparam_rel.serial AS id
		FROM ecuid, ecuparam, address, ecuparam_rel
		WHERE ecuparam_rel.ecuparamid=ecuparam.serial
		AND ecuparam_rel.ecuidid=ecuid.serial
		AND ecuparam_rel.addressid=address.serial];
	my $sth = $dbh->prepare($sql);
	$sth->execute;
	$sth->bind_columns(\$component, \$id);

	# get the returned rows and create the array
	while ($sth->fetch) {
		$unique_id{$component}=$id;
	}

	#debug print out array
	# for $key (keys %unique_id) {
		# print "Key: $key Value: $unique_id{$key}\n";
	# }
	$sth->finish;
}

sub update_unique_entry {
	# Address and length entry for an exisitng parameter
	my $serial = shift;
	my $addr_id = shift;
	my $sql = qq[UPDATE ecuparam_rel SET addressid = '$addr_id' WHERE serial = '$serial'];
	my $sth = $dbh->prepare($sql);
	$sth->execute;
	$sth->finish;
}

sub update_version {
	# update version of database
	# vserion = YYYYMMDD_hhmmss 
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
	$version = sprintf("%04d%02d%02d_%02d%02d%02d", $year, ++$mon, $mday, $hour, $min, $sec);
	$update =~ s/\n$//;
	my $sql_version_in = qq[INSERT INTO `version` (`version`, `update`)  VALUES ('$version', '$update')];
	my $sth = $dbh->prepare($sql_version_in);
	$sth->execute;
	$sth->finish;
}

sub new_ecuid_entry {
	# create a new entry in the database for the current ECU ID as we have
	# not seen it before. 

	my $ecuid = shift;			# ECU ID pasted to subroutine

	# if not already in the list insert a new entry and requery
	my $sql_ecuid_in = qq[INSERT INTO ecuid (ecuid) VALUES ('$ecuid')];
	my $sth = $dbh->prepare($sql_ecuid_in);
	$sth->execute;
	&get_ecu_id;
	$sth->finish;
}

sub new_addr_entry {
	# create a new entry in the database for the current address as we have
	# not seen it before. 

	my $address = shift;		# RAM address pasted to subroutine
	my $addr_len = shift;		# length of data to retrieve at address pasted to subroutine

	# next the address (if not already in the list insert a new entry and requery)
	my $sql_addr_in = qq[INSERT INTO address (address, length) VALUES ('$address', '$addr_len')];
	my $sth = $dbh->prepare($sql_addr_in);
	$sth->execute;
	&get_address_id;
	$sth->finish;
}

sub new_unique_entry {
	# create a new entry in the database for the current Extended Parameter as we have
	# not seen it before. 

	my $extparamid = shift;		# Extended parameter pasted to subroutine
	my $ecuid = shift;			# ECU ID pasted to subroutine
	my $address = shift;		# RAM address pasted to subroutine
	my $addr_len = shift;		# length of data to retrieve at address pasted to subroutine

	# now we can insert the new Extended Parameter relation info into the table
	my $sql_ecuparamrel_in = qq[INSERT INTO
		ecuparam_rel (ecuparamid, ecuidid, addressid)
		VALUES ('$ecuparam_id{$extparamid}', '$ecuid_id{$ecuid}', '$address_id{$address}{$addr_len}')];
	my $sth = $dbh->prepare($sql_ecuparamrel_in);
	$sth->execute;
	&get_unique_id;
	$sth->finish;
}
