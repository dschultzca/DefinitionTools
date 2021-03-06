#!/usr/bin/perl 
#
# Copyright (C) 2011+  Dale C. Schultz
# RomRaider member ID: dschultz
#
# You are free to use this source for any purpose, but please keep
# notice of where it came from!
#
#
# Purpose
#	Reads the database and dumps logger XML file to STDOUT
#	Version:	3
#	Update:	Sept. 20/2011
#------------------------------------------------------------------------------------------

# dump format
#                <parameter id="P12" name="Mass Airflow" desc="P12" ecubyteindex="9" ecubit="4">
#                    <address length="2">0x000013</address>
#                    <conversions>
#                        <conversion units="g/s" expr="x/100" format="0.00" gauge_min="0" gauge_max="400" gauge_step="20" />
#                    </conversions>
#                </parameter>

#                <switch id="S132" name="Cruise Control Inhibitor Switch" desc="S132-Becomes ON(1) in Park or Neutral. ECU input." byte="0x000121" bit="2" ecubyteindex="46" />

#                <ecuparam id="E6" name="Target Boost*" desc="E6-Target boost map target after compensations are applied.">
#                    <ecu id="43045B4005">
#                        <address length="2">0x20D40</address>
#                    </ecu>
#                    <conversions>
#                        <conversion units="psi relative sea level" expr="(x-760)*0.01933677" format="0.00" />
#                        <conversion units="psi absolute" expr="x*0.01933677" format="0.00" />
#                        <conversion units="bar relative sea level" expr="(x-760)*0.001333224" format="0.000" />
#                        <conversion units="bar absolute" expr="x*0.001333224" format="0.000" />
#                        <conversion units="mmHg absolute" expr="x" format="0" />
#                    </conversions>
#                </ecuparam>

use DBI;
# create a handle and connect to the statistics database
$dbh = DBI->connect (
	'DBI:mysql:database=logger;host=localhost',
	'root','ieee802',{AutoCommit=>1, RaiseError=>0, PrintError=>0})
	or die "$0: Couldn't connect to database";

# Get last version/update info to insert into def header
my $sql = qq(SELECT * FROM version ORDER BY id DESC LIMIT 1);
my $sth = $dbh->prepare($sql);
$sth->execute;
$sth->bind_columns(\$serial, \$version, \$update);
$sth->fetch;
$update =~ s/$\$\///;

# Dump standard parameters header section
&header;

# SSM Parameter list
my $id, $name, $desc, $byteidx, $bitidx, $target, $address, $length, $depends;
$sql = qq(
	SELECT parameter.serial, parameter.id, parameter.name,
	parameter.desc, parameter.byteidx, parameter.bitidx, parameter.target,
	address.address, address.length, depends.parameters
	FROM parameter
	LEFT JOIN parameter_rel ON parameter.serial = parameter_rel.parameterid
	LEFT JOIN address ON parameter_rel.addressid=address.serial
	LEFT JOIN depends ON parameter_rel.dependsid=depends.serial
  );
$sth = $dbh->prepare($sql);
$sth->execute;
$sth->bind_columns(\$serial, \$id, \$name, \$desc, \$byteidx, \$bitidx, \$target, \$address, \$length, \$depends);
while ($sth->fetch) {
	$parameter_id{$id}=$serial;
	$parameter_id{$id}{'name'}=$name;
	if ($desc) {
		$parameter_id{$id}{'desc'}="P${id}-$desc";
	}
	else {
		$parameter_id{$id}{'desc'}="P${id}";
	}
	$parameter_id{$id}{'byteidx'}=$byteidx;
	$parameter_id{$id}{'bitidx'}=$bitidx;
	$parameter_id{$id}{'target'}=$target;
	$parameter_id{$id}{'address'}=$address;
	$parameter_id{$id}{'length'}=$length;
	$parameter_id{$id}{'depends'}=$depends;
	}
$sth->finish;

# Print out SSM parameters
foreach $id (sort {$a<=>$b} keys %parameter_id) {
	if ($parameter_id{$id}{'byteidx'}) {
		$bytebit = sprintf(' ecubyteindex="%s" ecubit="%s"',
		$parameter_id{$id}{'byteidx'}, $parameter_id{$id}{'bitidx'})
	}
	printf('                <parameter id="P%d" name="%s" desc="%s"%s target="%d">',
		$id, $parameter_id{$id}{'name'}, $parameter_id{$id}{'desc'}, $bytebit, $parameter_id{$id}{'target'});
		my $length = ''; 
		if ($parameter_id{$id}{'length'} > 1) {
			$length = " length=\"$parameter_id{$id}{'length'}\"";
		}
	if ($parameter_id{$id}{'address'}) {
		print "\n                    <address${length}>0x$parameter_id{$id}{'address'}</address>\n";
	}
	if ($parameter_id{$id}{'depends'}) {
		print "\n                    <depends>\n";
		@dep_ssm = split(/:/, $parameter_id{$id}{'depends'});
		foreach $depid (@dep_ssm) {
            print "                        <ref parameter=\"P${depid}\" />\n";
		}
		print "                    </depends>\n";
	}
	print "                    <conversions>\n";
	get_ssm_conversion_id($parameter_id{$id});
	print "                    </conversions>\n";
	print "                </parameter>\n";
	$bytebit = "";
}

# Dump switches section
print "            </parameters>\n";
print "            <switches>\n";
my $id, $name, $desc, $byteidx, $bitidx, $target, $address;
$sql = qq(
	SELECT switch.serial, switch.id, switch.name,
	switch.desc, switch.byteidx, switch.bitidx,
	switch.target, address.address
	FROM switch
	LEFT JOIN switch_rel ON switch.serial = switch_rel.switchid
	LEFT JOIN address ON switch_rel.addressid=address.serial
  );
$sth = $dbh->prepare($sql);
$sth->execute;
$sth->bind_columns(\$serial, \$id, \$name, \$desc, \$byteidx, \$bitidx, \$target, \$address);
while ($sth->fetch) {
	$switch_id{$id}=$serial;
	$switch_id{$id}{'name'}=$name;
	if($target == 1) {
		$tn = "(E)";
	}
	elsif($target == 2) {
		$tn = "(T)";
	}
	elsif($target == 3) {
		$tn = "(B)";
	}
	if ($desc) {
		$switch_id{$id}{'desc'}="${tn} S${id}-$desc";
	}
	else {
		$switch_id{$id}{'desc'}="${tn} S${id}";
	}
	$switch_id{$id}{'byteidx'}=$byteidx;
	$switch_id{$id}{'bitidx'}=$bitidx;
	$switch_id{$id}{'target'}=$target;
	$switch_id{$id}{'address'}=$address;
	}
$sth->finish;

# Print out SSM Switches
foreach $id (sort {$a<=>$b} keys %switch_id) {
	printf('                <switch id="S%d" name="%s" desc="%s" byte="0x%s" bit="%s" ecubyteindex="%s" target="%d" />',
		$id, $switch_id{$id}{'name'}, $switch_id{$id}{'desc'},
		$switch_id{$id}{'address'}, $switch_id{$id}{'bitidx'},
		$switch_id{$id}{'byteidx'}, $switch_id{$id}{'target'});
	print "\n";
}
print "            </switches>\n";
print "            <ecuparams>\n";

# ECU parameter list
my $id, $name, $desc, $ecuid;
$sql = qq(SELECT `serial`, `id`, `name`, `desc`, `target` FROM ecuparam);
$sth = $dbh->prepare($sql);
$sth->execute;
$sth->bind_columns(\$serial, \$id, \$name, \$desc, \$target);
while ($sth->fetch) {
	$ecuparam_id{$id}=$serial;
	$ecuparam_id{$id}{'name'}=$name;
	if ($desc) {
		$ecuparam_id{$id}{'desc'}="E${id}-$desc";
	}
	else {
		$ecuparam_id{$id}{'desc'}="E${id}";
	}
	$ecuparam_id{$id}{'target'}=$target;
}
$sth->finish;
&get_address_id;
foreach $id (sort {$a<=>$b} keys %ecuparam_id) {
	my $param_serial = $ecuparam_id{$id};
	my @ecuids = get_ecu_id($param_serial);
	print "                <ecuparam id=\"E${id}\" name=\"$ecuparam_id{$id}{'name'}\" desc=\"$ecuparam_id{$id}{'desc'}\" target=\"$ecuparam_id{$id}{'target'}\">\n";
	foreach $ecuid (@ecuids) {
		my $length = ''; 
		if ($address_id{$ecuid}{$param_serial}{'length'} > 1) {
			$length = " length=\"$address_id{$ecuid}{$param_serial}{'length'}\"";
		}
		my $bit = "$address_id{$ecuid}{$param_serial}{'bit'}" if ($address_id{$ecuid}{$param_serial}{'bit'});
		print "                    <ecu id=\"${ecuid}\">\n";
		print "                        <address${length}>0x$address_id{$ecuid}{$param_serial}{'address'}</address>\n";
		print "                    </ecu>\n";
	}
	print "                    <conversions>\n";
	get_conversion_id($param_serial);
	print "                    </conversions>\n";
	print "                </ecuparam>\n";
}
&footer;

THE_END:
$dbh->do("FLUSH TABLES");
$dbh->disconnect;
exit;

# --- SUBROUTINES ---

sub get_address_id {
	# get the addresses, length and bit for all of the Extended Parameters by ECU ID 
	my $ecuid, $ecuparam, $address, $length, $bit;
	my $sql = qq( 
		SELECT ecuid.ecuid, ecuparam.serial, address.address, address.length, address.bit
		FROM ecuid
		LEFT JOIN ecuparam_rel ON ecuid.serial = ecuparam_rel.ecuidid
		LEFT JOIN address ON ecuparam_rel.addressid=address.serial
		LEFT JOIN ecuparam ON ecuparam_rel.ecuparamid=ecuparam.serial
		);
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	$sth->bind_columns(\$ecuid, \$ecuparam, \$address, \$length, \$bit);
	while ($sth->fetch) {
		$address_id{$ecuid}{$ecuparam}{'address'} = $address;
		$address_id{$ecuid}{$ecuparam}{'length'} = $length;
		$address_id{$ecuid}{$ecuparam}{'bit'} = $bit;
	}
	return;
}

sub get_ssm_conversion_id {
	# get the Conversions for the SSM Parameter serial# pasted to sub
	my $ssmparamid = shift;
	my $units, $type, $expression, $format, $min, $max, $step;
	my $sql = qq( 
		SELECT conversion.units, conversion.type, conversion.expression, conversion.format, conversion.min, conversion.max, conversion.step
		FROM conversion_rel
		LEFT JOIN conversion ON conversion_rel.conversionid=conversion.serial
		WHERE conversion_rel.parameterid = ?
		ORDER BY conversion.units DESC
		);
		my $sth = $dbh->prepare($sql);
	$sth->execute($ssmparamid);
	$sth->bind_columns(\$units, \$type, \$expression, \$format, \$min, \$max, \$step);
	while ($sth->fetch) {
		$storage = "storagetype=\"${type}\" " if ($type);
		if ($min) {
			$gauge = sprintf('gauge_min="%.5g" gauge_max="%.5g" gauge_step="%.5g" ',
			$min, $max, $step);
		}
		print "                        <conversion units=\"${units}\" ${storage}expr=\"${expression}\" format=\"${format}\" ${gauge}/>\n";
		$storage = "";
		$gauge = "";
	}
	return;
}

sub get_conversion_id {
	# get the Conversions for the Extended Parameter serial# pasted to sub
	my $ecuparamid = shift;
	my $units, $type, $expression, $format;
	my $sql = qq( 
		SELECT conversion.units, conversion.type, conversion.expression, conversion.format
		FROM conversion_rel
		LEFT JOIN conversion ON conversion_rel.conversionid=conversion.serial
		WHERE conversion_rel.ecuparamid = ?
		ORDER BY conversion.serial ASC
		);
		my $sth = $dbh->prepare($sql);
	$sth->execute($ecuparamid);
	$sth->bind_columns(\$units, \$type, \$expression, \$format);
	while ($sth->fetch) {
		$storage = "storagetype=\"${type}\" " if ($type);
		print "                        <conversion units=\"${units}\" ${storage}expr=\"${expression}\" format=\"${format}\" />\n";
		$storage = "";
	}
	return;
}

sub get_ecu_id {
	# get all of the ECU ID for the Extended Parameter serial# pasted to sub
	my $ecuparam = shift;
	my $ecuid;
	my @ecuids;
	my $sql = qq(
		SELECT ecuid.ecuid
		FROM ecuparam
		LEFT JOIN ecuparam_rel ON ecuparam.serial = ecuparam_rel.ecuparamid
		LEFT JOIN ecuid ON ecuparam_rel.ecuidid = ecuid.serial
		WHERE ecuparam.id = ?
		ORDER BY ecuid.ecuid ASC
		);
	my $sth = $dbh->prepare($sql);
	$sth->execute($ecuparam);
	$sth->bind_columns(\$ecuid);

	# get the returned rows and create the array
	while ($sth->fetch) {
		push(@ecuids, $ecuid);
	}

	#debug print out array
	# for $key (keys %unique_id) {
		# print "Key: $key Value: $unique_id{$key}\n";
	# }
	# $sth->finish;
	return @ecuids;
}

sub header {
print <<STDPARAM;
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE logger SYSTEM "logger.dtd">
<!--ROMRAIDER STANDARD UNITS LOGGER DEFINITION FILE (VERSION $serial) $version
$update

TERMS, CONDITIONS, AND DISCLAIMERS
- - - - - - - - - - - - - - - - - - - - - - - - -
WARNING: These definition files are created as the result of the extremely complex and time consuming process
of reverse-engineering the factory ECU. Because of this complexity, it is necessary to make certain assumptions
and, therefore, it is impossible to always deal in absolutes in regards to representations made by these
definitions. In addition, due to this complexity and the numerous variations among different ECUs, it is also
impossible to guarantee that the definitions will not contain errors or other bugs. What this all means is that
there is the potential for bugs, errors and misrepresentations which can result in damage to your motor, your
ECU as well the possibility of causing your vehicle to behave unexpectedly on the road, increasing the risk of
death or injury. Modifications to your vehicle's ECU may also be in violation of local, state and federal laws.
By using these definition files, either directly or indirectly, you agree to assume 100% of all risk and
RomRaider's creators and contributors shall not be held responsible for any damages or injuries you receive.
This product is for advanced users only. There are no safeguards in place when tuning with RomRaider. As such,
the potential for serious damage and injury still exists, even if the user does not experience any bugs or errors.
As always, use at your own risk.

These definitions are created for FREE without any sort of guarantee. The developers cannot be held liable for
any damage or injury incurred as a result of these definitions. USE AT YOUR OWN RISK! -->
<logger version="$serial">
    <protocols>
        <protocol id="SSM" baud="4800" databits="8" stopbits="1" parity="0" connect_timeout="2000" send_timeout="55">
            <parameters>
STDPARAM
}

sub footer {
print <<FOOTER;
            </ecuparams>
        </protocol>
    </protocols>
FOOTER
print "</logger>";
}