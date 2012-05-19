/*
* Copyright (C) 2011+  Dale C. Schultz
* RomRaider member ID: dschultz
*
* You are free to use this script for any purpose, but please keep
* notice of where it came from!
*
* Version: 3
*
* To use this script you must locate the bounds of the map table
* definitions in the ROM.  For a 32bit ROM this is in the 0x82000
* to 0x83000 area. Locate the ending of these definitions and copy
* the address. Move the cursor to beginning and start the script.
* Paste in the end address when requested.
* Check for warnings at the end of the script.  A rom_def.xml file
* will be written to the directory where the ROM is located.  This
* file can be used with RomRaider Editor to view the RAW formatted
* tables.
*/
// GetInputFilePath();
#include <idc.idc>
static main() {
	auto currAddr, endAddr, lastAddr, globals, fout, size, maxSize, calIdAddr, calId, ync;
//	calIdAddr = AskAddr(0x2000,"Enter the address where the CAL ID is stored,\n typically 2000 or 2004:");
	calIdAddr = Word(SegEnd(0) - 2);
	calId = GetString(calIdAddr, 8, ASCSTR_C);
	ync = AskYN(1,calId + ", is this the correct CAL ID?"); // -1:cancel,0-no,1-ok
	if (ync == -1) { return 0;}
	if (ync == 0 ) {
		calIdAddr = AskAddr(0x2000,"Enter the address where the CAL ID is stored,\n typically 2000 or 2004:");
		calId = GetString(calIdAddr, 8, ASCSTR_C);
	}
	globals = GetArrayId("myGlobals");
	DeleteArray(globals);
	globals = CreateArray("myGlobals");
	fout = fopen("rom_def.xml", "w");
	SetArrayLong(globals, 0, fout);
	writestr(fout, "<roms>\n<rom>\n <romid>\n   <xmlid>" + calId + "</xmlid>\n   <internalidaddress>" + ltoa(calIdAddr, 16) + "</internalidaddress>\n");
	writestr(fout, "   <internalidstring>" + calId + "</internalidstring>\n   <ecuid>0123456789</ecuid>\n   <year>05</year>\n");
	writestr(fout, "   <market>USDM</market>\n   <make>Subaru</make>\n   <model>CarModel</model>\n   <submodel>2.5</submodel>\n");
	writestr(fout, "   <transmission>MT</transmission>\n   <memmodel>SH7058</memmodel>\n   <flashmethod>sti05</flashmethod>\n");
	writestr(fout, "   <filesize>1024kb</filesize>\n  </romid>\n");
	currAddr = AskAddr(0,"Enter a start address or leave at 0 to use the current cursor position:");
	endAddr = AskAddr(0,"Enter end address:");
//	endAddr = GetMarkedPos(0);

	if (currAddr == 0){
		currAddr = here;
	}
	while (currAddr <= endAddr) {
		// 1 axis table with no data conversion values, undefined data type
		// Table Definition is 12 bytes long with the format:
		// word = axis length
		// word = data storage type
		// dword = axis address
		//dword = data address
		if (((Word(currAddr) > 0) && (Word(currAddr) < 256)) &&
			 (Word(currAddr+2) == 0x0000) &&
			 (((Word(currAddr+12) > 0) && (Word(currAddr+12) < 256)) &&
			 ((Word(currAddr+14) >= 0) && (Word(currAddr+14) < 3073)))) {
			lastAddr = currAddr;
			currAddr = Make2dRawTable(currAddr);
			size = currAddr+1-lastAddr;
//			Message("Table 2D, size:" + form("%d", size) + ", data:raw, ROM:0x" + ltoa(lastAddr, 16) + "\n");
			Message("Table 2D, size:" + form("%d", size) + ", data:raw, ROM:0x" + ltoa(lastAddr, 16) + ", " + GetArrayElement(AR_STR, globals, 1));
			lastAddr = currAddr+1;
		}
		// 1 axis table with data conversion values and defined data type
		// Table Definition is 20 bytes long with the format:
		// word = axis length
		// word = data storage type
		// dword = axis address
		// dword = data address
		// float = data multiplier
		// float = data additive
		if (((Word(currAddr) > 0) && (Word(currAddr) < 256)) &&
			((Word(currAddr+2) == 0x0400) || (Word(currAddr+2) == 0x0800) ||
			 (Word(currAddr+2) == 0x0C00) || (Word(currAddr+2) == 0x1000)) &&
//			!((Word(currAddr+14) == 0x0400) || (Word(currAddr+14) == 0x0800) ||
//			 (Word(currAddr+14) == 0x0C00) || (Word(currAddr+14) == 0x1000)) &&
			 (((Word(currAddr+20) > 0) && (Word(currAddr+20) < 256)) &&
			 ((Word(currAddr+22) >= 0) && (Word(currAddr+22) < 3073)))) {
			lastAddr = currAddr;
			currAddr = Make2dUintTable(currAddr);
			size = currAddr+1-lastAddr;
			Message("Table 2D, size:" + form("%d", size) + ", data:int, ROM:0x" + ltoa(lastAddr, 16) + ", " + GetArrayElement(AR_STR, globals, 1));
			lastAddr = currAddr+1;
		}
		// 1 axis table with no data conversion values and defined data type
		// Table Definition is 12 bytes long with the format:
		// word = axis length
		// word = data storage type
		// dword = axis address
		// dword = data address
		if (((Word(currAddr) > 0) && (Word(currAddr) < 256)) &&
			((Word(currAddr+2) == 0x0400) || (Word(currAddr+2) == 0x0800) ||
			 (Word(currAddr+2) == 0x0C00) || (Word(currAddr+2) == 0x1000)) &&
//			!((Word(currAddr+14) == 0x0400) || (Word(currAddr+14) == 0x0800) ||
//			 (Word(currAddr+14) == 0x0C00) || (Word(currAddr+14) == 0x1000)) &&
			 (((Word(currAddr+12) > 0) && (Word(currAddr+12) < 256)) &&
			 ((Word(currAddr+14) >= 0) && (Word(currAddr+14) < 3073)))) {
			lastAddr = currAddr;
			currAddr = Make2dUintTableNoConv(currAddr);
			size = currAddr+1-lastAddr;
			Message("Table 2D, size:" + form("%d", size) + ", data:int, ROM:0x" + ltoa(lastAddr, 16) + ", " + GetArrayElement(AR_STR, globals, 1));
			lastAddr = currAddr+1;
		}
		// 2 axis table with no data conversion values, undefined data type
		// Table Definition is 20 bytes long with the format:
		// word = X axis length
		// word = Y axis length
		// dword = X axis address
		// dword = Y axis address
		// dword = data address
		// word = data storage type
		if (((Word(currAddr) > 0) && (Word(currAddr) < 256)) &&
			((Word(currAddr+2) > 0) && (Word(currAddr+2) < 256)) &&
			(Dword(currAddr+16) == 0x00000000) &&
			 (((Word(currAddr+20) > 0) && (Word(currAddr+20) < 256)) &&
			 ((Word(currAddr+22) >= 0) && (Word(currAddr+22) < 3073)))) {
			lastAddr = currAddr;
			currAddr = Make3dRawTable(currAddr);
			size = currAddr+1-lastAddr;
//			Message("Table 3D, size:" + form("%d", size) + ", data:raw, ROM:0x" + ltoa(lastAddr, 16) + "\n");
			Message("Table 3D, size:" + form("%d", size) + ", data:raw, ROM:0x" + ltoa(lastAddr, 16) + ", " + GetArrayElement(AR_STR, globals, 1));
			lastAddr = currAddr+1;
		}
		// 2 axis table with data conversion values and defined data type
		// Table Definition is 28 bytes long with the format:
		// word = X axis length
		// word = Y axis length
		// dword = X axis address
		// dword = Y axis address
		// dword = data address
		// word = data storage type
		// float = data multiplier
		// float = data additive
		if (((Word(currAddr) > 0) && (Word(currAddr) < 256)) &&
			((Word(currAddr+2) > 0) && (Word(currAddr+2) < 256)) &&
			((Dword(currAddr+16) == 0x04000000) || (Dword(currAddr+16) == 0x08000000) ||
			 (Dword(currAddr+16) == 0x0C000000) || (Dword(currAddr+16) == 0x10000000)) &&
			 (((Word(currAddr+28) > 0) && (Word(currAddr+28) < 256)) &&
			 ((Word(currAddr+30) >= 0) && (Word(currAddr+30) < 3073)))) {
			lastAddr = currAddr;
			currAddr = Make3dUintTable(currAddr);
			size = currAddr+1-lastAddr;
			Message("Table 3D, size:" + form("%d", size) + ", data:int, ROM:0x" + ltoa(lastAddr, 16) + ", " + GetArrayElement(AR_STR, globals, 1));
			lastAddr = currAddr+1;
		}
		if (size > maxSize) {
			maxSize = size;
		}
		SetArrayString(globals, 1, "\n");
		currAddr = currAddr+1;
	}
	writestr(fout, "</rom>\n</roms>\n");
	fclose(fout);
	DeleteArray(globals);
	if (maxSize > 28) {
		Message("WARNING: Table definitions found that are greater than 28 bytes long. These tables need attention\n");
	}
	else {
		Message("Finished, no warnings\n");
	}
}

static Make2dRawTable(currAddr) {
	auto axisAddr, dataAddr, dataLength, dataType, dataAlign, x, fMin, fMax, fNum, fNumNext;
	fMin = -66000.1;
	fMax =  66000.1;
	MakeUnknown(currAddr, 12, DOUNK_SIMPLE);
	MakeWord(currAddr);			// length
	dataLength = Word(currAddr);
	currAddr = currAddr+2;
	MakeWord(currAddr);			// no data conversion
	currAddr = currAddr+2;
	MakeDword(currAddr);		// axis address
	axisAddr = Dword(currAddr);
	currAddr = currAddr+4;
	MakeDword(currAddr);		// data address
	dataAddr = Dword(currAddr);
	currAddr = currAddr+3;
	FormatTableAxis(axisAddr, dataLength);
	//if (dataLength > 0x4) {
		dataAlign = dataLength % 0x2;
	//}	
	//else {
	//	if (dataLength%0x4 == 0) dataAlign = 0;
		//if (dataLength%0x4 == 1) dataAlign = 3;
		//if (dataLength%0x4 == 2) dataAlign = 2;
		//if (dataLength%0x4 == 3) dataAlign = 1;
	//}
	if (DfirstB((dataAddr + (dataLength + dataAlign))) != BADADDR) {
		dataType = 0x04;
		FormatTableData(dataAddr, dataLength, 1, 0, dataType);
		//Message("uint8 reference for table 0x" + ltoa(dataAddr,16) + " to " + ltoa(DfirstB(dataAddr + (dataLength + dataAlign)),16) + "\n");
	}
	else if (DfirstB(dataAddr + ((dataLength + dataAlign)*2)) != BADADDR) {
		dataType = 0x08;
		FormatTableData(dataAddr, dataLength, 1, 0, dataType);
		//Message("uint16 reference for table 0x" + ltoa(dataAddr,16) + " to " + ltoa(DfirstB(dataAddr + ((dataLength + dataAlign)*2)),16) + "\n");
	}
	else if (DfirstB(dataAddr + (dataLength*4)) != BADADDR) {
		fNum = GetFpNum(dataAddr,4);
		fNumNext = GetFpNum(dataAddr+4,4);
		if ((fNum >= fMin && fNum <= fMax && fNumNext >= fMin && fNumNext <= fMax) || Dword(dataAddr) == 0) {
			dataType = "float";
			FormatTableData(dataAddr, dataLength, 1, 0, dataType);
			//Message("float reference for table 0x" + ltoa(dataAddr,16) + " to " + ltoa(DfirstB(dataAddr + (dataLength*4)),16) + "\n");
		}
		else {
			dataType = "float";
			FormatTableData(dataAddr, dataLength, 1, 0, dataType);
			// Message("dword reference for table 0x" + ltoa(dataAddr,16) + " to " + ltoa(DfirstB(dataAddr + (dataLength*4)),16) + " first data = 0x" + form("%08s",ltoa(Dword(dataAddr),16)) + "\n");
		}	
	}
	Print2dTable(axisAddr, dataAddr, dataLength, dataType, 1, 0);
	return currAddr;
}

static Make2dUintTable(currAddr) {
	auto axisAddr, dataAddr, dataLength, dataType, dataM, dataA;
	MakeUnknown(currAddr, 20, DOUNK_SIMPLE);
	MakeWord(currAddr);			// length
	dataLength = Word(currAddr);
	currAddr = currAddr+2;
	MakeWord(currAddr);			// data type and conversion
	dataType = Byte(currAddr);
	currAddr = currAddr+2;
	MakeDword(currAddr);		// axis address
	axisAddr = Dword(currAddr);
	currAddr = currAddr+4;
	MakeDword(currAddr);		// data addreess
	dataAddr = Dword(currAddr);
	currAddr = currAddr+4;
	MakeFloat(currAddr);		// multiplier
	dataM = GetFpNum(currAddr,4);
	currAddr = currAddr+4;
	MakeFloat(currAddr);		// additive
	dataA = GetFpNum(currAddr,4);
	currAddr = currAddr+3;
	FormatTableAxis(axisAddr, dataLength);
	FormatTableData(dataAddr, dataLength, dataM, dataA, dataType);
	Print2dTable(axisAddr, dataAddr, dataLength, dataType, dataM, dataA);
	return currAddr;
}

static Make2dUintTableNoConv(currAddr) {
	auto axisAddr, dataAddr, dataLength, dataType;
	MakeUnknown(currAddr, 12, DOUNK_SIMPLE);
	MakeWord(currAddr);			// length
	dataLength = Word(currAddr);
	currAddr = currAddr+2;
	MakeWord(currAddr);			// data type and conversion
	dataType = Byte(currAddr);
	currAddr = currAddr+2;
	MakeDword(currAddr);		// axis address
	axisAddr = Dword(currAddr);
	currAddr = currAddr+4;
	MakeDword(currAddr);		// data addreess
	dataAddr = Dword(currAddr);
	currAddr = currAddr+3;
	FormatTableAxis(axisAddr, dataLength);
	FormatTableData(dataAddr, dataLength, 1, 0, dataType);
	Print2dTable(axisAddr, dataAddr, dataLength, dataType, 1, 0);
	return currAddr;
}

static Make3dRawTable(currAddr) {
	auto axisYAddr, dataYLength, axisXAddr, dataXLength, dataAddr, dataLength, dataAlign, dataType, fMin, fMax, fNum, fNumNext;
	fMin = -66000.1;
	fMax =  66000.1;
	MakeUnknown(currAddr, 20, DOUNK_SIMPLE);
	MakeWord(currAddr);			// X length
	dataXLength = Word(currAddr);
	currAddr = currAddr+2;
	MakeWord(currAddr);			// Y Length
	dataYLength = Word(currAddr);
	currAddr = currAddr+2;
	MakeDword(currAddr);		// X axis address
	axisXAddr = Dword(currAddr);
	currAddr = currAddr+4;
	MakeDword(currAddr);		// Y axis address
	axisYAddr = Dword(currAddr);
	currAddr = currAddr+4;
	MakeDword(currAddr);		// data address
	dataAddr = Dword(currAddr);
	currAddr = currAddr+4;
	MakeDword(currAddr);		// no data conversion
	currAddr = currAddr+3;
	FormatTableAxis(axisYAddr, dataYLength);
	FormatTableAxis(axisXAddr, dataXLength);
	dataLength = dataXLength * dataYLength;
	if (dataLength > 0x4) {
		dataAlign = dataLength % 0x2;
	}	
	else {
		if (dataLength%0x4 == 0) dataAlign = 0;
		if (dataLength%0x4 == 1) dataAlign = 3;
		if (dataLength%0x4 == 2) dataAlign = 2;
		if (dataLength%0x4 == 3) dataAlign = 1;
	}
	if (DfirstB((dataAddr + (dataLength + dataAlign))) != BADADDR) {
		dataType = 0x04;
		FormatTableData(dataAddr, dataLength, 1, 0, dataType);
		//Message("uint8 reference for table 0x" + ltoa(dataAddr,16) + " to " + ltoa(DfirstB(dataAddr + (dataLength + dataAlign)),16) + "\n");
	}
	else if (DfirstB(dataAddr + ((dataLength + dataAlign)*2)) != BADADDR) {
		dataType = 0x08;
		FormatTableData(dataAddr, dataLength, 1, 0, dataType);
		//Message("uint16 reference for table 0x" + ltoa(dataAddr,16) + " to " + ltoa(DfirstB(dataAddr + ((dataLength + dataAlign)*2)),16) + "\n");
	}
	else if (DfirstB(dataAddr + (dataLength*4)) != BADADDR) {
		fNum = GetFpNum(dataAddr,4);
		fNumNext = GetFpNum(dataAddr+4,4);
		if ((fNum >= fMin && fNum <= fMax && fNumNext >= fMin && fNumNext <= fMax) || Dword(dataAddr) == 0) {
			dataType = "float";
			FormatTableData(dataAddr, dataLength, 1, 0, dataType);
			//Message("float reference for table 0x" + ltoa(dataAddr,16) + " to " + ltoa(DfirstB(dataAddr + (dataLength*4)),16) + "\n");
		}
		else {
			dataType = "float";
			FormatTableData(dataAddr, dataLength, 1, 0, dataType);
			// Message("dword reference for table 0x" + ltoa(dataAddr,16) + " to " + ltoa(DfirstB(dataAddr + (dataLength*4)),16) + " first data = 0x" + form("%08s",ltoa(Dword(dataAddr),16)) + "\n");
		}	
	}
	Print3dTable(axisYAddr, dataYLength, axisXAddr, dataAddr, dataXLength, dataType, 1, 0);
	return currAddr;
}

static Make3dUintTable(currAddr) {
	auto axisYAddr, dataYLength, axisXAddr, dataAddr, dataXLength, dataType, dataM, dataA;
	MakeUnknown(currAddr, 28, DOUNK_SIMPLE);
	MakeWord(currAddr);			// X length
	dataXLength = Word(currAddr);
	currAddr = currAddr+2;
	MakeWord(currAddr);			// Y Length
	dataYLength = Word(currAddr);
	currAddr = currAddr+2;
	MakeDword(currAddr);		// X axis address
	axisXAddr = Dword(currAddr);
	currAddr = currAddr+4;
	MakeDword(currAddr);		// Y axis address
	axisYAddr = Dword(currAddr);
	currAddr = currAddr+4;
	MakeDword(currAddr);		// data address
	dataAddr = Dword(currAddr);
	currAddr = currAddr+4;
	MakeDword(currAddr);		// data type
	dataType = Byte(currAddr);
	currAddr = currAddr+4;
	MakeFloat(currAddr);		// multiplier
	dataM = GetFpNum(currAddr,4);
	currAddr = currAddr+4;
	MakeFloat(currAddr);		// additive
	dataA = GetFpNum(currAddr,4);
	currAddr = currAddr+3;
	FormatTableAxis(axisYAddr, dataYLength);
	FormatTableAxis(axisXAddr, dataXLength);
	FormatTableData(dataAddr, dataYLength*dataXLength, dataM, dataA, dataType);
	Print3dTable(axisYAddr, dataYLength, axisXAddr, dataAddr, dataXLength, dataType, dataM, dataA);
	return currAddr;
}

static FormatTableAxis(axisAddr, myLength) {
	auto i;
	for ( i=0; i < myLength*4; i=i+4 ) {
		MakeUnknown(axisAddr+i, 4, DOUNK_SIMPLE);
//		if(axisAddr >= 0xC8174 && axisAddr <0xC8198) {
//			Warning("0x"+ltoa(Dword(axisAddr+i),16) + " float:" + form("%1.3f",GetFpNum(axisAddr+i,4)));
//		}
//		if (GetFpNum(axisAddr+i,4) == -1) {
			//Message("Make float failed\n");
//			MakeDword(axisAddr+i);
//		}
//		else {
			MakeFloat(axisAddr+i);
//		}
	}
}

static FormatTableData(dataAddr, dataLength, dataM, dataA, dataType) {
	auto i, x, da, arrayId, msg;
	arrayId = GetArrayId("myGlobals");
	da = dataAddr;
	if ((dataType == 0x04) || (dataType == 0x0C)) {	// byte data size
		x = 1;
		for ( i=0; i < dataLength*x; i=i+x ) {
			MakeUnknown(dataAddr+i, x, DOUNK_SIMPLE);
			MakeByte(dataAddr+i);
			if ((dataType == 0x0C) &&
				 ((Byte(dataAddr+i) & 0x80) == 0x80)) {	// is most sig bit set?
				MakeRptCmt((dataAddr+i), "= " + form("%1.3f",(float((Byte(dataAddr+i)-0x100)) * dataM + dataA)));
			}
			else {
				MakeRptCmt((dataAddr+i), "= " + form("%1.3f",(float(Byte(dataAddr+i)) * dataM + dataA)));
			}
		}
		SetArrayString(arrayId, 1, "formatted  8bit data at 0x" + ltoa(da, 16) + "\n");
	}
	if ((dataType == 0x08) || (dataType == 0x10)) {	// word data size
		x = 2;
		for ( i=0; i < dataLength*x; i=i+x ) {
			MakeUnknown(dataAddr+i, x, DOUNK_SIMPLE);
			MakeWord(dataAddr+i);
			if ((dataType == 0x10) &&
				((Word(dataAddr+i) & 0x8000) == 0x8000)) {	// is most sig bit set?
				MakeRptCmt((dataAddr+i), "= " + form("%1.3f",(float((Word(dataAddr+i)-0x10000)) * dataM + dataA)));
			}
			else {
				MakeRptCmt((dataAddr+i), "= " + form("%1.3f",(float(Word(dataAddr+i)) * dataM + dataA)));
			}
		}
		SetArrayString(arrayId, 1, "formatted 16bit data at 0x" + ltoa(da, 16) + "\n");
	}
	if (dataType == "dword") {
		x = 4;
		for ( i=0; i < dataLength*x; i=i+x ) {
			MakeUnknown(dataAddr+i, x, DOUNK_SIMPLE);
			MakeDword(dataAddr+i);
			MakeRptCmt((dataAddr+i), "= " + form("%1.3f",(float(Dword(dataAddr+i)) * dataM + dataA)));
		}
		SetArrayString(arrayId, 1, "formatted dword data at 0x" + ltoa(da, 16) + "\n");
	}
	if (dataType == "float") {
		x = 4;
		for ( i=0; i < dataLength*x; i=i+x ) {
			MakeUnknown(dataAddr+i, x, DOUNK_SIMPLE);
			MakeFloat(dataAddr+i);
			MakeRptCmt((dataAddr+i), "");
		}
		SetArrayString(arrayId, 1, "formatted float data at 0x" + ltoa(da, 16) + "\n");
	}
}

static Print2dTable(axisAddr, dataAddr, dataLength, dataType, dataM, dataA) {
	auto arrayId, dataStr;
	arrayId = GetArrayId("myGlobals");
	if (dataType == "raw") {
		dataType = "uint8";
		dataStr = "unkn data type";
	}
	if (dataType == "dword") {
		dataType = "int32";
		dataStr = "int32";
	}
	if (dataType == "float") {
		dataStr = dataType;
	}
	if (dataType == 0x04) {
		dataType = "uint8";
		dataStr = dataType;
	}
	if (dataType == 0x08) {
		dataType = "uint16";
		dataStr = dataType;
	}
	if (dataType == 0x0C) {
		dataType = "int8";
		dataStr = dataType;
	}
	if (dataType == 0x10) {
		dataType = "int16";
		dataStr = dataType;
	}
	dataLength = form("%d", dataLength);
	writestr(GetArrayElement(AR_LONG, arrayId, 0), 
		"<table type=\"2D\" name=\"Table at ROM:0x" + ltoa(dataAddr, 16) + " - size " + ltoa(dataLength, 10) + "\" category=\"2D - Tables - " + dataStr + "\" storagetype=\"" + dataType +"\" endian=\"big\" sizey=\"" + dataLength + "\" userlevel=\"4\" logparam=\"unkn\" storageaddress=\"0x" + ltoa(dataAddr, 16) + "\">\n");
	writestr(GetArrayElement(AR_LONG, arrayId, 0), 
		"\t<scaling units=\"Unknown\" expression=\"x*" + form("%1.6f",dataM) + "+" + form("%1.6f",dataA) + "\" to_byte=\"(x-" + form("%1.6f",dataA) + ")/" + form("%1.6f",dataM) + "\" format=\"0.000\" fineincrement=\".01\" coarseincrement=\".1\" />\n");
	writestr(GetArrayElement(AR_LONG, arrayId, 0), 
		"\t<table type=\"Y Axis\" name=\"Axis 0x" + ltoa(axisAddr, 16) + "\" storagetype=\"float\" endian=\"big\" logparam=\"unkn\" storageaddress=\"0x" + ltoa(axisAddr, 16) + "\">\n");
	writestr(GetArrayElement(AR_LONG, arrayId, 0), 
		"\t\t<scaling units=\"Unknown\" expression=\"x\" to_byte=\"x\" format=\"0.00\" fineincrement=\"1\" coarseincrement=\"5\" />\n");
	writestr(GetArrayElement(AR_LONG, arrayId, 0), 
		"\t</table>\n\t<description>no description</description>\n</table>\n");
}

static Print3dTable(axisYAddr, dataYLength, axisXAddr, dataAddr, dataXLength, dataType, dataM, dataA) {
	auto arrayId, dataStr;
	arrayId = GetArrayId("myGlobals");
	if (dataType == "raw") {
		dataType = "uint8";
		dataStr = "unkn data type";
	}
	if (dataType == "dword") {
		dataType = "int32";
		dataStr = "int32";
	}
	if (dataType == "float") {
		dataStr = dataType;
	}
	if (dataType == 0x04) {
		dataType = "uint8";
		dataStr = dataType;
	}
	if (dataType == 0x08) {
		dataType = "uint16";
		dataStr = dataType;
	}
	if (dataType == 0x0C) {
		dataType = "int8";
		dataStr = dataType;
	}
	if (dataType == 0x10) {
		dataType = "int16";
		dataStr = dataType;
	}
	dataYLength = form("%d", dataYLength);
	dataXLength = form("%d", dataXLength);
	writestr(GetArrayElement(AR_LONG, arrayId, 0), 
		"<table type=\"3D\" name=\"Table at ROM:0x" + ltoa(dataAddr, 16) + " - size " + ltoa(dataXLength, 10) + " x " + ltoa(dataYLength, 10) + "\" category=\"3D - Tables - " + dataStr + "\" storagetype=\"" + dataType +"\" endian=\"big\" sizey=\"" + dataYLength + "\" sizex=\"" + dataXLength + "\" userlevel=\"4\" logparam=\"unkn\" storageaddress=\"0x" + ltoa(dataAddr, 16) + "\">\n");
	writestr(GetArrayElement(AR_LONG, arrayId, 0), 
		"\t<scaling units=\"Unknown\" expression=\"x*" + form("%1.6f",dataM) + "+" + form("%1.6f",dataA) + "\" to_byte=\"(x-" + form("%1.6f",dataA) + ")/" + form("%1.6f",dataM) + "\" format=\"0.000\" fineincrement=\".01\" coarseincrement=\".1\" />\n");
	writestr(GetArrayElement(AR_LONG, arrayId, 0), 
		"\t<table type=\"X Axis\" name=\"X Axis 0x" + ltoa(axisXAddr, 16) + "\" storagetype=\"float\" endian=\"big\" logparam=\"unkn\" storageaddress=\"0x" + ltoa(axisXAddr, 16) + "\">\n");
	writestr(GetArrayElement(AR_LONG, arrayId, 0), 
		"\t\t<scaling units=\"Unknown\" expression=\"x\" to_byte=\"x\" format=\"0.00\" fineincrement=\"1\" coarseincrement=\"5\" />\n\t</table>\n");
	writestr(GetArrayElement(AR_LONG, arrayId, 0), 
		"\t<table type=\"Y Axis\" name=\"Y Axis 0x" + ltoa(axisYAddr, 16) + "\" storagetype=\"float\" endian=\"big\" logparam=\"unkn\" storageaddress=\"0x" + ltoa(axisYAddr, 16) + "\">\n");
	writestr(GetArrayElement(AR_LONG, arrayId, 0), 
		"\t\t<scaling units=\"Unknown\" expression=\"x\" to_byte=\"x\" format=\"0.00\" fineincrement=\"1\" coarseincrement=\"5\" />\n");
	writestr(GetArrayElement(AR_LONG, arrayId, 0), 
		"\t</table>\n\t<description>no description</description>\n</table>\n");
}
