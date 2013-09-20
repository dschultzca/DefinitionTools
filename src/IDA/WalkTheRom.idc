/*
* Copyright (C) 2013  Dale C. Schultz
* RomRaider member ID: dschultz
*
* You are free to use this script for any purpose, but please keep
* notice of where it came from!
*
* Version: 2
*/

#include <idc.idc>
static main() {
	auto currAddr, currName, fout, textOut, namesArray, xSize, ySize, xSizeAr, ySizeAr, lastAddr;
	namesArray = GetArrayId("myNAMES");
	DeleteArray(namesArray);
	namesArray = CreateArray("myNAMES");
	xSizeAr = GetArrayId("myXSIZE");
	DeleteArray(xSizeAr);
	xSizeAr = CreateArray("myXSIZE");
	ySizeAr = GetArrayId("myYSIZE");
	DeleteArray(ySizeAr);
	ySizeAr = CreateArray("myYSIZE");

	// walk the ROM and list the names and addresses
	currAddr = 0x00000000;
	lastAddr = SegEnd(currAddr);
	while (currAddr < lastAddr) {
		currName = Name(currAddr);
		if (currName != "") {
			if (
			strstr(currName, "dword_") == -1 &&
			strstr(currName, "off_")   == -1 &&
			strstr(currName, "byte_")  == -1 &&
			strstr(currName, "word_")  == -1 &&
			strstr(currName, "flt_")   == -1 &&
			strstr(currName, "loc_")   == -1 &&
			strstr(currName, "unk_")   == -1 &&
			strstr(currName, "sub_")   == -1 &&
			strstr(currName, "_Axis")  == -1) {
				if (strstr(currName, "Table_") == 0) {
					// 1 axis table with no data conversion values, undefined data type
					// Table Definition is 12 bytes long
					if (((Word(currAddr) > 0) && (Word(currAddr) < 256)) &&
						(Word(currAddr+2) == 0x0000)) {
						currAddr = Get2dTable(currAddr, 11);
					}
					// 1 axis table with data conversion values and defined data type
					// Table Definition is 20 bytes long
					if (((Word(currAddr) > 0) && (Word(currAddr) < 256)) &&
						((Word(currAddr+2) == 0x0400) || (Word(currAddr+2) == 0x0800)) &&
						!((Word(currAddr+14) == 0x0400) || (Word(currAddr+14) == 0x0800))) {
						currAddr = Get2dTable(currAddr, 19);
					}
					// 1 axis table with no data conversion values and defined data type
					// Table Definition is 12 bytes long
					if (((Word(currAddr) > 0) && (Word(currAddr) < 256)) &&
						((Word(currAddr+2) == 0x0400) || (Word(currAddr+2) == 0x0800)) &&
						((Word(currAddr+14) == 0x0400) || (Word(currAddr+14) == 0x0800))) {
						currAddr = Get2dTable(currAddr, 11);
					}
					// 2 axis table with no data conversion values, undefined data type
					// Table Definition is 20 bytes long
					if (((Word(currAddr) > 0) && (Word(currAddr) < 256)) &&
						((Word(currAddr+2) > 0) && (Word(currAddr+2) < 256)) &&
						(Dword(currAddr+16) == 0x00000000)) {
						currAddr = Get3dTable(currAddr, 19);
					}
					// 2 axis table with data conversion values and defined data type
					// Table Definition is 28 bytes long
					if (((Word(currAddr) > 0) && (Word(currAddr) < 256)) &&
						((Word(currAddr+2) > 0) && (Word(currAddr+2) < 256)) &&
						((Dword(currAddr+16) == 0x04000000) || (Dword(currAddr+16) == 0x08000000))) {
						currAddr = Get3dTable(currAddr, 27);
					}
				}
				else {
					Message(currName + " " + form("%08s",ltoa(currAddr, 16)) + "\n");
					SetHashLong(namesArray, currName, currAddr);
				}
			}
		}
		currAddr = currAddr + 1;
	}
	fout = fopen("addresses.txt", "w");
	textOut = GetFirstHashKey(namesArray);
	while (textOut != GetLastHashKey(namesArray)) {
		writestr(fout, textOut + " " + form("%08s",ltoa(GetHashLong(namesArray, textOut), 16)));
		xSize = GetHashLong(xSizeAr, textOut);
		if (xSize != 0) {
			writestr(fout, " " + form("%d",ltoa(xSize, 10)));
		}
		ySize = GetHashLong(ySizeAr, textOut);
		if (ySize != 0) {
			writestr(fout, " " + form("%d",ltoa(ySize, 10)));
		}
		writestr(fout, "\n");
		textOut = GetNextHashKey(namesArray, textOut);
	}
	fclose(fout);
	DeleteArray(namesArray);
	DeleteArray(xSizeAr);
	DeleteArray(ySizeAr);
}

static Get2dTable(currAddr, defSize) {
	auto arrayId, axisAddr, axisName, dataAddr, dataLength, dataName, sizeId;
	arrayId = GetArrayId("myNAMES");
	sizeId = GetArrayId("myYSIZE");
	dataLength = Word(currAddr);
	axisAddr = Dword(currAddr+4);
	dataAddr = Dword(currAddr+8);
	dataName = substr(Name(currAddr),6,-1);
	axisName = dataName + "_Y_Axis";
	MakeNameEx(axisAddr, axisName, SN_CHECK);
	MakeNameEx(dataAddr, dataName, SN_CHECK);
	Message(dataName + " " + form("%08s",ltoa(dataAddr, 16)) + " " + form("%d", dataLength,10) + "\n");
	SetHashLong(arrayId, dataName, dataAddr);
	SetHashLong(sizeId, dataName, dataLength);
	Message(axisName + " " + form("%08s",ltoa(axisAddr, 16)) + "\n");
	SetHashLong(arrayId, axisName, axisAddr);
	currAddr = currAddr + defSize;
	return currAddr;
}

static Get3dTable(currAddr, defSize) {
	auto arrayId, axisXAddr, axisXName, axisYAddr, axisYName, dataYLength,  dataXLength, dataAddr, dataName, xSizeId, ySizeId;
	arrayId = GetArrayId("myNAMES");
	xSizeId = GetArrayId("myXSIZE");
	ySizeId = GetArrayId("myYSIZE");
	dataXLength = Word(currAddr);
	dataYLength = Word(currAddr+2);
	axisXAddr = Dword(currAddr+4);
	axisYAddr = Dword(currAddr+8);
	dataAddr = Dword(currAddr+12);
	dataName = substr(Name(currAddr),6,-1);
	axisXName = dataName + "_X_Axis";
	axisYName = dataName + "_Y_Axis";
	MakeNameEx(axisXAddr, axisXName, SN_CHECK);
	MakeNameEx(axisYAddr, axisYName, SN_CHECK);
	MakeNameEx(dataAddr, dataName, SN_CHECK);
	Message(dataName + " " + form("%08s",ltoa(dataAddr, 16)) + " " + form("%d", dataXLength,10) + " " + form("%d", dataYLength,10) + "\n");
	SetHashLong(arrayId, dataName, dataAddr);
	SetHashLong(xSizeId, dataName, dataXLength);
	SetHashLong(ySizeId, dataName, dataYLength);
	Message(axisXName + " " + form("%08s",ltoa(axisXAddr, 16)) + "\n");
	SetHashLong(arrayId, axisXName, axisXAddr);
	Message(axisYName + " " + form("%08s",ltoa(axisYAddr, 16)) + "\n");
	SetHashLong(arrayId, axisYName, axisYAddr);
	currAddr = currAddr + defSize;
	return currAddr;
}
