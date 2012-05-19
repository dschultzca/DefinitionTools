# 
# Copyright (C) 2010+  Dale C. Schultz
# RomRaider member ID: dschultz
# 
# You are free to use this script for any purpose, but please keep
# notice of where it came from!
# 
# Use this script to convert the RomRaider Editor definition to an ECUFlash definition.
# Then update the ECUFlash ROM ID info.
#
# Caveats: This script expects only one ROM definition in the file
# excluding the <roms> tag.  Basically take the RR ECU def of interest
# and copy it to an XML format of a typical EcuFlash def, start/ending
# with only the <rom> and included elements.
# 
unless ($ARGV[0]) {
	print "Input file missing...\n";
	print "Usage: $0 <RomRaider Editor Def File>\n";
	exit 1;
}

($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$mDate = sprintf("%04d-%02d-%02d", $year+=1900, $mon+=1, $mday);

use XML::TreeBuilder;
my $tree = XML::TreeBuilder->new();

$tree->parse_file($ARGV[0]);
$xmlid = $tree->find_by_tag_name('xmlid')->as_text;
$address = $tree->find_by_tag_name('internalidaddress')->as_text;
$ecuid = $tree->find_by_tag_name('ecuid')->as_text;
$year = $tree->find_by_tag_name('year')->as_text;
$market = $tree->find_by_tag_name('market')->as_text;
$model = $tree->find_by_tag_name('model')->as_text;
$submodel = $tree->find_by_tag_name('submodel')->as_text;
$trans = $tree->find_by_tag_name('transmission')->as_text;
$flash = $tree->find_by_tag_name('flashmethod')->as_text;

open (OUTPUT, ">${xmlid}.xml") || die "Could not open output file to write. $!\n";

#  <table name="CL Fueling Target Compensation (Load)(MT)" address="ca238">
#    <table name="X" address="ca1c0" elements="11" />
#    <table name="Y" address="ca1ec" elements="19" />
#  </table>
print OUTPUT <<PREAMBLE;
<?xml version="1.0" encoding="UTF-8"?>
<!-- EcuFlash STANDARD UNITS ECU DEFINITION FILE (VERSION ${xmlid}_v1) $mDate

TERMS, CONDITIONS, AND DISCLAIMERS
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
WARNING: These definition files are created as the result of the extremely complex and time consuming
process of reverse-engineering the factory ECU. Because of this complexity, it is necessary to make certain
assumptions and, therefore, it is impossible to always deal in absolutes in regards to representations made
by these definitions. In addition, due to this complexity and the numerous variations among different ECUs,
it is also impossible to guarantee that the definitions will not contain errors or other bugs. What this all means
is that there is the potential for bugs, errors and misrepresentations which can result in damage to your motor,
your ECU as well the possibility of causing your vehicle to behave unexpectedly on the road, increasing the
risk of death or injury. Modifications to your vehicle's ECU may also be in violation of local, state and federal
laws. By using these definition files, either directly or indirectly, you agree to assume 100% of all risk and
RomRaider's creators and contributors shall not be held responsible for any damages or injuries you receive.
This product is for advanced users only. There are no safeguards in place when tuning with RomRaider. As such,
the potential for serious damage and injury still exists, even if the user does not experience any bugs or errors. 

As always, use at your own risk.

These definitions are created for FREE without any sort of guarantee. The developers cannot be held liable
for any damage or injury incurred as a result of these definitions. USE AT YOUR OWN RISK!-->
PREAMBLE
print OUTPUT  "<rom>\n";
print OUTPUT  " <romid>\n";
print OUTPUT  "   <xmlid>${xmlid}</xmlid>\n";
print OUTPUT  "   <internalidaddress>${address}</internalidaddress>\n";
print OUTPUT  "   <internalidstring>${xmlid}</internalidstring>\n";
print OUTPUT  "   <ecuid>${ecuid}</ecuid>\n";
print OUTPUT  "   <year>${year}</year>\n";
print OUTPUT  "   <market>${market}</market>\n";
print OUTPUT  "   <make>Subaru</make>\n";
print OUTPUT  "   <model>${model}</model>\n";
print OUTPUT  "   <submodel>${submodel}</submodel>\n";
print OUTPUT  "   <transmission>${trans}</transmission>\n";
print OUTPUT  "   <memmodel>SH7058</memmodel>\n";
print OUTPUT  "   <flashmethod>${flash}</flashmethod>\n";
print OUTPUT  "   <checksummodule>subarudbw</checksummodule>\n";
print OUTPUT  "  </romid>\n";
print OUTPUT  "  <include>32BITBASE</include>\n";
foreach my $rom ($tree->find_by_tag_name('table')){
	$TableName = $rom->attr_get_i('name');
	next if ($TableName eq "Checksum Fix");
	$TableName = "Fuel Pump Duty" if ($TableName eq "Fuel Pump Duty Cycle");
	$TableName =~ s/  $/__/;
	$TableName =~ s/ $/_/;
	$TableAddress = $rom->attr_get_i('storageaddress');
	$TableAddress =~ s/^0x//;
	$TableType = $rom->find_by_tag_name('table')->attr_get_i('type');
	$TableType =~ s/^X Axis$/X/;
	$TableType =~ s/^Y Axis$/Y/;
	$TableXsize = $rom->attr_get_i('sizex');
	$TableYsize = $rom->attr_get_i('sizey');
	if (!$TableType) {
		if (!$LastTable) {
		}
		elsif ($LastTable eq "data") {
			print OUTPUT  " />\n";
		}
		else {
			print OUTPUT  ">\n";
		}
		print OUTPUT  '  <table name="' . $TableName . '" address="' . lc($TableAddress) . '"';
		$LastTable = "data";
	}
	elsif ( $TableType eq "X") {
		print OUTPUT  ">\n" . '    <table name="X" address="' . lc($TableAddress) . '"';
		if ($TableXsize) {
			print OUTPUT  ' elements="' . $TableXsize . '"';
		}
		print OUTPUT  " /";
		$LastTable = "x";
		undef $TableXsize;
	}
	elsif ( $TableType eq "Y") {
		print OUTPUT  ">\n" . '    <table name="Y" address="' . lc($TableAddress) . '"';
		if ($TableYsize) {
			print OUTPUT  ' elements="' . $TableYsize . '"';
		}
		print OUTPUT  " />\n  </table";
		$LastTable = "y";
		undef $TableYsize;
	}
}
print OUTPUT  " />\n</rom>\n";
close OUTPUT;
