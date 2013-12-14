/*
* Copyright (C) 2013 Dale C. Schultz
* RomRaider member ID: dschultz
*
* You are free to use this script for any purpose, but please keep
* notice of where it came from!
*
* Version: 1
* Date   : 2013-12-14
*
* This script is used to format tables in a 16bit ROM.
*
Layout of a 2D table:
---------------------
axis values
axis length - 1 (i.e.: 0 based)
type   (this is the byte refereneced in subroutines, i.e.: Table_)
data values
When reading the map:
idxY = table map type byte (function assumes yk=2).
regB (byte) or regD (word) = axis (depending on data type).


Layout of a 3D table:
---------------------
y-axis values
y-axis length - 1 (i.e.: 0 based)
x-axis values
x-axis length - 1 (i.e.: 0 based)
type   (this is the byte refereneced in subroutines, i.e.: Table_)
data values
When reading the map:
idxY = table map type byte 16-bit offset
regB (byte) or regD (word) = x-axis (depending on data type)
regE = y-axis


Layout of a 2D series:
----------------------
axis step
axis start
number of data items - 1 (i.e.: 0 based)
type   (this is the byte refereneced in subroutines, i.e.: Table_)
data values


Layout of a 3D series:
----------------------
y-axis step
y-axis start
x-axis series length - 1 (i.e.: 0 based)
x-axis step
x-axis start
x-axis series length - 1 (i.e.: 0 based)
type   (this is the byte refereneced in subroutines, i.e.: Table_)
data values

Type byte - bit definition:
7--4-2-0
00000000
||||||||- bit 0: 0 = byte, 1 = word (X or single axis data type)
|||||||- 
||||||- bit 2: 0 = byte, 1 = word (Y or dual axis data type)
|||||- 
||||- bit 4: 0 = byte, 1 = word (data values)
|||- 
||- 
|- bit7: 0 = Table, 1 = Series

*/

#include <idc.idc>

static main() {
	auto ync, axisInfo, dim, typeByte, fAxisType, sAxisType, dataType, data, storageType, xStart, xStep, yStart, yStep;
	ync = AskYN(0, "Format as 3D table?"); // -1:cancel,0-no,1-ok
	if (ync == -1) { return 0;}

	axisInfo = GetArrayId("AXIS_INFO");
	DeleteArray(axisInfo);
	axisInfo = CreateArray("AXIS_INFO");
	MakeByte(here);
	typeByte = Byte(here);

	// Determine data type of first axis
	if (typeByte & 0x01)
	{
		fAxisType = 2;
	}
	else
	{
		fAxisType = 1;
	}

	// Determine data type of second axis
	if (typeByte & 0x04)
	{
		sAxisType = 2;
	}
	else
	{
		sAxisType = 1;
	}

	// Determine data type of data elements
	if (typeByte & 0x10)
	{
		dataType = 2;
	}
	else
	{
		dataType = 1;
	}

	// Determine if this is a Table or Series
	if (typeByte & 0x80)
	{
		storageType = 1;
	}
	else
	{
		storageType = 0;
	}

	if (storageType == 0)
	{
		Message(form("Table at ROM:0x%X", here));
		if (GetTrueName(here) == "" ||
			GetTrueName(here) == form("byte_%X", here))
		{
			MakeNameEx(here, form("Table_%X", here), SN_NOWARN);
		}
		SetArrayLong(axisInfo, 0, 0);
		SetArrayLong(axisInfo, 2, 1);
		FormatAxis(here, fAxisType, sAxisType, 1);
		if (ync == 1 )
		{
			FormatAxis(here, fAxisType, sAxisType, 2);
		}
		FormatData(here, dataType);
	}
	else if (storageType == 1)
	{
		Message(form("Series at ROM:0x%X", here));
		if (GetTrueName(here) == "" ||
			GetTrueName(here) == form("byte_%X", here))
		{
			MakeNameEx(here, form("Series_%X", here), SN_NOWARN);
		}
		SetArrayLong(axisInfo, 0, 1);
		SetArrayLong(axisInfo, 2, 1);
		FormatSeries(here, fAxisType, sAxisType, 1);
		if (ync == 1 )
		{
			FormatSeries(here, fAxisType, sAxisType, 2);
		}
		FormatData(here, dataType);
	}
	DeleteArray(axisInfo);
}

static FormatAxis(currAddr, fAxisType, sAxisType, axisCnt)
{
	auto axisInfo, label, axisSize, startAddr, endAddr, axisType, type;
	axisInfo = GetArrayId("AXIS_INFO");
	label = form("Table_%X_axis%d", currAddr, axisCnt);
	if (axisCnt == 1)
	{
		axisSize = Byte(currAddr - 1) + 1;
		MakeByte(currAddr - 1);
		startAddr = currAddr - 1 - (fAxisType * axisSize);
		endAddr = startAddr + (fAxisType * axisSize);
		axisType = fAxisType;
		SetArrayLong(axisInfo, 1, axisSize);
	}
	if (axisCnt == 2)
	{
		axisSize = Byte(currAddr - 1) + 1;
		currAddr = currAddr - 1 - (fAxisType * axisSize);
		axisSize = Byte(currAddr - 1) + 1;
		MakeByte(currAddr - 1);
		startAddr = currAddr - 1 - (sAxisType * axisSize);
		endAddr = startAddr + (sAxisType * axisSize);
		axisType = sAxisType;
		SetArrayLong(axisInfo, 2, axisSize);
	}

	if (axisType == 1)
	{
		type = "uint8";
		for (currAddr = startAddr; currAddr < endAddr; currAddr = currAddr + axisType)
		{
			MakeUnknown(currAddr, axisType, DOUNK_SIMPLE);
			MakeByte(currAddr);
		}
	}
	if (axisType == 2)
	{
		type = "uint16";
		for (currAddr = startAddr; currAddr < endAddr; currAddr = currAddr + axisType)
		{
			MakeUnknown(currAddr, axisType, DOUNK_SIMPLE);
			MakeWord(currAddr);
		}
	}
	if (GetTrueName(startAddr) == "")
	{
		MakeNameEx(startAddr, label, SN_NOWARN);
	}
	Message(form(", axis-%d %s, size: %d at ROM:0x%X", axisCnt, type, axisSize, startAddr));
}

static FormatSeries(currAddr, fAxisType, sAxisType, axisCnt)
{
	auto axisInfo, label, axisSize, startAddr, endAddr, axisType, type;
	axisInfo = GetArrayId("AXIS_INFO");
	label = form("Series_%X_axis%d_step", currAddr, axisCnt);
	if (axisCnt == 1)
	{
		axisSize = Byte(currAddr - 1) + 1;
		MakeByte(currAddr - 1);
		startAddr = currAddr - 1 - (fAxisType * 2);
		endAddr = startAddr + (fAxisType * 2);
		axisType = fAxisType;
		SetArrayLong(axisInfo, 1, axisSize);
	}
	if (axisCnt == 2)
	{
		axisSize = Byte(currAddr - 1) + 1;
		currAddr = currAddr - 1 - (fAxisType * 2);
		axisSize = Byte(currAddr - 1) + 1;
		MakeByte(currAddr - 1);
		startAddr = currAddr - 1 - (sAxisType * 2);
		endAddr = startAddr + (sAxisType * 2);
		axisType = sAxisType;
		SetArrayLong(axisInfo, 2, axisSize);
	}

	if (axisType == 1)
	{
		type = "uint8";
		for (currAddr = startAddr; currAddr < endAddr; currAddr = currAddr + axisType)
		{
			MakeUnknown(currAddr, axisType, DOUNK_SIMPLE);
			MakeByte(currAddr);
		}
	}
	if (axisType == 2)
	{
		type = "uint16";
		for (currAddr = startAddr; currAddr < endAddr; currAddr = currAddr + axisType)
		{
			MakeUnknown(currAddr, axisType, DOUNK_SIMPLE);
			MakeWord(currAddr);
		}
	}
	if (GetTrueName(startAddr) == "")
	{
		MakeNameEx(startAddr, label, SN_NOWARN);
	}
	Message(form(", axis-%d %s, size: %d at ROM:0x%X", axisCnt, type, axisSize, startAddr));
}

static FormatData(currAddr, dataType)
{
	auto axisInfo, format, label, fAxisSize, sAxisSize, startAddr, endAddr, type;
	axisInfo = GetArrayId("AXIS_INFO");
	label = "Table";
	format = GetArrayElement(AR_LONG, axisInfo, 0);
	if (format == 1)
	{
		label = "Series";
	}
	label = form("%s_%X_data", label, currAddr);
	fAxisSize = GetArrayElement(AR_LONG, axisInfo, 1);
	sAxisSize = GetArrayElement(AR_LONG, axisInfo, 2);
	startAddr = currAddr + 1;
	endAddr = startAddr + (fAxisSize * sAxisSize * dataType);

	if (dataType == 1)
	{
		type = "uint8";
		for (currAddr = startAddr; currAddr < endAddr; currAddr = currAddr + dataType)
		{
			MakeUnknown(currAddr, dataType, DOUNK_SIMPLE);
			MakeByte(currAddr);
		}
	}
	if (dataType == 2)
	{
		type = "uint16";
		for (currAddr = startAddr; currAddr < endAddr; currAddr = currAddr + dataType)
		{
			MakeUnknown(currAddr, dataType, DOUNK_SIMPLE);
			MakeWord(currAddr);
		}
	}
	SetArrayFormat(startAddr, 0, fAxisSize, 0);
	if (sAxisSize > 1)
	{
		MakeArray(startAddr, (fAxisSize * sAxisSize * dataType));
	}
	if (GetTrueName(startAddr) == "")
	{
		MakeNameEx(startAddr, label, SN_NOWARN);
	}
	Message(form(", data %s at ROM:0x%X\n", type, startAddr));
}