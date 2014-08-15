<?php
/* Copyright (C) 2014  Dale C. Schultz
   RomRaider member ID: dschultz

   You are free to use this source for any purpose, but please keep
   notice of where it came from!

   Purpose
    This script is called from the upload HTML form. It parses a logger.xml file
	for exteneded parameters specified by ECU ID.  Extended parameters are then
	checked against the logger database and updated or added as required.
	Version:	2
	Update:		Jul. 26/2014	
------------------------------------------------------------------------------------------
*/

function TestInput($data)
{
	$data = trim($data);
	$data = stripslashes($data);
	$data = htmlspecialchars($data);
	return $data;
}

function ConvertName($original)
{
	$original = str_replace(")(", "_", $original);
	$original = str_replace("(", "", $original);
	$original = str_replace(")", "", $original);
	$original = str_replace("-", "", $original);
	$original = str_replace("#", "", $original);
	$original = str_replace("/", "", $original);
	$original = str_replace(" ", "_", $original);
	$original = str_replace("*", "Ext", $original);
	return $original;
}

function ReportError($message, $con)
{
	if (!is_null($con)) mysqli_close($con);
	echo "<script>alert('" . $message . "\\nTerminating script.')</script></body></html>";
	exit;
}

function DbGetVersion($con)
{
	$sql_version = "SELECT * FROM version ORDER BY id DESC LIMIT 1";
	if (!$result = mysqli_query($con, $sql_version))
	{
		ReportError("Error retrieving DB version:" . mysqli_error($con), $con);
	}
	if (mysqli_num_rows($result) > 1)
	{
		ReportError("More than one version entry retrieved, count:" . mysqli_num_rows($result), $con);
	}
	$row = mysqli_fetch_array($result, MYSQLI_ASSOC);
	return array($row['id'], $row['version'], $row['update']);
}

function DbGetEcuIdSerial($con, $ecuid)
{
	$sql_version = "SELECT serial FROM ecuid where ecuid='" . $ecuid . "';";
	if (!$result = mysqli_query($con, $sql_version))
	{
		ReportError("Error retrieving ECU ID:" . mysqli_error($con), $con);
	}
	if (mysqli_num_rows($result) > 1)
	{
		ReportError("More than one ECU ID entry retrieved, count:" . mysqli_num_rows($result), $con);
	}
	$row = mysqli_fetch_array($result, MYSQLI_ASSOC);
	return $row['serial'];
}

function DbAddEcuId($con, $ecuid)
{
	$sql_addr_ecuid = "INSERT INTO ecuid (ecuid) VALUES ('" . $ecuid . "');";
	if (!mysqli_query($con, $sql_addr_ecuid))
	{
		ReportError("Error adding ecuid:" . mysqli_error($con), $con);
	}
	return mysqli_insert_id($con);
}

function DbAddAddress($con, $addr, $length, $bit)
{
	if (is_null($bit))
	{
		$bit = "NULL";
	}
	else
	{
		$bit = "'" . $bit . "'";
	}
	$sql_addr_add = "INSERT INTO address (address,length,bit) VALUES ('" . $addr . "','" . $length . "'," . $bit . ");";
	if (!mysqli_query($con, $sql_addr_add))
	{
		ReportError("Error adding address:" . mysqli_error($con), $con);
	}
	return mysqli_insert_id($con);
}

function DbUpdateEcuParamRel($con, $ecuparam_rel_serial, $address_serial)
{
	$sql_addrid_update = "UPDATE ecuparam_rel SET addressid='". $address_serial ."' WHERE serial='". $ecuparam_rel_serial ."';";
	if (!mysqli_query($con, $sql_addrid_update))
	{
		ReportError("Error updating address serial:" . mysqli_error($con), $con);
	}
	return;
}

function DbAddEcuParamRel($con, $ecuid_serial, $ecuparam_serial, $address_serial)
{
	$sql_addrid_add = "INSERT INTO ecuparam_rel (ecuparamid,ecuidid,addressid) VALUES ('" . $ecuparam_serial . "','" . $ecuid_serial . "','" . $address_serial . "');";
	if (!mysqli_query($con, $sql_addrid_add))
	{
		ReportError("Error adding ECU Parameter Relation:" . mysqli_error($con), $con);
	}
	return mysqli_insert_id($con);
}

function DbUpdateVersion($con, $message)
{
	date_default_timezone_set('America/New_York');
	$version = date("Ymd_His");
	$message = rtrim($message);
	$sql_version_update = "INSERT INTO `version` (`id`,`version`,`update`) VALUES (NULL,'" . $version . "','" . $message . "');";
	if (!mysqli_query($con, $sql_version_update))
	{
		ReportError("Error inserting version:" . mysqli_error($con), $con);
	}
	return;
}

$ecuid = NULL;
$operation = NULL;
$commit = NULL;
$allowedExts = array("txt", "xml");
$temp = explode(".", $_FILES["file"]["name"]);
$extension = end($temp);

echo "<html>";
echo "<head>";
echo "<title>RR Logger XML Import Tool</title>";
echo "<meta name=\"description\" content=\"RR Logger XML Import Tool\">";
echo "<meta name=\"author\" content=\"Dale C. Schultz\">";
echo "</head>";
echo "<body>";

if ((($_FILES["file"]["type"] == "text/plain")
  || ($_FILES["file"]["type"] == "text/xml"))
  && ($_FILES["file"]["size"] < 3000000)
  && in_array($extension, $allowedExts))
{
	if ($_FILES["file"]["error"] > 0)
    {
		ReportError("Return Code: " . $_FILES["file"]["error"], NULL);
    }
	else
    {
		echo "<b>Upload:</b> " . $_FILES["file"]["name"] . "<br>";
		echo "<b>Type:</b> " . $_FILES["file"]["type"] . "<br>";
		printf("<b>Size:</b> %.3f kB<br>", ($_FILES["file"]["size"] / 1024));
		echo "<b>Temp file:</b> " . $_FILES["file"]["tmp_name"] . "<br>";
    }
}
else
{
	ReportError("Invalid file", NULL);
}

if ($_SERVER["REQUEST_METHOD"] == "POST")
{
	$ecuid = TestInput($_POST["ecuid"]);
	$operation = TestInput($_POST["operation"]);
}
else
{
	ReportError("Invalid method", NULL);
}
if ($ecuid == '' || is_null($ecuid))
{
	ReportError("ECU ID must be specified", NULL);
}
echo "<b>Operation:</b> " . $operation . "<br>";
if ($operation == "Commit") $commit = 1;

$con = mysqli_connect("localhost","XXXX","XXXX","definitions");
if (mysqli_connect_errno())
{
    echo "Failed to connect to MySQL: " . mysqli_connect_error() . "</body></html>";
	return;
}

$version = DbGetVersion($con);
echo "<b>DB version:</b> " . $version[0] . " (" . $version[1] . ")<br>";

// Query database for the ECU ID, get serial number if found otherwise insert new ECU ID and get serial number
$ecuid_serial = DbGetEcuIdSerial($con, $ecuid);
$update = NULL;
$changed = 0;
if ($ecuid_serial)
{
	echo "<b>ECU ID:</b> " . $ecuid . " found with serial = " . $ecuid_serial . "<br><hr>";
	$update = "Updated ECU ID: " . $ecuid . " extended parameters\n";
}
else
{
	echo "<b>ECU ID:</b> " . $ecuid . " not found in database<br><hr>";
	if ($commit)
	{
		$ecuid_serial = DbAddEcuId($con, $ecuid);
		echo "<tr><td style=\"background-color:#00FF00\">COMMIT: ECU ID, new serial = " . $ecuid_serial;
		$update = "Added ECU ID: " . $ecuid . " to extended parameters\n";
		$changed++;
	}
	else
	{
		echo "<tr><td style=\"color:red\">TEST: New ECU ID will be added";
	}
}

$xml=simplexml_load_file($_FILES["file"]["tmp_name"]);
// query XML for all defined Extended parameter id attributes for this ECU ID
$parameter_ids = $xml->xpath("/logger/protocols/protocol[@id='SSM']/ecuparams/ecuparam[ecu[contains(@id, '". $ecuid . "')]]/@id");

$addresses = array();
echo "<table border='0'>";
foreach ($parameter_ids as $id)
{
	// query XML for all defined address attribute values using the Extended parameter id and ECU ID
	$address = $xml->xpath("/logger/protocols/protocol[@id='SSM']/ecuparams/ecuparam[@id='". (string)$id . "']/ecu[contains(@id, '". $ecuid . "')]/address");

	// query XML for the name attribute of this Extended parameter id
	$name = $xml->xpath("/logger/protocols/protocol[@id='SSM']/ecuparams/ecuparam[@id='". (string)$id . "']/@name");

	foreach ($address as $addr)
	{
		$bit_value = NULL;
		$db_addr = str_replace("0x0", "", $addr);
		$db_addr = str_replace("0x", "", $db_addr);
		// query XML for the bit attribute for this address and Extended parameter id and ECU ID
		$bit = $xml->xpath("/logger/protocols/protocol[@id='SSM']/ecuparams/ecuparam[@id='". (string)$id . "']/ecu[contains(@id, '". $ecuid . "')][address='" . (string)$addr . "']/address/@bit");

		if (count($bit) > 0)
		{
			$bit_value =  "<td>" . (string)$bit[0];
		}
		echo "<tr><td>E_" . ConvertName((string)$name[0]). "_" . (string)$id . "<td>" . $addr . $bit_value;

		// Query database for the Extended parameter ID to get the serial number and data storage length
		$query_ecuparam = "SELECT serial, length FROM ecuparam where id='" . str_replace("E", "", (string)$id) . "';";
		$result = mysqli_query($con, $query_ecuparam);
		if (mysqli_num_rows($result) > 1)
		{
			ReportError("More than one parameter ID " . (string)$id . " entry retrieved, count:" . mysqli_num_rows($result), $con);
		}
		elseif (mysqli_num_rows($result) != 1)
		{
			echo "<tr><td>Parameter : " . (string)$id . " not defined in database, skipping.<br>";
			continue;
		}
		$row = mysqli_fetch_array($result, MYSQLI_ASSOC);
		$ecuparam_serial = $row['serial'];
		$data_length = $row['length'];
		$bit_defined = NULL;
		if (count($bit) == 1)
		{
			$bit_defined = (string)$bit[0];
			if (is_null($data_length))
			{
				$length = 1;
			}
			else
			{
				$length = $data_length;
			}
			if (($length == 1 && $bit_defined >= 0 && $bit_defined <= 7 ) ||
				($length == 2 && $bit_defined >= 0 && $bit_defined <= 15) ||
				($length == 4 && $bit_defined >= 0 && $bit_defined <= 31))
			{
				$query_str = "SELECT serial FROM address where address='" . $db_addr .
							 "' and length='" . $data_length . "' and bit='" . $bit_defined . "';";
			}
			else
			{
				ReportError("Incompatible bit value passed for parameter address length, length:" . $length . ", bit:" . $bit_defined, $con);
			}
		}
		else
		{
			$query_str = "SELECT serial FROM address where address='" . $db_addr .
						 "' and length='" . $data_length . "' and bit IS NULL;";
		}

		// Query database for the address/length/bit combo, get serial number if found otherwise
		// insert new address/length/bit combo and get serial number
		mysqli_free_result($result);
		$result = mysqli_query($con, $query_str);
		$row = mysqli_fetch_array($result, MYSQLI_ASSOC);
		if (mysqli_num_rows($result) > 1)
		{
			ReportError("More than one address " . $addr . " entry retrieved, count:" . mysqli_num_rows($result), $con);
		}
		$address_serial = NULL;
		if ($row['serial'])
		{
			$address_serial = $row['serial'];
			//echo "<tr><td>address serial = " . $address_serial;
		}
		else
		{
			if ($commit)
			{
				echo "<tr><td>address/length/bit combo not defined:" . $addr . "/" . $data_length . "/" . $bit_defined;
				$address_serial = DbAddAddress($con, $db_addr, $data_length, $bit_defined);
				echo "<tr><td style=\"background-color:#00FF00\">COMMIT: address/length/bit combo new serial = " . $address_serial;
				$changed++;
			}
			else
			{
				echo "<tr><td style=\"color:red\">TEST: address/length/bit combo not defined, will be added";
			}
		}

		// Query database for the ECU ID/parameter/address combo, get serial number if found.
		// If the combo exists, check to see if the address serial is the same as what we have
		// determined above.  If it is not then update the current address serial entry.
		// If the combo does not exist, insert new ECU ID/parameter/address combo and get serial number
		mysqli_free_result($result);
		$query_ecuparam_rel = "SELECT * FROM ecuparam_rel where ecuparamid='" . $ecuparam_serial .
					 "' and ecuidid='" . $ecuid_serial . "';";
		$result = mysqli_query($con, $query_ecuparam_rel);
		$row = mysqli_fetch_array($result, MYSQLI_ASSOC);
		if (mysqli_num_rows($result) > 1)
		{
			ReportError("More than one ECU parameter relation " . $ecuparam_serial . 
						"/" . $ecuid_serial . " entry retrieved, count:" . mysqli_num_rows($result), $con);
		}
		$ecuparam_rel_serial = NULL;
		$ecuparam_rel_addr_serial = NULL;
		if ($row['serial'])
		{
			$ecuparam_rel_serial = $row['serial'];
			$ecuparam_rel_addr_serial = $row['addressid'];
			if ($ecuparam_rel_addr_serial == $address_serial)
			{
				echo "<tr><td>Address serials match: " . $ecuparam_rel_addr_serial  . " == " . $address_serial;
			}
			else
			{
				if ($commit)
				{
					echo "<tr><td style=\"background-color:#FFFF00\">COMMIT: Address serials do not match: " . $ecuparam_rel_addr_serial  . " != " . $address_serial . ", updated";
					DbUpdateEcuParamRel($con, $ecuparam_rel_serial, $address_serial);
					$update = $update . "Changed address/length/bit entry for ECU ID " . $ecuid . " for extended parameter " . (string)$id . "\n";
					$changed++;
				}
				else
				{
					echo "<tr><td style=\"background-color:#FFFF00\">TEST: Address serials do not match and will be updated";
				}
			}
		}
		else
		{
			if ($commit)
			{
				echo "<tr><td>ECU ID/parameter/address combo not defined: " . $ecuid_serial . "/" . $ecuparam_serial . "/" . $address_serial;
				$ecuparam_rel_serial = DbAddEcuParamRel($con, $ecuid_serial, $ecuparam_serial, $address_serial);
				echo "<tr><td style=\"background-color:#00FF00\">COMMIT: Inserted ECU ID/parameter/address combo new serial = " . $ecuparam_rel_serial;
				$changed++;
			}
			else
			{
				echo "<tr><td style=\"color:red\">TEST: ECU ID/parameter/address combo not defined, will be added";
			}
		}
	}
	if (array_key_exists((string)$id, $addresses))
	{
		$addresses[(string)$id]++;
	}
	else
	{
		$addresses[(string)$id] = 1;
	}
}
echo "</table><hr>";
if ($changed)
{
	DbUpdateVersion($con, $update);
	$version = DbGetVersion($con);
	echo "<b>DB version:</b> " . $version[0] . " (" . $version[1] . ")<br>";
}
else
{
	echo "<b>Test complete</b><br>";
}
mysqli_close($con);

$warn = NULL;
foreach($addresses as $id => $id_count)
{
	if ($id_count > 1)
	{
		echo "---WARNING:---<br>";
		echo "id = " . $id . ", Seen = " . $id_count;
		echo "<br>";
		$warn++;
	}
}
if ($warn) ReportError("Warnings present", NULL);
echo "</body></html>";
?>
