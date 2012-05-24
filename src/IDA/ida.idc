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
* Copyright (C) 2012  Dale C. Schultz
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
// Format the selected range of addresses or at the cursor position as BYTE
static myMakeByte(void) {
	auto addrFrom, addrTo;
	if ((SelStart() == BADADDR) || (SelEnd() == BADADDR)) {
		addrFrom = here;
		addrTo = addrFrom + 1;
	}
	else {
		addrFrom = SelStart();
		addrTo = SelEnd();
	}
	while (addrFrom < addrTo) {
		MakeUnknown(addrFrom, 1, DOUNK_SIMPLE);
		MakeByte(addrFrom);
		addrFrom = addrFrom+1;
	}
}

//-----------------------------------------------------------------------
// Format the selected range of addresses or at the cursor position as WORD
static myMakeWord(void) {
	auto addrFrom, addrTo;
	if ((SelStart() == BADADDR) || (SelEnd() == BADADDR)) {
		addrFrom = here;
		addrTo = addrFrom + 1;
	}
	else {
		addrFrom = SelStart();
		addrTo = SelEnd();
	}
	while (addrFrom < addrTo) {
		MakeUnknown(addrFrom, 2, DOUNK_SIMPLE);
		MakeWord(addrFrom);
		addrFrom = addrFrom+2;
	}
}
//-----------------------------------------------------------------------
// Format the selected range of addresses or at the cursor position as DOUBLE WORD
static myMakeDword(void) {
	auto addrFrom, addrTo;
	if ((SelStart() == BADADDR) || (SelEnd() == BADADDR)) {
		addrFrom = here;
		addrTo = addrFrom + 1;
	}
	else {
		addrFrom = SelStart();
		addrTo = SelEnd();
	}
	while (addrFrom < addrTo) {
		MakeUnknown(addrFrom, 4, DOUNK_SIMPLE);
		MakeDword(addrFrom);
		addrFrom = addrFrom+4;
	}
}

//-----------------------------------------------------------------------
// Format the selected range of addresses or at the cursor position as FLOAT
static myMakeFloat(void) {
	auto addrFrom, addrTo;
	if ((SelStart() == BADADDR) || (SelEnd() == BADADDR)) {
		addrFrom = here;
		addrTo = addrFrom + 1;
	}
	else {
		addrFrom = SelStart();
		addrTo = SelEnd();
	}
	while (addrFrom < addrTo) {
		MakeUnknown(addrFrom, 4, DOUNK_SIMPLE);
		MakeFloat(addrFrom);
		addrFrom = addrFrom+4;
	}
}
