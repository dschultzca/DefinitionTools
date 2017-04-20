#!/usr/bin/perl

# Copyright (C) 2017 Dale C. Schultz
# RomRaider member ID: dschultz
#
# You are free to use this source for any purpose, but please keep
# notice of where it came from!
#
#
# Purpose
#	Reads the database and dumps logger XML file to STDOUT
#	Version:    15
#	Update:     April 19/2017
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
use Getopt::Std;

# Set up the command line to accept the language to dump.
my $ret = getopts ("gl:u:v:");
my $groupEcuId = $opt_g;
my $locale = $opt_l;
my $measure = $opt_u;
my $preVersion = $opt_v;
if (($locale ne "en" && $locale ne "de") ||
    ($measure ne "std" && $measure ne "imp" && $measure ne "metric")) {
	print "\nUsage: $0 -g -l locale -u units -v previousVersion> <output_file.xml>\nThe optional -g flag groups the ECU IDs by common address.\nWhere locale is: 'en' or 'de'\n   and units is: 'std', 'imp' or 'metric'\n";
	exit 1;
}
my $unitname;
if ($measure eq "std") {
	$unitname = "STANDARD";
}
if ($measure eq "imp") {
	$unitname = "IMPERIAL";
}
if ($measure eq "metric") {
	$unitname = "METRIC";
}

# create a handle and connect to the statistics database
$dbh = DBI->connect (
	'DBI:mysql:database=definitions;host=localhost',
	'xxxx','xxxx',{AutoCommit=>1, RaiseError=>0, PrintError=>0})
	or die "$0: Couldn't connect to database";

if ($preVersion eq "") {
	# Get last version/update info to insert into def header
	my $sql = qq(SELECT * FROM version ORDER BY id DESC LIMIT 1);
	my $sth = $dbh->prepare($sql);
	$sth->execute;
	$sth->bind_columns(\$serial, \$version, \$update);
	$sth->fetch;
	$update =~ s/$\$\///;
	$update =~ s/\r\n/ /;
}
else {
	# Get update history from version provided and insert into def header
	my $sql = qq(SELECT * FROM version where id > ? ORDER BY id);
	my $sth = $dbh->prepare($sql);
	my $myUpdate;
	$sth->execute($preVersion);
	$sth->bind_columns(\$serial, \$version, \$update);
	while ($sth->fetch) {
		$update =~ s/$\$\///;
		$update =~ s/\r\n/ /;
		$myUpdate = "${myUpdate}$serial $version $update\n"
	}
	$myUpdate =~ s/\r\n$//;
	$update = $myUpdate;
	chop $update;
}

binmode(STDOUT, ":utf8");

# Dump standard parameters header section
&header;

# SSM Parameter list
my $id, $reserved, $name, $desc, $byteidx, $bitidx, $target, $address, $length, $depends;
if ($locale eq "de") {
	$sql = qq(
		SELECT parameter.serial, parameter.id, parameter.reserved, parameter.name_de,
		parameter.desc_de, parameter.byteidx, parameter.bitidx, parameter.target,
		address.address, address.length, depends.parameters
		FROM parameter
		LEFT JOIN parameter_rel ON parameter.serial = parameter_rel.parameterid
		LEFT JOIN address ON parameter_rel.addressid=address.serial
		LEFT JOIN depends ON parameter_rel.dependsid=depends.serial
	  );
}
if ($locale eq "en") {
	$sql = qq(
		SELECT parameter.serial, parameter.id, parameter.reserved, parameter.name,
		parameter.desc, parameter.byteidx, parameter.bitidx, parameter.target,
		address.address, address.length, depends.parameters
		FROM parameter
		LEFT JOIN parameter_rel ON parameter.serial = parameter_rel.parameterid
		LEFT JOIN address ON parameter_rel.addressid=address.serial
		LEFT JOIN depends ON parameter_rel.dependsid=depends.serial
	  );
}
$sth = $dbh->prepare($sql);
$sth->execute;
$sth->bind_columns(\$serial, \$id, \$reserved, \$name, \$desc, \$byteidx, \$bitidx, \$target, \$address, \$length, \$depends);
while ($sth->fetch) {
	next if ($reserved);
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
		my $addr = $parameter_id{$id}{'address'};
		if ($addr =~ /:/) {
			my @addresses = split(/:/, $addr);
			foreach $addrPart (@addresses) {
				print "\n                    <address>0x$addrPart</address>";
			}
			print "\n";
		}
		else {
			print "\n                    <address${length}>0x$addr</address>\n";
		}
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
my $id, $reserved, $name, $desc, $byteidx, $bitidx, $target, $address;
if ($locale eq "de") {
	$sql = qq(
		SELECT switch.serial, switch.id, switch.reserved, switch.name_de,
		switch.desc_de, switch.byteidx, switch.bitidx,
		switch.target, address.address
		FROM switch
		LEFT JOIN switch_rel ON switch.serial = switch_rel.switchid
		LEFT JOIN address ON switch_rel.addressid=address.serial
	  );
}
if ($locale eq "en") {
	$sql = qq(
		SELECT switch.serial, switch.id, switch.reserved, switch.name,
		switch.desc, switch.byteidx, switch.bitidx,
		switch.target, address.address
		FROM switch
		LEFT JOIN switch_rel ON switch.serial = switch_rel.switchid
		LEFT JOIN address ON switch_rel.addressid=address.serial
	  );
}
$sth = $dbh->prepare($sql);
$sth->execute;
$sth->bind_columns(\$serial, \$id, \$reserved, \$name, \$desc, \$byteidx, \$bitidx, \$target, \$address);
while ($sth->fetch) {
	next if ($reserved);
	$switch_id{$id}=$serial;
	$switch_id{$id}{'name'}=$name;
	if ($desc) {
		$switch_id{$id}{'desc'}="S${id}-$desc";
	}
	else {
		$switch_id{$id}{'desc'}="S${id}";
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
# DTC Code list
print "            </switches>\n";
print "            <dtcodes>\n";
my $id, $name, $tmpaddr, $memaddr, $bitidx;
if ($locale eq "de") {
	$sql = qq(
		SELECT dtcode.id, dtcode_xlt_de.code_xlt, dtcode.tmpaddr, dtcode.memaddr, dtcode.bitidx
		FROM dtcode
		INNER JOIN dtcode_xlt_de ON dtcode.translation_id = dtcode_xlt_de.serial
		WHERE dtcode.reserved is NULL
	  );
}
if ($locale eq "en") {
	$sql = qq(
		SELECT dtcode.id, dtcode.name, dtcode.tmpaddr, dtcode.memaddr, dtcode.bitidx
		FROM dtcode
		WHERE dtcode.reserved is NULL
	  );
}
$sth = $dbh->prepare($sql);
$sth->execute;
$sth->bind_columns(\$id, \$name, \$tmpaddr, \$memaddr, \$bitidx);
while ($sth->fetch) {
	$dtcode_id{$id}{'name'}=$name;
	$dtcode_id{$id}{'tmpaddr'}=$tmpaddr;
	$dtcode_id{$id}{'memaddr'}=$memaddr;
	$dtcode_id{$id}{'bitidx'}=$bitidx;
	}
$sth->finish;

# Print out DTC
foreach $id (sort {$a<=>$b} keys %dtcode_id) {
	$dtcName = $dtcode_id{$id}{'name'};
	$dtcName =~ s/&/&amp\;/;
	printf('                <dtcode id="D%d" name="%s" desc="D%d" tmpaddr="0x%s" memaddr="0x%s" bit="%s" />',
		$id, $dtcName, $id, $dtcode_id{$id}{'tmpaddr'},
		$dtcode_id{$id}{'memaddr'}, $dtcode_id{$id}{'bitidx'});
	print "\n";
}
print "            </dtcodes>\n";
print "            <ecuparams>\n";

# ECU parameter list
my $id, $name, $desc, $ecuid;
if ($locale eq "de") {
	$sql = qq(
		SELECT ecuparam.serial, ecuparam.id, ecuparam.reserved, ecuparam.name_de,
		ecuparam.desc_de, ecuparam.target
		FROM ecuparam;
	);
}
if ($locale eq "en") {
	$sql = qq(
		SELECT ecuparam.serial, ecuparam.id, ecuparam.reserved, ecuparam.name,
		ecuparam.desc, ecuparam.target
		FROM ecuparam;
	);
}
$sth = $dbh->prepare($sql);
$sth->execute;
$sth->bind_columns(\$serial, \$id, \$reserved, \$name, \$desc, \$target);
while ($sth->fetch) {
	next if ($reserved);
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
	print "                <ecuparam id=\"E${id}\" name=\"$ecuparam_id{$id}{'name'}\" desc=\"$ecuparam_id{$id}{'desc'}\" target=\"$ecuparam_id{$id}{'target'}\">\n";
	if ($groupEcuId) {
		foreach $addrgrp (sort {$a<=>$b} keys %{$address_group{$id}}) {
			my $length = '';
			my $bit = '';
			if ($address_group{$id}{$addrgrp}{'length'} > 1) {
				$length = " length=\"$address_group{$id}{$addrgrp}{'length'}\"";
			}
			if ($address_group{$id}{$addrgrp}{'bit'} != -1) {
				$bit = " bit=\"$address_group{$id}{$addrgrp}{'bit'}\"";
			}
			$ecuidList = $address_group{$id}{$addrgrp}{'ecuidList'};
			$ecuidList =~ s/,$//;
			print "                    <ecu id=\"${ecuidList}\">\n";
			printf("                        <address${length}${bit}>0x%06X</address>\n", $addrgrp);
			print "                    </ecu>\n";
		}
	}
	else {
		my @ecuids = get_ecu_id($id);
		foreach $ecuid (@ecuids) {
			my $length = '';
			my $bit = '';
			if ($address_id{$ecuid}{$id}{'length'} > 1) {
				$length = " length=\"$address_id{$ecuid}{$id}{'length'}\"";
			}
			if ($address_id{$ecuid}{$id}{'bit'} ne '') {
				$bit = " bit=\"$address_id{$ecuid}{$id}{'bit'}\"";
			}
			print "                    <ecu id=\"${ecuid}\">\n";
			printf("                        <address${length}${bit}>0x%06X</address>\n", $address_id{$ecuid}{$id}{'address'});
			print "                    </ecu>\n";
		}
	}
	print "                    <conversions>\n";
	get_conversion_id($ecuparam_id{$id});
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
		SELECT ecuid.ecuid, ecuparam.id, address.address, address.length, address.bit
		FROM ecuid
		LEFT JOIN ecuparam_rel ON ecuid.serial = ecuparam_rel.ecuidid
		LEFT JOIN address ON ecuparam_rel.addressid=address.serial
		LEFT JOIN ecuparam ON ecuparam_rel.ecuparamid=ecuparam.serial
		ORDER BY ecuid.ecuid
		);
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	$sth->bind_columns(\$ecuid, \$ecuparam, \$address, \$length, \$bit);
	while ($sth->fetch) {
		$address_id{$ecuid}{$ecuparam}{'address'} = $address;
		$address_id{$ecuid}{$ecuparam}{'length'} = $length;
		$address_id{$ecuid}{$ecuparam}{'bit'} = $bit;
		$bit = -1 if ($bit eq '');
		$address_group{$ecuparam}{hex($address)}{'ecuidList'} .= "${ecuid},";
		$address_group{$ecuparam}{hex($address)}{'length'} = $length;
		$address_group{$ecuparam}{hex($address)}{'bit'} = $bit;
	}
	return;
}

sub get_ssm_conversion_id {
	# get the Conversions for the SSM Parameter serial# pasted to sub
	my $ssmparamid = shift;
	my $units, $type, $expression, $format, $min, $max, $step, $std, $imp, $metric, $units_de, $gauge;
	my $orderby = "conversion.order_$measure";
	my $sql = qq(
		SELECT conversion.units, conversion.type, conversion.expression, conversion.format, conversion.min, conversion.max, conversion.step,
		conversion.order_std, conversion.order_imp, conversion.order_metric, conversion.units_de
		FROM conversion_rel
		LEFT JOIN conversion ON conversion_rel.conversionid=conversion.serial
		WHERE conversion_rel.parameterid = ?
		ORDER BY $orderby ASC
		);
		my $sth = $dbh->prepare($sql);
	$sth->execute($ssmparamid);
	$sth->bind_columns(\$units, \$type, \$expression, \$format, \$min, \$max, \$step, \$std, \$imp, \$metric, \$units_de);
	while ($sth->fetch) {
		$storage = "storagetype=\"${type}\" " if ($type);
		$units = $units_de if ($units_de ne '' && $locale eq "de");
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
	my $units, $type, $expression, $format, $min, $max, $step, $std, $imp, $metric, $units_de, $gauge;
	my $orderby = "conversion.order_$measure";
	my $sql = qq(
		SELECT conversion.units, conversion.type, conversion.expression, conversion.format, conversion.min, conversion.max, conversion.step,
		conversion.order_std, conversion.order_imp, conversion.order_metric, conversion.units_de
		FROM conversion_rel
		LEFT JOIN conversion ON conversion_rel.conversionid=conversion.serial
		WHERE conversion_rel.ecuparamid = ?
		ORDER BY $orderby ASC
		);
		my $sth = $dbh->prepare($sql);
	$sth->execute($ecuparamid);
	$sth->bind_columns(\$units, \$type, \$expression, \$format, \$min, \$max, \$step, \$std, \$imp, \$metric, \$units_de);
	while ($sth->fetch) {
		$storage = "storagetype=\"${type}\" " if ($type);
		$units = $units_de if ($units_de ne '' && $locale eq "de");
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
	# for $ecuid (@ecuids) {
		# print STDERR "ID: $ecuid\n";
	# }
	$sth->finish;
	return @ecuids;
}

sub header {
print <<STDPARAM;
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE logger SYSTEM "logger.dtd">
<!--ROMRAIDER $unitname UNITS LOGGER DEFINITION FILE (VERSION $serial) $version [$locale]
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
			<transports>
				<transport id="iso9141" name="K-Line" desc="Low speed serial protocol supported up to ~MY2014.">
					<module id="ecu" address="0x10" desc="Engine Control Unit" tester="0xF0" fastpoll="true"/>
					<module id="tcu" address="0x18" desc="Transmission Control Unit" tester="0xF0"  fastpoll="false"/>
				</transport>
				<transport id="iso15765" name="CAN bus" desc="CAN bus logging ~MY2007+.">
					<module id="ecu" address="0x000007E8" desc="Engine Control Unit" tester="0x000007E0" />
					<module id="tcu" address="0x000007E9" desc="Transmission Control Unit" tester="0x000007E1" />
				</transport>
			</transports>
            <parameters>
STDPARAM
}

sub footer {
print <<FOOTER;
            </ecuparams>
        </protocol>
        <protocol id="OBD" baud="500000" databits="8" stopbits="1" parity="0" connect_timeout="2000" send_timeout="55">
			<transports>
				<transport id="iso15765" name="CAN bus" desc="OBD is only supported on CAN bus using a J2534 compatible cable.">
					<module id="ecu" address="0x000007E8" desc="Engine Control Unit" tester="0x000007E0" />
					<module id="tcu" address="0x000007E9" desc="Transmission Control Unit" tester="0x000007E1" />
				</transport>
			</transports>
            <parameters>
                <parameter id="PID1a" name="MIL Status" desc="PID1a-[0 = Off] | [1 = On]" ecubyteindex="8" ecubit="7" target="3">
                    <address bit="31">0x01</address>
                    <conversions>
                        <conversion units="On/Off" storagetype="uint32" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1"/>
                    </conversions>
                </parameter>
                <parameter id="PID1b" name="DTC Count" desc="PID1b-Number of confirmed emissions-related DTCs available for display" ecubyteindex="8" ecubit="7" target="3">
                    <address>0x01</address>
                    <conversions>
                        <conversion units="count" storagetype="int32" expr="if(256+x/16777216&gt;127,(256+x/16777216)-128,x/16777216)" format="0" gauge_min="0" gauge_max="127" gauge_step="12"/>
                    </conversions>
                </parameter>
                <parameter id="E3" name="Fuel System #1 Status" desc="E3-[0 = no status] | [1 = conditions not satisfied] | [2 = CL (normal)] | [4 = OL (normal)] | [8 = OL due to system fault] | [16 = CL partial system fault]" ecubyteindex="8" ecubit="5" target="1">
                    <address>0x03</address>
                    <conversions>
                        <conversion units="status" storagetype="uint16" expr="x/256" format="0" gauge_min="0" gauge_max="16" gauge_step="4"/>
                    </conversions>
                </parameter>
                <parameter id="PID3" name="Fuel System #2 Status" desc="PID3-[0 = no status] | [1 = conditions not satisfied] | [2 = CL (normal)] | [4 = OL (normal)] | [8 = OL due to system fault] | [16 = CL partial system fault]" ecubyteindex="8" ecubit="5" target="1">
                    <address>0x03</address>
                    <conversions>
                        <conversion units="status" storagetype="uint16" expr="x%256" format="0" gauge_min="0" gauge_max="16" gauge_step="4"/>
                    </conversions>
                </parameter>
                <parameter id="P1" name="Engine Load (Calculated)" desc="P1-Percent of maximum available engine torque" ecubyteindex="8" ecubit="4" target="1">
                    <address>0x04</address>
                    <conversions>
                        <conversion units="%" expr="x*100/255" format="0.00" gauge_min="0" gauge_max="100" gauge_step="10"/>
                    </conversions>
                </parameter>
                <parameter id="P2" name="Coolant Temperature" desc="P2-Coolant Temperature" ecubyteindex="8" ecubit="3" target="1">
                    <address>0x05</address>
                    <conversions>
                        <conversion units="F" expr="32+9*(x-40)/5" format="0" gauge_min="-40" gauge_max="420" gauge_step="50" />
                        <conversion units="C" expr="x-40" format="0" gauge_min="-40" gauge_max="215" gauge_step="25"/>
                    </conversions>
                </parameter>
                <parameter id="P3" name="Fuel Trim #1 - Short Term" desc="P3-Short Term Fuel Trim for Bank #1 for closed loop feedback control of air/fuel ratio" ecubyteindex="8" ecubit="2" target="1">
                    <address>0x06</address>
                    <conversions>
                        <conversion units="%" expr="(x-128)*100/128" format="0.00" gauge_min="-100" gauge_max="100" gauge_step="20"/>
                    </conversions>
                </parameter>
                <parameter id="P4" name="Fuel Trim #1 - Long Term" desc="P4-Long Term Fuel Trim for Bank #1 for closed loop feedback control of air/fuel ratio" ecubyteindex="8" ecubit="1" target="1">
                    <address>0x07</address>
                    <conversions>
                        <conversion units="%" expr="(x-128)*100/128" format="0.00" gauge_min="-100" gauge_max="100" gauge_step="20"/>
                    </conversions>
                </parameter>
                <parameter id="P5" name="Fuel Trim #2 - Short Term" desc="P5-Short Term Fuel Trim for Bank #2 for closed loop feedback control of air/fuel ratio" ecubyteindex="8" ecubit="0" target="1">
                    <address>0x08</address>
                    <conversions>
                        <conversion units="%" expr="(x-128)*100/128" format="0.00" gauge_min="-100" gauge_max="100" gauge_step="20"/>
                    </conversions>
                </parameter>
                <parameter id="P6" name="Fuel Trim #2 - Long Term" desc="P6-Long Term Fuel Trim for Bank #2 for closed loop feedback control of air/fuel ratio" ecubyteindex="9" ecubit="7" target="1">
                    <address>0x09</address>
                    <conversions>
                        <conversion units="%" expr="(x-128)*100/128" format="0.00" gauge_min="-100" gauge_max="100" gauge_step="20"/>
                    </conversions>
                </parameter>
                <parameter id="P78" name="Fuel Pressure" desc="P78-Fuel Pressure referenced to atmosphere (gauge pressure)" ecubyteindex="9" ecubit="6" target="1">
                    <address>0x0A</address>
                    <conversions>
                        <conversion units="psi" expr="x*3*37/255" format="0.00" gauge_min="0" gauge_max="110" gauge_step="10" />
                        <conversion units="kPa" expr="x*3" format="0" gauge_min="0" gauge_max="765" gauge_step="80"/>
                        <conversion units="hPa" expr="x*30" format="0" gauge_min="0" gauge_max="7650" gauge_step="800" />
                        <conversion units="bar" expr="x*0.03" format="0.000" gauge_min="0" gauge_max="8" gauge_step="1" />
                   </conversions>
                </parameter>
                <parameter id="P7" name="Intake Manifold Pressure" desc="P7-Intake Manifold Pressure Absolute" ecubyteindex="9" ecubit="5" target="1">
                    <address>0x0B</address>
                    <conversions>
                        <conversion units="psi" expr="x*37/255" format="0.00" gauge_min="0" gauge_max="40" gauge_step="4" />
                        <conversion units="kPa" expr="x" format="0" gauge_min="0" gauge_max="255" gauge_step="25"/>
                        <conversion units="hPa" expr="x*10" format="0" gauge_min="0" gauge_max="2550" gauge_step="250" />
                        <conversion units="bar" expr="x*0.01" format="0.000" gauge_min="0" gauge_max="2.5" gauge_step="0.5" />
                   </conversions>
                </parameter>
                <parameter id="P8" name="Engine Speed" desc="P8-Engine crankshaft revolutions per minute" ecubyteindex="9" ecubit="4" target="1">
                    <address>0x0C</address>
                    <conversions>
                        <conversion units="RPM" storagetype="uint16" expr="x/4" format="0.00" gauge_min="0" gauge_max="10000" gauge_step="1000"/>
                    </conversions>
                </parameter>
                <parameter id="P9" name="Vehicle Speed" desc="P9-Vehicle speed derived from vehicle speed sensor or calculated" ecubyteindex="9" ecubit="3" target="1">
                    <address>0x0D</address>
                    <conversions>
                        <conversion units="mph" expr="x*0.621371192" format="0" gauge_min="0" gauge_max="200" gauge_step="20" />
                        <conversion units="km/h" expr="x" format="0" gauge_min="0" gauge_max="300" gauge_step="30" />
                    </conversions>
                </parameter>
                <parameter id="P10" name="Timing Advance" desc="P10-Timing Advance for cylinder #1" ecubyteindex="9" ecubit="2" target="1">
                    <address>0x0E</address>
                    <conversions>
                        <conversion units="degrees" expr="x/2-64" format="0.00" gauge_min="-64" gauge_max="64" gauge_step="15" />
                    </conversions>
                </parameter>
                <parameter id="P11" name="Intake Air Temperature" desc="P11-Intake manifold air temperature" ecubyteindex="9" ecubit="1" target="1">
                    <address>0x0F</address>
                    <conversions>
                        <conversion units="F" expr="32+9*(x-40)/5" format="0" gauge_min="-40" gauge_max="150" gauge_step="20" />
                        <conversion units="C" expr="x-40" format="0" gauge_min="-40" gauge_max="60" gauge_step="10" />
                    </conversions>
                </parameter>
                <parameter id="P12" name="Mass Airflow" desc="P12-Airflow rate" ecubyteindex="9" ecubit="0" target="1">
                    <address>0x10</address>
                    <conversions>
                        <conversion units="g/s" storagetype="uint16" expr="x/100" format="0.00" gauge_min="0" gauge_max="500" gauge_step="50" />
                    </conversions>
                </parameter>
                <parameter id="P13" name="Throttle Position" desc="P13-Absolute throttle position" ecubyteindex="10" ecubit="7" target="1">
                    <address>0x11</address>
                    <conversions>
                        <conversion units="%" expr="x*100/255" format="0.00" gauge_min="0" gauge_max="100" gauge_step="10" />
                    </conversions>
                </parameter>
                <parameter id="PID12" name="Commanded Secondary Air Status" desc="PID3-[0 = unsupported] | [1 = Upstream of first catalytic converter] | [2 = Downstream of first catalytic converter] | [4 = Atmosphere or Off] | [8 = On for diagnostics]" ecubyteindex="10" ecubit="6" target="1">
                    <address>0x12</address>
                    <conversions>
                        <conversion units="status" expr="x" format="0" gauge_min="0" gauge_max="8" gauge_step="2"/>
                    </conversions>
                </parameter>
                <parameter id="PID13" name="Oxygen Sensors Present" desc="PID13-[b0..b3] == Bank 1 Sensors 1-4 and [b4..b7] == Bank 2 Sensors 1-4, where sensor 1 is closest to the engine" ecubyteindex="10" ecubit="5" target="1">
                    <address>0x13</address>
                    <conversions>
                        <conversion units="bit flags" expr="x" format="0" gauge_min="0" gauge_max="255" gauge_step="25"/>
                    </conversions>
                </parameter>
                <parameter id="PID14" name="O2 Bank 1 Sensor 1" desc="PID14-Conventional 0 to 1 volt oxygen sensor" ecubyteindex="10" ecubit="4" target="1">
                    <address>0x14</address>
                    <conversions>
                        <conversion storagetype="uint16" units="VDC" expr="x/256/200" format="0.000" gauge_min="0" gauge_max="1.275" gauge_step="0.13" />
                        <conversion storagetype="uint16" units="%" expr="if(x%256==255,0,((x%256)-128)*100/128)" format="0.000" gauge_min="0" gauge_max="100" gauge_step="10" />
                    </conversions>
                </parameter>
                <parameter id="PID15" name="O2 Narrowband Bank 1 Sensor 2" desc="PID15-Conventional 0 to 1 volt oxygen sensor" ecubyteindex="10" ecubit="3" target="1">
                    <address>0x15</address>
                    <conversions>
                        <conversion storagetype="uint16" units="VDC" expr="x/256/200" format="0.000" gauge_min="0" gauge_max="1.275" gauge_step="0.13" />
                        <conversion storagetype="uint16" units="%" expr="if(x%256==255,0,((x%256)-128)*100/128)" format="0.000" gauge_min="0" gauge_max="100" gauge_step="10" />
                    </conversions>
                </parameter>
                <parameter id="PID16" name="O2 Narrowband Bank 1 Sensor 3" desc="PID16-Conventional 0 to 1 volt oxygen sensor" ecubyteindex="10" ecubit="2" target="1">
                    <address>0x16</address>
                    <conversions>
                        <conversion storagetype="uint16" units="VDC" expr="x/256/200" format="0.000" gauge_min="0" gauge_max="1.275" gauge_step="0.13" />
                        <conversion storagetype="uint16" units="%" expr="if(x%256==255,0,((x%256)-128)*100/128)" format="0.000" gauge_min="0" gauge_max="100" gauge_step="10" />
                   </conversions>
                </parameter>
                <parameter id="PID17" name="O2 Narrowband Bank 1 Sensor 4" desc="PID17-Conventional 0 to 1 volt oxygen sensor" ecubyteindex="10" ecubit="1" target="1">
                    <address>0x17</address>
                    <conversions>
                        <conversion storagetype="uint16" units="VDC" expr="x/256/200" format="0.000" gauge_min="0" gauge_max="1.275" gauge_step="0.13" />
                        <conversion storagetype="uint16" units="%" expr="if(x%256==255,0,((x%256)-128)*100/128)" format="0.000" gauge_min="0" gauge_max="100" gauge_step="10" />
                   </conversions>
                </parameter>
                <parameter id="PID18" name="O2 Narrowband Bank 2 Sensor 1" desc="PID18-Conventional 0 to 1 volt oxygen sensor" ecubyteindex="10" ecubit="0" target="1">
                    <address>0x18</address>
                    <conversions>
                        <conversion storagetype="uint16" units="VDC" expr="x/256/200" format="0.000" gauge_min="0" gauge_max="1.275" gauge_step="0.13" />
                        <conversion storagetype="uint16" units="%" expr="if(x%256==255,0,((x%256)-128)*100/128)" format="0.000" gauge_min="0" gauge_max="100" gauge_step="10" />
                    </conversions>
                </parameter>
                <parameter id="PID19" name="O2 Narrowband Bank 2 Sensor 2" desc="PID19-Conventional 0 to 1 volt oxygen sensor" ecubyteindex="11" ecubit="7" target="1">
                    <address>0x19</address>
                    <conversions>
                        <conversion storagetype="uint16" units="VDC" expr="x/256/200" format="0.000" gauge_min="0" gauge_max="1.275" gauge_step="0.13" />
                        <conversion storagetype="uint16" units="%" expr="if(x%256==255,0,((x%256)-128)*100/128)" format="0.000" gauge_min="0" gauge_max="100" gauge_step="10" />
                    </conversions>
                </parameter>
                <parameter id="PID1A" name="O2 Narrowband Bank 2 Sensor 3" desc="PID1A-Conventional 0 to 1 volt oxygen sensor" ecubyteindex="11" ecubit="6" target="1">
                    <address>0x1A</address>
                    <conversions>
                        <conversion storagetype="uint16" units="VDC" expr="x/256/200" format="0.000" gauge_min="0" gauge_max="1.275" gauge_step="0.13" />
                        <conversion storagetype="uint16" units="%" expr="if(x%256==255,0,((x%256)-128)*100/128)" format="0.000" gauge_min="0" gauge_max="100" gauge_step="10" />
                    </conversions>
                </parameter>
                <parameter id="PID1B" name="O2 Narrowband Bank 2 Sensor 4" desc="PID1B-Conventional 0 to 1 volt oxygen sensor" ecubyteindex="11" ecubit="5" target="1">
                    <address>0x1B</address>
                    <conversions>
                        <conversion storagetype="uint16" units="VDC" expr="x/256/200" format="0.000" gauge_min="0" gauge_max="1.275" gauge_step="0.13" />
                        <conversion storagetype="uint16" units="%" expr="if(x%256==255,0,((x%256)-128)*100/128)" format="0.000" gauge_min="0" gauge_max="100" gauge_step="10" />
                    </conversions>
                </parameter>
                <parameter id="PID1C" name="OBD standard to which vehicle conforms to" desc="PID1C-Refer to OBD standard for description of result. i.e.: [1 = CARB OBDII | 2 = OBD | 3 = OBD and OBD-II | etc ]" ecubyteindex="11" ecubit="4" target="1">
                    <address>0x1C</address>
                    <conversions>
                        <conversion units="index" expr="x" format="0" gauge_min="0" gauge_max="256" gauge_step="25"/>
                    </conversions>
                </parameter>
                <parameter id="PID1D" name="Oxygen Sensors Present" desc="PID1D-[b0..b7] == [B1S1, B1S2, B2S1, B2S2, B3S1, B3S2, B4S1, B4S2], where sensor 1 is closest to the engine" ecubyteindex="11" ecubit="3" target="1">
                    <address>0x1D</address>
                    <conversions>
                        <conversion units="bit flags" expr="x" format="0" gauge_min="0" gauge_max="255" gauge_step="25"/>
                    </conversions>
                </parameter>
                <parameter id="PID1E" name="Power Take Off (PTO) Status" desc="PID1E-[0 = Off] | [1 = On]" ecubyteindex="11" ecubit="2" target="1">
                    <address bit="0">0x1E</address>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1"/>
                    </conversions>
                </parameter>
                <parameter id="PID1F" name="Run Time Since Engine Start" desc="PID1F-Run time since ignition switch is turned On and the engine is running. Max count 65535, no wrap." ecubyteindex="11" ecubit="1" target="1">
                    <address>0x1F</address>
                    <conversions>
                        <conversion units="seconds" storagetype="uint16" expr="x" format="0" gauge_min="0" gauge_max="65535" gauge_step="5000"/>
                    </conversions>
                </parameter>
                <parameter id="PID21" name="Distance Traveled with MIL On" desc="PID21-Accumulate distance if MIL is On. Max count 65535, no wrap." ecubyteindex="12" ecubit="7" target="1">
                    <address>0x21</address>
                    <conversions>
                        <conversion units="miles" storagetype="uint16" expr="x*0.621371192" format="0" gauge_min="0" gauge_max="40000" gauge_step="4000" />
                        <conversion units="km" storagetype="uint16" expr="x" format="0" gauge_min="0" gauge_max="65535" gauge_step="5000"/>
                    </conversions>
                </parameter>
                <parameter id="PID22" name="Fuel Rail Pressure (relative to manifold vacuum)" desc="PID22-relative to manifold vacuum (relative pressure)" ecubyteindex="12" ecubit="6" target="1">
                    <address>0x22</address>
                    <conversions>
                        <conversion units="psi" storagetype="uint16" expr="x*0.011459605" format="0.00" gauge_min="0" gauge_max="800" gauge_step="80" />
                        <conversion units="kPa" storagetype="uint16" expr="x*5178/65535" format="0" gauge_min="0" gauge_max="5200" gauge_step="500"/>
                        <conversion units="hPa" storagetype="uint16" expr="x*51780/65535" format="0" gauge_min="0" gauge_max="52000" gauge_step="5000" />
                        <conversion units="bar" storagetype="uint16" expr="x*51.78/65535" format="0.000" gauge_min="0" gauge_max="52" gauge_step="5" />
                   </conversions>
                </parameter>
                <parameter id="PID23" name="Fuel Rail Pressure (direct inject)" desc="PID23-diesel or gasoline direct injection pressure referenced to atmosphere (gauge pressure)" ecubyteindex="12" ecubit="5" target="1">
                    <address>0x23</address>
                    <conversions>
                        <conversion units="psi" storagetype="uint16" expr="x*1.450377" format="0.00" gauge_min="0" gauge_max="100000" gauge_step="10000" />
                        <conversion units="kPa" storagetype="uint16" expr="x*10" format="0" gauge_min="0" gauge_max="655350" gauge_step="12000"/>
                        <conversion units="hPa" storagetype="uint16" expr="x*100" format="0" gauge_min="0" gauge_max="6553500" gauge_step="120000" />
                        <conversion units="bar" storagetype="uint16" expr="x*0.1" format="0.000" gauge_min="0" gauge_max="650" gauge_step="12" />
                   </conversions>
                </parameter>
                <parameter id="PID24" name="O2 Wideband Bank 1 Sensor 1" desc="PID24-Linear or Wideband Oxygen Sensor" ecubyteindex="12" ecubit="4" target="1">
                    <address>0x24</address>
                    <conversions>
                        <conversion storagetype="int32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="int32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="int32" units="VDC" expr="if(x&lt;2147483647,((x+2147483648)%65536)/8192,(x%65536)/8192)" format="0.000" gauge_min="0" gauge_max="8" gauge_step="1" />
                    </conversions>
                </parameter>
                <parameter id="PID25" name="O2 Wideband Bank 1 Sensor 2" desc="PID25-Linear or Wideband Oxygen Sensor" ecubyteindex="12" ecubit="3" target="1">
                    <address>0x25</address>
                    <conversions>
                        <conversion storagetype="int32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="int32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="int32" units="VDC" expr="if(x&lt;2147483647,((x+2147483648)%65536)/8192,(x%65536)/8192)" format="0.000" gauge_min="0" gauge_max="8" gauge_step="1" />
                    </conversions>
                </parameter>
                <parameter id="PID26" name="O2 Wideband Bank 1 Sensor 3" desc="PID26-Linear or Wideband Oxygen Sensor" ecubyteindex="12" ecubit="2" target="1">
                    <address>0x26</address>
                    <conversions>
                        <conversion storagetype="int32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="int32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="int32" units="VDC" expr="if(x&lt;2147483647,((x+2147483648)%65536)/8192,(x%65536)/8192)" format="0.000" gauge_min="0" gauge_max="8" gauge_step="1" />
                    </conversions>
                </parameter>
                <parameter id="PID27" name="O2 Wideband Bank 1 Sensor 4" desc="PID26-Linear or Wideband Oxygen Sensor" ecubyteindex="12" ecubit="1" target="1">
                    <address>0x27</address>
                    <conversions>
                        <conversion storagetype="int32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="int32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="int32" units="VDC" expr="if(x&lt;2147483647,((x+2147483648)%65536)/8192,(x%65536)/8192)" format="0.000" gauge_min="0" gauge_max="8" gauge_step="1" />
                    </conversions>
                </parameter>
                <parameter id="PID28" name="O2 Wideband Bank 2 Sensor 1" desc="PID28-Linear or Wideband Oxygen Sensor" ecubyteindex="12" ecubit="0" target="1">
                    <address>0x28</address>
                    <conversions>
                        <conversion storagetype="int32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="int32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="int32" units="VDC" expr="if(x&lt;2147483647,((x+2147483648)%65536)/8192,(x%65536)/8192)" format="0.000" gauge_min="0" gauge_max="8" gauge_step="1" />
                    </conversions>
                </parameter>
                <parameter id="PID29" name="O2 Wideband Bank 2 Sensor 2" desc="PID29-Linear or Wideband Oxygen Sensor" ecubyteindex="13" ecubit="7" target="1">
                    <address>0x29</address>
                    <conversions>
                        <conversion storagetype="int32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="int32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="int32" units="VDC" expr="if(x&lt;2147483647,((x+2147483648)%65536)/8192,(x%65536)/8192)" format="0.000" gauge_min="0" gauge_max="8" gauge_step="1" />
                    </conversions>
                </parameter>
                <parameter id="PID2A" name="O2 Wideband Bank 2 Sensor 3" desc="PID2A-Linear or Wideband Oxygen Sensor" ecubyteindex="13" ecubit="6" target="1">
                    <address>0x2A</address>
                    <conversions>
                        <conversion storagetype="int32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="int32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="int32" units="VDC" expr="if(x&lt;2147483647,((x+2147483648)%65536)/8192,(x%65536)/8192)" format="0.000" gauge_min="0" gauge_max="8" gauge_step="1" />
                    </conversions>
                </parameter>
                <parameter id="PID2B" name="O2 Wideband Bank 2 Sensor 4" desc="PID2B-Linear or Wideband Oxygen Sensor" ecubyteindex="13" ecubit="5" target="1">
                    <address>0x2B</address>
                    <conversions>
                        <conversion storagetype="int32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="int32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="int32" units="VDC" expr="if(x&lt;2147483647,((x+2147483648)%65536)/8192,(x%65536)/8192)" format="0.000" gauge_min="0" gauge_max="8" gauge_step="1" />
                    </conversions>
                </parameter>
                <parameter id="PID2C" name="EGR Commanded Control" desc="PID2C-Control of the amount of EGR delivered to the engine" ecubyteindex="13" ecubit="4" target="1">
                    <address>0x2C</address>
                    <conversions>
                        <conversion units="%" expr="x*100/255" format="0.00" gauge_min="0" gauge_max="100" gauge_step="10" />
                    </conversions>
                </parameter>
                <parameter id="PID2D" name="EGR Error" desc="PID2D-EGR system feedback" ecubyteindex="13" ecubit="3" target="1">
                    <address>0x2D</address>
                    <conversions>
                        <conversion units="%" expr="(x-128)*100/128" format="0.00" gauge_min="-100" gauge_max="100" gauge_step="20" />
                    </conversions>
                </parameter>
                <parameter id="PID2E" name="EVAP Commanded Purge" desc="PID2E-Commanded evaporative purge control percent" ecubyteindex="13" ecubit="2" target="1">
                    <address>0x2E</address>
                    <conversions>
                        <conversion units="%" expr="x*100/255" format="0.00" gauge_min="0" gauge_max="100" gauge_step="10" />
                    </conversions>
                </parameter>
                <parameter id="P35" name="Fuel Level" desc="P35-Fuel tank fill capacity as a percent of maximum" ecubyteindex="13" ecubit="1" target="1">
                    <address>0x2F</address>
                    <conversions>
                        <conversion units="%" expr="x*100/255" format="0.00" gauge_min="0" gauge_max="100" gauge_step="10" />
                    </conversions>
                </parameter>
                <parameter id="PID30" name="Number of warm-ups since DTCs cleared" desc="PID30-OBD warm-up cycle based on engine coolant temperature rise" ecubyteindex="13" ecubit="0" target="1">
                    <address>0x30</address>
                    <conversions>
                        <conversion units="count" expr="x" format="0" gauge_min="0" gauge_max="255" gauge_step="25" />
                    </conversions>
                </parameter>
                <parameter id="PID31" name="Distance Traveled since DTCs cleared" desc="PID31-Distance since last time external tester was used to clear DTCs. Max count 65535, no wrap." ecubyteindex="14" ecubit="7" target="1">
                    <address>0x31</address>
                    <conversions>
                        <conversion units="miles" storagetype="uint16" expr="x*0.621371192" format="0" gauge_min="0" gauge_max="40000" gauge_step="4000" />
                        <conversion units="km" storagetype="uint16" expr="x" format="0" gauge_min="0" gauge_max="65535" gauge_step="5000"/>
                    </conversions>
                </parameter>
                <parameter id="PID32" name="EVAP System Vapor Pressure" desc="PID32-Evaporative system vapor pressure from a sensor in fuel tank or vapor line" ecubyteindex="14" ecubit="6" target="1">
                    <address>0x32</address>
                    <conversions>
                        <conversion units="psi" storagetype="int16" expr="x*0.0000362594345" format="0.000000" gauge_min="-0.3" gauge_max="0.3" gauge_step="0.05" />
                        <conversion units="Pa" storagetype="int16" expr="x/4" format="0" gauge_min="-8192" gauge_max="8192" gauge_step="1600"/>
                        <conversion units="bar" storagetype="int16" expr="x*0.0000025" format="0.000000" gauge_min="-0.02" gauge_max="0.02" gauge_step="0.004" />
                   </conversions>
                </parameter>
                <parameter id="P24" name="Atmospheric Pressure" desc="P24-Barometric pressure (absolute)" ecubyteindex="14" ecubit="5" target="1">
                    <address>0x33</address>
                    <conversions>
                        <conversion units="psi" expr="x*37/255" format="0.00" gauge_min="0" gauge_max="20" gauge_step="2" />
                        <conversion units="kPa" expr="x" format="0" gauge_min="0" gauge_max="255" gauge_step="20" />
                        <conversion units="hPa" expr="x*10" format="0" gauge_min="0" gauge_max="1500" gauge_step="100" />
                        <conversion units="bar" expr="x*0.01" format="0.000" gauge_min="0" gauge_max="1.5" gauge_step="0.1" />
                        <conversion units="inHg" expr="x*0.2953" format="0.00" gauge_min="-40" gauge_max="60" gauge_step="10" />
                        <conversion units="mmHg" expr="x*7.5" format="0" gauge_min="-1000" gauge_max="2000" gauge_step="300" />
                    </conversions>
                </parameter>
                <parameter id="PID34" name="O2 Wideband Bank 1 Sensor 1" desc="PID34-Linear or Wideband Oxygen Sensor" ecubyteindex="14" ecubit="4" target="1">
                    <address>0x34</address>
                    <conversions>
                        <conversion storagetype="int32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="int32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="int32" units="mA" expr="if(x&lt;2147483647,((x+2147483648)%65536)/255-128,(x%65536)/255-128)" format="0.000" gauge_min="-128" gauge_max="128" gauge_step="25" />
                    </conversions>
                </parameter>
                <parameter id="PID35" name="O2 Wideband Bank 1 Sensor 2" desc="PID35-Linear or Wideband Oxygen Sensor" ecubyteindex="14" ecubit="3" target="1">
                    <address>0x35</address>
                    <conversions>
                        <conversion storagetype="int32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="int32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="int32" units="mA" expr="if(x&lt;2147483647,((x+2147483648)%65536)/255-128,(x%65536)/255-128)" format="0.000" gauge_min="-128" gauge_max="128" gauge_step="25" />
                    </conversions>
                </parameter>
                <parameter id="PID36" name="O2 Wideband Bank 1 Sensor 3" desc="PID36-Linear or Wideband Oxygen Sensor" ecubyteindex="14" ecubit="2" target="1">
                    <address>0x36</address>
                    <conversions>
                        <conversion storagetype="int32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="int32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="int32" units="mA" expr="if(x&lt;2147483647,((x+2147483648)%65536)/255-128,(x%65536)/255-128)" format="0.000" gauge_min="-128" gauge_max="128" gauge_step="25" />
                    </conversions>
                </parameter>
                <parameter id="PID37" name="O2 Wideband Bank 1 Sensor 4" desc="PID36-Linear or Wideband Oxygen Sensor" ecubyteindex="14" ecubit="1" target="1">
                    <address>0x37</address>
                    <conversions>
                        <conversion storagetype="int32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="int32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="int32" units="mA" expr="if(x&lt;2147483647,((x+2147483648)%65536)/255-128,(x%65536)/255-128)" format="0.000" gauge_min="-128" gauge_max="128" gauge_step="25" />
                    </conversions>
                </parameter>
                <parameter id="PID38" name="O2 Wideband Bank 2 Sensor 1" desc="PID38-Linear or Wideband Oxygen Sensor" ecubyteindex="14" ecubit="0" target="1">
                    <address>0x38</address>
                    <conversions>
                        <conversion storagetype="int32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="int32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="int32" units="mA" expr="if(x&lt;2147483647,((x+2147483648)%65536)/255-128,(x%65536)/255-128)" format="0.000" gauge_min="-128" gauge_max="128" gauge_step="25" />
                    </conversions>
                </parameter>
                <parameter id="PID39" name="O2 Wideband Bank 2 Sensor 2" desc="PID39-Linear or Wideband Oxygen Sensor" ecubyteindex="15" ecubit="7" target="1">
                    <address>0x39</address>
                    <conversions>
                        <conversion storagetype="int32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="int32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="int32" units="mA" expr="if(x&lt;2147483647,((x+2147483648)%65536)/255-128,(x%65536)/255-128)" format="0.000" gauge_min="-128" gauge_max="128" gauge_step="25" />
                    </conversions>
                </parameter>
                <parameter id="PID3A" name="O2 Wideband Bank 2 Sensor 3" desc="PID3A-Linear or Wideband Oxygen Sensor" ecubyteindex="15" ecubit="6" target="1">
                    <address>0x3A</address>
                    <conversions>
                        <conversion storagetype="int32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="int32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="int32" units="mA" expr="if(x&lt;2147483647,((x+2147483648)%65536)/255-128,(x%65536)/255-128)" format="0.000" gauge_min="-128" gauge_max="128" gauge_step="25" />
                    </conversions>
                </parameter>
                <parameter id="PID3B" name="O2 Wideband Bank 2 Sensor 4" desc="PID3B-Linear or Wideband Oxygen Sensor" ecubyteindex="15" ecubit="5" target="1">
                    <address>0x3B</address>
                    <conversions>
                        <conversion storagetype="int32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="int32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="int32" units="mA" expr="if(x&lt;2147483647,((x+2147483648)%65536)/255-128,(x%65536)/255-128)" format="0.000" gauge_min="-128" gauge_max="128" gauge_step="25" />
                    </conversions>
                </parameter>
                <parameter id="PID3C" name="Catalyst Temperature Bank 1 Sensor 1" desc="PID3C-Catalyst temperature sensor" ecubyteindex="15" ecubit="4" target="1">
                    <address>0x3C</address>
                    <conversions>
                        <conversion units="\xB0F" storagetype="uint16" expr="32+9*(x*0.1-40)/5" format="0" gauge_min="-40" gauge_max="4000" gauge_step="400" />
                        <conversion units="\xB0C" storagetype="uint16" expr="x*0.1-40" format="0" gauge_min="-40" gauge_max="2000" gauge_step="200" />
                    </conversions>
                </parameter>
                <parameter id="PID3D" name="Catalyst Temperature Bank 2 Sensor 1" desc="PID3D-Catalyst temperature sensor" ecubyteindex="15" ecubit="3" target="1">
                    <address>0x3D</address>
                    <conversions>
                        <conversion units="\xB0F" storagetype="uint16" expr="32+9*(x*0.1-40)/5" format="0" gauge_min="-40" gauge_max="4000" gauge_step="400" />
                        <conversion units="\xB0C" storagetype="uint16" expr="x*0.1-40" format="0" gauge_min="-40" gauge_max="2000" gauge_step="200" />
                    </conversions>
                </parameter>
                <parameter id="PID3E" name="Catalyst Temperature Bank 1 Sensor 2" desc="PID3E-Catalyst temperature sensor" ecubyteindex="15" ecubit="2" target="1">
                    <address>0x3E</address>
                    <conversions>
                        <conversion units="\xB0F" storagetype="uint16" expr="32+9*(x*0.1-40)/5" format="0" gauge_min="-40" gauge_max="4000" gauge_step="400" />
                        <conversion units="\xB0C" storagetype="uint16" expr="x*0.1-40" format="0" gauge_min="-40" gauge_max="2000" gauge_step="200" />
                    </conversions>
                </parameter>
                <parameter id="PID3F" name="Catalyst Temperature Bank 2 Sensor 2" desc="PID3F-Catalyst temperature sensor" ecubyteindex="15" ecubit="1" target="1">
                    <address>0x3F</address>
                    <conversions>
                        <conversion units="\xB0F" storagetype="uint16" expr="32+9*(x*0.1-40)/5" format="0" gauge_min="-40" gauge_max="4000" gauge_step="400" />
                        <conversion units="\xB0C" storagetype="uint16" expr="x*0.1-40" format="0" gauge_min="-40" gauge_max="2000" gauge_step="200" />
                    </conversions>
                </parameter>
                <parameter id="P17" name="Battery Voltage" desc="P17" ecubyteindex="16" ecubit="6" target="3">
                    <address>0x42</address>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x/1000" format="0.000" gauge_min="0" gauge_max="25" gauge_step="2" />
                    </conversions>
                </parameter>
                <parameter id="PID43" name="Engine Load (Absolute)" desc="PID43-Percent of air mass per intake stroke. (up to 95% for NA engines and up to 400% for boosted engines)" ecubyteindex="16" ecubit="5" target="1">
                    <address>0x43</address>
                    <conversions>
                        <conversion units="%" storagetype="uint16" expr="x*100/255" format="0.00" gauge_min="0" gauge_max="500" gauge_step="50" />
                    </conversions>
                </parameter>
                <parameter id="PID44" name="Fuel/Air Commanded" desc="PID44-Linear or Wideband Oxygen Sensor" ecubyteindex="16" ecubit="4" target="1">
                    <address>0x44</address>
                    <conversions>
                        <conversion storagetype="uint16" units="lambda" expr="x/32767" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="uint16" units="AFR Gas" expr="x/32767*14.64" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                    </conversions>
                </parameter>
                <parameter id="PID45" name="Throttle Position (relative)" desc="PID45-Learned throttle position normalized" ecubyteindex="16" ecubit="3" target="1">
                    <address>0x45</address>
                    <conversions>
                        <conversion units="%" expr="x*100/255" format="0.00" gauge_min="0" gauge_max="100" gauge_step="10" />
                    </conversions>
                </parameter>
                <parameter id="PID46" name="Ambient Air Temperature" desc="PID46-Ambient air temperature" ecubyteindex="16" ecubit="2" target="1">
                    <address>0x46</address>
                    <conversions>
                        <conversion units="\xB0F" expr="32+9*(x-40)/5" format="0" gauge_min="0" gauge_max="140" gauge_step="20" />
                        <conversion units="\xB0C" expr="x-40" format="0" gauge_min="-20" gauge_max="60" gauge_step="10" />
                    </conversions>
                </parameter>
                <parameter id="PID47" name="Throttle Position (B)" desc="PID47-Absolute throttle position sensor B" ecubyteindex="16" ecubit="1" target="1">
                    <address>0x47</address>
                    <conversions>
                        <conversion units="%" expr="x*100/255" format="0.00" gauge_min="0" gauge_max="100" gauge_step="10" />
                    </conversions>
                </parameter>
                <parameter id="PID48" name="Throttle Position (C)" desc="PID48-Absolute throttle position sensor C" ecubyteindex="16" ecubit="0" target="1">
                    <address>0x48</address>
                    <conversions>
                        <conversion units="%" expr="x*100/255" format="0.00" gauge_min="0" gauge_max="100" gauge_step="10" />
                    </conversions>
                </parameter>
                <parameter id="PID49" name="Accelerator Pedal (D)" desc="PID49-Absolute accelerator pedal position sensor D" ecubyteindex="17" ecubit="7" target="1">
                    <address>0x49</address>
                    <conversions>
                        <conversion units="%" expr="x*100/255" format="0.00" gauge_min="0" gauge_max="100" gauge_step="10" />
                    </conversions>
                </parameter>
                <parameter id="PID4A" name="Accelerator Pedal (E)" desc="PID4A-Absolute accelerator pedal position sensor E" ecubyteindex="17" ecubit="6" target="1">
                    <address>0x4A</address>
                    <conversions>
                        <conversion units="%" expr="x*100/255" format="0.00" gauge_min="0" gauge_max="100" gauge_step="10" />
                    </conversions>
                </parameter>
                <parameter id="PID4B" name="Accelerator Pedal (F)" desc="PID4B-Absolute accelerator pedal position sensor F" ecubyteindex="17" ecubit="5" target="1">
                    <address>0x4B</address>
                    <conversions>
                        <conversion units="%" expr="x*100/255" format="0.00" gauge_min="0" gauge_max="100" gauge_step="10" />
                    </conversions>
                </parameter>
                <parameter id="PID4C" name="Throttle Opening (Commanded)" desc="PID4C-Percent of throttle plate opening commanded" ecubyteindex="17" ecubit="4" target="1">
                    <address>0x4C</address>
                    <conversions>
                        <conversion units="%" expr="x*100/255" format="0.00" gauge_min="0" gauge_max="100" gauge_step="10" />
                    </conversions>
                </parameter>
                <parameter id="PID4D" name="Time Run with MIL On" desc="PID4D-Time Run with MIL On. Max count 65535, no wrap." ecubyteindex="17" ecubit="3" target="1">
                    <address>0x4D</address>
                    <conversions>
                        <conversion units="minutes" storagetype="uint16" expr="(x*256)/256" format="0" gauge_min="0" gauge_max="65535" gauge_step="5000"/>
                    </conversions>
                </parameter>
                <parameter id="PID4E" name="Time Run since DTCs Cleared" desc="PID4E-Time Run since last time external tester was used to clear DTCs. Max count 65535, no wrap." ecubyteindex="17" ecubit="2" target="1">
                    <address>0x4E</address>
                    <conversions>
                        <conversion units="minutes" storagetype="uint16" expr="(x*256)/256" format="0" gauge_min="0" gauge_max="65535" gauge_step="5000"/>
                    </conversions>
                </parameter>
                <parameter id="PID51" name="Fuel Type" desc="PID51-Refer to OBD standard for description of result. i.e.: [0 = N/A | 1 = Gasoline | 2 = Methanol | 3 = Ethanol | 4 = Diesel | etc ]" ecubyteindex="18" ecubit="7" target="1">
                    <address>0x51</address>
                    <conversions>
                        <conversion units="index" expr="x" format="0" gauge_min="0" gauge_max="256" gauge_step="25"/>
                    </conversions>
                </parameter>
                <parameter id="PID52" name="Alcohol Fuel Percentage" desc="PID52-Percent of alcohol in fuel blend supplied to engine" ecubyteindex="18" ecubit="6" target="1">
                    <address>0x52</address>
                    <conversions>
                        <conversion units="%" expr="x*100/255" format="0.00" gauge_min="0" gauge_max="100" gauge_step="10" />
                    </conversions>
                </parameter>
                <parameter id="PID53" name="EVAP System Vapor Pressure (Absolute)" desc="PID53-Evaporative system vapor pressure from a sensor in fuel tank or vapor line" ecubyteindex="18" ecubit="5" target="1">
                    <address>0x53</address>
                    <conversions>
                        <conversion units="psi" storagetype="uint16" expr="x*0.005*37/255" format="0.00" gauge_min="0" gauge_max="50" gauge_step="5" />
                        <conversion units="kPa" storagetype="uint16" expr="x*0.005" format="0" gauge_min="0" gauge_max="350" gauge_step="35"/>
                        <conversion units="bar" storagetype="uint16" expr="x*0.00005" format="0.00000" gauge_min="0" gauge_max="3.5" gauge_step="0.35" />
                   </conversions>
                </parameter>
                <parameter id="PID54" name="EVAP System Vapor Pressure" desc="PID54-Evaporative system vapor pressure from a sensor in fuel tank or vapor line" ecubyteindex="18" ecubit="4" target="1">
                    <address>0x54</address>
                    <conversions>
                        <conversion units="psi" storagetype="int16" expr="x*0.000145037738" format="0.00000" gauge_min="-1" gauge_max="1" gauge_step="0.2" />
                        <conversion units="Pa" storagetype="int16" expr="x" format="0" gauge_min="-32768" gauge_max="32768" gauge_step="6400"/>
                        <conversion units="bar" storagetype="int16" expr="x*0.00001" format="0.00000" gauge_min="-0.3" gauge_max="0.3" gauge_step="0.06" />
                   </conversions>
                </parameter>
                <parameter id="PID55" name="Fuel Trim #1 - Secondary Short Term" desc="PID55-Secondary Short Term Fuel Trim for Bank #1 for closed loop feedback control of air/fuel ratio" ecubyteindex="18" ecubit="3" target="1">
                    <address>0x55</address>
                    <conversions>
                        <conversion units="%" expr="(x-128)*100/128" format="0.00" gauge_min="-100" gauge_max="100" gauge_step="20"/>
                    </conversions>
                </parameter>
                <parameter id="PID56" name="Fuel Trim #1 - Secondary Long Term" desc="PID56-Secondary Long Term Fuel Trim for Bank #1 for closed loop feedback control of air/fuel ratio" ecubyteindex="18" ecubit="2" target="1">
                    <address>0x56</address>
                    <conversions>
                        <conversion units="%" expr="(x-128)*100/128" format="0.00" gauge_min="-100" gauge_max="100" gauge_step="20"/>
                    </conversions>
                </parameter>
                <parameter id="PID57" name="Fuel Trim #2 - Secondary Short Term" desc="PID57-Secondary Short Term Fuel Trim for Bank #2 for closed loop feedback control of air/fuel ratio" ecubyteindex="18" ecubit="1" target="1">
                    <address>0x57</address>
                    <conversions>
                        <conversion units="%" expr="(x-128)*100/128" format="0.00" gauge_min="-100" gauge_max="100" gauge_step="20"/>
                    </conversions>
                </parameter>
                <parameter id="PID58" name="Fuel Trim #2 - Secondary Long Term" desc="PID58-Secondary Long Term Fuel Trim for Bank #2 for closed loop feedback control of air/fuel ratio" ecubyteindex="18" ecubit="0" target="1">
                    <address>0x58</address>
                    <conversions>
                        <conversion units="%" expr="(x-128)*100/128" format="0.00" gauge_min="-100" gauge_max="100" gauge_step="20"/>
                    </conversions>
                </parameter>
                <parameter id="PID59" name="Fuel Rail Pressure (Absolute)" desc="PID59-Absolute Fuel Rail Pressure" ecubyteindex="19" ecubit="7" target="1">
                    <address>0x59</address>
                    <conversions>
                        <conversion units="psi" storagetype="uint16" expr="x*1.450377" format="0.00" gauge_min="0" gauge_max="100000" gauge_step="10000" />
                        <conversion units="kPa" storagetype="uint16" expr="x*10" format="0" gauge_min="0" gauge_max="655350" gauge_step="12000"/>
                        <conversion units="hPa" storagetype="uint16" expr="x*100" format="0" gauge_min="0" gauge_max="6553500" gauge_step="120000" />
                        <conversion units="bar" storagetype="uint16" expr="x*0.1" format="0.000" gauge_min="0" gauge_max="650" gauge_step="12" />
                   </conversions>
                </parameter>
                <parameter id="P30" name="Accelerator Pedal Angle" desc="P30-Relative or learned pedal position percent" ecubyteindex="19" ecubit="6" target="1">
                    <address>0x5A</address>
                    <conversions>
                        <conversion units="%" expr="x*100/255" format="0.00" gauge_min="0" gauge_max="100" gauge_step="10" />
                    </conversions>
                </parameter>
                <parameter id="PID5B" name="State Of Charge" desc="PID5B-Percent remaining charge for the hybrid battery pack" ecubyteindex="19" ecubit="5" target="1">
                    <address>0x5B</address>
                    <conversions>
                        <conversion units="%" expr="x*100/255" format="0.00" gauge_min="0" gauge_max="100" gauge_step="10" />
                    </conversions>
                </parameter>
                <parameter id="PID5C" name="Engine Oil Temperature" desc="PID5C-Engine oil temperature" ecubyteindex="19" ecubit="4" target="1">
                    <address>0x5C</address>
                    <conversions>
                        <conversion units="\xB0F" expr="32+9*(x-40)/5" format="0" gauge_min="0" gauge_max="140" gauge_step="20" />
                        <conversion units="\xB0C" expr="x-40" format="0" gauge_min="-20" gauge_max="60" gauge_step="10" />
                    </conversions>
                </parameter>
                <parameter id="PID5D" name="Fuel Injection Timing" desc="PID5D-Degrees relative to Top Dead Center [ + = before | - = after ]" ecubyteindex="19" ecubit="3" target="1">
                    <address>0x5D</address>
                    <conversions>
                        <conversion units="\xB0" storagetype="uint16" expr="(x-26880)/128" format="0.000" gauge_min="-210" gauge_max="300" gauge_step="50" />
                   </conversions>
                </parameter>
                <parameter id="PID5E" name="Fuel Rate" desc="PID5E-Average fuel rate consumed by engine updated each second" ecubyteindex="19" ecubit="2" target="1">
                    <address>0x5E</address>
                    <conversions>
                        <conversion units="gph (US)" storagetype="uint16" expr="x*0.01321" format="0.000" gauge_min="0" gauge_max="40" gauge_step="4" />
                        <conversion units="l/h" storagetype="uint16" expr="x*0.05" format="0.00" gauge_min="0" gauge_max="3000" gauge_step="300" />
                        <conversion units="gph (UK)" storagetype="uint16" expr="x*0.011" format="0.000" gauge_min="0" gauge_max="50" gauge_step="5" />
                   </conversions>
                </parameter>
                <parameter id="PID5F" name="Emissions standard to which vehicle conforms to" desc="PID5F-Refer to OBD standard for description of result. i.e.: [14 = EURO IV B1 | 15 = EURO V B2 | 16 = EURO C | etc ]" ecubyteindex="19" ecubit="1" target="1">
                    <address>0x5F</address>
                    <conversions>
                        <conversion units="index" expr="x" format="0" gauge_min="0" gauge_max="256" gauge_step="25"/>
                    </conversions>
                </parameter>
                <parameter id="PID61" name="Engine Driver's Demand Percent Torque" desc="PID61-Requested torque output of the engine demanded by the driver" ecubyteindex="20" ecubit="7" target="1">
                    <address>0x61</address>
                    <conversions>
                        <conversion units="%" expr="x-125" format="0" gauge_min="-125" gauge_max="130" gauge_step="25"/>
                    </conversions>
                </parameter>
                <parameter id="PID62" name="Engine Actual Percent Torque" desc="PID62-Calculated indicated output torque of the engine" ecubyteindex="20" ecubit="6" target="1">
                    <address>0x62</address>
                    <conversions>
                        <conversion units="%" expr="x-125" format="0" gauge_min="-125" gauge_max="130" gauge_step="25"/>
                    </conversions>
                </parameter>
                <parameter id="PID63" name="Engine Reference Torque" desc="PID63-This is the 100% reference value for all defined indicated engine torque parameters. This value does not change once set." ecubyteindex="20" ecubit="5" target="1">
                    <address>0x63</address>
                    <conversions>
                        <conversion units="ft-lbs" storagetype="uint16" expr="x*0.7376" format="0.0" gauge_min="0" gauge_max="1000" gauge_step="100"/>
                        <conversion units="Nm" storagetype="uint16" expr="x" format="0" gauge_min="0" gauge_max="1500" gauge_step="150"/>
                    </conversions>
                </parameter>
                <parameter id="PID65a" name="Power Take Off (PTO) Status" desc="PID65a-If supported [0 = Inactive/Off] | [1 = Active/On]" ecubyteindex="40" ecubit="0" target="1">
                    <address bit="0">0x65</address>
                    <conversions>
                        <conversion units="On/Off" storagetype="uint16" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1"/>
                    </conversions>
                </parameter>
                <parameter id="PID65b" name="Auto Transmission Neutral Status" desc="PID65b-If supported [0 = Park/Neutral] | [1 = In gear]" ecubyteindex="40" ecubit="1" target="1">
                    <address bit="1">0x65</address>
                    <conversions>
                        <conversion units="On/Off" storagetype="uint16" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1"/>
                    </conversions>
                </parameter>
                <parameter id="PID65c" name="Manual Transmission Neutral Status" desc="PID65c-If supported [0 = Clutch Pressed and/or Neutral] | [1 = In gear]" ecubyteindex="40" ecubit="2" target="1">
                    <address bit="2">0x65</address>
                    <conversions>
                        <conversion units="On/Off" storagetype="uint16" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1"/>
                    </conversions>
                </parameter>
                <parameter id="PID65D" name="Glow Plug Lamp Status" desc="PID65D-If supported [0 = Wait To Start Off] | [1 = Wait To Start On]" ecubyteindex="40" ecubit="3" target="1">
                    <address bit="3">0x65</address>
                    <conversions>
                        <conversion units="On/Off" storagetype="uint16" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1"/>
                    </conversions>
                </parameter>
            </parameters>
        </protocol>
        <protocol id="DS2" baud="9600" databits="8" stopbits="1" parity="2" connect_timeout="2000" send_timeout="55">
			<transports>
				<transport id="iso9141" name="K-Line" desc="Low speed Diagnosis Bus (D-bus).">
					<module id="ecu" address="0x12" desc="Engine Control Module" />
				</transport>
			</transports>
            <ecuparams>
<!-- MS41 Parameters -->
                <ecuparam id="P8" name="* Engine Speed" desc="P8-(STATUS_MOTORDREHZAHL)" group="0x0B" subgroup="0x03" groupsize="25" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x00</address>
                    </ecu>
                    <conversions>
                        <conversion units="RPM" storagetype="uint16" expr="x" format="0" gauge_min="0" gauge_max="10000" gauge_step="1000" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P9" name="* Vehicle Speed" desc="P9-(STATUS_GESCHWINDIGKEIT)" group="0x0B" subgroup="0x03" groupsize="25" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x02</address>
                    </ecu>
                    <conversions>
                        <conversion units="km/h" expr="x" format="0" gauge_min="0" gauge_max="300" gauge_step="30" />
                        <conversion units="mph" expr="x*0.621371192" format="0.0" gauge_min="0" gauge_max="250" gauge_step="25" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P13" name="* Throttle Position" desc="P13-(STATUS_DROSSELKLAPPEN)" group="0x0B" subgroup="0x03" groupsize="25" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x03</address>
                    </ecu>
                    <conversions>
                        <conversion units="%" expr="x*100/255" format="0.0" gauge_min="0" gauge_max="100" gauge_step="10" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E2" name="* Engine Load" desc="E2-(STATUS_LAST)" group="0x0B" subgroup="0x03" groupsize="25" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x04</address>
                    </ecu>
                    <conversions>
                        <conversion units="mg/stroke" storagetype="uint16" expr="x*0.021" format="0.00" gauge_min="0" gauge_max="1000" gauge_step="100" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P11" name="* Intake Air Temperature" desc="P11-(STATUS_AN_LUFTTEMPERATUR)" group="0x0B" subgroup="0x03" groupsize="25" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x06</address>
                    </ecu>
                    <conversions>
                        <conversion units="\xB0C" expr="-0.000000002553359367*x^5+0.000001714258075*x^4-0.0004429255577*x^3+0.05516816161*x^2-3.757117047*x+175.6311846" format="0.0" gauge_min="-20" gauge_max="60" gauge_step="10" />
                        <conversion units="\xB0F" expr="32+9*(-0.000000002553359367*x^5+0.000001714258075*x^4-0.0004429255577*x^3+0.05516816161*x^2-3.757117047*x+175.6311846)/5" format="0.0" gauge_min="0" gauge_max="140" gauge_step="20" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P2" name="* Coolant Temperature" desc="P2-(STATUS_MOTORTEMPERATUR)" group="0x0B" subgroup="0x03" groupsize="25" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x07</address>
                    </ecu>
                    <conversions>
                        <conversion units="\xB0C" expr="-0.000000002760659115*x^5+0.000001811206109*x^4-0.0004546185504*x^3+0.05495453644*x^2-3.701729653*x+184.7560348" format="0.0" gauge_min="-20" gauge_max="120" gauge_step="20" />
                        <conversion units="\xB0F" expr="32+9*(-0.000000002760659115*x^5+0.000001811206109*x^4-0.0004546185504*x^3+0.05495453644*x^2-3.701729653*x+184.7560348)/5" format="0.0" gauge_min="0" gauge_max="240" gauge_step="30" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P10" name="* Ignition Angle" desc="P10-(STATUS_ZUENDWINKEL)" group="0x0B" subgroup="0x03" groupsize="25" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x08</address>
                    </ecu>
                    <conversions>
                        <conversion units="\xB0 BTDC" expr="0.373*x-23.6" format="0.0" gauge_min="-20" gauge_max="50" gauge_step="5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P21" name="* Fuel Injector Pulse Width" desc="P21-(STATUS_EINSPRITZZEIT)" group="0x0B" subgroup="0x03" groupsize="25" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x09</address>
                    </ecu>
                    <conversions>
                        <conversion units="ms" storagetype="uint16" expr="x*0.004" format="0.000" />
                        <conversion units="\xB5s" storagetype="uint16" expr="x*4" format="0" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E9" name="* Idle Air Control Valve" desc="E9-(STATUS_LL_REGLER)" group="0x0B" subgroup="0x03" groupsize="25" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x0B</address>
                    </ecu>
                    <conversions>
                        <conversion units="%" storagetype="uint16" expr="x*0.00153" format="0.00" gauge_min="0" gauge_max="100" gauge_step="10" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E10" name="* Parameter 0x0D" desc="E10-INT_IO_E904" group="0x0B" subgroup="0x03" groupsize="25" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x0D</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" storagetype="uint16" expr="x" format="0" gauge_min="0" gauge_max="65535" gauge_step="500" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E11" name="* VANOS Angle" desc="E11-(STATUS_NW_POSITION) Variable Valve angle" group="0x0B" subgroup="0x03" groupsize="25" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x0F</address>
                    </ecu>
                    <conversions>
                        <conversion units="KW \xB0" expr="x*0.3745" format="0.00" gauge_min="20" gauge_max="60" gauge_step="10" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P17" name="* Battery Voltage" desc="P17-Battery Voltage" group="0x0B" subgroup="0x03" groupsize="25" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x10</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" expr="x*0.1" format="0.0" gauge_min="0" gauge_max="25" gauge_step="2" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E13" name="* Lambda Integrator - Bank 1" desc="E13-(TI_LAM_1)" group="0x0B" subgroup="0x03" groupsize="25" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x11</address>
                    </ecu>
                    <conversions>
                        <conversion units="%" storagetype="uint16" expr="(x-32768)*100/65536" format="0.00" gauge_min="-32" gauge_max="32" gauge_step="12" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E14" name="* Lambda Integrator - Bank 2" desc="E14-(TI_LAM_2)" group="0x0B" subgroup="0x03" groupsize="25" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x13</address>
                    </ecu>
                    <conversions>
                        <conversion units="%" storagetype="uint16" expr="(x-32768)*100/65536" format="0.00" gauge_min="-32" gauge_max="32" gauge_step="12" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E15" name="* Upstream Lambda Probe Heater - Bank 1" desc="E15-(STATUS_H_SONDE)" group="0x0B" subgroup="0x03" groupsize="25" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x15</address>
                    </ecu>
                    <conversions>
                        <conversion units="%" expr="x*100/255" format="0.0" gauge_min="0" gauge_max="100" gauge_step="10" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E16" name="* Upstream Lambda Probe Heater - Bank 2" desc="E16-(STATUS_H_SONDE_2)" group="0x0B" subgroup="0x03" groupsize="25" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x16</address>
                    </ecu>
                    <conversions>
                        <conversion units="%" expr="x*100/255" format="0.0" gauge_min="0" gauge_max="100" gauge_step="10" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E17" name="* Downstream Lambda Probe Heater - Bank 1" desc="E17-(STATUS_LS_VKAT_HEIZUNG_TV_1)" group="0x0B" subgroup="0x03" groupsize="25" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x17</address>
                    </ecu>
                    <conversions>
                        <conversion units="%" expr="x*100/255" format="0.0" gauge_min="0" gauge_max="100" gauge_step="10" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E18" name="* Downstream Lambda Probe Heater - Bank 2" desc="E18-(STATUS_LS_VKAT_HEIZUNG_TV_2)" group="0x0B" subgroup="0x03" groupsize="25" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x18</address>
                    </ecu>
                    <conversions>
                        <conversion units="%" expr="x*100/255" format="0.0" gauge_min="0" gauge_max="100" gauge_step="10" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E19" name="** Lambda Additive Adaptation - Bank 1" desc="E19-(TI_AD_ADD_1)" group="0x0B" subgroup="0x91" groupsize="8" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x00</address>
                    </ecu>
                    <conversions>
                        <conversion units="ms" storagetype="uint16" expr="(x-32768)*.004" format="0.00" gauge_min="-5" gauge_max="5" gauge_step="1" />
						<conversion units="\xB5s" storagetype="uint16" expr="(x-32768)*4" format="0" gauge_min="-5000" gauge_max="5000" gauge_step="1000" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E20" name="** Lambda Additive Adaptation - Bank 2" desc="E20-(TI_AD_ADD_2)" group="0x0B" subgroup="0x91" groupsize="8" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x02</address>
                    </ecu>
                    <conversions>
                        <conversion units="ms" storagetype="uint16" expr="(x-32768)*.004" format="0.00" gauge_min="-5" gauge_max="5" gauge_step="1" />
						<conversion units="\xB5s" storagetype="uint16" expr="(x-32768)*4" format="0" gauge_min="-5000" gauge_max="5000" gauge_step="1000" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E21" name="** Lambda Multiplicative Adaptation - Bank 1" desc="E21-(TI_AD_FAC_1)" group="0x0B" subgroup="0x91" groupsize="8" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x04</address>
                    </ecu>
                    <conversions>
                        <conversion units="%" storagetype="uint16" expr="(x-32768)*100/65536" format="0.00" gauge_min="-32" gauge_max="32" gauge_step="12" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E22" name="** Lambda Multiplicative Adaptation - Bank 2" desc="E22-(TI_AD_FAC_2)" group="0x0B" subgroup="0x91" groupsize="8" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x06</address>
                    </ecu>
                    <conversions>
                        <conversion units="%" storagetype="uint16" expr="(x-32768)*100/65536" format="0.00" gauge_min="-32" gauge_max="32" gauge_step="12" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E23" name="Throttle Position Adaptation*" desc="E23-(TPS_AD_MMV_IS)" group="0x0B" subgroup="0x92" groupsize="4" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x00</address>
                    </ecu>
                    <conversions>
                        <conversion units="%" storagetype="int16" expr="x*1.526E-3" format="0.00" gauge_min="-50" gauge_max="50" gauge_step="10" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E24" name="Knock Retard - Global" desc="E24-Global correction applied to total timing" group="0x0B" subgroup="0x93" groupsize="1" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x00</address>
                    </ecu>
                    <conversions>
                        <conversion units="\xB0 Cor" storagetype="uint8" expr="(x-128)*0.375" format="0.00" gauge_min="-50" gauge_max="50" gauge_step="10" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E99" name="Knock Adaptation Table 1 Index**" desc="E99-Knock Adaptation Table 1 Index Direct RAM Read used by Adaptation display tool" group="0x06" subgroup="0x00" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x00D840</address>
                    </ecu>
                    <conversions>
                        <conversion units="\xB0 Cor" storagetype="uint8" endian="little" expr="(x-128)*0.375" format="0.000" gauge_min="-48" gauge_max="0" gauge_step="5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E100" name="Air Intake Temperature Sensor*" desc="E100-Air Intake Temperature Sensor" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x000000</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.01952" format="0.00" gauge_min="0" gauge_max="5" gauge_step="0.5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E101" name="STATUS_LS_VKAT_SIGNAL_1*" desc="E101-STATUS_LS_VKAT_SIGNAL_1" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x000001</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.01952" format="0.00" gauge_min="0" gauge_max="5" gauge_step="0.5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E102" name="STATUS_LS_VKAT_SIGNAL_2*" desc="E102-STATUS_LS_VKAT_SIGNAL_2" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x000002</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.01952" format="0.00" gauge_min="0" gauge_max="5" gauge_step="0.5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E103" name="Engine Coolant Temperature Sensor*" desc="E103-Engine Coolant Temperature Sensor" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x000003</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.00488" format="0.00" gauge_min="0" gauge_max="5" gauge_step="0.5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P19" name="Throttle Position Volts*" desc="P19-Throttle Position Volts" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x000004</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.01952" format="0.00" gauge_min="0" gauge_max="5" gauge_step="0.5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E105" name="STATUS_ZSR*" desc="E105-STATUS_ZSR" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x000005</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.01952" format="0.00" gauge_min="0" gauge_max="5" gauge_step="0.5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P18" name="Mass Airflow Volts*" desc="P18-Mass Airflow Volts" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x000006</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.01952" format="0.00" gauge_min="0" gauge_max="5" gauge_step="0.5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E107" name="Battery Voltage Sensor*" desc="E107-Battery Voltage Sensor" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x000007</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.1" format="0.0" gauge_min="0" gauge_max="20" gauge_step="2" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E123" name="STATUS_KLOPF_ADC1*" desc="E123-STATUS_KLOPF_ADC1" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x000017</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.01952" format="0.00" gauge_min="0" gauge_max="5" gauge_step="0.5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E124" name="STATUS_KLOPF_ADC2*" desc="E124-STATUS_KLOPF_ADC2" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x000018</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.01952" format="0.00" gauge_min="0" gauge_max="5" gauge_step="0.5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E125" name="STATUS_VLS_DOWN_2_BAS*" desc="E125-STATUS_VLS_DOWN_2_BAS" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x000019</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.01952" format="0.00" gauge_min="0" gauge_max="5" gauge_step="0.5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E126" name="STATUS_VLS_DOWN_1_BAS*" desc="E126-STATUS_VLS_DOWN_1_BAS" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x00001A</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.01952" format="0.00" gauge_min="0" gauge_max="5" gauge_step="0.5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E127" name="Tank Pressure Sensor*" desc="E127-Tank Pressure Sensor" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x00001B</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.00488" format="0.00" gauge_min="0" gauge_max="5" gauge_step="0.5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P12" name="Mass Airflow**" desc="P12-Mass Airflow Direct RAM Read" group="0x06" subgroup="0x00" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x00DA34</address>
                    </ecu>
                    <conversions>
                        <conversion units="kg/h" storagetype="uint16" endian="little" expr="x*0.25" format="0.00" gauge_min="0" gauge_max="65" gauge_step="6" />
                        <conversion units="g/sec" storagetype="uint16" endian="little" expr="x*0.06944445" format="0.00" gauge_min="0" gauge_max="65" gauge_step="6" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E201" name="TAST_LL_STELLER**" desc="E201-TAST_LL_STELLER Direct RAM Read" group="0x06" subgroup="0x00" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x00DA38</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" storagetype="uint16" endian="little" expr="x" format="0.00" gauge_min="0" gauge_max="65" gauge_step="6" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E202" name="STATUS_TEV_TAST**" desc="E202-STATUS_TEV_TAST Direct RAM Read" group="0x06" subgroup="0x00" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x00DA56</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" storagetype="uint8" endian="little" expr="x" format="0.00" gauge_min="0" gauge_max="65" gauge_step="6" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E203" name="STATUS_FLAG_BELADUNG**" desc="E203-STATUS_FLAG_BELADUNG Direct RAM Read" group="0x06" subgroup="0x00" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x00DA57</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" storagetype="uint8" endian="little" expr="x" format="0.00" gauge_min="0" gauge_max="65" gauge_step="6" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E204" name="STATUS_K_MW_1**" desc="E204-Result knock sensor increment cyl1 Direct RAM Read" group="0x06" subgroup="0x00" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x00DA65</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" storagetype="uint8" endian="little" expr="x" format="0" gauge_min="0" gauge_max="255" gauge_step="25" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E205" name="STATUS_K_MW_2**" desc="E205-Result knock sensor increment cyl2 Direct RAM Read" group="0x06" subgroup="0x00" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x00DA68</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" storagetype="uint8" endian="little" expr="x" format="0" gauge_min="0" gauge_max="255" gauge_step="25" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E206" name="STATUS_K_MW_3**" desc="E206-Result knock sensor increment cyl3 Direct RAM Read" group="0x06" subgroup="0x00" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x00DA67</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" storagetype="uint8" endian="little" expr="x" format="0" gauge_min="0" gauge_max="255" gauge_step="25" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E207" name="STATUS_K_MW_4**" desc="E207-Result knock sensor increment cyl4 Direct RAM Read" group="0x06" subgroup="0x00" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x00DA69</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" storagetype="uint8" endian="little" expr="x" format="0" gauge_min="0" gauge_max="255" gauge_step="25" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E208" name="STATUS_K_MW_5**" desc="E208-Result knock sensor increment cyl5 Direct RAM Read" group="0x06" subgroup="0x00" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x00DA66</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" storagetype="uint8" endian="little" expr="x" format="0" gauge_min="0" gauge_max="255" gauge_step="25" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E209" name="STATUS_K_MW_6**" desc="E209-Result knock sensor increment cyl6 Direct RAM Read" group="0x06" subgroup="0x00" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x00DA64</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" storagetype="uint8" endian="little" expr="x" format="0" gauge_min="0" gauge_max="255" gauge_step="25" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E210" name="STATUS_VANOS_VERSTELLWINKEL**" desc="E210-STATUS_VANOS_VERSTELLWINKEL Direct RAM Read" group="0x06" subgroup="0x00" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x00DAA4</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" storagetype="uint8" endian="little" expr="x" format="0" gauge_min="0" gauge_max="255" gauge_step="25" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E211" name="STATUS_GEBERRAD_ADAPTION**" desc="E211-STATUS_GEBERRAD_ADAPTION Direct RAM Read" group="0x06" subgroup="0x00" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x00DB0F</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" storagetype="uint8" endian="little" expr="x" format="0" gauge_min="0" gauge_max="255" gauge_step="25" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E212" name="STATUS_TANK_DIFF_DRUCK**" desc="E212-STATUS_TANK_DIFF_DRUCK Direct RAM Read" group="0x06" subgroup="0x00" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x00DB10</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" storagetype="uint16" endian="little" expr="x" format="0.00" gauge_min="0" gauge_max="65535" gauge_step="500" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E213" name="STATUS_TIMER_TE_DIAG**" desc="E213-STATUS_TIMER_TE_DIAG Direct RAM Read" group="0x06" subgroup="0x00" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x00DB14</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" storagetype="uint16" endian="little" expr="x" format="0.00" gauge_min="0" gauge_max="65535" gauge_step="500" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E214" name="STATUS_LAMBDA_COUNTER**" desc="E214-STATUS_LAMBDA_COUNTER Direct RAM Read" group="0x06" subgroup="0x00" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x00EDE6</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" storagetype="uint16" endian="little" expr="x" format="0.00" gauge_min="0" gauge_max="65535" gauge_step="500" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E215" name="STATUS_TIMER_TL_SP_DTE**" desc="E215-STATUS_TIMER_TL_SP_DTE Direct RAM Read" group="0x06" subgroup="0x00" target="1">
                    <ecu id="1406464">
						<address>0x00F576</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" storagetype="uint8" endian="little" expr="x" format="0" gauge_min="0" gauge_max="255" gauge_step="25" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E216" name="STATUS_TIMER_NB_SP_DTE**" desc="E216-STATUS_TIMER_NB_SP_DTE Direct RAM Read" group="0x06" subgroup="0x00" target="1">
                    <ecu id="1406464">
						<address>0x00F578</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" storagetype="uint8" endian="little" expr="x" format="0" gauge_min="0" gauge_max="255" gauge_step="25" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E217" name="Knock Retard - Current" desc="E217-Current average correction applied to total timing" group="0x06" subgroup="0x00" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x00E98D</address>
                    </ecu>
                    <conversions>
                        <conversion units="\xB0 Cor" storagetype="uint8" expr="(x-128)*0.375" format="0.00" gauge_min="-50" gauge_max="50" gauge_step="10" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P24" name="Atmospheric Pressure**" desc="P24-A temporary fake entry for the Dyno tab" group="0x0B" subgroup="0x03" groupsize="25" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x00</address>
                    </ecu>
                    <conversions>
                        <conversion units="psi" expr="101.325*37/255" format="0.00" gauge_min="0" gauge_max="20" gauge_step="2" />
                        <conversion units="kPa" expr="101.325" format="0" gauge_min="0" gauge_max="255" gauge_step="20" />
                        <conversion units="hPa" expr="101.325*10" format="0" gauge_min="0" gauge_max="1500" gauge_step="100" />
                        <conversion units="bar" expr="101.325/100" format="0.000" gauge_min="0" gauge_max="1.5" gauge_step="0.1" />
                        <conversion units="inHg" expr="101.325*0.2953" format="0.00" gauge_min="-40" gauge_max="60" gauge_step="10" />
                        <conversion units="mmHg" expr="101.325*7.5" format="0" gauge_min="-1000" gauge_max="2000" gauge_step="300" />
                    </conversions>
                </ecuparam>
<!-- Switches -->
                <ecuparam id="S0" name="SW - Compressor Signal" desc="S0-S_KO" group="0x0B" subgroup="0x04" groupsize="3" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address bit="7">0x00</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S1" name="SW - Air Conditioning (High load)" desc="S1-S_AC" group="0x0B" subgroup="0x04" groupsize="3" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address bit="6">0x00</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S2" name="SW - Theft Deterrent System" desc="S2-S_DWA" group="0x0B" subgroup="0x04" groupsize="3" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address bit="5">0x00</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S3" name="SW - Torque Reduction Request - Gear-Shift" desc="S3-S_GS" group="0x0B" subgroup="0x04" groupsize="3" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address bit="4">0x00</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S4" name="SW - Engine Drag Torque Reduction" desc="S4-S_MSR" group="0x0B" subgroup="0x04" groupsize="3" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address bit="3">0x00</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S5" name="SW - Torque Reduction Request" desc="S5-S_ASC" group="0x0B" subgroup="0x04" groupsize="3" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address bit="2">0x00</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S6" name="SW - Full Load" desc="S6-S_VL" group="0x0B" subgroup="0x04" groupsize="3" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x00</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="BitWise(3,x,1)/3" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S7" name="SW - Part Load" desc="S7-Part load" group="0x0B" subgroup="0x04" groupsize="3" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x00</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="BitWise(2,x,1)/2" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S8" name="SW - Closed Throttle" desc="S8-S_LL" group="0x0B" subgroup="0x04" groupsize="3" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address>0x00</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="BitWise(1,x,1)" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S9" name="SW - S_REG2" desc="S9-S_REG2" group="0x0B" subgroup="0x04" groupsize="3" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address bit="7">0x01</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S10" name="SW - S_REG1" desc="S10-S_REG1" group="0x0B" subgroup="0x04" groupsize="3" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address bit="6">0x01</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S11" name="SW - Trailing Throttle Fuel Cut Off" desc="S11-LV_PUC" group="0x0B" subgroup="0x04" groupsize="3" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address bit="5">0x01</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S12" name="SW - Acceleration Enrichment" desc="S12-LV_AE" group="0x0B" subgroup="0x04" groupsize="3" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address bit="4">0x01</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S13" name="SW - Engine Operating State (Start)" desc="S13-LV_ST" group="0x0B" subgroup="0x04" groupsize="3" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address bit="3">0x01</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S14" name="SW - AT Drive engaged" desc="S14-S_FS" group="0x0B" subgroup="0x04" groupsize="3" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address bit="2">0x01</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S15" name="SW - Generator" desc="S15-S_GE" group="0x0B" subgroup="0x04" groupsize="3" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address bit="1">0x01</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S16" name="SW - S_CAN" desc="S16-S_CAN" group="0x0B" subgroup="0x04" groupsize="3" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address bit="0">0x01</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S17" name="SW - Secondary Air Valve" desc="S17-S_SLV" group="0x0B" subgroup="0x04" groupsize="3" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address bit="7">0x02</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S18" name="SW - Secondary Air Pump" desc="S18-S_SLP" group="0x0B" subgroup="0x04" groupsize="3" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address bit="6">0x02</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S19" name="SW - Tank Ventilation Valve" desc="S19-S_AAV" group="0x0B" subgroup="0x04" groupsize="3" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address bit="5">0x02</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
<!--                <ecuparam id="S20" name="Rear Defogger Switch" desc="S20">  Reserved as Logger control switch -->
                <ecuparam id="S21" name="SW - S_RUN_LOSSES" desc="S21-S_RUN_LOSSES" group="0x0B" subgroup="0x04" groupsize="3" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address bit="4">0x02</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S22" name="SW - Exhaust Flap" desc="S22-S_KLAPPE" group="0x0B" subgroup="0x04" groupsize="3" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address bit="3">0x02</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S23" name="SW - S_VANOS" desc="S23-S_VANOS" group="0x0B" subgroup="0x04" groupsize="3" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address bit="2">0x02</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S24" name="SW - Compressor Relay" desc="S24-S_KO_REL" group="0x0B" subgroup="0x04" groupsize="3" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address bit="1">0x02</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S25" name="SW - Electric Fuel Pump" desc="S25-S_EKP" group="0x0B" subgroup="0x04" groupsize="3" target="1">
                    <ecu id="1406464,1429861,1437806,1440176">
						<address bit="0">0x02</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
<!-- MS43 Parameters -->
                <ecuparam id="P8" name="* Engine Speed" desc="P8-(STATUS_MOTORDREHZAHL)" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x00</address>
                    </ecu>
                    <conversions>
                        <conversion units="RPM" storagetype="uint16" expr="x" format="0" gauge_min="0" gauge_max="10000" gauge_step="1000" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P9" name="* Vehicle Speed" desc="P9-(STATUS_GESCHWINDIGKEIT)" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x02</address>
                    </ecu>
                    <conversions>
                        <conversion units="km/h" expr="x" format="0" gauge_min="0" gauge_max="300" gauge_step="30" />
                        <conversion units="mph" expr="x*0.621371192" format="0.0" gauge_min="0" gauge_max="250" gauge_step="25" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P96" name="* Accelerator Position" desc="P96" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x03</address>
                    </ecu>
                    <conversions>
                        <conversion units="\xB0TPS" storagetype="uint16" expr="0.0018310547*x" format="0.0" gauge_min="0" gauge_max="120" gauge_step="10" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P13" name="* Throttle Position" desc="P13" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x05</address>
                    </ecu>
                    <conversions>
                        <conversion units="\xB0TPS" storagetype="uint16" expr="0.0018310547*x" format="0.0" gauge_min="0" gauge_max="120" gauge_step="10" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P12" name="* Mass Airflow" desc="P12-Mass Airflow" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x07</address>
                    </ecu>
                    <conversions>
                        <conversion units="kg/h" storagetype="uint16" expr="x*0.25" format="0.00" gauge_min="0" gauge_max="65" gauge_step="6" />
                        <conversion units="g/sec" storagetype="uint16" expr="x*0.06944445" format="0.00" gauge_min="0" gauge_max="65" gauge_step="6" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P11" name="* Intake Air Temperature" desc="P11-(STATUS_AN_LUFTTEMPERATUR)" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x09</address>
                    </ecu>
                    <conversions>
                        <conversion units="\xB0C" expr="x*0.75-48" format="0.0" gauge_min="-20" gauge_max="60" gauge_step="10" />
                        <conversion units="\xB0F" expr="32+9*(x*0.75-48)/5" format="0.0" gauge_min="0" gauge_max="140" gauge_step="20" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P2" name="* Coolant Temperature" desc="P2-(STATUS_MOTORTEMPERATUR)" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x0A</address>
                    </ecu>
                    <conversions>
                        <conversion units="\xB0C" expr="x*0.75-48" format="0.0" gauge_min="-20" gauge_max="60" gauge_step="10" />
                        <conversion units="\xB0F" expr="32+9*(x*0.75-48)/5" format="0.0" gauge_min="0" gauge_max="140" gauge_step="20" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E11" name="* Oil Temperature" desc="E11-Oil Temperature" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x0B</address>
                    </ecu>
                    <conversions>
                        <conversion units="\xB0C" expr="x*0.79607843-48" format="0.0" gauge_min="-20" gauge_max="60" gauge_step="10" />
                        <conversion units="\xB0F" expr="32+9*(x*0.79607843-48)/5" format="0.0" gauge_min="0" gauge_max="140" gauge_step="20" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P98" name="* Parameter 0x0C (Temperature ?)" desc="P98" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x0C</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" expr="x" format="0" gauge_min="0" gauge_max="255" gauge_step="20" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P10" name="* Ignition Angle" desc="P10-(STATUS_ZUENDWINKEL)" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x0D</address>
                    </ecu>
                    <conversions>
                        <conversion units="\xB0 CRK" expr="-0.375*x+72" format="0.0" gauge_min="-20" gauge_max="50" gauge_step="5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P99" name="* Parameter 0x0E" desc="P99" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x0E</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" storagetype="uint16" expr="x" format="0" gauge_min="0" gauge_max="65535" gauge_step="6500" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P100" name="* Parameter 0x10" desc="P100" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x10</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" storagetype="uint16" expr="x" format="0" gauge_min="0" gauge_max="65535" gauge_step="6500" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P101" name="* Parameter 0x12" desc="P101" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x12</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" storagetype="uint16" expr="x" format="0" gauge_min="0" gauge_max="65535" gauge_step="6500" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P102" name="* Ignition Key Voltage" desc="P102-KL 15" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x14</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" expr="x*0.1" format="0.0" gauge_min="0" gauge_max="25" gauge_step="2" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P103" name="* Parameter 0x15" desc="P103" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x15</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" expr="x" format="0" gauge_min="0" gauge_max="255" gauge_step="20" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P17" name="* Battery Voltage" desc="P17-Battery Voltage" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x16</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" expr="x*0.1" format="0.0" gauge_min="0" gauge_max="25" gauge_step="2" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E13" name="* Lambda Integrator - Bank 1" desc="E13-(TI_LAM_1)" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x17</address>
                    </ecu>
                    <conversions>
                        <conversion units="%" storagetype="uint16" expr="0.0015258789*x-50" format="0.00" gauge_min="-50" gauge_max="50" gauge_step="12" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E14" name="* Lambda Integrator - Bank 2" desc="E14-(TI_LAM_2)" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x19</address>
                    </ecu>
                    <conversions>
                        <conversion units="%" storagetype="uint16" expr="0.0015258789*x-50" format="0.00" gauge_min="-50" gauge_max="50" gauge_step="12" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P104" name="* Parameter 0x1B" desc="P104" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x1B</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" expr="x" format="0" gauge_min="0" gauge_max="255" gauge_step="20" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P105" name="* Parameter 0x1C" desc="P105" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x1C</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" expr="x" format="0" gauge_min="0" gauge_max="255" gauge_step="20" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P106" name="* Parameter 0x1D" desc="P106" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x1D</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" expr="x" format="0" gauge_min="0" gauge_max="255" gauge_step="20" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P107" name="* Parameter 0x1E" desc="P107" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x1E</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" expr="x" format="0" gauge_min="0" gauge_max="255" gauge_step="20" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E2" name="* Engine Load" desc="E2-(STATUS_LAST)" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x1F</address>
                    </ecu>
                    <conversions>
                        <conversion units="mg/stroke" storagetype="uint16" expr="x*0.021" format="0.00" gauge_min="0" gauge_max="1000" gauge_step="100" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P108" name="* Parameter 0x21" desc="P108" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x21</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" storagetype="uint16" expr="x" format="0" gauge_min="0" gauge_max="65535" gauge_step="6500" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P110" name="* Parameter 0x23" desc="P110" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x23</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" storagetype="uint16" expr="x" format="0" gauge_min="0" gauge_max="65535" gauge_step="6500" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P112" name="* Parameter 0x25" desc="P112" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x25</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" expr="x" format="0" gauge_min="0" gauge_max="255" gauge_step="20" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P113" name="* Parameter 0x26" desc="P113" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x26</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" storagetype="uint16" expr="x" format="0" gauge_min="0" gauge_max="65535" gauge_step="6500" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P114" name="* Parameter 0x28" desc="P114" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x28</address>
                    </ecu>
                    <conversions>
                        <conversion units="?" expr="x" format="0" gauge_min="0" gauge_max="255" gauge_step="20" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E99" name="Knock Adaptation Table 1 Index**" desc="E99-Knock Adaptation Table 1 Index Direct RAM Read used by Adaptation display tool" group="0x06" subgroup="0x00" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x040218</address>
                    </ecu>
                    <conversions>
                        <conversion units="\xB0 Cor" storagetype="uint8" endian="little" expr="(x-128)*0.375" format="0.000" gauge_min="-48" gauge_max="0" gauge_step="5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E19" name="** Lambda Additive Adaptation - Bank 1" desc="E19-(TI_AD_ADD_1)" group="0x0B" subgroup="0x91" groupsize="11" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x01</address>
                    </ecu>
                    <conversions>
                        <conversion units="ms" storagetype="uint16" expr="(x-32768)*.004" format="0.00" gauge_min="-5" gauge_max="5" gauge_step="1" />
						<conversion units="\xB5s" storagetype="uint16" expr="(x-32768)*4" format="0" gauge_min="-5000" gauge_max="5000" gauge_step="1000" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E20" name="** Lambda Additive Adaptation - Bank 2" desc="E20-(TI_AD_ADD_2)" group="0x0B" subgroup="0x91" groupsize="11" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x05</address>
                    </ecu>
                    <conversions>
                        <conversion units="ms" storagetype="uint16" expr="(x-32768)*.004" format="0.00" gauge_min="-5" gauge_max="5" gauge_step="1" />
						<conversion units="\xB5s" storagetype="uint16" expr="(x-32768)*4" format="0" gauge_min="-5000" gauge_max="5000" gauge_step="1000" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E21" name="** Lambda Multiplicative Adaptation - Bank 1" desc="E21-(TI_AD_FAC_1 or LTFT 1)" group="0x0B" subgroup="0x91" groupsize="11" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x03</address>
                    </ecu>
                    <conversions>
                        <conversion units="%" storagetype="uint16" expr="(x-32768)*100/65536" format="0.00" gauge_min="-32" gauge_max="32" gauge_step="12" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E22" name="** Lambda Multiplicative Adaptation - Bank 2" desc="E22-(TI_AD_FAC_2 or LTFT 2)" group="0x0B" subgroup="0x91" groupsize="11" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x07</address>
                    </ecu>
                    <conversions>
                        <conversion units="%" storagetype="uint16" expr="(x-32768)*100/65536" format="0.00" gauge_min="-32" gauge_max="32" gauge_step="12" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E24" name="Knock Retard - Global" desc="E24-Global correction applied to total timing" group="0x0B" subgroup="0x93" groupsize="2" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x00</address>
                    </ecu>
                    <conversions>
                        <conversion units="\xB0 Cor" storagetype="uint16" expr="x/65536" format="0.00" gauge_min="-50" gauge_max="50" gauge_step="10" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E100" name="Air Intake Temperature Sensor*" desc="E100-Air Intake Temperature Sensor" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x000000</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.00488" format="0.00" gauge_min="0" gauge_max="5" gauge_step="0.5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E101" name="STATUS_LS_VKAT_SIGNAL_1*" desc="E101-STATUS_LS_VKAT_SIGNAL_1" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x000001</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.00488" format="0.00" gauge_min="0" gauge_max="5" gauge_step="0.5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E102" name="STATUS_LS_VKAT_SIGNAL_2*" desc="E102-STATUS_LS_VKAT_SIGNAL_2" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x000002</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.00488" format="0.00" gauge_min="0" gauge_max="5" gauge_step="0.5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E103" name="Engine Coolant Temperature Sensor*" desc="E103-Engine Coolant Temperature Sensor" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x000003</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.00488" format="0.00" gauge_min="0" gauge_max="5" gauge_step="0.5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E104" name="ADC Input 0x04*" desc="E104" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x000004</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.00488" format="0.00" gauge_min="0" gauge_max="5" gauge_step="0.5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E105" name="Oil Temperature Sensor Volts*" desc="E105-Oil Temperature Sensor Volts" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x000005</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.00488" format="0.00" gauge_min="0" gauge_max="5" gauge_step="0.5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P18" name="Mass Airflow Volts*" desc="P18-Mass Airflow Volts" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x000006</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.00488" format="0.00" gauge_min="0" gauge_max="5" gauge_step="0.5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E107" name="Battery Voltage Sensor 1*" desc="E107-Battery Voltage Sensor" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x000007</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.025" format="0.0" gauge_min="0" gauge_max="20" gauge_step="2" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E108" name="Accelerator Pedal Request Volts*" desc="E108-Battery Voltage Sensor" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x000008</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.025" format="0.0" gauge_min="0" gauge_max="20" gauge_step="2" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E109" name="Accelerator Pedal Plausibility Volts*" desc="E109" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x000009</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.00488" format="0.00" gauge_min="0" gauge_max="5" gauge_step="0.5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P19" name="Throttle Position Volts*" desc="P19-Throttle 1 Position Volts" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x00000A</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.00488" format="0.00" gauge_min="0" gauge_max="5" gauge_step="0.5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P110" name="Throttle Plausibility Volts*" desc="P110-Throttle 2 Position Volts" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x00000B</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.00488" format="0.00" gauge_min="0" gauge_max="5" gauge_step="0.5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E120" name="ADC Input 0x10*" desc="E120" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x000010</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.00488" format="0.00" gauge_min="0" gauge_max="5" gauge_step="0.5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E127" name="Knock Sensor 1 Volts*" desc="E127" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x000017</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.00488" format="0.00" gauge_min="0" gauge_max="5" gauge_step="0.5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E128" name="Knock Sensor 2 Volts*" desc="E128" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x000018</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.00488" format="0.00" gauge_min="0" gauge_max="5" gauge_step="0.5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E129" name="STATUS_VLS_DOWN_2_BAS*" desc="E129-STATUS_VLS_DOWN_2_BAS" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x000019</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.00488" format="0.00" gauge_min="0" gauge_max="5" gauge_step="0.5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="E130" name="STATUS_VLS_DOWN_1_BAS*" desc="E130-STATUS_VLS_DOWN_1_BAS" group="0x0B" subgroup="0x020E" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x00001A</address>
                    </ecu>
                    <conversions>
                        <conversion units="VDC" storagetype="uint16" expr="x*0.00488" format="0.00" gauge_min="0" gauge_max="5" gauge_step="0.5" />
                    </conversions>
                </ecuparam>
                <ecuparam id="P24" name="Atmospheric Pressure**" desc="P24-A temporary fake entry for the Dyno tab" group="0x0B" subgroup="0x03" groupsize="41" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x00</address>
                    </ecu>
                    <conversions>
                        <conversion units="psi" expr="101.325*37/255" format="0.00" gauge_min="0" gauge_max="20" gauge_step="2" />
                        <conversion units="kPa" expr="101.325" format="0" gauge_min="0" gauge_max="255" gauge_step="20" />
                        <conversion units="hPa" expr="101.325*10" format="0" gauge_min="0" gauge_max="1500" gauge_step="100" />
                        <conversion units="bar" expr="101.325/100" format="0.000" gauge_min="0" gauge_max="1.5" gauge_step="0.1" />
                        <conversion units="inHg" expr="101.325*0.2953" format="0.00" gauge_min="-40" gauge_max="60" gauge_step="10" />
                        <conversion units="mmHg" expr="101.325*7.5" format="0" gauge_min="-1000" gauge_max="2000" gauge_step="300" />
                    </conversions>
                </ecuparam>
<!-- Switches -->
                <ecuparam id="S0" name="SW - Byte 0 Bit 7" desc="S0" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="7">0x00</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S1" name="SW - Byte 0 Bit 6" desc="S1" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="6">0x00</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S2" name="SW - Byte 0 Bit 5" desc="S2" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="5">0x00</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S3" name="SW - Byte 0 Bit 4" desc="S3" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="4">0x00</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S4" name="SW - Byte 0 Bit 3" desc="S4" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="3">0x00</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S5" name="SW - Byte 0 Bit 2" desc="S5" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="2">0x00</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S6" name="SW - Full Load" desc="S6-S_VL" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x00</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="BitWise(3,x,1)/3" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S7" name="SW - Part Load" desc="S7-Part load" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x00</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="BitWise(2,x,1)/2" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S8" name="SW - Closed Throttle" desc="S8-S_LL" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address>0x00</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="BitWise(1,x,1)" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S9" name="SW - Byte 1 Bit 7" desc="S9" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="7">0x01</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S10" name="SW - Byte 1 Bit 6" desc="S10" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="6">0x01</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S11" name="SW - Byte 1 Bit 5" desc="S11" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="5">0x01</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S12" name="SW - Byte 1 Bit 4" desc="S12" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="4">0x01</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S13" name="SW - Byte 1 Bit 3" desc="S13" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="3">0x01</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S14" name="SW - Byte 1 Bit 2" desc="S14" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="2">0x01</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S15" name="SW - Byte 1 Bit 1" desc="S15" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="1">0x01</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S16" name="SW - Byte 1 Bit 0" desc="S16" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="0">0x01</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S17" name="SW - Byte 2 Bit 7" desc="S17" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="7">0x02</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S18" name="SW - Byte 2 Bit 6" desc="S18" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="6">0x02</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S19" name="SW - Byte 2 Bit 5" desc="S19" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="5">0x02</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
<!--                <ecuparam id="S20" name="Rear Defogger Switch" desc="S20">  Reserved as Logger control switch -->
                <ecuparam id="S21" name="SW - Byte 2 Bit 4" desc="S21" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="4">0x02</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S22" name="SW - Byte 2 Bit 3" desc="S22" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="3">0x02</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S23" name="SW - Byte 2 Bit 2" desc="S23" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="2">0x02</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S24" name="SW - Byte 2 Bit 1" desc="S24" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="1">0x02</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S25" name="SW - Byte 2 Bit 0" desc="S25" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="0">0x02</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S26" name="SW - Byte 3 Bit 7" desc="S26" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="7">0x03</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S27" name="SW - Byte 3 Bit 6" desc="S27" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="6">0x03</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S28" name="SW - Byte 3 Bit 5" desc="S28" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="5">0x03</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S29" name="SW - Byte 3 Bit 4" desc="S29" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="4">0x03</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S30" name="SW - Byte 3 Bit 3" desc="S30" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="3">0x03</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S31" name="SW - Byte 3 Bit 2" desc="S31" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="2">0x03</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S32" name="SW - Byte 3 Bit 1" desc="S32" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="1">0x03</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S33" name="SW - Byte 3 Bit 0" desc="S33" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="0">0x03</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S34" name="SW - Byte 4 Bit 7" desc="S34" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="7">0x04</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S35" name="SW - Byte 4 Bit 6" desc="S35" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="6">0x04</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S36" name="SW - Byte 4 Bit 5" desc="S36" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="5">0x04</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S37" name="SW - Byte 4 Bit 4" desc="S37" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="4">0x04</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S38" name="SW - Byte 4 Bit 3" desc="S38" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="3">0x04</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S39" name="SW - Byte 4 Bit 2" desc="S39" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="2">0x04</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S40" name="SW - Byte 4 Bit 1" desc="S40" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="1">0x04</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S41" name="SW - Byte 4 Bit 0" desc="S41" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="0">0x04</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S42" name="SW - Byte 5 Bit 7" desc="S42" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="7">0x05</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S43" name="SW - Byte 5 Bit 6" desc="S43" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="6">0x05</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S44" name="SW - Byte 5 Bit 5" desc="S44" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="5">0x05</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S45" name="SW - Byte 5 Bit 4" desc="S45" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="4">0x05</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S46" name="SW - Byte 5 Bit 3" desc="S46" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="3">0x05</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S47" name="SW - Byte 5 Bit 2" desc="S47" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="2">0x05</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S48" name="SW - Byte 5 Bit 1" desc="S48" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="1">0x05</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
                <ecuparam id="S49" name="SW - Byte 5 Bit 0" desc="S49" group="0x0B" subgroup="0x04" groupsize="6" target="1">
                    <ecu id="7511570,7519308,7545150">
						<address bit="0">0x05</address>
                    </ecu>
                    <conversions>
                        <conversion units="On/Off" expr="x" format="0" gauge_min="0" gauge_max="1" gauge_step="1" />
                    </conversions>
                </ecuparam>
            </ecuparams>
		</protocol>
    </protocols>
</logger>
FOOTER
}
