//
//      This file is automatically executed when IDA is started.
//      You can define your own IDC functions and assign hotkeys to them.
//
//      You may add your frequently used functions here and they will
//      be always available.
//
//
#include <idc.idc>

static main(void) {

//
//      This function is executed when IDA is started.

AddHotkey("Ctrl-Alt-B", "myMakeByte");
AddHotkey("Ctrl-Alt-W", "myMakeWord");
AddHotkey("Ctrl-Alt-D", "myMakeDword");
AddHotkey("Ctrl-Alt-F", "myMakeFloat");
}

/*
 * Copyright (C) 2010+  Dale C. Schultz
 * RomRaider member ID: dschultz
 *
 * You are free to use this script and the finctions:
 * myMakeByte
 * myMakeWord
 * myMakeDword
 * myMakeFloat
 * for any purpose, but please keep
 * notice of where it came from!
 *
 */
//-----------------------------------------------------------------------
// Format the range of addresses from the cursor to the address entered as BYTE
static myMakeByte(void) {
	auto addrFrom, addrTo;
	addrTo = AskAddr(0,"Make BYTE:\nPlace cursor on the start address, then Enter the end address:");
	addrFrom = here;
	while (addrFrom < addrTo) {
		MakeUnknown(addrFrom, 1, DOUNK_SIMPLE);
		MakeByte(addrFrom);
		addrFrom = addrFrom+1;
	}
}

//-----------------------------------------------------------------------
// Format the range of addresses from the cursor to the address entered as WORD
static myMakeWord(void) {
	auto addrFrom, addrTo;
	addrTo = AskAddr(0,"Make WORD:\nPlace cursor on the start address, then Enter the end address:");
	addrFrom = here;
	while (addrFrom < addrTo) {
		MakeUnknown(addrFrom, 2, DOUNK_SIMPLE);
		MakeWord(addrFrom);
		addrFrom = addrFrom+2;
	}
}
//-----------------------------------------------------------------------
// Format the range of addresses from the cursor to the address entered as DOUBLE WORD
static myMakeDword(void) {
	auto addrFrom, addrTo;
	addrTo = AskAddr(0,"Make DWORD:\nPlace cursor on the start address, then Enter the end address:");
	addrFrom = here;
	while (addrFrom < addrTo) {
		MakeUnknown(addrFrom, 4, DOUNK_SIMPLE);
		MakeDword(addrFrom);
		addrFrom = addrFrom+4;
	}
}

//-----------------------------------------------------------------------
// Format the range of addresses from the cursor to the address entered as FLOAT
static myMakeFloat(void) {
	auto addrFrom, addrTo;
	addrTo = AskAddr(0,"Make FLOAT:\nPlace cursor on the start address, then Enter the end address:");
	addrFrom = here;
	while (addrFrom < addrTo) {
		MakeUnknown(addrFrom, 4, DOUNK_SIMPLE);
		MakeFloat(addrFrom);
		addrFrom = addrFrom+4;
	}
}
