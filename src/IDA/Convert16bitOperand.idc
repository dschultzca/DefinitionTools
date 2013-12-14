/*
* Copyright (C) 2013  Dale C. Schultz
* RomRaider member ID: dschultz
*
* You are free to use this script for any purpose, but please keep
* notice of where it came from!
*
* Version: 4
* Date   : 2013-12-09
*
* This script attempts to convert immediate and indirect references to
* offsets if the value is greater than 0x00FF.
* This script REQUIRES that Segments are create prior to its use.
* Use the IDA scipt Format16BitROM.idc to achieve this.  The
* DATA segment to be referenced must have a base paragraph set to the
* offest value >> 8.  i.e.: offset 0x20000, segment base: 0x2000
*
* Offest creation can be started in four ways.
*    1) run the script at the screen cursor position to convert one instruction entry, but beware of item 2)
*    2) place the screen cursor at the beginning of a function to convert the entire function start to end
*    3) select a screen range and convert the selected range
*    4) place the screen cursor at 0x0000 to convert the entire segment, NOT ADVISED
*       NOTE: if you need to remove an offset from an instruction, press Alt-F1 and delete the operand info
*             in the Operand text field and press OK.
*
* If you wish to make this script available via an IDA hotkey you will need to modify your ida.idc script.
* Add the line:   #include <path_to\Convert16bitOperand.idc>
* at the top of the file.
* Then add this line to the main() section of ida.idc
*                 AddHotkey("F4", "Convert16bitOperand");
*
*/

#include <idc.idc>
// uncomment the next line if you are using hotkeys, then comment out the static main() line
//static Convert16bitOperand() {
static main() {
	auto proc, currAddr, endAddr, opType, segReg, op1, op2, newOp1, xAddrStr, xAddr, opTypeStr;
	proc = get_processor_name();
	if (proc != "6816") {
		Message(form("%s processor not supported by Convert16bitOperand() function\n", proc));
		return;
	}
	if (SegByName("RAM") == BADADDR) {
		Warning("This ROM is not segmented properly for use by the Convert16bitOperand() function");
		return;
	}
	currAddr = here;
	if (currAddr == 0x0) {
		currAddr = Word(0x2);
		endAddr = SegEnd(currAddr);
	}
	else if (GetFunctionAttr(currAddr, FUNCATTR_START) == currAddr) {
		endAddr = GetFunctionAttr(currAddr, FUNCATTR_END);
	}
	else if ((SelStart() == BADADDR) || (SelEnd() == BADADDR)) {
		currAddr = here;
		endAddr = currAddr + 1;
	}
	else {
		currAddr = SelStart();
		endAddr = SelEnd();
	}
	// walk the selected range and convert referecnes
	while (currAddr < endAddr) {
		opType = GetOpType(currAddr, 0);
		opTypeStr = "";
		if ((opType == o_displ) || (opType == o_imm)) {
			op2 = "";
			segReg = -1;
			op1 = GetOpnd(currAddr, 0);
			if (strstr(op1, "X") != BADADDR) {
				op2 = "X";
				segReg = GetReg(currAddr,"XK");
			}
			if (strstr(op1, "Y") != BADADDR) {
				op2 = "Y";
				segReg = GetReg(currAddr,"YK");
			}
			if (strstr(op1, "Z") != BADADDR) {
				op2 = "Z";
				segReg = GetReg(currAddr,"ZK");
			}
			if (strstr(GetMnem(currAddr), "ldx") != BADADDR) {
				op2 = "X";
				segReg = GetReg(currAddr,"XK");
			}
			if (strstr(GetMnem(currAddr), "ldy") != BADADDR) {
				op2 = "Y";
				segReg = GetReg(currAddr,"YK");
			}
			if (strstr(GetMnem(currAddr), "ldz") != BADADDR) {
				op2 = "Z";
				segReg = GetReg(currAddr,"ZK");
			}
			if (op2 != "" && segReg != BADADDR) {
				if (opType == o_displ) {
					OpAlt(currAddr, 0, "");
					OpOff(MK_FP("ROM", currAddr), 0, segReg << 16);
					opTypeStr = "register";
				}
				if (opType == o_imm && (GetOperandValue(currAddr, 0) > 0x00FF)) {
					OpAlt(currAddr, 0, "");
					OpOffEx(MK_FP("ROM", currAddr), 0, REF_OFF32, -1, segReg << 16, 0);
					opTypeStr = "immediate";
				}
				newOp1 = GetOpnd(currAddr, 0);
				xAddrStr = substr(newOp1 , 0, strstr(newOp1, ","));
				xAddr = LocByName(xAddrStr);
				add_dref(currAddr, xAddr, dr_I);
				Message(form("At %s converting %s reference using I%s with base 0x%X, referencing location %s\n", atoa(currAddr), opTypeStr, op2, segReg << 16, xAddrStr));
			}
		}
		currAddr = currAddr + 2;
	}
}

