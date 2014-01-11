/*
* Copyright (C) 2014 Dale C. Schultz
* RomRaider member ID: dschultz
*
* You are free to use this script for any purpose, but please keep
* notice of where it came from!
*
* Version: 2
* Date   : 2014-01-11
*
* This script is used to format and name the SH705x Vector Table.
* To use the script place the cursor at the Vector Table base address.
* Typically SH7055  this is at 0x0007FC50
* Typically SH7058  this is at 0x000FFC50
* Typically SH72531 this is at 0x0013F600
*
*/

#include <idc.idc>

static main() {
	auto vnArray, PC, SP, currAddr, ync, vbAddr, i, a, procName, subName;
	ync = AskYN(-1, "Format, mark and name the Vector Table?"); // -1:cancel,0-no,1-ok
	if (ync != 1) {
		Message("Aborting ROM formating at user request\n");
		return 0;
	}

	vnArray = GetArrayId("VNARRAY");
	DeleteArray(vnArray);
	procName = GetProcessorName();
	if (procName == "SH4B") {
		CreateVectorNameArraySH4B();
		Message("Formating for SH4B processor\n");
	}
	else if (procName == "SH2A") {
		CreateVectorNameArraySH2A();
		Message("Formating for SH2A processor\n");
	}
	else {
		Message(form("Unknown processor: %s, format cancelled\n", procName));
		return 0;
	}
	vnArray = GetArrayId("VNARRAY");

	vbAddr = here;
	MakeName(here, "VectorAddr_Base");
	for (i = GetFirstIndex(AR_STR, vnArray); i != BADADDR; i = GetNextIndex(AR_STR, vnArray, i)) {
		currAddr = vbAddr + (4 * i);
		a = GetArrayElement(AR_STR, vnArray, i);
		MakeUnknown(currAddr, 4, DOUNK_SIMPLE);
		MakeDword(currAddr);
		subName = substr(GetTrueName(currAddr), 0, 3);
		if (subName == "sub" || subName == "loc" || subName == "") MakeName(currAddr, form("Ptr_%s",a));
		MakeUnknown(Dword(currAddr), 4, DOUNK_SIMPLE);
		MakeFunction(Dword(currAddr), BADADDR);
		subName = substr(GetTrueName(Dword(currAddr)), 0, 3);
		if (subName == "sub" || subName == "loc" || subName == "") MakeName(Dword(currAddr), a);
	}
	MakeDword(0x0);
	PC = Dword(0x0);
	MakeRptCmt(0x0, form("PwrOn RESET Initial PC = 0x%X", PC));
	MakeName(0x0, "PwrOn_RESET");
	MakeName(PC, "IntrRESET");
	MakeDword(0x4);
	SP = Dword(0x4);
	MakeRptCmt(0x4, form("PwrOn RESET Initial SP = 0x%X", SP));
	MakeName(0x4, "Initial_SP");
	MakeDword(SP);
	MakeName(SP, "STACKBASE");
	if (procName == "SH4B") {
		PC = Dword(0x8);
		MakeDword(0x8);
		MakeRptCmt(0x8, form("Manual RESET Initial PC = 0x%X", PC));
		MakeName(0x8, "Manual_RESET");
		MakeDword(0xC);
		SP = Dword(0xC);
		MakeRptCmt(0xC, form("Manual RESET Initial SP = 0x%X", SP));
		MakeFunction(PC, BADADDR);
		for (i = 0x10; i < 0x40; i = i + 4) {
			MakeUnknown(i, 4, DOUNK_SIMPLE);
			MakeDword(i);
		}
	}
	else if (procName == "SH2A") {
		for (i = 0x08; i < 0x60; i = i + 4) {
			MakeUnknown(i, 4, DOUNK_SIMPLE);
			MakeDword(i);
		}
	}
}

static GetProcessorName(void) {
	auto i, name, chr;

	name = "";
	for (i = 0; i < 8; i++) {
		chr = GetCharPrm(INF_PROCNAME + i);
		if (chr == 0) break;
		name = name + chr;
	}
	return name;
}

static CreateVectorNameArraySH4B() {
	auto vnArray;
	vnArray = CreateArray("VNARRAY");
	SetArrayString(vnArray, 0, "IntrPwrOn_RESET");
	SetArrayString(vnArray, 4, "Intr_Gnrl_Illegal_Inst");
	SetArrayString(vnArray, 5, "Intr_Reserved0");
	SetArrayString(vnArray, 6, "Intr_Slot_llegal_Inst");
	SetArrayString(vnArray, 7, "Intr_Reserved1");
	SetArrayString(vnArray, 8, "Intr_Reserved2");
	SetArrayString(vnArray, 9, "Intr_CPU");
	SetArrayString(vnArray, 10, "Intr_DMAC");
	SetArrayString(vnArray, 11, "Intr_NMI_Priority16");
	SetArrayString(vnArray, 12, "Intr_UBC_Priority15");
	SetArrayString(vnArray, 14, "Intr_HUDI_Priority15");
	SetArrayString(vnArray, 64, "Intr_IRQ0_IPRA_b15_12");
	SetArrayString(vnArray, 65, "Intr_IRQ1_IPRA_b11_8");
	SetArrayString(vnArray, 66, "Intr_IRQ2_IPRA_b7_4");
	SetArrayString(vnArray, 67, "Intr_IRQ3_IPRA_b3_0");
	SetArrayString(vnArray, 68, "Intr_IRQ4_IPRB_b15_12");
	SetArrayString(vnArray, 69, "Intr_IRQ5_IPRB_b11_8");
	SetArrayString(vnArray, 70, "Intr_IRQ6_IPRB_b7_4");
	SetArrayString(vnArray, 71, "Intr_IRQ7_IPRB_b3_0");
	SetArrayString(vnArray, 72, "Intr_DMAC0_DEI0_IPRC_b15_12_p1");
	SetArrayString(vnArray, 74, "Intr_DMAC1_DEI1_IPRC_b15_12_p2");
	SetArrayString(vnArray, 76, "Intr_DMAC2_DEI2_IPRC_b11_8_p1");
	SetArrayString(vnArray, 78, "Intr_DMAC3_DEI3_IPRC_b11_8_p2");
	SetArrayString(vnArray, 80, "Intr_ATU01_ITV1_IPRC_b7_4");
	SetArrayString(vnArray, 81, "Intr_ATU01_ITV2A_IPRC_b7_4");
	SetArrayString(vnArray, 82, "Intr_ATU01_ITV2B_IPRC_b7_4");
	SetArrayString(vnArray, 84, "Intr_ATU02_ICI0A_IPRC_b3_0_p1");
	SetArrayString(vnArray, 86, "Intr_ATU02_ICI0B_IPRC_b3_0_p2");
	SetArrayString(vnArray, 88, "Intr_ATU03_ICI0C_IPRD_b15_12_p1");
	SetArrayString(vnArray, 90, "Intr_ATU03_ICI0D_IPRD_b15_12_p2");
	SetArrayString(vnArray, 92, "Intr_ATU04_OVI0_IPRD_b11_8");
	SetArrayString(vnArray, 96, "Intr_ATU11_IMI1A_CMI1_IPRD_b7_4_p1");
	SetArrayString(vnArray, 97, "Intr_ATU11_IMI1B_IPRD_b7_4_p2");
	SetArrayString(vnArray, 98, "Intr_ATU11_IMI1C_IPRD_b7_4_p3");
	SetArrayString(vnArray, 99, "Intr_ATU11_IMI1D_IPRD_b7_4_p4");
	SetArrayString(vnArray, 100, "Intr_ATU12_IMI1E_IPRD_b3_0_p1");
	SetArrayString(vnArray, 101, "Intr_ATU12_IMI1F_IPRD_b3_0_p2");
	SetArrayString(vnArray, 102, "Intr_ATU12_IMI1G_IPRD_b3_0_p3");
	SetArrayString(vnArray, 103, "Intr_ATU12_IMI1H_IPRD_b3_0_p4");
	SetArrayString(vnArray, 104, "Intr_ATU13_OVI1A_OVI1B_IPRE_b15_12");
	SetArrayString(vnArray, 108, "Intr_ATU21_IMI2A_CMI2A_IPRE_b11_8_p1");
	SetArrayString(vnArray, 109, "Intr_ATU21_IMI2B_CMI2B_IPRE_b11_8_p2");
	SetArrayString(vnArray, 110, "Intr_ATU21_IMI2C_CMI2C_IPRE_b11_8_p3");
	SetArrayString(vnArray, 111, "Intr_ATU21_IMI2D_CMI2D_IPRE_b11_8_p4");
	SetArrayString(vnArray, 112, "Intr_ATU22_IMI2E_CMI2E_IPRE_b7_4_p1");
	SetArrayString(vnArray, 113, "Intr_ATU22_IMI2F_CMI2F_IPRE_b7_4_p2");
	SetArrayString(vnArray, 114, "Intr_ATU22_IMI2G_CMI2G_IPRE_b7_4_p3");
	SetArrayString(vnArray, 115, "Intr_ATU22_IMI2H_CMI2H_IPRE_b7_4_p4");
	SetArrayString(vnArray, 116, "Intr_ATU23_OVI2A_OVI2B_IPRE_b3_0");
	SetArrayString(vnArray, 120, "Intr_ATU31_IMI3A_IPRF_b15_12_p1");
	SetArrayString(vnArray, 121, "Intr_ATU31_IMI3B_IPRF_b15_12_p2");
	SetArrayString(vnArray, 122, "Intr_ATU31_IMI3C_IPRF_b15_12_p3");
	SetArrayString(vnArray, 123, "Intr_ATU31_IMI3D_IPRF_b15_12_p4");
	SetArrayString(vnArray, 124, "Intr_ATU32_OVI3_IPRF_b11_8");
	SetArrayString(vnArray, 128, "Intr_ATU41_IMI4A_IPRF_b7_4_p1");
	SetArrayString(vnArray, 129, "Intr_ATU41_IMI4B_IPRF_b7_4_p2");
	SetArrayString(vnArray, 130, "Intr_ATU41_IMI4C_IPRF_b7_4_p3");
	SetArrayString(vnArray, 131, "Intr_ATU41_IMI4D_IPRF_b7_4_p4");
	SetArrayString(vnArray, 132, "Intr_ATU42_OVI4_IPRF_b3_0");
	SetArrayString(vnArray, 136, "Intr_ATU51_IMI5A_IPRG_b15_12_p1");
	SetArrayString(vnArray, 137, "Intr_ATU51_IMI5B_IPRG_b15_12_p2");
	SetArrayString(vnArray, 138, "Intr_ATU51_IMI5C_IPRG_b15_12_p3");
	SetArrayString(vnArray, 139, "Intr_ATU51_IMI5D_IPRG_b15_12_p4");
	SetArrayString(vnArray, 140, "Intr_ATU52_OVI5_IPRG_b11_8");
	SetArrayString(vnArray, 144, "Intr_ATU6_CMI6A_IPRG_b7_4_p1");
	SetArrayString(vnArray, 145, "Intr_ATU6_CMI6B_IPRG_b7_4_p2");
	SetArrayString(vnArray, 146, "Intr_ATU6_CMI6C_IPRG_b7_4_p3");
	SetArrayString(vnArray, 147, "Intr_ATU6_CMI6D_IPRG_b7_4_p4");
	SetArrayString(vnArray, 148, "Intr_ATU7_CMI7A_IPRG_b3_0_p1");
	SetArrayString(vnArray, 149, "Intr_ATU7_CMI7B_IPRG_b3_0_p2");
	SetArrayString(vnArray, 150, "Intr_ATU7_CMI7C_IPRG_b3_0_p3");
	SetArrayString(vnArray, 151, "Intr_ATU7_CMI7D_IPRG_b3_0_p4");
	SetArrayString(vnArray, 152, "Intr_ATU81_OSI8A_IPRH_b15_12_p1");
	SetArrayString(vnArray, 153, "Intr_ATU81_OSI8B_IPRH_b15_12_p2");
	SetArrayString(vnArray, 154, "Intr_ATU81_OSI8C_IPRH_b15_12_p3");
	SetArrayString(vnArray, 155, "Intr_ATU81_OSI8D_IPRH_b15_12_p4");
	SetArrayString(vnArray, 156, "Intr_ATU82_OSI8E_IPRH_b11_8_p1");
	SetArrayString(vnArray, 157, "Intr_ATU82_OSI8F_IPRH_b11_8_p2");
	SetArrayString(vnArray, 158, "Intr_ATU82_OSI8G_IPRH_b11_8_p3");
	SetArrayString(vnArray, 159, "Intr_ATU82_OSI8H_IPRH_b11_8_p4");
	SetArrayString(vnArray, 160, "Intr_ATU83_OSI8I_IPRH_b7_4_p1");
	SetArrayString(vnArray, 161, "Intr_ATU83_OSI8J_IPRH_b7_4_p2");
	SetArrayString(vnArray, 162, "Intr_ATU83_OSI8K_IPRH_b7_4_p3");
	SetArrayString(vnArray, 163, "Intr_ATU83_OSI8L_IPRH_b7_4_p4");
	SetArrayString(vnArray, 164, "Intr_ATU84_OSI8M_IPRH_b3_0_p1");
	SetArrayString(vnArray, 165, "Intr_ATU84_OSI8N_IPRH_b3_0_p2");
	SetArrayString(vnArray, 166, "Intr_ATU84_OSI8O_IPRH_b3_0_p3");
	SetArrayString(vnArray, 167, "Intr_ATU84_OSI8P_IPRH_b3_0_p4");
	SetArrayString(vnArray, 168, "Intr_ATU91_CMI9A_IPRI_b15_12_p1");
	SetArrayString(vnArray, 169, "Intr_ATU91_CMI9B_IPRI_b15_12_p2");
	SetArrayString(vnArray, 170, "Intr_ATU91_CMI9C_IPRI_b15_12_p3");
	SetArrayString(vnArray, 171, "Intr_ATU91_CMI9D_IPRI_b15_12_p4");
	SetArrayString(vnArray, 172, "Intr_ATU92_CMI9E_IPRI_b11_8_p1");
	SetArrayString(vnArray, 174, "Intr_ATU92_CMI9F_IPRI_b11_8_p2");
	SetArrayString(vnArray, 176, "Intr_ATU101_CMI10A_IPRI_b7_4_p1");
	SetArrayString(vnArray, 178, "Intr_ATU101_CMI10B_IPRI_b7_4_p2");
	SetArrayString(vnArray, 180, "Intr_ATU102_ICI10A_CMI10G_IPRI_b3_0");
	SetArrayString(vnArray, 184, "Intr_ATU11_IMI11A_IPRJ_b15_12_p1");
	SetArrayString(vnArray, 186, "Intr_ATU11_IMI11B_IPRJ_b15_12_p2");
	SetArrayString(vnArray, 187, "Intr_ATU11_OVI11_IPRJ_b15_12_p3");
	SetArrayString(vnArray, 188, "Intr_CMT0_CMTI0_IPRJ_b11_8_p1");
	SetArrayString(vnArray, 189, "Intr_MTAD0_ADT0_IPRJ_b11_8_p2");
	SetArrayString(vnArray, 190, "Intr_AD0_ADI0_IPRJ_b11_8_p3");
	SetArrayString(vnArray, 192, "Intr_CMT1_CMTI1_IPRJ_b7_4_p1");
	SetArrayString(vnArray, 193, "Intr_MTAD1_ADT1_IPRJ_b7_4_p2");
	SetArrayString(vnArray, 194, "Intr_AD1_ADI1_IPRJ_b7_4_p3");
	SetArrayString(vnArray, 196, "Intr_AD2_ADI2_IPRJ_b3_0");
	SetArrayString(vnArray, 200, "Intr_SCI0_ERI0_IPRK_b15_12_p1");
	SetArrayString(vnArray, 201, "Intr_SCI0_RXI0_IPRK_b15_12_p2");
	SetArrayString(vnArray, 202, "Intr_SCI0_TXI0_IPRK_b15_12_p3");
	SetArrayString(vnArray, 203, "Intr_SCI0_TEI0_IPRK_b15_12_p4");
	SetArrayString(vnArray, 204, "Intr_SCI1_ERI1_IPRK_b11_8_p1");
	SetArrayString(vnArray, 205, "Intr_SCI1_RXI1_IPRK_b11_8_p2");
	SetArrayString(vnArray, 206, "Intr_SCI1_TXI1_IPRK_b11_8_p3");
	SetArrayString(vnArray, 207, "Intr_SCI1_TEI1_IPRK_b11_8_p4");
	SetArrayString(vnArray, 208, "Intr_SCI2_ERI2_IPRK_b7_4_p1");
	SetArrayString(vnArray, 209, "Intr_SCI2_RXI2_IPRK_b7_4_p2");
	SetArrayString(vnArray, 210, "Intr_SCI2_TXI2_IPRK_b7_4_p3");
	SetArrayString(vnArray, 211, "Intr_SCI2_TEI2_IPRK_b7_4_p4");
	SetArrayString(vnArray, 212, "Intr_SCI3_ERI3_IPRK_b3_0_p1");
	SetArrayString(vnArray, 213, "Intr_SCI3_RXI3_IPRK_b3_0_p2");
	SetArrayString(vnArray, 214, "Intr_SCI3_TXI3_IPRK_b3_0_p3");
	SetArrayString(vnArray, 215, "Intr_SCI3_TEI3_IPRK_b3_0_p4");
	SetArrayString(vnArray, 216, "Intr_SCI4_ERI4_IPRL_b15_12_p1");
	SetArrayString(vnArray, 217, "Intr_SCI4_RXI4_IPRL_b15_12_p2");
	SetArrayString(vnArray, 218, "Intr_SCI4_TXI4_IPRL_b15_12_p3");
	SetArrayString(vnArray, 219, "Intr_SCI4_TEI4_IPRL_b15_12_p4");
	SetArrayString(vnArray, 220, "Intr_HCAN0_ERS0_IPRL_b11_8_p1");
	SetArrayString(vnArray, 221, "Intr_HCAN0_OVR0_IPRL_b11_8_p2");
	SetArrayString(vnArray, 222, "Intr_HCAN0_RM0_IPRL_b11_8_p3");
	SetArrayString(vnArray, 223, "Intr_HCAN0_SLE0_IPRL_b11_8_p4");
	SetArrayString(vnArray, 224, "Intr_WDT_ITI_IPRL_b7_4");
	SetArrayString(vnArray, 228, "Intr_HCAN1_ERS1_IPRL_b3_0_p1");
	SetArrayString(vnArray, 229, "Intr_HCAN1_OVR1_IPRL_b3_0_p2");
	SetArrayString(vnArray, 230, "Intr_HCAN1_RM1_IPRL_b3_0_p3");
	SetArrayString(vnArray, 231, "Intr_HCAN1_SLE1_IPRL_b3_0_p4");
}

static CreateVectorNameArraySH2A() {
	auto vnArray;
	vnArray = CreateArray("VNARRAY");
	SetArrayString(vnArray, 0, "IntrPwrOn_RESET");
	SetArrayString(vnArray, 2, "Intr_Reserved2");
	SetArrayString(vnArray, 3, "Intr_Reserved3");
	SetArrayString(vnArray, 4, "Intr_Gnrl_Illegal_Inst");
	SetArrayString(vnArray, 5, "Intr_Reserved5");
	SetArrayString(vnArray, 6, "Intr_Slot_llegal_Inst");
	SetArrayString(vnArray, 7, "Intr_Reserved7");
	SetArrayString(vnArray, 8, "Intr_Reserved8");
	SetArrayString(vnArray, 9, "Intr_Address_Error");
	SetArrayString(vnArray, 10, "Intr_DMAC_Error");
	SetArrayString(vnArray, 11, "Intr_NMI");
	SetArrayString(vnArray, 12, "Intr_UBC");
	SetArrayString(vnArray, 13, "Intr_FPU_exception");
	SetArrayString(vnArray, 14, "Intr_Reserved14");
	SetArrayString(vnArray, 15, "Intr_Bank_overflow");
	SetArrayString(vnArray, 16, "Intr_Bank_underflow");
	SetArrayString(vnArray, 17, "Intr_Integer_Division_by_zero");
	SetArrayString(vnArray, 18, "Intr_Integer_Division_overflow");
	SetArrayString(vnArray, 19, "Intr_Reserved19");
	SetArrayString(vnArray, 20, "Intr_Reserved20");
	SetArrayString(vnArray, 21, "Intr_Reserved21");
	SetArrayString(vnArray, 22, "Intr_Reserved22");
	SetArrayString(vnArray, 23, "Intr_Reserved23");
	SetArrayString(vnArray, 24, "Intr_Reserved24");
	SetArrayString(vnArray, 25, "Intr_Reserved25");
	SetArrayString(vnArray, 26, "Intr_Reserved26");
	SetArrayString(vnArray, 27, "Intr_Reserved27");
	SetArrayString(vnArray, 28, "Intr_Reserved28");
	SetArrayString(vnArray, 29, "Intr_Reserved29");
	SetArrayString(vnArray, 30, "Intr_Reserved30");
	SetArrayString(vnArray, 31, "Intr_Reserved31");
	SetArrayString(vnArray, 32, "Intr_Trap_instruction_uv32");
	SetArrayString(vnArray, 33, "Intr_Trap_instruction_uv33");
	SetArrayString(vnArray, 34, "Intr_Trap_instruction_uv34");
	SetArrayString(vnArray, 35, "Intr_Trap_instruction_uv35");
	SetArrayString(vnArray, 36, "Intr_Trap_instruction_uv36");
	SetArrayString(vnArray, 37, "Intr_Trap_instruction_uv37");
	SetArrayString(vnArray, 38, "Intr_Trap_instruction_uv38");
	SetArrayString(vnArray, 39, "Intr_Trap_instruction_uv39");
	SetArrayString(vnArray, 40, "Intr_Trap_instruction_uv40");
	SetArrayString(vnArray, 41, "Intr_Trap_instruction_uv41");
	SetArrayString(vnArray, 42, "Intr_Trap_instruction_uv42");
	SetArrayString(vnArray, 43, "Intr_Trap_instruction_uv43");
	SetArrayString(vnArray, 44, "Intr_Trap_instruction_uv44");
	SetArrayString(vnArray, 45, "Intr_Trap_instruction_uv45");
	SetArrayString(vnArray, 46, "Intr_Trap_instruction_uv46");
	SetArrayString(vnArray, 47, "Intr_Trap_instruction_uv47");
	SetArrayString(vnArray, 48, "Intr_Trap_instruction_uv48");
	SetArrayString(vnArray, 49, "Intr_Trap_instruction_uv49");
	SetArrayString(vnArray, 50, "Intr_Trap_instruction_uv50");
	SetArrayString(vnArray, 51, "Intr_Trap_instruction_uv51");
	SetArrayString(vnArray, 52, "Intr_Trap_instruction_uv52");
	SetArrayString(vnArray, 53, "Intr_Trap_instruction_uv53");
	SetArrayString(vnArray, 54, "Intr_Trap_instruction_uv54");
	SetArrayString(vnArray, 55, "Intr_Trap_instruction_uv55");
	SetArrayString(vnArray, 56, "Intr_Trap_instruction_uv56");
	SetArrayString(vnArray, 57, "Intr_Trap_instruction_uv57");
	SetArrayString(vnArray, 58, "Intr_Trap_instruction_uv58");
	SetArrayString(vnArray, 59, "Intr_Trap_instruction_uv59");
	SetArrayString(vnArray, 60, "Intr_Trap_instruction_uv60");
	SetArrayString(vnArray, 61, "Intr_Trap_instruction_uv61");
	SetArrayString(vnArray, 62, "Intr_Trap_instruction_uv62");
	SetArrayString(vnArray, 63, "Intr_Trap_instruction_uv63");
	SetArrayString(vnArray, 64, "Intr_IRQ0_IPR01_b15_12");
	SetArrayString(vnArray, 65, "Intr_IRQ1_IPR01_b11_8");
	SetArrayString(vnArray, 66, "Intr_IRQ2_IPR01_b7_4");
	SetArrayString(vnArray, 67, "Intr_IRQ3_IPR01_b3_0");
	SetArrayString(vnArray, 79, "Intr_RAME");
	SetArrayString(vnArray, 82, "Intr_FIFE");
	SetArrayString(vnArray, 93, "Intr_SINT15");
	SetArrayString(vnArray, 94, "Intr_SINT14");
	SetArrayString(vnArray, 95, "Intr_SINT13");
	SetArrayString(vnArray, 96, "Intr_SINT12");
	SetArrayString(vnArray, 97, "Intr_SINT11");
	SetArrayString(vnArray, 98, "Intr_SINT10");
	SetArrayString(vnArray, 99, "Intr_SINT9");
	SetArrayString(vnArray, 100, "Intr_SINT8");
	SetArrayString(vnArray, 101, "Intr_SINT7");
	SetArrayString(vnArray, 102, "Intr_SINT6");
	SetArrayString(vnArray, 105, "Intr_SINT3");
	SetArrayString(vnArray, 106, "Intr_SINT2");
	SetArrayString(vnArray, 107, "Intr_SINT1");
	SetArrayString(vnArray, 108, "Intr_DMAC0_DEI0_IPR03_b15_12_p1");
	SetArrayString(vnArray, 109, "Intr_DMAC0_HEI0_p2");
	SetArrayString(vnArray, 112, "Intr_DMAC1_DEI1_IPR03_b11_8_p1");
	SetArrayString(vnArray, 113, "Intr_DMAC1_HEI1_p2");
	SetArrayString(vnArray, 116, "Intr_DMAC2_DEI2_IPR03_b7_4_p1");
	SetArrayString(vnArray, 117, "Intr_DMAC2_HEI2_p2");
	SetArrayString(vnArray, 120, "Intr_DMAC3_DEI3_IPR03_b3_0_p1");
	SetArrayString(vnArray, 121, "Intr_DMAC3_HEI3_p2");
	SetArrayString(vnArray, 124, "Intr_DMAC4_DEI4_IPR04_b15_12_p1");
	SetArrayString(vnArray, 125, "Intr_DMAC4_HEI4_p2");
	SetArrayString(vnArray, 128, "Intr_DMAC5_DEI5_IPR04_b11_8_p1");
	SetArrayString(vnArray, 129, "Intr_DMAC5_HEI5_p2");
	SetArrayString(vnArray, 132, "Intr_DMAC6_DEI6_IPR04_b7_4_p1");
	SetArrayString(vnArray, 133, "Intr_DMAC6_HEI6_p2");
	SetArrayString(vnArray, 136, "Intr_DMAC7_DEI7_IPR04_b3_0_p1");
	SetArrayString(vnArray, 137, "Intr_DMAC7_HEI7_p2");
	SetArrayString(vnArray, 140, "Intr_CMI0_IPR05_b15_12");
	SetArrayString(vnArray, 144, "Intr_CMI1_IPR05_b11_8");
	SetArrayString(vnArray, 148, "Intr_ITI_IPR05_b3_0");
	SetArrayString(vnArray, 152, "Intr_ICIA0_IPR06_b15_12_p1");
	SetArrayString(vnArray, 153, "Intr_ICIA1_p2");
	SetArrayString(vnArray, 156, "Intr_ICIA2_IPR06_b11_8_p1");
	SetArrayString(vnArray, 157, "Intr_ICIA3_p2");
	SetArrayString(vnArray, 164, "Intr_OVIA_IPR06_b3_0_p");
	SetArrayString(vnArray, 168, "Intr_CMIB0_IPR07_b15_12_p1");
	SetArrayString(vnArray, 169, "Intr_CMIB1_p2");
	SetArrayString(vnArray, 172, "Intr_CMIB6_IPR07_b11_8_p1");
	SetArrayString(vnArray, 173, "Intr_ICIB0_p2");
	SetArrayString(vnArray, 176, "Intr_ATU_C0_IMIC00_IPR07_b7_4_p1");
	SetArrayString(vnArray, 177, "Intr_ATU_C0_IMIC01_p2");
	SetArrayString(vnArray, 178, "Intr_ATU_C0_IMIC02_p3");
	SetArrayString(vnArray, 179, "Intr_ATU_C0_IMIC03_p4");
	SetArrayString(vnArray, 180, "Intr_ATU_C0_OVIC0_IPR07_b3_0");
	SetArrayString(vnArray, 184, "Intr_ATU_C1_IMIC10_IPR08_b15_12_p1");
	SetArrayString(vnArray, 185, "Intr_ATU_C1_IMIC11_p2");
	SetArrayString(vnArray, 186, "Intr_ATU_C1_IMIC12_p3");
	SetArrayString(vnArray, 187, "Intr_ATU_C1_IMIC13_p4");
	SetArrayString(vnArray, 188, "Intr_ATU_C1_OVIC1_IPR08_b11_8");
	SetArrayString(vnArray, 192, "Intr_ATU_C2_IMIC20_IPR08_b7_4_p1");
	SetArrayString(vnArray, 193, "Intr_ATU_C2_IMIC21_p2");
	SetArrayString(vnArray, 194, "Intr_ATU_C2_IMIC22_p3");
	SetArrayString(vnArray, 195, "Intr_ATU_C2_IMIC23_p4");
	SetArrayString(vnArray, 196, "Intr_ATU_C2_OVIC2_IPR08_b3_0");
	SetArrayString(vnArray, 200, "Intr_ATU_C3_IMIC30_IPR09_b15_12_p1");
	SetArrayString(vnArray, 201, "Intr_ATU_C3_IMIC31_p2");
	SetArrayString(vnArray, 202, "Intr_ATU_C3_IMIC32_p3");
	SetArrayString(vnArray, 203, "Intr_ATU_C3_IMIC33_p4");
	SetArrayString(vnArray, 204, "Intr_ATU_C3_OVIC3_IPR09_b11_8");
	SetArrayString(vnArray, 208, "Intr_ATU_C4_IMIC40_IPR09_b7_4_p1");
	SetArrayString(vnArray, 209, "Intr_ATU_C4_IMIC41_p2");
	SetArrayString(vnArray, 210, "Intr_ATU_C4_IMIC42_p3");
	SetArrayString(vnArray, 211, "Intr_ATU_C4_IMIC43_p4");
	SetArrayString(vnArray, 212, "Intr_ATU_C4_OVIC4_IPR09_b3_0");
	SetArrayString(vnArray, 216, "Intr_ATU_D0_CMID00_IPR10_b15_12_p1");
	SetArrayString(vnArray, 217, "Intr_ATU_D0_CMID01_p2");
	SetArrayString(vnArray, 218, "Intr_ATU_D0_CMID02_p3");
	SetArrayString(vnArray, 219, "Intr_ATU_D0_CMID03_p4");
	SetArrayString(vnArray, 220, "Intr_ATU_D0_OVI1D0_IPR10_b11_8_p1");
	SetArrayString(vnArray, 221, "Intr_ATU_D0_OVI2D0_p2");
	SetArrayString(vnArray, 224, "Intr_ATU_D0_UDID00_IPR10_b7_4_p1");
	SetArrayString(vnArray, 225, "Intr_ATU_D0_UDID01_p2");
	SetArrayString(vnArray, 226, "Intr_ATU_D0_UDID02_p3");
	SetArrayString(vnArray, 227, "Intr_ATU_D0_UDID03_p4");
	SetArrayString(vnArray, 228, "Intr_ATU_D1_CMID10_IPR10_b3_0_p1");
	SetArrayString(vnArray, 229, "Intr_ATU_D1_CMID11_p2");
	SetArrayString(vnArray, 230, "Intr_ATU_D1_CMID12_p3");
	SetArrayString(vnArray, 231, "Intr_ATU_D1_CMID13_p4");
	SetArrayString(vnArray, 232, "Intr_ATU_D1_OVI1D1_IPR11_b15_12_p1");
	SetArrayString(vnArray, 233, "Intr_ATU_D1_OVI2D1_p2");
	SetArrayString(vnArray, 236, "Intr_ATU_D1_UDID10_IPR11_b11_8_p1");
	SetArrayString(vnArray, 237, "Intr_ATU_D1_UDID11_p2");
	SetArrayString(vnArray, 238, "Intr_ATU_D1_UDID12_p3");
	SetArrayString(vnArray, 239, "Intr_ATU_D1_UDID13_p4");
	SetArrayString(vnArray, 240, "Intr_ATU_D2_CMID20_IPR11_b7_4_p1");
	SetArrayString(vnArray, 241, "Intr_ATU_D2_CMID21_p2");
	SetArrayString(vnArray, 242, "Intr_ATU_D2_CMID22_p3");
	SetArrayString(vnArray, 243, "Intr_ATU_D2_CMID23_p4");
	SetArrayString(vnArray, 244, "Intr_ATU_D2_OVI1D2_IPR11_b3_0_p1");
	SetArrayString(vnArray, 245, "Intr_ATU_D2_OVI2D2_p2");
	SetArrayString(vnArray, 248, "Intr_ATU_D2_UDID20_IPR12_b15_12_p1");
	SetArrayString(vnArray, 249, "Intr_ATU_D2_UDID21_p2");
	SetArrayString(vnArray, 250, "Intr_ATU_D2_UDID22_p3");
	SetArrayString(vnArray, 251, "Intr_ATU_D2_UDID23_p4");
	SetArrayString(vnArray, 252, "Intr_ATU_D3_CMID30_IPR12_b11_8_p1");
	SetArrayString(vnArray, 253, "Intr_ATU_D3_CMID31_p2");
	SetArrayString(vnArray, 254, "Intr_ATU_D3_CMID32_p3");
	SetArrayString(vnArray, 255, "Intr_ATU_D3_CMID33_p4");
	SetArrayString(vnArray, 256, "Intr_ATU_D3_OVI1D3_IPR12_b7_4_p1");
	SetArrayString(vnArray, 257, "Intr_ATU_D3_OVI2D3_p2");
	SetArrayString(vnArray, 260, "Intr_ATU_D3_UDID30_IPR12_b3_0_p1");
	SetArrayString(vnArray, 261, "Intr_ATU_D3_UDID31_p2");
	SetArrayString(vnArray, 262, "Intr_ATU_D3_UDID32_p3");
	SetArrayString(vnArray, 263, "Intr_ATU_D3_UDID33_p4");
	SetArrayString(vnArray, 288, "Intr_ATU_E0_CMIE00_IPR14_b7_4_p1");
	SetArrayString(vnArray, 289, "Intr_ATU_E0_CMIE01_p2");
	SetArrayString(vnArray, 290, "Intr_ATU_E0_CMIE02_p3");
	SetArrayString(vnArray, 291, "Intr_ATU_E0_CMIE03_p4");
	SetArrayString(vnArray, 292, "Intr_ATU_E1_CMIE10_IPR14_b3_0_p1");
	SetArrayString(vnArray, 293, "Intr_ATU_E1_CMIE11_p2");
	SetArrayString(vnArray, 294, "Intr_ATU_E1_CMIE12_p3");
	SetArrayString(vnArray, 295, "Intr_ATU_E1_CMIE13_p4");
	SetArrayString(vnArray, 296, "Intr_ATU_E2_CMIE20_IPR15_b15_12_p1");
	SetArrayString(vnArray, 297, "Intr_ATU_E2_CMIE21_p2");
	SetArrayString(vnArray, 298, "Intr_ATU_E2_CMIE22_p3");
	SetArrayString(vnArray, 299, "Intr_ATU_E2_CMIE23_p4");
	SetArrayString(vnArray, 300, "Intr_ATU_E3_CMIE30_IPR15_b11_8_p1");
	SetArrayString(vnArray, 301, "Intr_ATU_E3_CMIE31_p2");
	SetArrayString(vnArray, 302, "Intr_ATU_E3_CMIE32_p3");
	SetArrayString(vnArray, 303, "Intr_ATU_E3_CMIE33_p4");
	SetArrayString(vnArray, 304, "Intr_ATU_E4_CMIE40_IPR15_b7_4_p1");
	SetArrayString(vnArray, 305, "Intr_ATU_E4_CMIE41_p2");
	SetArrayString(vnArray, 306, "Intr_ATU_E4_CMIE42_p3");
	SetArrayString(vnArray, 307, "Intr_ATU_E4_CMIE43_p4");
	SetArrayString(vnArray, 312, "Intr_ATU_F_ICIF0_IPR16_b15_12_p1");
	SetArrayString(vnArray, 313, "Intr_ATU_F_ICIF1_p2");
	SetArrayString(vnArray, 314, "Intr_ATU_F_ICIF2_p3");
	SetArrayString(vnArray, 315, "Intr_ATU_F_ICIF3_p4");
	SetArrayString(vnArray, 316, "Intr_ATU_F_ICIF4_IPR16_b11_8_p1");
	SetArrayString(vnArray, 317, "Intr_ATU_F_ICIF5_p2");
	SetArrayString(vnArray, 318, "Intr_ATU_F_ICIF6_p3");
	SetArrayString(vnArray, 319, "Intr_ATU_F_ICIF7_p4");
	SetArrayString(vnArray, 320, "Intr_ATU_F_ICIF8_IPR16_b7_4_p1");
	SetArrayString(vnArray, 321, "Intr_ATU_F_ICIF9_p2");
	SetArrayString(vnArray, 322, "Intr_ATU_F_ICIF10_p3");
	SetArrayString(vnArray, 323, "Intr_ATU_F_ICIF11_p4");
	SetArrayString(vnArray, 324, "Intr_ATU_F_ICIF12_IPR16_b3_0_p1");
	SetArrayString(vnArray, 325, "Intr_ATU_F_ICIF13_p2");
	SetArrayString(vnArray, 326, "Intr_ATU_F_ICIF14_p3");
	SetArrayString(vnArray, 327, "Intr_ATU_F_ICIF15_p4");
	SetArrayString(vnArray, 328, "Intr_ATU_F_ICIF16_IPR17_b15_12_p1");
	SetArrayString(vnArray, 329, "Intr_ATU_F_ICIF17_p2");
	SetArrayString(vnArray, 330, "Intr_ATU_F_ICIF18_p3");
	SetArrayString(vnArray, 331, "Intr_ATU_F_ICIF19_p4");
	SetArrayString(vnArray, 340, "Intr_ATU_F_OVIF0_IPR18_b15_12_p1");
	SetArrayString(vnArray, 341, "Intr_ATU_F_OVIF1_p2");
	SetArrayString(vnArray, 342, "Intr_ATU_F_OVIF2_p3");
	SetArrayString(vnArray, 343, "Intr_ATU_F_OVIF3_p4");
	SetArrayString(vnArray, 344, "Intr_ATU_F_OVIF4_IPR18_b11_8_p1");
	SetArrayString(vnArray, 345, "Intr_ATU_F_OVIF5_p2");
	SetArrayString(vnArray, 346, "Intr_ATU_F_OVIF6_p3");
	SetArrayString(vnArray, 347, "Intr_ATU_F_OVIF7_p4");
	SetArrayString(vnArray, 348, "Intr_ATU_F_OVIF8_IPR18_b7_4_p1");
	SetArrayString(vnArray, 349, "Intr_ATU_F_OVIF9_p2");
	SetArrayString(vnArray, 350, "Intr_ATU_F_OVIF10_p3");
	SetArrayString(vnArray, 351, "Intr_ATU_F_OVIF11_p4");
	SetArrayString(vnArray, 352, "Intr_ATU_F_OVIF12_IPR18_b3_0_p1");
	SetArrayString(vnArray, 353, "Intr_ATU_F_OVIF13_p2");
	SetArrayString(vnArray, 354, "Intr_ATU_F_OVIF14_p3");
	SetArrayString(vnArray, 355, "Intr_ATU_F_OVIF15_p4");
	SetArrayString(vnArray, 356, "Intr_ATU_F_OVIF16_IPR19_b15_12_p1");
	SetArrayString(vnArray, 357, "Intr_ATU_F_OVIF17_p2");
	SetArrayString(vnArray, 358, "Intr_ATU_F_OVIF18_p3");
	SetArrayString(vnArray, 359, "Intr_ATU_F_OVIF19_p4");
	SetArrayString(vnArray, 368, "Intr_ATU_F_CMIG0_IPR20_b15_12_p1");
	SetArrayString(vnArray, 369, "Intr_ATU_F_CMIG1_p2");
	SetArrayString(vnArray, 370, "Intr_ATU_F_CMIG2_p3");
	SetArrayString(vnArray, 371, "Intr_ATU_F_CMIG3_p4");
	SetArrayString(vnArray, 372, "Intr_ATU_F_CMIG4_IPR20_b11_8_p1");
	SetArrayString(vnArray, 373, "Intr_ATU_F_CMIG5_p2");
	SetArrayString(vnArray, 376, "Intr_ATU_H_CMIH_IPR20_b7_4");
	SetArrayString(vnArray, 380, "Intr_ATU_J_DFIJ0_IPR21_b15_12_p1");
	SetArrayString(vnArray, 381, "Intr_ATU_J_DFIJ1_p2");
	SetArrayString(vnArray, 384, "Intr_ATU_J_OVIJ0_IPR21_b11_8_p1");
	SetArrayString(vnArray, 385, "Intr_ATU_J_OVIJ1_p2");
	SetArrayString(vnArray, 388, "Intr_ATU_J_DOVIJ0_IPR21_b7_4_p1");
	SetArrayString(vnArray, 389, "Intr_ATU_J_DOVIJ1_p2");
	SetArrayString(vnArray, 392, "Intr_ADC_ADI0_IPR22_b15_12");
	SetArrayString(vnArray, 396, "Intr_ADC_ADI1_IPR22_b11_8");
	SetArrayString(vnArray, 400, "Intr_ADC_ADID0_IPR22_b7_4_p1");
	SetArrayString(vnArray, 401, "Intr_ADC_ADID1_p2");
	SetArrayString(vnArray, 402, "Intr_ADC_ADID2_p3");
	SetArrayString(vnArray, 403, "Intr_ADC_ADID3_p4");
	SetArrayString(vnArray, 404, "Intr_ADC_ADID4_IPR22_b3_0_p1");
	SetArrayString(vnArray, 405, "Intr_ADC_ADID5_p2");
	SetArrayString(vnArray, 406, "Intr_ADC_ADID6_p3");
	SetArrayString(vnArray, 407, "Intr_ADC_ADID7_p4");
	SetArrayString(vnArray, 408, "Intr_ADC_ADID8_IPR23_b15_12_p1");
	SetArrayString(vnArray, 409, "Intr_ADC_ADID9_p2");
	SetArrayString(vnArray, 410, "Intr_ADC_ADID10_p3");
	SetArrayString(vnArray, 411, "Intr_ADC_ADID11_IPR23_b15_12_p4");
	SetArrayString(vnArray, 412, "Intr_ADC_ADID12_IPR23_b11_8_p1");
	SetArrayString(vnArray, 413, "Intr_ADC_ADID13_p2");
	SetArrayString(vnArray, 414, "Intr_ADC_ADID14_p3");
	SetArrayString(vnArray, 415, "Intr_ADC_ADID15_p4");
	SetArrayString(vnArray, 416, "Intr_ADC_ADID40_IPR23_b7_4");
	SetArrayString(vnArray, 417, "Intr_ADC_ADID41_IPR23_b3_0");
	SetArrayString(vnArray, 418, "Intr_ADC_ADID42_IPR24_b15_12");
	SetArrayString(vnArray, 419, "Intr_ADC_ADID43_IPR24_b11_8");
	SetArrayString(vnArray, 420, "Intr_ADC_ADID44_IPR24_b7_4");
	SetArrayString(vnArray, 421, "Intr_ADC_ADID45_IPR24_b3_0");
	SetArrayString(vnArray, 422, "Intr_ADC_ADID46_IPR25_b15_12");
	SetArrayString(vnArray, 423, "Intr_ADC_ADID47_IPR25_b11_8");
	SetArrayString(vnArray, 424, "Intr_SCI_A_ERIA_IPR26_b15_12_p1");
	SetArrayString(vnArray, 425, "Intr_SCI_A_RXIA_p2");
	SetArrayString(vnArray, 426, "Intr_SCI_A_TXIA_p3");
	SetArrayString(vnArray, 427, "Intr_SCI_A_TEIA_p4");
	SetArrayString(vnArray, 428, "Intr_SCI_B_ERIB_IPR26_b11_8_p1");
	SetArrayString(vnArray, 429, "Intr_SCI_B_RXIB_p2");
	SetArrayString(vnArray, 430, "Intr_SCI_B_TXIB_p3");
	SetArrayString(vnArray, 431, "Intr_SCI_B_TEIB_p4");
	SetArrayString(vnArray, 432, "Intr_SCI_C_ERIC_IPR26_b7_4_p1");
	SetArrayString(vnArray, 433, "Intr_SCI_C_RXIC_p2");
	SetArrayString(vnArray, 434, "Intr_SCI_C_TXIC_p3");
	SetArrayString(vnArray, 435, "Intr_SCI_C_TEIC_p4");
	SetArrayString(vnArray, 444, "Intr_RSPI_A_SPEIA_IPR27_b11_8_p1");
	SetArrayString(vnArray, 445, "Intr_RSPI_A_SPRIA_p2");
	SetArrayString(vnArray, 446, "Intr_RSPI_A_SPTIA_p3");
	SetArrayString(vnArray, 448, "Intr_RSPI_B_SPEIB_IPR27_b7_4_p1");
	SetArrayString(vnArray, 449, "Intr_RSPI_B_SPRIB_p2");
	SetArrayString(vnArray, 450, "Intr_RSPI_B_SPTIB_p3");
	SetArrayString(vnArray, 456, "Intr_RCAN_A_ERSA_IPR28_b15_12_p1");
	SetArrayString(vnArray, 457, "Intr_RCAN_A_OVRA_p2");
	SetArrayString(vnArray, 458, "Intr_RCAN_A_RMA0_p3");
	SetArrayString(vnArray, 459, "Intr_RCAN_A_RMA1_p4");
	SetArrayString(vnArray, 460, "Intr_RCAN_A_SLEA_p5");
	SetArrayString(vnArray, 461, "Intr_RCAN_A_MBEA_p6");
	SetArrayString(vnArray, 464, "Intr_RCAN_B_ERSB_IPR28_b11_8_p1");
	SetArrayString(vnArray, 465, "Intr_RCAN_B_OVRB_p2");
	SetArrayString(vnArray, 466, "Intr_RCAN_B_RMB0_p3");
	SetArrayString(vnArray, 467, "Intr_RCAN_B_RMB1_p4");
	SetArrayString(vnArray, 468, "Intr_RCAN_B_SLEB_p5");
	SetArrayString(vnArray, 469, "Intr_RCAN_B_MBEB_p6");
	SetArrayString(vnArray, 488, "Intr_ADMAC_TE74_IPR29_b15_12_p1");
}