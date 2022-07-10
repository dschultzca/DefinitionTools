/*
 * Copyright (C) 2022  Dale C. Schultz
 * RomRaider member ID: dschultz
 *
 * You are free to use this script for any purpose, but please keep
 * notice of where it came from!
 *
 * To use this script you must locate the start of the CEL routine
 * definitions in the ROM.
 * You also need to locate the start of the CEL switch table.
 * Move the cursor to beginning of the CEL routine definitions and
 * start the script.  Enter the CEL switch start address.
 * Each routine will be commented with the P code and Enable/disable
 * status.  The CEL switch table will be named with the P code.
 * The message area will contain the P code, status and address.
 * The script stops when either 280 codes are ID'd or the P code is 
 * non-numeric or orverruns the CEL routines address.
 * The results are written to the file pcode_def.xml in the ROM
 * directory in a format that can be pasted into a RomRaider
 * Editor def file.
 */

#include <idc.idc>
static main() {
	auto i, startFrom, addrFrom, CelSwTable, pcodeEnabled, pcount, pcArray, currentCode, proceed, endCheck, fout, resultArray, pOOOO, strPcode, alpha, pDesc;
	auto byteOffset, codeBit, ync, offset, combined, tableSize, tableEnd, celCount;
	pcArray = GetArrayId("PCODEARRAY");
	DeleteArray(pcArray);
	resultArray = GetArrayId("RESULTARRAY");
	DeleteArray(resultArray);
	CreatePcodeArray();
	pcArray = GetArrayId("PCODEARRAY");

	ync = AskYN(-1, "Are the CEL Switch and CEL Routine tables combined?"); // -1:cancel,0-no,1-ok
	if (ync == -1) {
		Message("Aborting ROM formating at user request\n");
		return 0;
	}
	else if (ync == 1) {
		tableEnd = AskAddr(0,"Enter the CEL Table End address, or 0 to cancel:\n");
		if (tableEnd <= here) {
			Message("Script cancelled by user, invalid table end address.\n");
			return;
		}
		offset = 2;
		combined = 1;
		tableSize = 12;
	}
	else {
		ync = AskYN(-1, "This question helps determine the CEL table format.\n\nIs this a CAN ROM (2008+)?"); // -1:cancel,0-no,1-ok
		if (ync == -1) {
			Message("Aborting ROM formating at user request\n");
			return 0;
		}
		else if (ync == 1) {
			offset = 2;
		}
		else {
			offset = 1;
		}
		CelSwTable = AskAddr(0,"Make sure the cursor is on the CEL Routine Table Start address then,\nEnter the CEL Switch Table Starting Address:\n");
		if (CelSwTable < 1) {
			Message("Script cancelled by user.\n");
			return;
		}
		combined = 0;
		tableSize = 20;
		tableEnd = 99999999;
	}

	fout = fopen("pcode_def.xml", "w");
	resultArray = CreateArray("RESULTARRAY");
	startFrom = here;
	addrFrom = here;
	pcount = 0;
	celCount = 0;
	endCheck = 1;	// true
	do {
		alpha = 0;
		if (combined) {
			CelSwTable = FormatCombinedTable(addrFrom);
			byteOffset = Byte(addrFrom + 1);
			currentCode = Word(addrFrom + 5);
			pcount = 0;
		}
		else {
			FormatRoutinesTable(addrFrom, CelSwTable, pcount);
			currentCode = Word(addrFrom + 4);
			byteOffset = Byte(addrFrom + offset);
			codeBit = Byte(addrFrom + 1 + offset);
		}
		if (codeBit == 0x01) {
			codeBit = 0;
		}
		else if (codeBit == 0x02) {
			codeBit = 1;
		}
		else if (codeBit == 0x04) {
			codeBit = 2;
		}
		else if (codeBit == 0x08) {
			codeBit = 3;
		}
		else if (codeBit == 0x010) {
			codeBit = 4;
		}
		else if (codeBit == 0x020) {
			codeBit = 5;
		}
		else if (codeBit == 0x040) {
			codeBit = 6;
		}
		else if (codeBit == 0x080) {
			codeBit = 7;
		}

		// Check for P codes with Alphabetical characters in them
		strPcode = form("%04X",currentCode);
		if (substr(strPcode,0,1)  > "9") {alpha = 1;}
		if (substr(strPcode,0,1) == "C") {alpha = 2;}
		if (currentCode == 0xFFFF)		{ endCheck = 0; Message("Found P code of FFFF\n"); }

		pcodeEnabled = CheckEnabled(CelSwTable, currentCode, pcount);
		strPcode = StringOfPcode(currentCode);
		MakeRptCmt(addrFrom + 4 + combined, form("%s - %s %s", pcodeEnabled, strPcode, GetArrayElement(AR_STR, pcArray, currentCode)));
		Message(form("%s, 0x%s, LUT_idx:%02X, byte:%02X, bit:%d, %s %s\n", pcodeEnabled, ltoa(CelSwTable+pcount, 16), celCount, byteOffset, codeBit, strPcode, GetArrayElement(AR_STR, pcArray, currentCode)));
		if (endCheck != 0 && alpha != 1) {
			if (pcodeEnabled == "E") {
				pDesc = GetArrayElement(AR_STR, pcArray, currentCode);
				if (currentCode == 0x0000 && pOOOO == "") {
					pOOOO = form("    <table name=\"(%s) %s\" storageaddress=\"%s\" />\n", strPcode, GetArrayElement(AR_STR, pcArray, 0xFFFE), ltoa(CelSwTable+pcount, 16));
				}
				if (pDesc != "") {
					SetArrayString(resultArray, currentCode,
						form("    <table name=\"(%s) %s\" storageaddress=\"%s\" />\n", strPcode, pDesc, ltoa(CelSwTable+pcount, 16)));
				}
			}
		}
		addrFrom = addrFrom + tableSize;
		celCount = celCount + 1;
		pcount = pcount + 1;
		if (pcount > 280) 						{ endCheck = 0; Message("More than 280 P codes analyzed\n"); }
		if (CelSwTable + pcount == startFrom)	{ endCheck = 0; Message("Overrunning CEL Switch start address\n"); }
		if (addrFrom >= tableEnd)				{ endCheck = 0; Message("Table End address reached\n"); }
	} while (endCheck != 0);
	Message("Finished, " + form("%d", celCount) + " P codes defined.\n");
	currentCode = GetFirstIndex(AR_STR, resultArray);
	Message("Writing pcode_def.xml file in the directory where the ROM file is stored.\n");
	while (currentCode != -1) {
		if (currentCode == 0x0000) {
			writestr(fout, pOOOO);
		}
		writestr(fout, GetArrayElement(AR_STR, resultArray, currentCode));
		currentCode = GetNextIndex(AR_STR, resultArray, currentCode);
	}
	fclose(fout);
	DeleteArray(pcArray);
	DeleteArray(resultArray);
}

static FormatRoutinesTable(addrFrom, CelSwTable, pcount) {
	auto i;
	MakeUnknown(addrFrom, 20, DOUNK_SIMPLE);
	for ( i=0; i < 20; i = i + 1 ) {
		MakeRptCmt(addrFrom + i, "");
	}
	MakeByte(addrFrom);
	MakeByte(addrFrom + 1);	// pre-CAN offset into DTC storage table
	MakeByte(addrFrom + 2);	// pre-CAN DTC bit mask (sets bit for active)
							// CAN offset into DTC storage table
	MakeByte(addrFrom + 3);	// CAN DTC bit mask (sets bit for active)
	MakeWord(addrFrom + 4);	// Diagnostic Trouble Code in this word
	MakeByte(addrFrom + 6);
	MakeByte(addrFrom + 7);
	MakeByte(addrFrom + 8);
	MakeByte(addrFrom + 9);
	MakeByte(addrFrom + 10);
	MakeByte(addrFrom + 11);
	MakeDword(addrFrom + 12);	// Subroutine address
	MakeByte(addrFrom + 16);
	MakeByte(addrFrom + 17);
	MakeByte(addrFrom + 18);
	MakeByte(addrFrom + 19);
	MakeUnknown(CelSwTable + pcount, 1, DOUNK_SIMPLE);
	MakeByte(CelSwTable + pcount);
}

static FormatCombinedTable(addrFrom) {
	auto i;
	MakeUnknown(addrFrom, 12, DOUNK_SIMPLE);
	for ( i=0; i < 12; i = i + 1 ) {
		MakeRptCmt(addrFrom + i, "");
	}
	MakeByte(addrFrom);		// CEL Switch
	MakeByte(addrFrom + 1);	// byte 0-F
	MakeByte(addrFrom + 2);
	MakeByte(addrFrom + 3);
	MakeByte(addrFrom + 4);
	MakeWord(addrFrom + 5);	// Diagnostic Trouble Code in this word
	MakeByte(addrFrom + 7);
	MakeByte(addrFrom + 8);	// byte 0 or 1
	MakeByte(addrFrom + 9);
	MakeByte(addrFrom + 10);
	MakeByte(addrFrom + 11);
	return addrFrom;
}

static CheckEnabled(CelSwTable, currentCode, pcount) {
	auto celEnabled, pcArray, strPcode;
	strPcode = StringOfPcode(currentCode);
	pcArray = GetArrayId("PCODEARRAY");
	CelSwTable = CelSwTable + pcount;
	celEnabled = Byte(CelSwTable);
	if (celEnabled) {
		celEnabled = "E";
		MakeRptCmt(CelSwTable, "");
		if (MakeNameEx(CelSwTable, form("%s_%s",strPcode, GetArrayElement(AR_STR, pcArray, currentCode)), SN_NOWARN)){
		} else {
			MakeNameEx(CelSwTable, form("%s__%s",strPcode, GetArrayElement(AR_STR, pcArray, currentCode)), SN_NOCHECK);
			Message(form("DUPLICATE: %s_%s\n",strPcode, GetArrayElement(AR_STR, pcArray, currentCode)));
		}
	} else {
		celEnabled = "D";
		MakeRptCmt(CelSwTable, form("%s %s", strPcode, GetArrayElement(AR_STR, pcArray, currentCode)));
	}
	return celEnabled;
}

static StringOfPcode(currentCode) {
	auto strPcode;
	strPcode = form("%04X",currentCode);
	if (substr(strPcode,0,1) == "C") {
		strPcode = form("U0%s", substr(strPcode,1,4));
	} else {
		strPcode = form("P%s", strPcode);
	}
	return strPcode;
}

static CreatePcodeArray() {
	auto pcArray;
	pcArray = CreateArray("PCODEARRAY");
	SetArrayString(pcArray, 0x0000, "PASS CODE (NO DTC DETECTED) ");
	SetArrayString(pcArray, 0x0009, "ENGINE POSITION SYSTEM PERFORMANCE BANK 2");
	SetArrayString(pcArray, 0x000A, "A CAMSHAFT POSITION SLOW RESPONSE (BANK 1)");
	SetArrayString(pcArray, 0x000B, "B CAMSHAFT POSITION SLOW RESPONSE (BANK 1)");
	SetArrayString(pcArray, 0x000C, "A CAMSHAFT POSITION SLOW RESPONSE (BANK 2)");
	SetArrayString(pcArray, 0x000D, "B CAMSHAFT POSITION SLOW RESPONSE (BANK 2)");
	SetArrayString(pcArray, 0x0010, "A CAMSHAFT POSITION ACTUATOR CIRCUIT/OPEN (BANK 1)");
	SetArrayString(pcArray, 0x0011, "CAMSHAFT POS. - TIMING OVER-ADVANCED 1");
	SetArrayString(pcArray, 0x0013, "B CAMSHAFT POSITION ACTUATOR CIRCUIT/OPEN (BANK 1)");
	SetArrayString(pcArray, 0x0014, "EXHAUST AVCS SYSTEM 1 RANGE/PERF");
	SetArrayString(pcArray, 0x0016, "CRANKSHAFT/CAMSHAFT CORRELATION 1A");
	SetArrayString(pcArray, 0x0017, "CRANK/CAM TIMING B FAILURE 1");
	SetArrayString(pcArray, 0x0018, "CRANKSHAFT/CAMSHAFT CORRELATION 2A");
	SetArrayString(pcArray, 0x0019, "CRANK/CAM TIMING B FAILURE 2");
	SetArrayString(pcArray, 0x0020, "A CAMSHAFT POSITION ACTUATOR CIRCUIT/OPEN (BANK 2)");
	SetArrayString(pcArray, 0x0021, "CAMSHAFT POS. - TIMING OVER-ADVANCED 2");
	SetArrayString(pcArray, 0x0023, "B CAMSHAFT POSITION ACTUATOR CIRCUIT/OPEN (BANK 2)");
	SetArrayString(pcArray, 0x0024, "EXHAUST AVCS SYSTEM 2 RANGE/PERF");
	SetArrayString(pcArray, 0x0026, "OSV SOLENOID VALVE CIRCUIT RANGE/PERF B1");
	SetArrayString(pcArray, 0x0028, "OSV SOLENOID VALVE CIRCUIT RANGE/PERF B2");
	SetArrayString(pcArray, 0x0030, "FRONT O2 SENSOR RANGE/PERF");
	SetArrayString(pcArray, 0x0031, "FRONT O2 SENSOR LOW INPUT");
	SetArrayString(pcArray, 0x0032, "FRONT O2 SENSOR HIGH INPUT");
	SetArrayString(pcArray, 0x0037, "REAR O2 SENSOR LOW INPUT");
	SetArrayString(pcArray, 0x0038, "REAR O2 SENSOR HIGH INPUT");
	SetArrayString(pcArray, 0x0043, "HO2S CIRCUIT LOW B1 S3");
	SetArrayString(pcArray, 0x0044, "HO2S CIRCUIT HIGH B1 S3");
	SetArrayString(pcArray, 0x0050, "HO2S CIRCUIT RANGE/PERF B2 S1");
	SetArrayString(pcArray, 0x0051, "HO2S CIRCUIT LOW B2 S1");
	SetArrayString(pcArray, 0x0052, "HO2S CIRCUIT HIGH B2 S1");
	SetArrayString(pcArray, 0x0057, "HO2S CIRCUIT LOW B2 S2");
	SetArrayString(pcArray, 0x0058, "HO2S CIRCUIT HIGH B2 S2");
	SetArrayString(pcArray, 0x0068, "MAP SENSOR RANGE/PERF");
	SetArrayString(pcArray, 0x0071, "AMBIENT TEMPERATURE SENSOR CIRCUIT A RANGE/PERF");
	SetArrayString(pcArray, 0x0072, "AMBIENT TEMPERATURE SENSOR CIRCUIT A LOW");
	SetArrayString(pcArray, 0x0073, "AMBIENT TEMPERATURE SENSOR CIRCUIT A HIGH");
	SetArrayString(pcArray, 0x0076, "INTAKE VALVE CIRCUIT LOW (BANK 1)");
	SetArrayString(pcArray, 0x0077, "INTAKE VALVE CONTROL HIGH (BANK 1)");
	SetArrayString(pcArray, 0x0082, "INTAKE VALVE CONTROL LOW (BANK 2)");
	SetArrayString(pcArray, 0x0083, "INTAKE VALVE CONTROL HIGH (BANK 2)");
	SetArrayString(pcArray, 0x0087, "FUEL RAIL/SYSTEM PRESSURE - TOO LOW");
	SetArrayString(pcArray, 0x0088, "FUEL RAIL/SYSTEM PRESSURE - TOO HIGH");
	SetArrayString(pcArray, 0x0091, "FUEL PRESSURE REGULATOR 1 CONTROL LOW");
	SetArrayString(pcArray, 0x0092, "FUEL PRESSURE REGULATOR 1 CONTROL HIGH");
	SetArrayString(pcArray, 0x0096, "IAT SENSOR 2 RANGE/PERF");
	SetArrayString(pcArray, 0x0097, "IAT SENSOR 2 LOW INPUT");
	SetArrayString(pcArray, 0x0098, "IAT SENSOR 2 HIGH INPUT");
	SetArrayString(pcArray, 0x0101, "MAF SENSOR RANGE/PERF");
	SetArrayString(pcArray, 0x0102, "MAF SENSOR LOW INPUT");
	SetArrayString(pcArray, 0x0103, "MAF SENSOR HIGH INPUT");
	SetArrayString(pcArray, 0x0107, "MAP SENSOR LOW INPUT");
	SetArrayString(pcArray, 0x0108, "MAP SENSOR HIGH INPUT");
	SetArrayString(pcArray, 0x0111, "IAT SENSOR RANGE/PERF");
	SetArrayString(pcArray, 0x0112, "IAT SENSOR LOW INPUT");
	SetArrayString(pcArray, 0x0113, "IAT SENSOR HIGH INPUT");
	SetArrayString(pcArray, 0x0116, "COOLANT TEMP SENSOR 1 CIRCUIT RANGE/PERF");
	SetArrayString(pcArray, 0x0117, "COOLANT TEMP SENSOR LOW INPUT");
	SetArrayString(pcArray, 0x0118, "COOLANT TEMP SENSOR HIGH INPUT");
	SetArrayString(pcArray, 0x0121, "TPS RANGE/PERF");
	SetArrayString(pcArray, 0x0122, "TPS A LOW INPUT");
	SetArrayString(pcArray, 0x0123, "TPS A HIGH INPUT");
	SetArrayString(pcArray, 0x0125, "INSUFFICIENT COOLANT TEMP (FUELING)");
	SetArrayString(pcArray, 0x0126, "INSUFFICIENT COOLANT TEMP (OPERATION)");
	SetArrayString(pcArray, 0x0128, "THERMOSTAT MALFUNCTION");
	SetArrayString(pcArray, 0x0129, "ATMOS. PRESSURE SENSOR RANGE/PERF");
	SetArrayString(pcArray, 0x0131, "FRONT O2 SENSOR LOW INPUT");
	SetArrayString(pcArray, 0x0132, "FRONT O2 SENSOR HIGH INPUT");
	SetArrayString(pcArray, 0x0133, "FRONT O2 SENSOR SLOW RESPONSE");
	SetArrayString(pcArray, 0x0134, "FRONT O2 SENSOR NO ACTIVITY");
	SetArrayString(pcArray, 0x0137, "REAR O2 SENSOR LOW VOLTAGE");
	SetArrayString(pcArray, 0x0138, "REAR O2 SENSOR HIGH VOLTAGE");
	SetArrayString(pcArray, 0x0139, "REAR O2 SENSOR SLOW RESPONSE");
	SetArrayString(pcArray, 0x013A, "O2 SENSOR SLOW RESPONSE RICH TO LEAN B1 S2");
	SetArrayString(pcArray, 0x013B, "O2 SENSOR SLOW RESPONSE LEAN TO RICH B1 S2");
	SetArrayString(pcArray, 0x013C, "O2 SENSOR SLOW RESPONSE RICH TO LEAN B2 S2");
	SetArrayString(pcArray, 0x013D, "O2 SENSOR SLOW RESPONSE LEAN TO RICH B2 S2");
	SetArrayString(pcArray, 0x013E, "O2 SENSOR DELAYED RESPONSE RICH TO LEAN B1 S2");
	SetArrayString(pcArray, 0x013F, "O2 SENSOR DELAYED RESPONSE LEAN TO RICH B1 S2");
	SetArrayString(pcArray, 0x0140, "REAR O2 SENSOR NO ACTIVITY");
	SetArrayString(pcArray, 0x0141, "REAR O2 SENSOR MALFUNCTION");
	SetArrayString(pcArray, 0x0143, "O2 SENSOR CIRCUIT LOW B1 S3");
	SetArrayString(pcArray, 0x0144, "O2 SENSOR CIRCUIT HIGH B1 S3");
	SetArrayString(pcArray, 0x0145, "O2 SENSOR CIRCUIT SLOW RESPONSE B1 S3");
	SetArrayString(pcArray, 0x014A, "O2 SENSOR DELAYED RESPONSE RICH TO LEAN B2 S2");
	SetArrayString(pcArray, 0x014B, "O2 SENSOR DELAYED RESPONSE LEAN TO RICH B2 S2");
	SetArrayString(pcArray, 0x014C, "O2 SENSOR SLOW RESPONSE RICH TO LEAN B1 S1");
	SetArrayString(pcArray, 0x014D, "O2 SENSOR SLOW RESPONSE LEAN TO RICH B1 S1");
	SetArrayString(pcArray, 0x014E, "O2 SENSOR SLOW RESPONSE RICH TO LEAN B2 S1");
	SetArrayString(pcArray, 0x014F, "O2 SENSOR SLOW RESPONSE LEAN TO RICH B2 S1");
	SetArrayString(pcArray, 0x0151, "O2 SENSOR CIRCUIT LOW B2 S1");
	SetArrayString(pcArray, 0x0152, "O2 SENSOR CIRCUIT HIGH B2 S1");
	SetArrayString(pcArray, 0x0153, "O2 SENSOR CIRCUIT SLOW RESPONSE B2 S1");
	SetArrayString(pcArray, 0x0154, "O2 SENSOR CIRCUIT OPEN B2 S1");
	SetArrayString(pcArray, 0x0157, "O2 SENSOR CIRCUIT LOW B2 S2");
	SetArrayString(pcArray, 0x0158, "O2 SENSOR CIRCUIT HIGH B2 S2");
	SetArrayString(pcArray, 0x0159, "O2 SENSOR CIRCUIT SLOW RESPONSE B2 S2");
	SetArrayString(pcArray, 0x015A, "O2 SENSOR DELAYED RESPONSE RICH TO LEAN B1 S1");
	SetArrayString(pcArray, 0x015B, "O2 SENSOR DELAYED RESPONSE LEAN TO RICH B1 S1");
	SetArrayString(pcArray, 0x015C, "O2 SENSOR DELAYED RESPONSE RICH TO LEAN B2 S1");
	SetArrayString(pcArray, 0x015D, "O2 SENSOR DELAYED RESPONSE LEAN TO RICH B2 S1");
	SetArrayString(pcArray, 0x0160, "O2 SENSOR NO ACTIVITY B2 S2");
	SetArrayString(pcArray, 0x0161, "O2 SENSOR HEATER CIRCUIT MALFUNCTION B2 S2");
	SetArrayString(pcArray, 0x0171, "SYSTEM TOO LEAN");
	SetArrayString(pcArray, 0x0172, "SYSTEM TOO RICH");
	SetArrayString(pcArray, 0x0174, "SYSTEM TOO LEAN B2");
	SetArrayString(pcArray, 0x0175, "SYSTEM TOO RICH B2");
	SetArrayString(pcArray, 0x0181, "FUEL TEMP SENSOR A RANGE/PERF");
	SetArrayString(pcArray, 0x0182, "FUEL TEMP SENSOR A LOW INPUT");
	SetArrayString(pcArray, 0x0183, "FUEL TEMP SENSOR A HIGH INPUT");
	SetArrayString(pcArray, 0x0191, "FUEL RAIL PRESSURE SENSOR A CIRCUIT RANGE/PERF");
	SetArrayString(pcArray, 0x0192, "FUEL RAIL PRESSURE SENSOR CIRCUIT LOW INPUT");
	SetArrayString(pcArray, 0x0193, "FUEL RAIL PRESSURE SENSOR CIRCUIT HIGH INPUT");
	SetArrayString(pcArray, 0x0196, "OIL TEMP SENSOR RANGE/PERF");
	SetArrayString(pcArray, 0x0197, "OIL TEMP SENSOR LOW");
	SetArrayString(pcArray, 0x0198, "OIL TEMP SENSOR HIGH");
	SetArrayString(pcArray, 0x0201, "INJECTOR CIRCUIT MALFUNCTION CYLINDER 1");
	SetArrayString(pcArray, 0x0202, "INJECTOR CIRCUIT MALFUNCTION CYLINDER 2");
	SetArrayString(pcArray, 0x0203, "INJECTOR CIRCUIT MALFUNCTION CYLINDER 3");
	SetArrayString(pcArray, 0x0204, "INJECTOR CIRCUIT MALFUNCTION CYLINDER 4");
	SetArrayString(pcArray, 0x0205, "INJECTOR CIRCUIT MALFUNCTION CYLINDER 5");
	SetArrayString(pcArray, 0x0206, "INJECTOR CIRCUIT MALFUNCTION CYLINDER 6");
	SetArrayString(pcArray, 0x0222, "TPS B LOW INPUT");
	SetArrayString(pcArray, 0x0223, "TPS B HIGH INPUT");
	SetArrayString(pcArray, 0x0230, "FUEL PUMP PRIMARY CIRCUIT");
	SetArrayString(pcArray, 0x0244, "WASTEGATE SOLENOID A RANGE/PERF");
	SetArrayString(pcArray, 0x0245, "WASTEGATE SOLENOID A LOW");
	SetArrayString(pcArray, 0x0246, "WASTEGATE SOLENOID A HIGH");
	SetArrayString(pcArray, 0x0261, "FUEL INJECTOR #1 CIRCUIT LOW");
	SetArrayString(pcArray, 0x0264, "FUEL INJECTOR #2 CIRCUIT LOW");
	SetArrayString(pcArray, 0x0267, "FUEL INJECTOR #3 CIRCUIT LOW");
	SetArrayString(pcArray, 0x0270, "FUEL INJECTOR #4 CIRCUIT LOW");
	SetArrayString(pcArray, 0x0300, "RANDOM/MULTIPLE CYLINDER MISFIRE DETECTED");
	SetArrayString(pcArray, 0x0301, "MISFIRE CYLINDER 1");
	SetArrayString(pcArray, 0x0302, "MISFIRE CYLINDER 2");
	SetArrayString(pcArray, 0x0303, "MISFIRE CYLINDER 3");
	SetArrayString(pcArray, 0x0304, "MISFIRE CYLINDER 4");
	SetArrayString(pcArray, 0x0305, "MISFIRE CYLINDER 5");
	SetArrayString(pcArray, 0x0306, "MISFIRE CYLINDER 6");
	SetArrayString(pcArray, 0x0327, "KNOCK SENSOR 1 LOW INPUT");
	SetArrayString(pcArray, 0x0328, "KNOCK SENSOR 1 HIGH INPUT");
	SetArrayString(pcArray, 0x0332, "KNOCK SENSOR 2 LOW INPUT");
	SetArrayString(pcArray, 0x0333, "KNOCK SENSOR 2 HIGH INPUT");
	SetArrayString(pcArray, 0x0335, "CRANKSHAFT POS. SENSOR A MALFUNCTION");
	SetArrayString(pcArray, 0x0336, "CRANKSHAFT POS. SENSOR A RANGE/PERF");
	SetArrayString(pcArray, 0x0340, "CAMSHAFT POS. SENSOR A MALFUNCTION");
	SetArrayString(pcArray, 0x0340, "CAMSHAFT POS. SENSOR A MALFUNCTION");
	SetArrayString(pcArray, 0x0341, "CAMSHAFT POS. SENSOR A RANGE/PERF");
	SetArrayString(pcArray, 0x0345, "CAMSHAFT POS. SENSOR A BANK 2");
	SetArrayString(pcArray, 0x0346, "CAMSHAFT POS. SENSOR A CIRCUIT RANGE/PERF BANK 2");
	SetArrayString(pcArray, 0x0350, "IGNITION COIL PRIMARY/SECONDARY");
	SetArrayString(pcArray, 0x0351, "IGNITION COIL A PRIMARY/SECONDARY CIRCUIT MALFUNCTION");
	SetArrayString(pcArray, 0x0352, "IGNITION COIL B PRIMARY/SECONDARY CIRCUIT MALFUNCTION");
	SetArrayString(pcArray, 0x0353, "IGNITION COIL C PRIMARY/SECONDARY CIRCUIT MALFUNCTION");
	SetArrayString(pcArray, 0x0354, "IGNITION COIL D PRIMARY/SECONDARY CIRCUIT MALFUNCTION");
	SetArrayString(pcArray, 0x0355, "IGNITION COIL E PRIMARY/SECONDARY CIRCUIT MALFUNCTION");
	SetArrayString(pcArray, 0x0356, "IGNITION COIL F PRIMARY/SECONDARY CIRCUIT MALFUNCTION");
	SetArrayString(pcArray, 0x0365, "CAMSHAFT POS. SENSOR B BANK 1");
	SetArrayString(pcArray, 0x0366, "CAMSHAFT POS. SENSOR B CIRCUIT RANGE/PERF BANK 1");
	SetArrayString(pcArray, 0x0390, "CAMSHAFT POS. SENSOR B BANK 2");
	SetArrayString(pcArray, 0x0391, "CAMSHAFT POS. SENSOR B CIRCUIT RANGE/PERF BANK 2");
	SetArrayString(pcArray, 0x0400, "EGR FLOW");
	SetArrayString(pcArray, 0x0410, "SECONDARY AIR PUMP SYSTEM");
	SetArrayString(pcArray, 0x0411, "SECONDARY AIR PUMP INCORRECT FLOW");
	SetArrayString(pcArray, 0x0413, "SECONDARY AIR PUMP A OPEN");
	SetArrayString(pcArray, 0x0414, "SECONDARY AIR PUMP A SHORTED");
	SetArrayString(pcArray, 0x0416, "SECONDARY AIR PUMP B OPEN");
	SetArrayString(pcArray, 0x0417, "SECONDARY AIR PUMP B SHORTED");
	SetArrayString(pcArray, 0x0418, "SECONDARY AIR PUMP RELAY A");
	SetArrayString(pcArray, 0x0420, "CAT EFFICIENCY BELOW THRESHOLD");
	SetArrayString(pcArray, 0x0441, "EVAP INCORRECT PURGE FLOW");
	SetArrayString(pcArray, 0x0442, "EVAP LEAK DETECTED (SMALL)");
	SetArrayString(pcArray, 0x0445, "EVAP EMISSION CONTROL SYSTEM PURGE CONTROL VALVE CIRCUIT SHORTED");
	SetArrayString(pcArray, 0x0447, "EVAP VENT CONTROL CIRCUIT OPEN");
	SetArrayString(pcArray, 0x0448, "EVAP VENT CONTROL CIRCUIT SHORTED");
	SetArrayString(pcArray, 0x0451, "EVAP PRESSURE SENSOR RANGE/PERF");
	SetArrayString(pcArray, 0x0452, "EVAP PRESSURE SENSOR LOW INPUT");
	SetArrayString(pcArray, 0x0453, "EVAP PRESSURE SENSOR HIGH INPUT");
	SetArrayString(pcArray, 0x0455, "EVAP EMISSION CONTROL SYSTEM LEAK DETECTED (GROSS LEAK)");
	SetArrayString(pcArray, 0x0456, "EVAP LEAK DETECTED (VERY SMALL)");
	SetArrayString(pcArray, 0x0457, "EVAP LEAK DETECTED (FUEL CAP)");
	SetArrayString(pcArray, 0x0458, "EVAP PURGE VALVE CIRCUIT LOW");
	SetArrayString(pcArray, 0x0459, "EVAP PURGE VALVE CIRCUIT HIGH");
	SetArrayString(pcArray, 0x0461, "FUEL LEVEL SENSOR RANGE/PERF");
	SetArrayString(pcArray, 0x0462, "FUEL LEVEL SENSOR LOW INPUT");
	SetArrayString(pcArray, 0x0463, "FUEL LEVEL SENSOR HIGH INPUT");
	SetArrayString(pcArray, 0x0464, "FUEL LEVEL SENSOR INTERMITTENT");
	SetArrayString(pcArray, 0x0483, "RADIATOR FAN RATIONALITY CHECK");
	SetArrayString(pcArray, 0x04AC, "EVAP SYSTEM PURGE CONTROL VALVE B CIRCUIT LOW");
	SetArrayString(pcArray, 0x04AD, "EVAP SYSTEM PURGE CONTROL VALVE B CIRCUIT HIGH");
	SetArrayString(pcArray, 0x04AF, "EVAP CANISTER PURGE VALVE B - EVAP VALVE STUCK CLOSED");
	SetArrayString(pcArray, 0x04DB, "CRANKCASE VENTILATION SYSTEM DISCONNECTED");
	SetArrayString(pcArray, 0x04F0, "EVAP SYSTEM HIGH PRESSURE PURGE LINE (CPC2) PERF");
	SetArrayString(pcArray, 0x0500, "VEHICLE SPEED SENSOR A");
	SetArrayString(pcArray, 0x0502, "VEHICLE SPEED SENSOR LOW INPUT");
	SetArrayString(pcArray, 0x0503, "VEHICLE SPEED SENSOR INTERMITTENT");
	SetArrayString(pcArray, 0x0504, "BRAKE SWITCH A / B CORRELATION");
	SetArrayString(pcArray, 0x0506, "IDLE CONTROL RPM LOWER THAN EXPECTED");
	SetArrayString(pcArray, 0x0507, "IDLE CONTROL RPM HIGH THAN EXPECTED");
	SetArrayString(pcArray, 0x0508, "IDLE CONTROL CIRCUIT LOW");
	SetArrayString(pcArray, 0x0509, "IDLE CONTROL CIRCUIT HIGH");
	SetArrayString(pcArray, 0x050A, "COLD START IDLE AIR CONTROL SYSTEM PERFORMANCE");
	SetArrayString(pcArray, 0x050B, "COLD START IGNITION TIMING PERFORMANCE");
	SetArrayString(pcArray, 0x050E, "COLD START ENGINE EXHAUST TEMPERATURE OUT OF RANGE");
	SetArrayString(pcArray, 0x0512, "STARTER REQUEST CIRCUIT");
	SetArrayString(pcArray, 0x0516, "BATTERY TEMPERATURE SENSOR CIRCUIT LOW");
	SetArrayString(pcArray, 0x0517, "BATTERY TEMPERATURE SENSOR CIRCUIT HIGH");
	SetArrayString(pcArray, 0x0519, "IDLE CONTROL MALFUNCTION (FAIL-SAFE)");
	SetArrayString(pcArray, 0x0545, "EGT SENSOR CIRCUIT LOW");
	SetArrayString(pcArray, 0x0546, "EGT SENSOR CIRCUIT HIGH");
	SetArrayString(pcArray, 0x0557, "BRAKE BOOSTER PRESSURE SENSOR CIRCUIT LOW");
	SetArrayString(pcArray, 0x0558, "ALTERNATOR CIRCUIT LOW");
	SetArrayString(pcArray, 0x0559, "ALTERNATOR CIRCUIT HIGH");
	SetArrayString(pcArray, 0x0560, "BACKUP POWER SUPPLY");
	SetArrayString(pcArray, 0x0562, "SYSTEM VOLTAGE LOW");
	SetArrayString(pcArray, 0x0563, "SYSTEM VOLTAGE HIGH");
	SetArrayString(pcArray, 0x0565, "CRUISE CONTROL SET SIGNAL");
	SetArrayString(pcArray, 0x0600, "SERIAL COMMUNICATION LINK");
	SetArrayString(pcArray, 0x0602, "CONTROL MODULE PROG. ERROR");
	SetArrayString(pcArray, 0x0604, "CONTROL MODULE RAM ERROR");
	SetArrayString(pcArray, 0x0605, "CONTROL MODULE ROM ERROR");
	SetArrayString(pcArray, 0x0606, "MICRO-COMPUTER (CPU FAILURE)");
	SetArrayString(pcArray, 0x0607, "CONTROL MODULE PERFORMANCE");
	SetArrayString(pcArray, 0x060A, "INTERNAL CONTROL MODULE MONITORING PROCESSOR PERFORMANCE");
	SetArrayString(pcArray, 0x060B, "INTERNAL CONTROL MODULE A/D PROCESSING PERFORMANCE");
	SetArrayString(pcArray, 0x0616, "STARTER RELAY CIRCUIT (LOW)");
	SetArrayString(pcArray, 0x0617, "STARTER RELAY CIRCUIT (HIGH)");
	SetArrayString(pcArray, 0x062D, "NO.1 FUEL INJECTOR DRIVER CIRCUIT PERFORMANCE");
	SetArrayString(pcArray, 0x062F, "EEPROM ERROR");
	SetArrayString(pcArray, 0x0638, "THROTTLE ACTUATOR RANGE/PERF");
	SetArrayString(pcArray, 0x0685, "ENGINE CONTROL MODULE POWER RELAY CONTROL CIRCUIT OPEN");
	SetArrayString(pcArray, 0x0691, "RADIATOR FAN CIRCUIT LOW");
	SetArrayString(pcArray, 0x0692, "RADIATOR FAN CIRCUIT HIGH");
	SetArrayString(pcArray, 0x0700, "TRANSMISSION CONTROL SYSTEM");
	SetArrayString(pcArray, 0x0703, "BRAKE SWITCH INPUT MALFUNCTION");
	SetArrayString(pcArray, 0x0705, "TRANSMISSION RANGE SENSOR MALFUNCTION");
	SetArrayString(pcArray, 0x0710, "ATF TEMP SENSOR MALFUNCTION");
	SetArrayString(pcArray, 0x0716, "TORQUE CONVERTER TURBINE SPEED RANGE/PERF");
	SetArrayString(pcArray, 0x0720, "AT VEHICLE SPEED SENSOR HIGH");
	SetArrayString(pcArray, 0x0726, "ENGINE SPEED INPUT RANGE/PERF");
	SetArrayString(pcArray, 0x0731, "GEAR 1 INCORRECT RATIO");
	SetArrayString(pcArray, 0x0732, "GEAR 2 INCORRECT RATIO");
	SetArrayString(pcArray, 0x0733, "GEAR 3 INCORRECT RATIO");
	SetArrayString(pcArray, 0x0734, "GEAR 4 INCORRECT RATIO");
	SetArrayString(pcArray, 0x0741, "TORQUE CONVERTER CLUTCH MALFUNCTION");
	SetArrayString(pcArray, 0x0743, "TORQUE CONVERTER CLUTCH LOCK-UP DUTY SOLENOID");
	SetArrayString(pcArray, 0x0748, "PRESSURE CONTROL LINE PRESSURE DUTY SOLENOID");
	SetArrayString(pcArray, 0x0753, "SHIFT SOLENOID A ELECTRICAL");
	SetArrayString(pcArray, 0x0758, "SHIFT SOLENOID B ELECTRICAL");
	SetArrayString(pcArray, 0x0771, "AT LOW CLUTCH TIMING SOLENOID MALFUNCTION");
	SetArrayString(pcArray, 0x0778, "AT 2-4 BRAKE PRESSURE SOLENOID MALFUNCTION");
	SetArrayString(pcArray, 0x0785, "AT 2-4 BRAKE TIMING SOLENOID MALFUNCTION");
	SetArrayString(pcArray, 0x081A, "STARTER CUT RELAY SYSTEM CIRCUIT (LOW)");
	SetArrayString(pcArray, 0x0851, "NEUTRAL SWITCH INPUT LOW");
	SetArrayString(pcArray, 0x0852, "NEUTRAL SWITCH INPUT HIGH");
	SetArrayString(pcArray, 0x0864, "TCM COMMUNICATION RANGE/PERF");
	SetArrayString(pcArray, 0x0865, "TCM COMMUNICATION CIRCUIT LOW");
	SetArrayString(pcArray, 0x0866, "TCM COMMUNICATION CIRCUIT HIGH");
	SetArrayString(pcArray, 0x1026, "VVL SYSTEMS 1 PERFORMANCE");
	SetArrayString(pcArray, 0x1028, "VVL SYSTEMS 2 PERFORMANCE");
	SetArrayString(pcArray, 0x1086, "TGV POS. 2 CIRCUIT LOW");
	SetArrayString(pcArray, 0x1087, "TGV POS. 2 CIRCUIT HIGH");
	SetArrayString(pcArray, 0x1088, "TGV POS. 1 CIRCUIT LOW");
	SetArrayString(pcArray, 0x1089, "TGV POS. 1 CIRCUIT HIGH");
	SetArrayString(pcArray, 0x1090, "TGV SYSTEM 1 (VALVE OPEN)");
	SetArrayString(pcArray, 0x1091, "TGV SYSTEM 1 (VALVE CLOSE)");
	SetArrayString(pcArray, 0x1092, "TGV SYSTEM 2 (VALVE OPEN)");
	SetArrayString(pcArray, 0x1093, "TGV SYSTEM 2 (VALVE CLOSE)");
	SetArrayString(pcArray, 0x1094, "TGV SIGNAL 1 (OPEN)");
	SetArrayString(pcArray, 0x1095, "TGV SIGNAL 1 (SHORT)");
	SetArrayString(pcArray, 0x1096, "TGV SIGNAL 2 (OPEN)");
	SetArrayString(pcArray, 0x1097, "TGV SIGNAL 2 (SHORT)");
	SetArrayString(pcArray, 0x1109, "DETECTED THROTTLE DEPOSIT");
	SetArrayString(pcArray, 0x1110, "ATMOS. PRESSURE SENSOR LOW INPUT");
	SetArrayString(pcArray, 0x1111, "ATMOS. PRESSURE SENSOR HIGH INPUT");
	SetArrayString(pcArray, 0x1152, "FRONT O2 SENSOR RANGE/PERF LOW B1 S1");
	SetArrayString(pcArray, 0x1153, "FRONT O2 SENSOR RANGE/PERF HIGH B1 S1");
	SetArrayString(pcArray, 0x1154, "O2 SENSOR RANGE/PERF LOW B2 S1");
	SetArrayString(pcArray, 0x1155, "O2 SENSOR RANGE/PERF HIGH B2 S1");
	SetArrayString(pcArray, 0x1160, "ABNORMAL RETURN SPRING");
	SetArrayString(pcArray, 0x1170, "FUEL SYSTEM ABNORMAL (PORT)");
	SetArrayString(pcArray, 0x117B, "FUEL SYSTEM ABNORMAL (DI)");
	SetArrayString(pcArray, 0x1235, "HIGH-PRESSURE FUEL PUMP ABNORMAL");
	SetArrayString(pcArray, 0x1261, "DI INJECTOR CIRCUIT OPEN (CYLINDER 1)");
	SetArrayString(pcArray, 0x1262, "DI INJECTOR CIRCUIT OPEN (CYLINDER 2)");
	SetArrayString(pcArray, 0x1263, "DI INJECTOR CIRCUIT OPEN (CYLINDER 3)");
	SetArrayString(pcArray, 0x1264, "DI INJECTOR CIRCUIT OPEN (CYLINDER 4)");
	SetArrayString(pcArray, 0x1282, "PCV SYSTEM CIRCUIT (OPEN)");
	SetArrayString(pcArray, 0x1301, "MISFIRE (HIGH TEMP EXHAUST GAS)");
	SetArrayString(pcArray, 0x1312, "EGT SENSOR MALFUNCTION");
	SetArrayString(pcArray, 0x1400, "FUEL TANK PRESSURE SOL. LOW");
	SetArrayString(pcArray, 0x1410, "SECONDARY AIR PUMP VALVE STUCK OPEN");
	SetArrayString(pcArray, 0x1418, "SECONDARY AIR PUMP CIRCUIT SHORTED");
	SetArrayString(pcArray, 0x1420, "FUEL TANK PRESSURE SOL. HIGH INPUT");
	SetArrayString(pcArray, 0x1443, "VENT CONTROL SOLENOID FUNCTION PROBLEM");
	SetArrayString(pcArray, 0x1446, "FUEL TANK SENSOR CONTROL CIRCUIT LOW");
	SetArrayString(pcArray, 0x1447, "FUEL TANK SENSOR CONTROL CIRCUIT HIGH");
	SetArrayString(pcArray, 0x1448, "FUEL TANK SENSOR CONTROL RANGE/PERF");
	SetArrayString(pcArray, 0x1449, "EVAPORATIVE EMISSION CONT. SYS. AIR FILTER CLOG");
	SetArrayString(pcArray, 0x1451, "EVAPORATIVE EMISSION CONT. SYS.");
	SetArrayString(pcArray, 0x1458, "CANISTER PURGE CONTROL SOLENOID VALVE 2 LOW");
	SetArrayString(pcArray, 0x1459, "CANISTER PURGE CONTROL SOLENOID VALVE 2 HIGH");
	SetArrayString(pcArray, 0x145A, "A/C PRESSURE INSUFFICIENT - A/C CLUTCH DISABLED");
	SetArrayString(pcArray, 0x1491, "PCV (BLOWBY) FUNCTION PROBLEM");
	SetArrayString(pcArray, 0x1492, "EGR SOLENOID SIGNAL 1 MALFUNCTION (LOW)");
	SetArrayString(pcArray, 0x1493, "EGR SOLENOID SIGNAL 1 MALFUNCTION (HIGH)");
	SetArrayString(pcArray, 0x1494, "EGR SOLENOID SIGNAL 2 MALFUNCTION (LOW)");
	SetArrayString(pcArray, 0x1495, "EGR SOLENOID SIGNAL 2 MALFUNCTION (HIGH)");
	SetArrayString(pcArray, 0x1496, "EGR SIGNAL 3 CIRCUIT LOW");
	SetArrayString(pcArray, 0x1497, "EGR SOLENOID SIGNAL 3 MALFUNCTION (HIGH)");
	SetArrayString(pcArray, 0x1498, "EGR SIGNAL 4 CIRCUIT LOW");
	SetArrayString(pcArray, 0x1499, "EGR SIGNAL 4 CIRCUIT HIGH");
	SetArrayString(pcArray, 0x1518, "STARTER SWITCH LOW INPUT");
	SetArrayString(pcArray, 0x1519, "IMRC STUCK CLOSED");
	SetArrayString(pcArray, 0x1520, "IMRC CIRCUIT MALFUNCTION");
	SetArrayString(pcArray, 0x1530, "BATTERY CURRENT SENSOR CIRCUIT (LOW)");
	SetArrayString(pcArray, 0x1531, "BATTERY CURRENT SENSOR CIRCUIT (HIGH)");
	SetArrayString(pcArray, 0x1532, "CHARGING CONTROL SYSTEM");
	SetArrayString(pcArray, 0x1544, "EGT TOO HIGH");
	SetArrayString(pcArray, 0x1560, "BACK-UP VOLTAGE MALFUNCTION");
	SetArrayString(pcArray, 0x1602, "CONTROL MODULE PROGRAMMING ERROR");
	SetArrayString(pcArray, 0x1603, "ENGINE STALL HISTORY");
	SetArrayString(pcArray, 0x1604, "STARTABILITY MALFUNCTION");
	SetArrayString(pcArray, 0x1616, "SBDS INTERACTIVE CODES");
	SetArrayString(pcArray, 0x1700, "TPS CIRCUIT MALFUNCTION (AT)");
	SetArrayString(pcArray, 0x2004, "TGV - INTAKE MANIFOLD RUNNER 1 STUCK OPEN");
	SetArrayString(pcArray, 0x2005, "TGV - INTAKE MANIFOLD RUNNER 2 STUCK OPEN");
	SetArrayString(pcArray, 0x2006, "TGV - INTAKE MANIFOLD RUNNER 1 STUCK CLOSED");
	SetArrayString(pcArray, 0x2007, "TGV - INTAKE MANIFOLD RUNNER 2 STUCK CLOSED");
	SetArrayString(pcArray, 0x2008, "TGV - INTAKE MANIFOLD RUNNER 1 CIRCUIT OPEN");
	SetArrayString(pcArray, 0x2009, "TGV - INTAKE MANIFOLD RUNNER 1 CIRCUIT LOW");
	SetArrayString(pcArray, 0x2011, "TGV - INTAKE MANIFOLD RUNNER 2 CIRCUIT OPEN");
	SetArrayString(pcArray, 0x2012, "TGV - INTAKE MANIFOLD RUNNER 2 CIRCUIT LOW");
	SetArrayString(pcArray, 0x2016, "TGV - INTAKE MANIFOLD RUNNER 1 POS. SENSOR LOW");
	SetArrayString(pcArray, 0x2017, "TGV - INTAKE MANIFOLD RUNNER 1 POS. SENSOR HIGH");
	SetArrayString(pcArray, 0x2021, "TGV - INTAKE MANIFOLD RUNNER 2 POS. SENSOR LOW");
	SetArrayString(pcArray, 0x2022, "TGV - INTAKE MANIFOLD RUNNER 2 POS. SENSOR HIGH");
	SetArrayString(pcArray, 0x2088, "OCV SOLENOID A1 CIRCUIT OPEN");
	SetArrayString(pcArray, 0x2089, "OCV SOLENOID A1 CIRCUIT SHORT");
	SetArrayString(pcArray, 0x2090, "OCV SOLENOID B1 CIRCUIT OPEN");
	SetArrayString(pcArray, 0x2091, "OCV SOLENOID B1 CIRCUIT SHORT");
	SetArrayString(pcArray, 0x2092, "OCV SOLENOID A2 CIRCUIT OPEN");
	SetArrayString(pcArray, 0x2093, "OCV SOLENOID A2 CIRCUIT SHORT");
	SetArrayString(pcArray, 0x2094, "OCV SOLENOID B2 CIRCUIT OPEN");
	SetArrayString(pcArray, 0x2095, "OCV SOLENOID B2 CIRCUIT SHORT");
	SetArrayString(pcArray, 0x2096, "POST CATALYST TOO LEAN B1");
	SetArrayString(pcArray, 0x2097, "POST CATALYST TOO RICH B1");
	SetArrayString(pcArray, 0x2098, "POST CATALYST TOO LEAN B2");
	SetArrayString(pcArray, 0x2099, "POST CATALYST TOO RICH B2");
	SetArrayString(pcArray, 0x2101, "THROTTLE ACTUATOR CIRCUIT RANGE/PERF");
	SetArrayString(pcArray, 0x2102, "THROTTLE ACTUATOR CIRCUIT LOW");
	SetArrayString(pcArray, 0x2103, "THROTTLE ACTUATOR CIRCUIT HIGH");
	SetArrayString(pcArray, 0x2109, "TPS A MINIMUM STOP PERF");
	SetArrayString(pcArray, 0x2119, "THROTTLE CONTROL CIRCUIT RANGE/PERF PROBLEM");
	SetArrayString(pcArray, 0x2122, "TPS D CIRCUIT LOW INPUT");
	SetArrayString(pcArray, 0x2123, "TPS D CIRCUIT HIGH INPUT");
	SetArrayString(pcArray, 0x2127, "TPS E CIRCUIT LOW INPUT");
	SetArrayString(pcArray, 0x2128, "TPS E CIRCUIT HIGH INPUT");
	SetArrayString(pcArray, 0x2135, "TPS A/B VOLTAGE");
	SetArrayString(pcArray, 0x2138, "TPS D/E VOLTAGE");
	SetArrayString(pcArray, 0x2158, "VEHICLE SPEED SENSOR B");
	SetArrayString(pcArray, 0x2195, "O2 SENSOR SIGNAL BIASED/STUCK LEAN BANK 1 SENSOR 1");
	SetArrayString(pcArray, 0x2196, "O2 SENSOR SIGNAL BIASED/STUCK RICH BANK 1 SENSOR 1");
	SetArrayString(pcArray, 0x219A, "BANK 1 AFR IMBALANCE");
	SetArrayString(pcArray, 0x219B, "BANK 2 AFR IMBALANCE");
	SetArrayString(pcArray, 0x2227, "BARO. PRESSURE CIRCUIT RANGE/PERF");
	SetArrayString(pcArray, 0x2228, "BARO. PRESSURE CIRCUIT LOW INPUT");
	SetArrayString(pcArray, 0x2229, "BARO. PRESSURE CIRCUIT HIGH INPUT");
	SetArrayString(pcArray, 0x226B, "TURBOCHARGER BOOST PRESSURE TOO HIGH – MECHANICAL");
	SetArrayString(pcArray, 0x2270, "O2 SENSOR SIGNAL BIASED/STUCK LEAN BANK 1 SENSOR 2");
	SetArrayString(pcArray, 0x2271, "O2 SENSOR SIGNAL BIASED/STUCK RICH BANK 1 SENSOR 2");
	SetArrayString(pcArray, 0x2272, "O2 SENSOR SIGNAL BIASED/STUCK LEAN BANK 2 SENSOR 2");
	SetArrayString(pcArray, 0x2273, "O2 SENSOR SIGNAL BIASED/STUCK RICH BANK 2 SENSOR 2");
	SetArrayString(pcArray, 0x2401, "EVAP LEAK DETECTION PUMP CONTROL CIRCUIT LOW");
	SetArrayString(pcArray, 0x2402, "EVAP LEAK DETECTION PUMP CONTROL CIRCUIT HIGH");
	SetArrayString(pcArray, 0x2404, "EVAP LEAK DETECTION PUMP SENSE CIRCUIT RANGE/PERF");
	SetArrayString(pcArray, 0x2419, "EVAP SWITCHING VALVE LOW");
	SetArrayString(pcArray, 0x2420, "EVAP SWITCHING VALVE HIGH");
	SetArrayString(pcArray, 0x2431, "SECONDARY AIR PUMP CIRCUIT RANGE/PERF");
	SetArrayString(pcArray, 0x2432, "SECONDARY AIR PUMP CIRCUIT LOW");
	SetArrayString(pcArray, 0x2433, "SECONDARY AIR PUMP CIRCUIT HIGH");
	SetArrayString(pcArray, 0x2440, "SECONDARY AIR PUMP VALVE 1 STUCK OPEN");
	SetArrayString(pcArray, 0x2441, "SECONDARY AIR PUMP VALVE 1 STUCK CLOSED");
	SetArrayString(pcArray, 0x2442, "SECONDARY AIR PUMP VALVE 2 STUCK OPEN");
	SetArrayString(pcArray, 0x2443, "SECONDARY AIR PUMP 2 STUCK CLOSED");
	SetArrayString(pcArray, 0x2444, "SECONDARY AIR PUMP 1 STUCK ON B1");
	SetArrayString(pcArray, 0x24B9, "EVAP SYSTEM LEAK DETECTION PUMP PRESSURE SENSOR CIRCUIT RANGE/PERF");
	SetArrayString(pcArray, 0x24BA, "EVAP SYSTEM LEAK DETECTION PUMP PRESSURE SENSOR CIRCUIT LOW");
	SetArrayString(pcArray, 0x24BB, "EVAP SYSTEM LEAK DETECTION PUMP PRESSURE SENSOR CIRCUIT HIGH");
	SetArrayString(pcArray, 0x2503, "CHARGING SYSTEM VOLTAGE LOW");
	SetArrayString(pcArray, 0x2504, "CHARGING SYSTEM VOLTAGE HIGH");
	SetArrayString(pcArray, 0x2530, "IGNITION SWITCH RUN POSITION CIRCUIT");
	SetArrayString(pcArray, 0x2257, "AIR SYSTEM CONTROL A CIRCUIT LOW");
	SetArrayString(pcArray, 0x2258, "AIR SYSTEM CONTROL A CIRCUIT HIGH");
	SetArrayString(pcArray, 0x2610, "ECM/PCM INTERNAL ENGINE OFF TIMER PERFORMANCE");
	SetArrayString(pcArray, 0xC073, "CAN COMMUNICATION BUS A OFF");
	SetArrayString(pcArray, 0xC100, "ENGINE DATA NOT RECEIVED");
	SetArrayString(pcArray, 0xC101, "CAN LOST COMMUNICATION WITH TCM");
	SetArrayString(pcArray, 0xC122, "CAN LOST COMMUNICATION WITH VDC");
	SetArrayString(pcArray, 0xC126, "MISSING DATA FOR STEERING ANGLE SENSOR");
	SetArrayString(pcArray, 0xC131, "LOST COMMUNICATION WITH EPS");
	SetArrayString(pcArray, 0xC140, "CAN LOST COMMUNICATION WITH BIU");
	SetArrayString(pcArray, 0xC151, "LOST COMMUNICATION WITH AIR BAG");
	SetArrayString(pcArray, 0xC155, "LOST COMMUNICATION WITH INSTRUMENT PANEL CLUSTER (IPC) CONTROL MODULE");
	SetArrayString(pcArray, 0xC164, "MISSING DATA FOR AIR CONDITIONER");
	SetArrayString(pcArray, 0xC327, "MISSING DATA FOR SMART KEY COMPUTER ASSY");
	SetArrayString(pcArray, 0xC401, "DATA ERROR FROM ENGINE");
	SetArrayString(pcArray, 0xC402, "CAN INVALID DATA RECEIVED FROM TCM");
	SetArrayString(pcArray, 0xC416, "CAN INVALID DATA RECEIVED FROM VDC");
	SetArrayString(pcArray, 0xC422, "CAN INVALID DATA RECEIVED FROM BIU");
	SetArrayString(pcArray, 0xC423, "INVALID DATA RECEIVED FROM INSTRUMENT PANEL CLUSTER CONTROL MODULE");
	SetArrayString(pcArray, 0xC424, "DATA ERROR FROM AIR CONDITIONER");
	SetArrayString(pcArray, 0xC427, "DATA ERROR FROM SMART KEY COMPUTER ASSY");
	SetArrayString(pcArray, 0xC428, "DATA ERROR FROM STEERING ANGLE SENSOR");
	SetArrayString(pcArray, 0xC452, "DATA ERROR FROM AIR BAG");
	SetArrayString(pcArray, 0xFFFE, "PASS CODE (NO DTC DETECTED)");
}
