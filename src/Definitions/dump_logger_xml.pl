#!/usr/bin/perl 

# Copyright (C) 2014 Dale C. Schultz
# RomRaider member ID: dschultz
#
# You are free to use this source for any purpose, but please keep
# notice of where it came from!
#
#
# Purpose
#	Reads the database and dumps logger XML file to STDOUT
#	Version:    13
#	Update:     May 31/2014
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
my $ret = getopts ("gl:u:");
my $groupEcuId = $opt_g;
my $locale = $opt_l;
my $measure = $opt_u;
if (($locale ne "en" && $locale ne "de") || 
    ($measure ne "std" && $measure ne "imp" && $measure ne "metric")) {
	print "\nUsage: $0 -g -l locale -u units > <output_file.xml>\nThe optional -g flag groups the ECU IDs by common address.\nWhere locale is: 'en' or 'de'\n   and units is: 'std', 'imp' or 'metric'\n";
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

# Get last version/update info to insert into def header
my $sql = qq(SELECT * FROM version ORDER BY id DESC LIMIT 1);
my $sth = $dbh->prepare($sql);
$sth->execute;
$sth->bind_columns(\$serial, \$version, \$update);
$sth->fetch;
$update =~ s/$\$\///;
$update =~ s/\r\n/ /;

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
}
	$sql = qq(
		SELECT dtcode.id, dtcode_xlt_de.code_xlt, dtcode.tmpaddr, dtcode.memaddr, dtcode.bitidx
		FROM dtcode
		INNER JOIN dtcode_xlt_de ON dtcode.translation_id = dtcode_xlt_de.serial
		WHERE dtcode.reserved is NULL
	  );
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
            <parameters>
STDPARAM
}

sub footer {
print <<FOOTER;
            </ecuparams>
        </protocol>
        <protocol id="OBD" baud="500000" databits="8" stopbits="1" parity="0" connect_timeout="2000" send_timeout="55">
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
                        <conversion units="count" storagetype="uint32" expr="if(256+x/16777216&gt;127,(256+x/16777216)-128,x/16777216)" format="0" gauge_min="0" gauge_max="127" gauge_step="12"/>
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
                        <conversion storagetype="uint32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="uint32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="uint32" units="VDC" expr="if(x&lt;2147483647,((x+2147483648)%65536)/8192,(x%65536)/8192)" format="0.000" gauge_min="0" gauge_max="8" gauge_step="1" />
                    </conversions>
                </parameter>
                <parameter id="PID25" name="O2 Wideband Bank 1 Sensor 2" desc="PID25-Linear or Wideband Oxygen Sensor" ecubyteindex="12" ecubit="3" target="1">
                    <address>0x25</address>
                    <conversions>
                        <conversion storagetype="uint32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="uint32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="uint32" units="VDC" expr="if(x&lt;2147483647,((x+2147483648)%65536)/8192,(x%65536)/8192)" format="0.000" gauge_min="0" gauge_max="8" gauge_step="1" />
                    </conversions>
                </parameter>
                <parameter id="PID26" name="O2 Wideband Bank 1 Sensor 3" desc="PID26-Linear or Wideband Oxygen Sensor" ecubyteindex="12" ecubit="2" target="1">
                    <address>0x26</address>
                    <conversions>
                        <conversion storagetype="uint32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="uint32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="uint32" units="VDC" expr="if(x&lt;2147483647,((x+2147483648)%65536)/8192,(x%65536)/8192)" format="0.000" gauge_min="0" gauge_max="8" gauge_step="1" />
                    </conversions>
                </parameter>
                <parameter id="PID27" name="O2 Wideband Bank 1 Sensor 4" desc="PID26-Linear or Wideband Oxygen Sensor" ecubyteindex="12" ecubit="1" target="1">
                    <address>0x27</address>
                    <conversions>
                        <conversion storagetype="uint32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="uint32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="uint32" units="VDC" expr="if(x&lt;2147483647,((x+2147483648)%65536)/8192,(x%65536)/8192)" format="0.000" gauge_min="0" gauge_max="8" gauge_step="1" />
                    </conversions>
                </parameter>
                <parameter id="PID28" name="O2 Wideband Bank 2 Sensor 1" desc="PID28-Linear or Wideband Oxygen Sensor" ecubyteindex="12" ecubit="0" target="1">
                    <address>0x28</address>
                    <conversions>
                        <conversion storagetype="uint32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="uint32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="uint32" units="VDC" expr="if(x&lt;2147483647,((x+2147483648)%65536)/8192,(x%65536)/8192)" format="0.000" gauge_min="0" gauge_max="8" gauge_step="1" />
                    </conversions>
                </parameter>
                <parameter id="PID29" name="O2 Wideband Bank 2 Sensor 2" desc="PID29-Linear or Wideband Oxygen Sensor" ecubyteindex="13" ecubit="7" target="1">
                    <address>0x29</address>
                    <conversions>
                        <conversion storagetype="uint32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="uint32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="uint32" units="VDC" expr="if(x&lt;2147483647,((x+2147483648)%65536)/8192,(x%65536)/8192)" format="0.000" gauge_min="0" gauge_max="8" gauge_step="1" />
                    </conversions>
                </parameter>
                <parameter id="PID2A" name="O2 Wideband Bank 2 Sensor 3" desc="PID2A-Linear or Wideband Oxygen Sensor" ecubyteindex="13" ecubit="6" target="1">
                    <address>0x2A</address>
                    <conversions>
                        <conversion storagetype="uint32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="uint32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="uint32" units="VDC" expr="if(x&lt;2147483647,((x+2147483648)%65536)/8192,(x%65536)/8192)" format="0.000" gauge_min="0" gauge_max="8" gauge_step="1" />
                    </conversions>
                </parameter>
                <parameter id="PID2B" name="O2 Wideband Bank 2 Sensor 4" desc="PID2B-Linear or Wideband Oxygen Sensor" ecubyteindex="13" ecubit="5" target="1">
                    <address>0x2B</address>
                    <conversions>
                        <conversion storagetype="uint32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="uint32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="uint32" units="VDC" expr="if(x&lt;2147483647,((x+2147483648)%65536)/8192,(x%65536)/8192)" format="0.000" gauge_min="0" gauge_max="8" gauge_step="1" />
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
                        <conversion storagetype="uint32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="uint32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="uint32" units="mA" expr="if(x&lt;2147483647,((x+2147483648)%65536)/255-128,(x%65536)/255-128)" format="0.000" gauge_min="-128" gauge_max="128" gauge_step="25" />
                    </conversions>
                </parameter>
                <parameter id="PID35" name="O2 Wideband Bank 1 Sensor 2" desc="PID35-Linear or Wideband Oxygen Sensor" ecubyteindex="14" ecubit="3" target="1">
                    <address>0x35</address>
                    <conversions>
                        <conversion storagetype="uint32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="uint32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="uint32" units="mA" expr="if(x&lt;2147483647,((x+2147483648)%65536)/255-128,(x%65536)/255-128)" format="0.000" gauge_min="-128" gauge_max="128" gauge_step="25" />
                    </conversions>
                </parameter>
                <parameter id="PID36" name="O2 Wideband Bank 1 Sensor 3" desc="PID36-Linear or Wideband Oxygen Sensor" ecubyteindex="14" ecubit="2" target="1">
                    <address>0x36</address>
                    <conversions>
                        <conversion storagetype="uint32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="uint32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="uint32" units="mA" expr="if(x&lt;2147483647,((x+2147483648)%65536)/255-128,(x%65536)/255-128)" format="0.000" gauge_min="-128" gauge_max="128" gauge_step="25" />
                    </conversions>
                </parameter>
                <parameter id="PID37" name="O2 Wideband Bank 1 Sensor 4" desc="PID36-Linear or Wideband Oxygen Sensor" ecubyteindex="14" ecubit="1" target="1">
                    <address>0x37</address>
                    <conversions>
                        <conversion storagetype="uint32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="uint32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="uint32" units="mA" expr="if(x&lt;2147483647,((x+2147483648)%65536)/255-128,(x%65536)/255-128)" format="0.000" gauge_min="-128" gauge_max="128" gauge_step="25" />
                    </conversions>
                </parameter>
                <parameter id="PID38" name="O2 Wideband Bank 2 Sensor 1" desc="PID38-Linear or Wideband Oxygen Sensor" ecubyteindex="14" ecubit="0" target="1">
                    <address>0x38</address>
                    <conversions>
                        <conversion storagetype="uint32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="uint32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="uint32" units="mA" expr="if(x&lt;2147483647,((x+2147483648)%65536)/255-128,(x%65536)/255-128)" format="0.000" gauge_min="-128" gauge_max="128" gauge_step="25" />
                    </conversions>
                </parameter>
                <parameter id="PID39" name="O2 Wideband Bank 2 Sensor 2" desc="PID39-Linear or Wideband Oxygen Sensor" ecubyteindex="15" ecubit="7" target="1">
                    <address>0x39</address>
                    <conversions>
                        <conversion storagetype="uint32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="uint32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="uint32" units="mA" expr="if(x&lt;2147483647,((x+2147483648)%65536)/255-128,(x%65536)/255-128)" format="0.000" gauge_min="-128" gauge_max="128" gauge_step="25" />
                    </conversions>
                </parameter>
                <parameter id="PID3A" name="O2 Wideband Bank 2 Sensor 3" desc="PID3A-Linear or Wideband Oxygen Sensor" ecubyteindex="15" ecubit="6" target="1">
                    <address>0x3A</address>
                    <conversions>
                        <conversion storagetype="uint32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="uint32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="uint32" units="mA" expr="if(x&lt;2147483647,((x+2147483648)%65536)/255-128,(x%65536)/255-128)" format="0.000" gauge_min="-128" gauge_max="128" gauge_step="25" />
                    </conversions>
                </parameter>
                <parameter id="PID3B" name="O2 Wideband Bank 2 Sensor 4" desc="PID3B-Linear or Wideband Oxygen Sensor" ecubyteindex="15" ecubit="5" target="1">
                    <address>0x3B</address>
                    <conversions>
                        <conversion storagetype="uint32" units="lambda" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768,x/65536/32768)" format="0.000" gauge_min="0" gauge_max="2" gauge_step="0.2" />
                        <conversion storagetype="uint32" units="AFR Gas" expr="if(65536+x/65536&gt;32767,(65536+x/65536)/32768*14.64,x/65536/32768*14.64)" format="0.000" gauge_min="0" gauge_max="30" gauge_step="3" />
                        <conversion storagetype="uint32" units="mA" expr="if(x&lt;2147483647,((x+2147483648)%65536)/255-128,(x%65536)/255-128)" format="0.000" gauge_min="-128" gauge_max="128" gauge_step="25" />
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
    </protocols>
FOOTER
print "</logger>";
}