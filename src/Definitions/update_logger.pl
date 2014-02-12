#!/usr/bin/perl 
#
# Copyright (C) 2014  Dale C. Schultz
# RomRaider member ID: dschultz
#
# You are free to use this source for any purpose, but please keep
# notice of where it came from!
#
#
# Purpose
#   Reads from IDC dump file to update MySQL Logger definitions tables.
#	Version:	8
#	Update:		Feb. 06/2014	
#------------------------------------------------------------------------------------------

use File::Basename;
unless ($ARGV[0])
{
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
$ecuid = uc($param_file);
use DBI;

# create a handle and connect to the statistics database
$dbh = DBI->connect (
	'DBI:mysql:database=definitions;host=localhost',
	'xxxx','xxxx',{AutoCommit=>1, RaiseError=>0, PrintError=>0})
	or die "$0: Couldn't connect to database";

&get_db_version;
&get_ecuparam_id;
$add_ecuid = 0;
$add_addr = 0;
$change_addr = 0;
$add_entry = 0;

print "Current Database Version: $db_id ($db_version)\n";
#check if we have the ECU ID already
$ecuid_serial = get_ecu_id($ecuid);
if ($ecuid_serial)
{
	print "ECU ID $ecuid ($ecuid_serial) exists.\n";
	$update = "Updated ECU ID: $ecuid extended parameters \n";
}
else
{
	print "ECU ID $ecuid is not defined.\n";
	if ($commit)
	{
		$ecuid_serial = new_ecuid_entry($ecuid);
		$update = "Added ECU ID: $ecuid to extended parameters\n";
		print "+  COMMIT: ECU ID $ecuid ($ecuid_serial) added.\n\n";
	}
	else
	{
		print "+  TEST: ECU ID $ecuid will be added.\n\n";
	}
		$add_ecuid++;
}
$count = 0;
$count1 = 0;
foreach $line (<INPUT>)
{
	$bit = '';
	$count++;
	if ($line =~ /^\#/)
	{
		$count--;
		next;
	}
	@values = split(/\s+/, $line);		# line format expected: Extended Paramter ID <space> RAM Address [<space> bit]
	if ($#values > 2)					# line contains two or three values
	{
		print "WARNING: Line $count invalid number of parameters, line skipped.\n";
		$warn++;
		next;
	}
	@extname = split(/_/, $values[0]);	# split first argument to extract the ID from the last element
	$extid = $extname[$#extname];		# get last element
	$extid =~ s/^E//;					# clean last element up so we have digits only
	if (length($values[1]) > 6)
	{
		$values[1] =~ s/.*(\w{6,6}$)/\1/;	# make the address six bytes long
	}
	$addr = $values[1];
	if ($#values == 2)					# line contains three values, get bit
	{
		$bit = $values[2];
	}
	# check if we have the Extended Parameter id already
	if (!$ecuparam_id{$extid})
	{
		print "WARNING: Extended parameter $extid is not a known ID.\n";
		$warn++;
		next;
	}
	
	# default length of data expected for this Extended Parameter id
	$deft_len = $ecuparam_len{$ecuparam_id{$extid}};

	# check that the bit value is appropriate for the length
	$address_id = '';
	if (($deft_len == 1 && $bit >= 0 && $bit <= 7 ) ||
		($deft_len == 2 && $bit >= 0 && $bit <= 15) ||
		($deft_len == 4 && $bit >= 0 && $bit <= 31))
	{
		$address_id = get_address_id($addr, $deft_len, $bit);
	}
	else
	{
		print "WARNING: Incompatible bit value passed for parameter address length, length:$deft_len, bit:$bit\n";
		$warn++;
	}

	# check if we have the RAM address/length/bit id already
	$address_id = get_address_id($addr, $deft_len, $bit);
	if ($address_id)
	{
		print "Address $addr/$deft_len/$bit ($address_id) exists.\n\n";
	}
	else
	{
		print "Address $addr/$deft_len/$bit is not defined.\n";
		if ($commit)
		{
			$address_id = new_addr_entry($addr, $deft_len, $bit);
			print "+  COMMIT: Address $addr/$deft_len/$bit ($address_id) added.\n\n";
		}
		else
		{
			print "+  TEST: Address $addr/$deft_len/$bit will be added.\n\n";
		}
		$add_addr++;
	}
	# check to see if the parameter entry exists and if the address_id matches or not.
	# If they don't match then UPDATE rather than INSERT the entry
	($param_rel_id, $address_serial) = get_relation_id($ecuid_serial, $ecuparam_id{$extid});
	if ($param_rel_id)
	{
		if ($address_serial == $address_id)
		{
				print "E${extid} - Parameter combination Address entry matches ($address_serial), no change.\n\n";
		}
		else
		{
			if ($commit)
			{
				update_unique_entry($param_rel_id, $address_id);
				print "~  COMMIT: E${extid} - Parameter combination Address entry ($address_serial) ";
				print "changed to $address_id.\n\n";
				$update = $update."Changed address/length/bit entry for ECU ID $ecuid for extended parameter E${extid}\n";
			}
			else
			{
				print "*  TEST: E${extid} - Parameter combination Address entry ($address_serial) ";
				if ($address_id)
				{
					print "will change to $address_id.\n\n";
				}
				else
				{
					print "will be updated.\n\n";
				}
			}
			$change_addr++;
		}
	}
	else
	{
		print "E${extid} - Parameter combination is not defined.\n";
		if ($commit)
		{
			$param_rel_id = new_unique_entry($ecuid_serial, $ecuparam_id{$extid}, $address_id);
			print "+  COMMIT: E${extid} - unique entry ($param_rel_id) added.\n\n";
		}
		else
		{
			print "+  TEST: E${extid} - will be added.\n\n";
		}
		$add_entry++;
	}
	$count1++;
}
print "$count1 of $count lines evaluated.\n";
if ($warn)
{
	print "$warn WARNING(S)\n";
}
if ($commit)
{
	&update_version;
	&get_db_version;
	print "COMMIT: New Database version is $db_id ($db_version)\n";
	print "Changes:\n$update\n";
}
elsif ($warn)
{
	print "!--> Correct input file and test again <--!\n";
}
else
{
	print "TEST complete, run with commit to add entries to database.\n";
}
print "Summary:\n";
print "\tECU ID added: $add_ecuid\n" if ($add_ecuid);
print "\tAddresses added: $add_addr\n" if ($add_addr);
print "\tParameter Combo Addresses changed: $change_addr\n" if ($change_addr);
print "\tEntries added: $add_entry\n" if ($add_entry);
print "\tNo changes\n" if (!$add_ecuid && !$add_addr && !$change_addr && !$add_entry);

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
}

sub get_ecuparam_id {
	# create an array for all of the extended parameters
	my $serial, $id, $length;

	my $sql = qq(SELECT serial, id, length FROM ecuparam);
	my $sth = $dbh->prepare($sql);
	$sth->execute;
	$sth->bind_columns(\$serial, \$id, \$length);
	while ($sth->fetch) {
		$ecuparam_id{$id}=$serial;
		$ecuparam_len{$serial}=$length;
	}
}

sub get_address_id {
	# return the id of the passed address/length/bit
	my $serial;
	my $address = shift;
	my $length = shift;
	my $bit = shift;

	if ($bit eq '')
	{
		$bit = " IS NULL";
	}
	elsif ($bit >= 0 && $bit <= 31)
	{
		$bit = "='" . $bit . "'";
	}
	else
	{
		report_error("Invalid address bit value passed, value:$bit");
	}
	my $sql = qq[SELECT serial FROM address where address='$address' and length='$length' and bit$bit];
	my $sth = $dbh->prepare($sql);
	$sth->execute;
	$sth->bind_columns(\$serial);
	my $count = 0;
	while ($sth->fetch) {
		$count++;
	}
	report_error("More than one address/length/bit combo found in database") if ($count > 1);
	return $serial;
}

sub get_ecu_id {
	# get serial number for the ECU ID
	my $ecuid = shift;
	my $serial;

	my $sql = qq(SELECT serial FROM ecuid where ecuid='$ecuid');
	my $sth = $dbh->prepare($sql);
	$sth->execute;
	$sth->bind_columns(\$serial);
	my $count = 0;
	while ($sth->fetch) {
		$count++;
	}
	report_error("More than one ECU ID found in database") if ($count > 1);
	return $serial;
}

sub get_relation_id {
	# get the serial number for the ECU ID, Extended Parameter, Address combo
	my $ecuid_id = shift;
	my $param_id = shift;
	my $serial, $address_serial;

	my $sql = qq[SELECT serial,addressid from ecuparam_rel 
		WHERE ecuparamid='$param_id' 
		AND ecuidid='$ecuid_id'];
	my $sth = $dbh->prepare($sql);
	$sth->execute;
	$sth->bind_columns(\$serial, \$address_serial);
	my $count = 0;
	while ($sth->fetch) {
		$count++;
	}
	report_error("More than one ECU ID/Parameter/Address combo found in database") if ($count > 1);
	return ($serial, $address_serial);
}

sub update_unique_entry {
	# Update Address ID entry for an exisitng parameter
	my $serial = shift;
	my $addr_id = shift;

	my $sql = qq[UPDATE ecuparam_rel SET addressid = '$addr_id' WHERE serial = '$serial'];
	my $sth = $dbh->prepare($sql);
	$sth->execute;
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
}

sub new_ecuid_entry {
	# create a new entry in the database for the current ECU ID as we have
	# not seen it before. 

	my $ecuid = shift;			# ECU ID pasted to subroutine

	my $sql_ecuid_in = qq[INSERT INTO ecuid (ecuid) VALUES ('$ecuid')];
	my $sth = $dbh->prepare($sql_ecuid_in);
	$sth->execute;
	return $sth->{mysql_insertid};
}

sub new_addr_entry {
	# create a new entry in the database for the current address as we have
	# not seen it before. 

	my $address = shift;		# RAM address pasted to subroutine
	my $addr_len = shift;		# length of data to retrieve at address pasted to subroutine
	my $addr_bit = shift;		# bit to isolate at address pasted to subroutine

	if ($addr_bit eq '')
	{
		$addr_bit = "NULL";
	}
	elsif ($addr_bit >= 0 && $addr_bit <= 31)
	{
		$addr_bit = "'$addr_bit'";
	}
	else
	{
		report_error("Invalid address bit value passed, value:$addr_bit");
	}

	my $sql_addr_in = qq[INSERT INTO address (address,length,bit) VALUES ('$address','$addr_len',$addr_bit)];
	my $sth = $dbh->prepare($sql_addr_in);
	$sth->execute;
	return $sth->{mysql_insertid};
}

sub new_unique_entry {
	# create a new entry in the database for the current Extended Parameter as we have
	# not seen it before. 

	my $ecuid_id = shift;			# ECU ID pasted to subroutine
	my $extparamid_id = shift;		# Extended parameter pasted to subroutine
	my $address_id = shift;			# RAM address pasted to subroutine
	my $serial = shift;	

	# now we can insert the new Extended Parameter relation info into the table
	my $sql_ecuparamrel_in = qq[INSERT INTO
		ecuparam_rel (ecuparamid, ecuidid, addressid)
		VALUES ('$extparamid_id', '$ecuid_id', '$address_id')];
	my $sth = $dbh->prepare($sql_ecuparamrel_in);
	$sth->execute;
	return $sth->{mysql_insertid};
}

sub report_error {
	my $message = shift;
	print "ERROR: $message\n";
	$dbh->do("FLUSH TABLES");
	$dbh->disconnect;
	exit;
}
