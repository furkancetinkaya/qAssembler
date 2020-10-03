
/*#=========================================================================###
##                                                                           ##
##        Author:  Furkan Çetinkaya <furkan.cetinkaya@outlook.com.tr>        ##
##                                                                           ##
###=========================================================================#*/

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include "../../include/Definitions.h"
#include "../../include/Errors.h"
#include "../../include/Assembler.h"
#include "../../include/Encoding.h"

extern Boolean_t erroneous;                // Is there any error?
extern Fname_t SrcFile;                    // Source File to be scanned/parsed
extern LCounter_t LN;                      // Line Number
extern MCounter_t LC;                      // Global Location Counter
extern Flag_t isORG;                       // Is ORG directive used
extern Flag_t isSOP;                       // Is segment is overwridden
extern uint8_t SOP;                        // Overridden Segment

/* Tables */
extern Segment_t *SegmentTable;            // Segments
extern Label_t *LabelTable;                // Labels
extern size_t CurrentSegment;              // Current Segment Index
extern size_t stsize;                      // Label Segment Size
extern size_t ltsize;                      // Segment Table Size

/* Error Variables */
extern uint8_t errcode;                                     // Error Codes for Internal Errors
extern void PrintError(char *color, char *format, ...);     // Print Custom Error Message
extern void InternalError(char *format, ...);               // Print Internal Error
extern void ExternalError(char *format, ...);               // Print External Error

extern SCounter_t CalculateSize(short int val);         // Calculate the size of a number
extern Boolean_t CheckSignExtension(short int val);     // Check a number if it's sign extended
extern void ExitSafely(int retcode);                    // Safe Exit Function

/* Function Declerations */
extern void WriteByte2File(uint8_t byte);

Boolean_t EncodeArithmeticBlock(uint8_t mode, uint8_t inst, Register_t regd, Register_t regs, Memory_t mem, Immediate_t imm);  // ADC, ADD, AND, CMP, OR, SBB, SUB, XOR
Boolean_t EncodeMov(uint8_t mode, Register_t regd, Register_t regs, Memory_t mem, Immediate_t imm, uint8_t sreg);              // MOV
Boolean_t EncodeStackBlock(uint8_t mode, uint8_t inst, Register_t reg, uint8_t sreg, Memory_t mem);                            // POP, PUSH
Boolean_t EncodeIOBlock(uint8_t mode, uint8_t inst, Register_t reg, Immediate_t imm);                                          // INB, INW, OUTB, OUTW
Boolean_t EncodeXchg(uint8_t mode, Register_t regd, Register_t regs, Memory_t mem);                                            // XCHG
Boolean_t EncodeAddressBlock(uint8_t inst, Register_t reg, Memory_t mem);                                                      // LEA, LES, LDS
Boolean_t EncodeShiftRotateBlock(uint8_t mode, uint8_t inst, Register_t regd, Register_t regs, Memory_t mem);                  // RCL, RCR, ROL, ROR, SAL, SAR, SHL, SHR
Boolean_t EncodeInterrupt(Immediate_t imm);                                                                                    // INT
Boolean_t EncodeReturnBlock(uint8_t mode, uint8_t inst, Immediate_t imm);                                                      // RETN, RETF
Boolean_t EncodeTest(uint8_t mode, Register_t regd, Register_t regs, Memory_t mem, Immediate_t imm);                           // TEST
Boolean_t EncodeArithmetic2Block(uint8_t mode, uint8_t inst, Register_t reg, Memory_t mem);                                    // DIV, IDIV, MUL, IMUL, NEG, NOT
Boolean_t EncodeIncDecBlock(uint8_t mode, uint8_t inst, Register_t reg, Memory_t mem);                                         // INC, DEC
Boolean_t EncodeSingleByteInst(uint8_t byte);
Boolean_t EncodeTwoByteInst(uint8_t byte1, uint8_t byte2);
Boolean_t EncodeJccBlock(uint8_t byte1, Immediate_t imm);
Boolean_t EncodeFarOp(uint8_t mode, uint8_t inst, Memory_t mem, Immediate_t imm1, Immediate_t imm2);                           // JMPF, CALLF
Boolean_t EncodeNearOp(uint8_t mode, uint8_t inst, Register_t reg, Memory_t mem, Immediate_t imm);                             // JMPN, CALLN

Boolean_t EncodeEscapeBlock(void);                                                                                             // ESC0-7

/* Function Definitions */
Boolean_t EncodeMov(uint8_t mode, Register_t regd, Register_t regs, Memory_t mem, Immediate_t imm, uint8_t sreg)
{
    switch(mode){
        case MODE_REG_REG:
            if( (regd.size == SZ_BYTE) && (regs.size == SZ_BYTE) ){              // Reg8, Reg8
                SegmentTable[stsize-1].LC += 2;
                uint8_t byte1 = 0b10001000;
                uint8_t byte2 = 0b11000000 | (regs.id << 3) | regd.id;
                WriteByte2File(byte1);
                WriteByte2File(byte2);
            }else if( (regd.size == SZ_WORD) && (regs.size == SZ_WORD) ){      // Reg16, Reg16
                SegmentTable[stsize-1].LC += 2;
                uint8_t byte1 = 0b10001001;
                uint8_t byte2 = 0b11000000 | (regs.id << 3) | regd.id;
                WriteByte2File(byte1);
                WriteByte2File(byte2);
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }
            break;
        case MODE_REG_MEM:
            if( (mem.size == SZ_BYTE) &&(regd.size == SZ_BYTE) ){
                if( (mem.mod == 0) && (mem.rm == 6) && (regd.id == GPR_ALAX) ){     // Acc8, Mem8
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 4;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = 0xA0;
                        uint8_t byte3 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                    }else{
                        SegmentTable[stsize-1].LC += 3;
                        uint8_t byte1 = 0xA0;
                        uint8_t byte2 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte3 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                    }
                }else{
                    if( ((mem.mod == 0) && (mem.rm == 6)) || (mem.mod != 0) ){      // Reg8, Mem8
                        if(isSOP == SET){
                            SegmentTable[stsize-1].LC += 5;
                            uint8_t byte1 = SOP;
                            uint8_t byte2 = 0x8A;
                            uint8_t byte3 = (mem.mod << 6) | (regd.id << 3) | mem.rm;
                            uint8_t byte4 = (uint8_t) (mem.disp & 0x00FF);
                            uint8_t byte5 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                            WriteByte2File(byte4);
                            WriteByte2File(byte5);
                        }else{
                            SegmentTable[stsize-1].LC += 4;
                            uint8_t byte1 = 0xA0;
                            uint8_t byte2 = (mem.mod << 6) | (regd.id << 3) | mem.rm;
                            uint8_t byte3 = (uint8_t) (mem.disp & 0x00FF);
                            uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                            WriteByte2File(byte4);
                        }
                    }else{
                        if(isSOP == SET){
                            SegmentTable[stsize-1].LC += 3;
                            uint8_t byte1 = SOP;
                            uint8_t byte2 = 0x8A;
                            uint8_t byte3 = (mem.mod << 6) | (regd.id << 3) | mem.rm;
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                        }else{
                            SegmentTable[stsize-1].LC += 2;
                            uint8_t byte1 = 0xA0;
                            uint8_t byte2 = (mem.mod << 6) | (regd.id << 3) | mem.rm;
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                        }
                    }
                }
            }else if( (mem.size == SZ_WORD) && (regd.size == SZ_WORD) ){
                if( (mem.mod == 0) && (mem.rm == 6) && (regd.id == GPR_ALAX) ){     // Acc16, Mem16
                    if(isSOP == SET){
                            SegmentTable[stsize-1].LC += 4;
                            uint8_t byte1 = SOP;
                            uint8_t byte2 = 0xA1;
                            uint8_t byte3 = (uint8_t) ( mem.disp & 0x00FF );
                            uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                            WriteByte2File(byte4);
                        }else{
                            SegmentTable[stsize-1].LC += 3;
                            uint8_t byte1 = 0xA1;
                            uint8_t byte2 = (uint8_t) ( mem.disp & 0x00FF );
                            uint8_t byte3 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                        }
                }else{
                    if( ((mem.mod == 0) && (mem.rm == 6)) || (mem.mod != 0) ){      // Reg16, Mem16
                        if(isSOP == SET){
                            SegmentTable[stsize-1].LC += 5;
                            uint8_t byte1 = SOP;
                            uint8_t byte2 = 0x8B;
                            uint8_t byte3 = (mem.mod << 6) | (regd.id << 3) | mem.rm;
                            uint8_t byte4 = (uint8_t) ( mem.disp & 0x00FF );
                            uint8_t byte5 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                            WriteByte2File(byte4);
                            WriteByte2File(byte5);
                        }else{
                            SegmentTable[stsize-1].LC += 4;
                            uint8_t byte1 = 0x8B;
                            uint8_t byte2 = (mem.mod << 6) | (regd.id << 3) | mem.rm;
                            uint8_t byte3 = (uint8_t) ( mem.disp & 0x00FF );
                            uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                            WriteByte2File(byte4);
                        }
                    }else{
                        if(isSOP == SET){
                            SegmentTable[stsize-1].LC += 3;
                            uint8_t byte1 = SOP;
                            uint8_t byte2 = 0x8B;
                            uint8_t byte3 = (mem.mod << 6) | (regd.id << 3) | mem.rm;
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                        }else{
                            SegmentTable[stsize-1].LC += 2;
                            uint8_t byte1 = 0x8B;
                            uint8_t byte2 = (mem.mod << 6) | (regd.id << 3) | mem.rm;
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                        }
                    }
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }

            if(isSOP == SET)
                isSOP = NSET;
            break;
        case MODE_MEM_REG:
            if( (mem.size == SZ_BYTE) && (regs.size == SZ_BYTE) ){
                if( (mem.mod == 0) && (mem.rm == 6) && (regs.id == GPR_ALAX) ){
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 4;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = 0xA2;
                        uint8_t byte3 = (uint8_t) ( mem.disp & 0x00FF );
                        uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                    }else{
                        SegmentTable[stsize-1].LC += 3;
                        uint8_t byte1 = 0xA2;
                        uint8_t byte2 = (uint8_t) ( mem.disp & 0x00FF );
                        uint8_t byte3 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                    }
                }else{
                    if( ((mem.mod == 0) && (mem.rm == 6)) || (mem.mod != 0) ){      // Reg16, Mem16
                        if(isSOP == SET){
                            SegmentTable[stsize-1].LC += 5;
                            uint8_t byte1 = SOP;
                            uint8_t byte2 = 0x88;
                            uint8_t byte3 = (mem.mod << 6) | (regs.id << 3) | mem.rm;
                            uint8_t byte4 = (uint8_t) ( mem.disp & 0x00FF );
                            uint8_t byte5 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                            WriteByte2File(byte4);
                            WriteByte2File(byte5);
                        }else{
                            SegmentTable[stsize-1].LC += 4;
                            uint8_t byte1 = 0x88;
                            uint8_t byte2 = (mem.mod << 6) | (regs.id << 3) | mem.rm;
                            uint8_t byte3 = (uint8_t) ( mem.disp & 0x00FF );
                            uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                            WriteByte2File(byte4);
                        }
                    }else{
                        if(isSOP == SET){
                            SegmentTable[stsize-1].LC += 3;
                            uint8_t byte1 = SOP;
                            uint8_t byte2 = 0x88;
                            uint8_t byte3 = (mem.mod << 6) | (regs.id << 3) | mem.rm;
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                        }else{
                            SegmentTable[stsize-1].LC += 2;
                            uint8_t byte1 = 0x88;
                            uint8_t byte2 = (mem.mod << 6) | (regs.id << 3) | mem.rm;
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                        }
                    }
                }
            }else if( (mem.size == SZ_WORD) && (regs.size == SZ_WORD) ){
                if( (mem.mod == 0) && (mem.rm == 6) && (regs.id == GPR_ALAX) ){     // Acc16, Mem16
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 4;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = 0xA3;
                        uint8_t byte3 = (uint8_t) ( mem.disp & 0x00FF );
                        uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                    }else{
                        SegmentTable[stsize-1].LC += 3;
                        uint8_t byte1 = 0xA3;
                        uint8_t byte2 = (uint8_t) ( mem.disp & 0x00FF );
                        uint8_t byte3 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                    }
                }else{
                    if( ((mem.mod == 0) && (mem.rm == 6)) || (mem.mod != 0) ){      // Reg16, Mem16
                        if(isSOP == SET){
                            SegmentTable[stsize-1].LC += 5;
                            uint8_t byte1 = SOP;
                            uint8_t byte2 = 0x89;
                            uint8_t byte3 = (mem.mod << 6) | (regs.id << 3) | mem.rm;
                            uint8_t byte4 = (uint8_t) ( mem.disp & 0x00FF );
                            uint8_t byte5 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                            WriteByte2File(byte4);
                            WriteByte2File(byte5);
                        }else{
                            SegmentTable[stsize-1].LC += 4;
                            uint8_t byte1 = 0x89;
                            uint8_t byte2 = (mem.mod << 6) | (regs.id << 3) | mem.rm;
                            uint8_t byte3 = (uint8_t) ( mem.disp & 0x00FF );
                            uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                            WriteByte2File(byte4);
                        }
                    }else{
                        if(isSOP == SET){
                            SegmentTable[stsize-1].LC += 3;
                            uint8_t byte1 = SOP;
                            uint8_t byte2 = 0x89;
                            uint8_t byte3 = (mem.mod << 6) | (regs.id << 3) | mem.rm;
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                        }else{
                            SegmentTable[stsize-1].LC += 2;
                            uint8_t byte1 = 0x89;
                            uint8_t byte2 = (mem.mod << 6) | (regs.id << 3) | mem.rm;
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                        }
                    }
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }

            if(isSOP == SET)
                isSOP = NSET;
            break;
        case MODE_REG_IMM:
            if( (regd.size == SZ_BYTE) && (imm.size == SZ_BYTE) ){
                SegmentTable[stsize-1].LC += 2;
                uint8_t byte1 = 0b10110000 | regd.id;
                uint8_t byte2 = (uint8_t) (imm.val & 0x00FF);
                WriteByte2File(byte1);
                WriteByte2File(byte2);
            }else if( (regd.size == SZ_WORD) && ( (imm.size == SZ_BYTE) || (imm.size == SZ_WORD) ) ){
                SegmentTable[stsize-1].LC += 3;
                uint8_t byte1 = 0b10111000 | regd.id;
                uint8_t byte2 = (uint8_t) (imm.val & 0x00FF);
                uint8_t byte3 = (imm.size == SZ_BYTE) ? 0 : (uint8_t) ( (imm.val >> 8) & 0x00FF );
                WriteByte2File(byte1);
                WriteByte2File(byte2);
                WriteByte2File(byte3);
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }
            break;
        case MODE_MEM_IMM:
            if( (mem.size == SZ_BYTE) && (imm.size == SZ_BYTE) ){
                if( ((mem.mod == 0) && (mem.rm == 6)) || (mem.mod != 0) ){
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 6;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = 0xC6;
                        uint8_t byte3 = (mem.mod << 6) | mem.rm;
                        uint8_t byte4 = (uint8_t) ( mem.disp & 0x00FF );
                        uint8_t byte5 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        uint8_t byte6 = (uint8_t) ( imm.val & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                        WriteByte2File(byte5);
                        WriteByte2File(byte6);
                    }else{
                        SegmentTable[stsize-1].LC += 5;
                        uint8_t byte1 = 0xC6;
                        uint8_t byte2 = (mem.mod << 6) | mem.rm;
                        uint8_t byte3 = (uint8_t) ( mem.disp & 0x00FF );
                        uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        uint8_t byte5 = (uint8_t) ( imm.val & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                        WriteByte2File(byte5);
                    }
                }else{
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 4;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = 0xC6;
                        uint8_t byte3 = (mem.mod << 6) | mem.rm;
                        uint8_t byte4 = (uint8_t) ( imm.val & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                    }else{
                        SegmentTable[stsize-1].LC += 3;
                        uint8_t byte1 = 0xC6;
                        uint8_t byte2 = (mem.mod << 6) | mem.rm;
                        uint8_t byte3 = (uint8_t) ( imm.val & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                    }
                }
            }else if( (mem.size == SZ_WORD) && ( (imm.size == SZ_BYTE) || (imm.size == SZ_WORD) ) ){
                if( ((mem.mod == 0) && (mem.rm == 6)) || (mem.mod != 0) ){
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 7;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = 0xC7;
                        uint8_t byte3 = (mem.mod << 6) | mem.rm;
                        uint8_t byte4 = (uint8_t) ( mem.disp & 0x00FF );
                        uint8_t byte5 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        uint8_t byte6 = (uint8_t) ( imm.val & 0x00FF );
                        uint8_t byte7 = (imm.size == SZ_BYTE) ? 0 : (uint8_t) ( (imm.val >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                        WriteByte2File(byte5);
                        WriteByte2File(byte6);
                        WriteByte2File(byte7);
                    }else{
                        SegmentTable[stsize-1].LC += 6;
                        uint8_t byte1 = 0xC7;
                        uint8_t byte2 = (mem.mod << 6) | mem.rm;
                        uint8_t byte3 = (uint8_t) ( mem.disp & 0x00FF );
                        uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        uint8_t byte5 = (uint8_t) ( imm.val & 0x00FF );
                        uint8_t byte6 = (imm.size == SZ_BYTE) ? 0 : (uint8_t) ( (imm.val >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                        WriteByte2File(byte5);
                        WriteByte2File(byte6);
                    }
                }else{
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 5;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = 0xC7;
                        uint8_t byte3 = (mem.mod << 6) | mem.rm;
                        uint8_t byte4 = (uint8_t) ( imm.val & 0x00FF );
                        uint8_t byte5 = (imm.size == SZ_BYTE) ? 0 : (uint8_t) ( (imm.val >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                        WriteByte2File(byte5);
                    }else{
                        SegmentTable[stsize-1].LC += 4;
                        uint8_t byte1 = 0xC7;
                        uint8_t byte2 = (mem.mod << 6) | mem.rm;
                        uint8_t byte3 = (uint8_t) ( imm.val & 0x00FF );
                        uint8_t byte4 = (imm.size == SZ_BYTE) ? 0 : (uint8_t) ( (imm.val >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                    }
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }

            if(isSOP == SET)
                isSOP = NSET;
            break;
        case MODE_SREG_REG:
            if(regs.size == SZ_WORD){
                SegmentTable[stsize-1].LC += 2;
                uint8_t byte1 = 0x8E;
                uint8_t byte2 = 0b11000000 | (sreg << 5) | regs.id;
                WriteByte2File(byte1);
                WriteByte2File(byte2);
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }
            break;
        case MODE_SREG_MEM:
            if( mem.size == SZ_WORD ){
                if( ((mem.mod == 0) && (mem.rm == 6)) || (mem.mod != 0) ){
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 5;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = 0x8E;
                        uint8_t byte3 = (mem.mod << 6) | (sreg << 5) | mem.rm;
                        uint8_t byte4 = (uint8_t) ( mem.disp & 0x00FF );
                        uint8_t byte5 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                        WriteByte2File(byte5);
                    }else{
                        SegmentTable[stsize-1].LC += 4;
                        uint8_t byte1 = 0x8E;
                        uint8_t byte2 = (mem.mod << 6) | (sreg << 5) | mem.rm;
                        uint8_t byte3 = (uint8_t) ( mem.disp & 0x00FF );
                        uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                    }
                }else{
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 3;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = 0x8E;
                        uint8_t byte3 = (mem.mod << 6) | (sreg << 5) | mem.rm;
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                    }else{
                        SegmentTable[stsize-1].LC += 2;
                        uint8_t byte1 = 0x8E;
                        uint8_t byte2 = (mem.mod << 6) | (sreg << 5) | mem.rm;
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                    }
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }

            if(isSOP == SET)
                isSOP = NSET;
            break;
        case MODE_REG_SREG:
            if(regd.size == SZ_WORD){
                SegmentTable[stsize-1].LC += 2;
                uint8_t byte1 = 0x8C;
                uint8_t byte2 = 0b11000000 | (sreg << 5) | regd.id;
                WriteByte2File(byte1);
                WriteByte2File(byte2);
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }
            break;
        case MODE_MEM_SREG:
            if( mem.size == SZ_WORD ){
                if( ((mem.mod == 0) && (mem.rm == 6)) || (mem.mod != 0) ){
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 5;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = 0x8C;
                        uint8_t byte3 = (mem.mod << 6) | (sreg << 5) | mem.rm;
                        uint8_t byte4 = (uint8_t) ( mem.disp & 0x00FF );
                        uint8_t byte5 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                        WriteByte2File(byte5);
                    }else{
                        SegmentTable[stsize-1].LC += 4;
                        uint8_t byte1 = 0x8C;
                        uint8_t byte2 = (mem.mod << 6) | (sreg << 5) | mem.rm;
                        uint8_t byte3 = (uint8_t) ( mem.disp & 0x00FF );
                        uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                    }
                }else{
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 3;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = 0x8C;
                        uint8_t byte3 = (mem.mod << 6) | (sreg << 5) | mem.rm;
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                    }else{
                        SegmentTable[stsize-1].LC += 2;
                        uint8_t byte1 = 0x8C;
                        uint8_t byte2 = (mem.mod << 6) | (sreg << 5) | mem.rm;
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                    }
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }

            if(isSOP == SET)
                isSOP = NSET;
            break;
        default:
            PrintError(COLOR_BOLDRED, "Line %d :: Instruction-Operand mismatch!\n", LN);
            return FALSE;
            break;
    }

    return TRUE;
}

Boolean_t EncodeStackBlock(uint8_t mode, uint8_t inst, Register_t reg, uint8_t sreg, Memory_t mem)
{
    printf("Mod: %d, Rm: %d, Reg: %d\n", mem.mod, mem.rm, reg.id);
    switch(mode){
        case MODE_REG:
            if(reg.size == SZ_WORD){
                SegmentTable[stsize-1].LC += 1;
                uint8_t byte1 = (inst == PUSH_INST) ? 0b01010000 : 0b01011000;
                byte1 = byte1 | reg.id;
                WriteByte2File(byte1);
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand Size Mismatch!\n", LN);
                return FALSE;
            }
            break;
        case MODE_SREG:
            if(inst == PUSH_INST){
                SegmentTable[stsize-1].LC += 1;
                uint8_t byte1 = 0b00000110 | (sreg << 3);
                WriteByte2File(byte1);
            }else{
                if( sreg != SREG_CODE ){
                    SegmentTable[stsize-1].LC += 1;
                    uint8_t byte1 = 0b00000111 | (sreg << 3);
                    WriteByte2File(byte1);
                }else{
                    PrintError(COLOR_BOLDRED, "Line %d :: CS is illegal with POP instruction!\n", LN);
                    return FALSE;
                }
            }
            break;
        case MODE_MEM:
            if(mem.size == SZ_WORD){
                if( ((mem.mod == 0) && (mem.rm == 6)) || (mem.mod != 0) ){
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 5;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = (inst == PUSH_INST) ? 0xFF : 0x8F;
                        uint8_t byte3 = (inst == POP_INST) ? ((mem.mod << 6) | mem.rm) : ((mem.mod << 6) | 0b00110000 | mem.rm);
                        uint8_t byte4 = (uint8_t) ( mem.disp & 0x00FF );
                        uint8_t byte5 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                        WriteByte2File(byte5);
                        printf("Mod: %d, Rm: %d, Reg: %d\n", mem.mod, mem.rm, reg.id);
                    }else{
                        SegmentTable[stsize-1].LC += 4;
                        uint8_t byte1 = (inst == PUSH_INST) ? 0xFF : 0x8F;
                        uint8_t byte2 = (inst == POP_INST) ? ((mem.mod << 6) | mem.rm) : ((mem.mod << 6) | 0b00110000 | mem.rm);
                        uint8_t byte3 = (uint8_t) ( mem.disp & 0x00FF );
                        uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                    }
                }
                else{
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 3;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = (inst == PUSH_INST) ? 0xFF : 0x8F;
                        uint8_t byte3 = (inst == PUSH_INST) ? ((mem.mod << 6) | mem.rm) : ((mem.mod << 6) | 0b00110000 | mem.rm);
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        printf("Mod: %d, Rm: %d, Reg: %d\n", mem.mod, mem.rm, reg.id);
                    }else{
                        SegmentTable[stsize-1].LC += 2;
                        uint8_t byte1 = (inst == PUSH_INST) ? 0xFF : 0x8F;
                        uint8_t byte2 = (inst == POP_INST) ? ((mem.mod << 6) | mem.rm) : ((mem.mod << 6) | 0b00110000 | mem.rm);
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        printf("Mod: %d, Rm: %d, Reg: %d\n", mem.mod, mem.rm, reg.id);
                    }
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand Size Mismatch!\n", LN);
                return FALSE;
            }
            
            if(isSOP == SET)
                isSOP = NSET;
            break;
        default:
            PrintError(COLOR_BOLDRED, "Line %d :: Instruction-Operand mismatch!\n", LN);
            return FALSE;
            break;
    }

    return TRUE;
}

Boolean_t EncodeXchg(uint8_t mode, Register_t regd, Register_t regs, Memory_t mem)
{
    switch(mode){
        case MODE_REG_REG:
            if( (regd.id == GPR_ALAX) && (regd.size == SZ_WORD) && (regs.size == SZ_WORD) ){
                SegmentTable[stsize-1].LC += 1;
                uint8_t byte1 = 0b10010000 | regd.id;
                WriteByte2File(byte1);
            }else if( (regd.size == SZ_BYTE) && (regs.size == SZ_BYTE) ){
                SegmentTable[stsize-1].LC += 2;
                uint8_t byte1 = 0x86;
                uint8_t byte2 = 0b11000000 | (regd.id << 3) | regs.id;
                WriteByte2File(byte1);
                WriteByte2File(byte2);
            }else if( (regd.size == SZ_WORD) && (regs.size == SZ_WORD) ){
                SegmentTable[stsize-1].LC += 2;
                uint8_t byte1 = 0x87;
                uint8_t byte2 = 0b11000000 | (regd.id << 3) | regs.id;
                WriteByte2File(byte1);
                WriteByte2File(byte2);
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }
            break;
        case MODE_MEM_REG:
            if( mem.size == regs.size ){
                if( ((mem.mod == 0) && (mem.rm == 6)) || (mem.mod != 0) ) {
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 5;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = (mem.size == SZ_BYTE) ? 0x86 : 0x87;
                        uint8_t byte3 = (mem.mod << 6) | (regs.id << 3) | mem.rm;
                        uint8_t byte4 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte5 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                        WriteByte2File(byte5);
                    }else{
                        SegmentTable[stsize-1].LC += 4;
                        uint8_t byte1 = (mem.size == SZ_BYTE) ? 0x86 : 0x87;
                        uint8_t byte2 = (mem.mod << 6) | (regs.id << 3) | mem.rm;
                        uint8_t byte3 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                    }
                }else{
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 3;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = (mem.size == SZ_BYTE) ? 0x86 : 0x87;
                        uint8_t byte3 = (mem.mod << 6) | (regs.id << 3) | mem.rm;
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                    }else{
                        SegmentTable[stsize-1].LC += 2;
                        uint8_t byte1 = (mem.size == SZ_BYTE) ? 0x86 : 0x87;
                        uint8_t byte2 = (mem.mod << 6) | (regs.id << 3) | mem.rm;
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                    }
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }
            if(isSOP == SET)
                isSOP = NSET;
            break;
    }

    return TRUE;
}

Boolean_t EncodeIOBlock(uint8_t mode, uint8_t inst, Register_t reg, Immediate_t imm)
{
    switch(mode){
        case MODE_IMM:
            if( imm.size == SZ_BYTE ){
                SegmentTable[stsize-1].LC += 2;
                uint8_t byte1;
                uint8_t byte2 = (uint8_t) (imm.val & 0x00FF);
                switch(inst){
                    case INB_INST:
                        byte1 = 0xE4;
                        break;
                    case INW_INST:
                        byte1 = 0xE5;
                        break;
                    case OUTB_INST:
                        byte1 = 0xE6;
                        break;
                    case OUTW_INST:
                        byte1 = 0xE7;
                        break;
                }
                WriteByte2File(byte1);
                WriteByte2File(byte2);
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }
            break;
        case MODE_REG:
            if( reg.size == SZ_WORD ){
                if( reg.id == GPR_DLDX ){
                    SegmentTable[stsize-1].LC += 1;
                    uint8_t byte1;
                    switch(inst){
                        case INB_INST:
                            byte1 = 0xEC;
                            break;
                        case INW_INST:
                            byte1 = 0xED;
                            break;
                        case OUTB_INST:
                            byte1 = 0xEE;
                            break;
                        case OUTW_INST:
                            byte1 = 0xEF;
                            break;
                    }
                    WriteByte2File(byte1);
                }else{
                    PrintError(COLOR_BOLDRED, "Line %d :: Instruction-Operand mismatch!\n", LN);
                    return FALSE;
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }
            break;
        default:
            PrintError(COLOR_BOLDRED, "Line %d :: Instruction-Operand mismatch!\n", LN);
            return FALSE;
            break;
    }

    return TRUE;
}

Boolean_t EncodeAddressBlock(uint8_t inst, Register_t reg, Memory_t mem)
{
    switch(inst){
        case LEA_INST:
            if( (reg.size == SZ_WORD) && (mem.size == SZ_WORD) ){
                if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) ){
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 5;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = 0x8D;
                        uint8_t byte3 = (mem.mod << 6) | (reg.id << 3) | mem.rm;
                        uint8_t byte4 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte5 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                        WriteByte2File(byte5);
                    }else{
                        SegmentTable[stsize-1].LC += 4;
                        uint8_t byte1 = 0x8D;
                        uint8_t byte2 = (mem.mod << 6) | (reg.id << 3) | mem.rm;
                        uint8_t byte3 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                    }
                }else{
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 3;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = 0x8D;
                        uint8_t byte3 = (mem.mod << 6) | (reg.id << 3) | mem.rm;
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                    }else{
                        SegmentTable[stsize-1].LC += 2;
                        uint8_t byte1 = 0x8D;
                        uint8_t byte2 = (mem.mod << 6) | (reg.id << 3) | mem.rm;
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                    }
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }
            break;
        case LDS_INST:
            if( (reg.size == SZ_WORD) && (mem.size == SZ_DWORD) ){
                if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) ){
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 5;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = 0xC5;
                        uint8_t byte3 = (mem.mod << 6) | (reg.id << 3) | mem.rm;
                        uint8_t byte4 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte5 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                        WriteByte2File(byte5);
                    }else{
                        SegmentTable[stsize-1].LC += 4;
                        uint8_t byte1 = 0xC5;
                        uint8_t byte2 = (mem.mod << 6) | (reg.id << 3) | mem.rm;
                        uint8_t byte3 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                    }
                }else{
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 3;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = 0xC5;
                        uint8_t byte3 = (mem.mod << 6) | (reg.id << 3) | mem.rm;
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                    }else{
                        SegmentTable[stsize-1].LC += 2;
                        uint8_t byte1 = 0xC5;
                        uint8_t byte2 = (mem.mod << 6) | (reg.id << 3) | mem.rm;
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                    }
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }
            break;
        case LES_INST:
            if( (reg.size == SZ_WORD) && (mem.size == SZ_DWORD) ){
                if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) ){
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 5;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = 0xC4;
                        uint8_t byte3 = (mem.mod << 6) | (reg.id << 3) | mem.rm;
                        uint8_t byte4 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte5 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                        WriteByte2File(byte5);
                    }else{
                        SegmentTable[stsize-1].LC += 4;
                        uint8_t byte1 = 0xC4;
                        uint8_t byte2 = (mem.mod << 6) | (reg.id << 3) | mem.rm;
                        uint8_t byte3 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                    }
                }else{
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 3;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = 0xC4;
                        uint8_t byte3 = (mem.mod << 6) | (reg.id << 3) | mem.rm;
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                    }else{
                        SegmentTable[stsize-1].LC += 2;
                        uint8_t byte1 = 0xC4;
                        uint8_t byte2 = (mem.mod << 6) | (reg.id << 3) | mem.rm;
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                    }
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }
            break;
        default:
            PrintError(COLOR_BOLDRED, "Line %d :: Instruction-Operand mismatch!\n", LN);
            return FALSE;
    }

    if(isSOP == SET)
        isSOP = NSET;

    return TRUE;
}

Boolean_t EncodeArithmeticBlock(uint8_t mode, uint8_t inst, Register_t regd, Register_t regs, Memory_t mem, Immediate_t imm)
{
    Boolean_t sgx;
    switch(mode){
        case MODE_REG_REG:
            if(regd.size == regs.size){
                SegmentTable[stsize-1].LC += 2;
                uint8_t byte1;
                switch(inst){
                    case ADC_INST:
                        byte1 = (regd.size == SZ_BYTE) ? 0x10 : 0x11 ;
                        break;
                    case ADD_INST:
                        byte1 = (regd.size == SZ_BYTE) ? 0x00 : 0x01 ;
                        break;
                    case AND_INST:
                        byte1 = (regd.size == SZ_BYTE) ? 0x20 : 0x21 ;
                        break;
                    case CMP_INST:
                        byte1 = (regd.size == SZ_BYTE) ? 0x38 : 0x39 ;
                        break;
                    case OR_INST:
                        byte1 = (regd.size == SZ_BYTE) ? 0x08 : 0x09 ;
                        break;
                    case SBB_INST:
                        byte1 = (regd.size == SZ_BYTE) ? 0x18 : 0x19 ;
                        break;
                    case SUB_INST:
                        byte1 = (regd.size == SZ_BYTE) ? 0x28 : 0x29 ;
                        break;
                    case XOR_INST:
                        byte1 = (regd.size == SZ_BYTE) ? 0x30 : 0x31 ;
                        break;
                }
                uint8_t byte2 = 0b11000000 | (regs.id << 3) | regd.id;
                WriteByte2File(byte1);
                WriteByte2File(byte2);
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }
            break;
        case MODE_REG_MEM:
            if(regd.size == mem.size){
                if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) ){
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 5;
                        uint8_t byte1 = SOP;
                        uint8_t byte2;
                        switch(inst){
                            case ADC_INST:
                                byte2 = (regd.size == SZ_BYTE) ? 0x12 : 0x13 ;
                                break;
                            case ADD_INST:
                                byte2 = (regd.size == SZ_BYTE) ? 0x02 : 0x03 ;
                                break;
                            case AND_INST:
                                byte2 = (regd.size == SZ_BYTE) ? 0x22 : 0x23 ;
                                break;
                            case CMP_INST:
                                byte2 = (regd.size == SZ_BYTE) ? 0x3A : 0x3B ;
                                break;
                            case OR_INST:
                                byte2 = (regd.size == SZ_BYTE) ? 0x0A : 0x0B ;
                                break;
                            case SBB_INST:
                                byte2 = (regd.size == SZ_BYTE) ? 0x1A : 0x1B ;
                                break;
                            case SUB_INST:
                                byte2 = (regd.size == SZ_BYTE) ? 0x2A : 0x2B ;
                                break;
                            case XOR_INST:
                                byte2 = (regd.size == SZ_BYTE) ? 0x32 : 0x33 ;
                                break;
                        }
                        uint8_t byte3 = (mem.mod << 6) | (regd.id << 3) | mem.rm;
                        uint8_t byte4 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte5 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                        WriteByte2File(byte5);
                    }else{
                        SegmentTable[stsize-1].LC += 4;
                        uint8_t byte1;
                        switch(inst){
                            case ADC_INST:
                                byte1 = (regd.size == SZ_BYTE) ? 0x12 : 0x13 ;
                                break;
                            case ADD_INST:
                                byte1 = (regd.size == SZ_BYTE) ? 0x02 : 0x03 ;
                                break;
                            case AND_INST:
                                byte1 = (regd.size == SZ_BYTE) ? 0x22 : 0x23 ;
                                break;
                            case CMP_INST:
                                byte1 = (regd.size == SZ_BYTE) ? 0x3A : 0x3B ;
                                break;
                            case OR_INST:
                                byte1 = (regd.size == SZ_BYTE) ? 0x0A : 0x0B ;
                                break;
                            case SBB_INST:
                                byte1 = (regd.size == SZ_BYTE) ? 0x1A : 0x1B ;
                                break;
                            case SUB_INST:
                                byte1 = (regd.size == SZ_BYTE) ? 0x2A : 0x2B ;
                                break;
                            case XOR_INST:
                                byte1 = (regd.size == SZ_BYTE) ? 0x32 : 0x33 ;
                                break;
                        }
                        uint8_t byte2 = (mem.mod << 6) | (regd.id << 3) | mem.rm;
                        uint8_t byte3 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                    }
                }else{
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 3;
                        uint8_t byte1 = SOP;
                        uint8_t byte2;
                        switch(inst){
                            case ADC_INST:
                                byte2 = (regd.size == SZ_BYTE) ? 0x12 : 0x13 ;
                                break;
                            case ADD_INST:
                                byte2 = (regd.size == SZ_BYTE) ? 0x02 : 0x03 ;
                                break;
                            case AND_INST:
                                byte2 = (regd.size == SZ_BYTE) ? 0x22 : 0x23 ;
                                break;
                            case CMP_INST:
                                byte2 = (regd.size == SZ_BYTE) ? 0x3A : 0x3B ;
                                break;
                            case OR_INST:
                                byte2 = (regd.size == SZ_BYTE) ? 0x0A : 0x0B ;
                                break;
                            case SBB_INST:
                                byte2 = (regd.size == SZ_BYTE) ? 0x1A : 0x1B ;
                                break;
                            case SUB_INST:
                                byte2 = (regd.size == SZ_BYTE) ? 0x2A : 0x2B ;
                                break;
                            case XOR_INST:
                                byte2 = (regd.size == SZ_BYTE) ? 0x32 : 0x33 ;
                                break;
                        }
                        uint8_t byte3 = (mem.mod << 6) | (regd.id << 3) | mem.rm;
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                    }else{
                        SegmentTable[stsize-1].LC += 2;
                        uint8_t byte1;
                        switch(inst){
                            case ADC_INST:
                                byte1 = (regd.size == SZ_BYTE) ? 0x12 : 0x13 ;
                                break;
                            case ADD_INST:
                                byte1 = (regd.size == SZ_BYTE) ? 0x02 : 0x03 ;
                                break;
                            case AND_INST:
                                byte1 = (regd.size == SZ_BYTE) ? 0x22 : 0x23 ;
                                break;
                            case CMP_INST:
                                byte1 = (regd.size == SZ_BYTE) ? 0x3A : 0x3B ;
                                break;
                            case OR_INST:
                                byte1 = (regd.size == SZ_BYTE) ? 0x0A : 0x0B ;
                                break;
                            case SBB_INST:
                                byte1 = (regd.size == SZ_BYTE) ? 0x1A : 0x1B ;
                                break;
                            case SUB_INST:
                                byte1 = (regd.size == SZ_BYTE) ? 0x2A : 0x2B ;
                                break;
                            case XOR_INST:
                                byte1 = (regd.size == SZ_BYTE) ? 0x32 : 0x33 ;
                                break;
                        }
                        uint8_t byte2 = (mem.mod << 6) | (regd.id << 3) | mem.rm;
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                    }
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }
            if(isSOP == SET)
                isSOP = NSET;
            break;
        case MODE_MEM_REG:
            if(regs.size == mem.size){
                if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) ){
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 5;
                        uint8_t byte1 = SOP;
                        uint8_t byte2;
                        switch(inst){
                            case ADC_INST:
                                byte2 = (regs.size == SZ_BYTE) ? 0x10 : 0x11 ;
                                break;
                            case ADD_INST:
                                byte2 = (regs.size == SZ_BYTE) ? 0x00 : 0x01 ;
                                break;
                            case AND_INST:
                                byte2 = (regs.size == SZ_BYTE) ? 0x20 : 0x21 ;
                                break;
                            case CMP_INST:
                                byte2 = (regs.size == SZ_BYTE) ? 0x38 : 0x39 ;
                                break;
                            case OR_INST:
                                byte2 = (regs.size == SZ_BYTE) ? 0x08 : 0x09 ;
                                break;
                            case SBB_INST:
                                byte2 = (regs.size == SZ_BYTE) ? 0x18 : 0x19 ;
                                break;
                            case SUB_INST:
                                byte2 = (regs.size == SZ_BYTE) ? 0x28 : 0x29 ;
                                break;
                            case XOR_INST:
                                byte2 = (regs.size == SZ_BYTE) ? 0x30 : 0x31 ;
                                break;
                        }
                        uint8_t byte3 = (mem.mod << 6) | (regs.id << 3) | mem.rm;
                        uint8_t byte4 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte5 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                        WriteByte2File(byte5);
                    }else{
                        SegmentTable[stsize-1].LC += 4;
                        uint8_t byte1;
                        switch(inst){
                            case ADC_INST:
                                byte1 = (regs.size == SZ_BYTE) ? 0x10 : 0x11 ;
                                break;
                            case ADD_INST:
                                byte1 = (regs.size == SZ_BYTE) ? 0x00 : 0x01 ;
                                break;
                            case AND_INST:
                                byte1 = (regs.size == SZ_BYTE) ? 0x20 : 0x21 ;
                                break;
                            case CMP_INST:
                                byte1 = (regs.size == SZ_BYTE) ? 0x38 : 0x39 ;
                                break;
                            case OR_INST:
                                byte1 = (regs.size == SZ_BYTE) ? 0x08 : 0x09 ;
                                break;
                            case SBB_INST:
                                byte1 = (regs.size == SZ_BYTE) ? 0x18 : 0x19 ;
                                break;
                            case SUB_INST:
                                byte1 = (regs.size == SZ_BYTE) ? 0x28 : 0x29 ;
                                break;
                            case XOR_INST:
                                byte1 = (regs.size == SZ_BYTE) ? 0x30 : 0x31 ;
                                break;
                        }
                        uint8_t byte2 = (mem.mod << 6) | (regs.id << 3) | mem.rm;
                        uint8_t byte3 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                    }
                }else{
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 3;
                        uint8_t byte1 = SOP;
                        uint8_t byte2;
                        switch(inst){
                            case ADC_INST:
                                byte2 = (regs.size == SZ_BYTE) ? 0x10 : 0x11 ;
                                break;
                            case ADD_INST:
                                byte2 = (regs.size == SZ_BYTE) ? 0x00 : 0x01 ;
                                break;
                            case AND_INST:
                                byte2 = (regs.size == SZ_BYTE) ? 0x20 : 0x21 ;
                                break;
                            case CMP_INST:
                                byte2 = (regs.size == SZ_BYTE) ? 0x38 : 0x39 ;
                                break;
                            case OR_INST:
                                byte2 = (regs.size == SZ_BYTE) ? 0x08 : 0x09 ;
                                break;
                            case SBB_INST:
                                byte2 = (regs.size == SZ_BYTE) ? 0x18 : 0x19 ;
                                break;
                            case SUB_INST:
                                byte2 = (regs.size == SZ_BYTE) ? 0x28 : 0x29 ;
                                break;
                            case XOR_INST:
                                byte2 = (regs.size == SZ_BYTE) ? 0x30 : 0x31 ;
                                break;
                        }
                        uint8_t byte3 = (mem.mod << 6) | (regs.id << 3) | mem.rm;
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                    }else{
                        SegmentTable[stsize-1].LC += 2;
                        uint8_t byte1;
                        switch(inst){
                            case ADC_INST:
                                byte1 = (regs.size == SZ_BYTE) ? 0x10 : 0x11 ;
                                break;
                            case ADD_INST:
                                byte1 = (regs.size == SZ_BYTE) ? 0x00 : 0x01 ;
                                break;
                            case AND_INST:
                                byte1 = (regs.size == SZ_BYTE) ? 0x20 : 0x21 ;
                                break;
                            case CMP_INST:
                                byte1 = (regs.size == SZ_BYTE) ? 0x38 : 0x39 ;
                                break;
                            case OR_INST:
                                byte1 = (regs.size == SZ_BYTE) ? 0x08 : 0x09 ;
                                break;
                            case SBB_INST:
                                byte1 = (regs.size == SZ_BYTE) ? 0x18 : 0x19 ;
                                break;
                            case SUB_INST:
                                byte1 = (regs.size == SZ_BYTE) ? 0x28 : 0x29 ;
                                break;
                            case XOR_INST:
                                byte1 = (regs.size == SZ_BYTE) ? 0x30 : 0x31 ;
                                break;
                        }
                        uint8_t byte2 = (mem.mod << 6) | (regs.id << 3) | mem.rm;
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                    }
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }

            if(isSOP == SET)
                isSOP = NSET;
            break;
        case MODE_REG_IMM:
            sgx = CheckSignExtension(imm.val);
            if( (regd.size == SZ_BYTE) && (imm.size == SZ_BYTE) ){
                if(regd.id == GPR_ALAX){
                    SegmentTable[stsize-1].LC += 2;     // Acc8, imm8
                    uint8_t byte1;
                    switch(inst){
                        case ADC_INST:
                            byte1 = 0x14;
                            break;
                        case ADD_INST:
                            byte1 = 0x04;
                            break;
                        case AND_INST:
                            byte1 = 0x24;
                            break;
                        case CMP_INST:
                            byte1 = 0x3C;
                            break;
                        case OR_INST:
                            byte1 = 0x0C;
                            break;
                        case SBB_INST:
                            byte1 = 0x1C;
                            break;
                        case SUB_INST:
                            byte1 = 0x2C;
                            break;
                        case XOR_INST:
                            byte1 = 0x34;
                            break;
                    }
                    uint8_t byte2 = (uint8_t) (imm.val & 0x00FF);
                    WriteByte2File(byte1);
                    WriteByte2File(byte2);
                }else{
                    SegmentTable[stsize-1].LC += 3;     // Reg8, Imm8
                    uint8_t byte1 = 0x80;
                    uint8_t byte2;
                    switch(inst){
                        case ADC_INST:
                            byte2 = 0b11000000 | 0b00010000 | regd.id;
                            break;
                        case ADD_INST:
                            byte2 = 0b11000000 | 0b00000000 | regd.id;
                            break;
                        case AND_INST:
                            byte2 = 0b11000000 | 0b00100000 | regd.id;
                            break;
                        case CMP_INST:
                            byte2 = 0b11000000 | 0b00111000 | regd.id;
                            break;
                        case OR_INST:
                            byte2 = 0b11000000 | 0b00001000 | regd.id;
                            break;
                        case SBB_INST:
                            byte2 = 0b11000000 | 0b00011000 | regd.id;
                            break;
                        case SUB_INST:
                            byte2 = 0b11000000 | 0b00101000 | regd.id;
                            break;
                        case XOR_INST:
                            byte2 = 0b11000000 | 0b00110000 | regd.id;
                            break;
                    }
                    uint8_t byte3 = (uint8_t) (imm.val & 0x00FF);
                    WriteByte2File(byte1);
                    WriteByte2File(byte2);
                    WriteByte2File(byte3);
                }
            }else if( (regd.size == SZ_WORD) && (imm.size == SZ_BYTE) ){
                if( (regd.id == GPR_ALAX) && (sgx == FALSE) ){
                    SegmentTable[stsize-1].LC += 3;    // Acc16, imm8
                    uint8_t byte1;
                    switch(inst){
                        case ADC_INST:
                            byte1 = 0x15;
                            break;
                        case ADD_INST:
                            byte1 = 0x05;
                            break;
                        case AND_INST:
                            byte1 = 0x25;
                            break;
                        case CMP_INST:
                            byte1 = 0x3D;
                            break;
                        case OR_INST:
                            byte1 = 0x0D;
                            break;
                        case SBB_INST:
                            byte1 = 0x1D;
                            break;
                        case SUB_INST:
                            byte1 = 0x2D;
                            break;
                        case XOR_INST:
                            byte1 = 0x35;
                            break;
                    }
                    uint8_t byte2 = (uint8_t) (imm.val & 0x00FF);
                    uint8_t byte3 = (uint8_t) ( (imm.val >> 8) & 0x00FF );
                    WriteByte2File(byte1);
                    WriteByte2File(byte2);
                    WriteByte2File(byte3);
                }else if( (regd.id != GPR_ALAX) && (sgx == FALSE) ){
                    SegmentTable[stsize-1].LC += 4;    // Reg16, imm8
                    uint8_t byte1 = 0x81;
                    uint8_t byte2;
                    switch(inst){
                        case ADC_INST:
                            byte2 = 0b11000000 | 0b00010000 | regd.id;
                            break;
                        case ADD_INST:
                            byte2 = 0b11000000 | 0b00000000 | regd.id;
                            break;
                        case AND_INST:
                            byte2 = 0b11000000 | 0b00100000 | regd.id;
                            break;
                        case CMP_INST:
                            byte2 = 0b11000000 | 0b00111000 | regd.id;
                            break;
                        case OR_INST:
                            byte2 = 0b11000000 | 0b00001000 | regd.id;
                            break;
                        case SBB_INST:
                            byte2 = 0b11000000 | 0b00011000 | regd.id;
                            break;
                        case SUB_INST:
                            byte2 = 0b11000000 | 0b00101000 | regd.id;
                            break;
                        case XOR_INST:
                            byte2 = 0b11000000 | 0b00110000 | regd.id;
                            break;
                    }
                    uint8_t byte3 = (uint8_t) (imm.val & 0x00FF);
                    uint8_t byte4 = 0;
                    WriteByte2File(byte1);
                    WriteByte2File(byte2);
                    WriteByte2File(byte3);
                    WriteByte2File(byte4);
                }else{
                    SegmentTable[stsize-1].LC += 3;    // Reg16, imm8_sgx
                    uint8_t byte1 = 0x83;
                    uint8_t byte2;
                    switch(inst){
                        case ADC_INST:
                            byte2 = 0b11000000 | 0b00010000 | regd.id;
                            break;
                        case ADD_INST:
                            byte2 = 0b11000000 | 0b00000000 | regd.id;
                            break;
                        case AND_INST:
                            byte2 = 0b11000000 | 0b00100000 | regd.id;
                            break;
                        case CMP_INST:
                            byte2 = 0b11000000 | 0b00111000 | regd.id;
                            break;
                        case OR_INST:
                            byte2 = 0b11000000 | 0b00001000 | regd.id;
                            break;
                        case SBB_INST:
                            byte2 = 0b11000000 | 0b00011000 | regd.id;
                            break;
                        case SUB_INST:
                            byte2 = 0b11000000 | 0b00101000 | regd.id;
                            break;
                        case XOR_INST:
                            byte2 = 0b11000000 | 0b00110000 | regd.id;
                            break;
                    }
                    uint8_t byte3 = (uint8_t) (imm.val & 0x00FF);
                    WriteByte2File(byte1);
                    WriteByte2File(byte2);
                    WriteByte2File(byte3);
                }
            }else if( (regd.size == SZ_WORD) && (imm.size == SZ_WORD) ){
                if( (regd.id == GPR_ALAX) && (sgx == FALSE) ){
                    SegmentTable[stsize-1].LC += 3;    // Acc16, imm16
                    uint8_t byte1;
                    switch(inst){
                        case ADC_INST:
                            byte1 = 0x15;
                            break;
                        case ADD_INST:
                            byte1 = 0x05;
                            break;
                        case AND_INST:
                            byte1 = 0x25;
                            break;
                        case CMP_INST:
                            byte1 = 0x3D;
                            break;
                        case OR_INST:
                            byte1 = 0x0D;
                            break;
                        case SBB_INST:
                            byte1 = 0x1D;
                            break;
                        case SUB_INST:
                            byte1 = 0x2D;
                            break;
                        case XOR_INST:
                            byte1 = 0x35;
                            break;
                    }
                    uint8_t byte2 = (uint8_t) (imm.val & 0x00FF);
                    uint8_t byte3 = (uint8_t) ( (imm.val >> 8) & 0x00FF );
                    WriteByte2File(byte1);
                    WriteByte2File(byte2);
                    WriteByte2File(byte3);
                }else if( (regd.id != GPR_ALAX) && (sgx == FALSE) ){
                    SegmentTable[stsize-1].LC += 4;    // Reg16, imm16
                    uint8_t byte1 = 0x81;
                    uint8_t byte2;
                    switch(inst){
                        case ADC_INST:
                            byte2 = 0b11000000 | 0b00010000 | regd.id;
                            break;
                        case ADD_INST:
                            byte2 = 0b11000000 | 0b00000000 | regd.id;
                            break;
                        case AND_INST:
                            byte2 = 0b11000000 | 0b00100000 | regd.id;
                            break;
                        case CMP_INST:
                            byte2 = 0b11000000 | 0b00111000 | regd.id;
                            break;
                        case OR_INST:
                            byte2 = 0b11000000 | 0b00001000 | regd.id;
                            break;
                        case SBB_INST:
                            byte2 = 0b11000000 | 0b00011000 | regd.id;
                            break;
                        case SUB_INST:
                            byte2 = 0b11000000 | 0b00101000 | regd.id;
                            break;
                        case XOR_INST:
                            byte2 = 0b11000000 | 0b00110000 | regd.id;
                            break;
                    }
                    uint8_t byte3 = (uint8_t) (imm.val & 0x00FF);
                    uint8_t byte4 = (uint8_t) ( (imm.val >> 8) & 0x00FF );
                    WriteByte2File(byte1);
                    WriteByte2File(byte2);
                    WriteByte2File(byte3);
                    WriteByte2File(byte4);
                }else{
                    SegmentTable[stsize-1].LC += 3;    // Reg16, imm16_sgx
                    uint8_t byte1 = 0x83;
                    uint8_t byte2;
                    switch(inst){
                        case ADC_INST:
                            byte2 = 0b11000000 | 0b00010000 | regd.id;
                            break;
                        case ADD_INST:
                            byte2 = 0b11000000 | 0b00000000 | regd.id;
                            break;
                        case AND_INST:
                            byte2 = 0b11000000 | 0b00100000 | regd.id;
                            break;
                        case CMP_INST:
                            byte2 = 0b11000000 | 0b00111000 | regd.id;
                            break;
                        case OR_INST:
                            byte2 = 0b11000000 | 0b00001000 | regd.id;
                            break;
                        case SBB_INST:
                            byte2 = 0b11000000 | 0b00011000 | regd.id;
                            break;
                        case SUB_INST:
                            byte2 = 0b11000000 | 0b00101000 | regd.id;
                            break;
                        case XOR_INST:
                            byte2 = 0b11000000 | 0b00110000 | regd.id;
                            break;
                    }
                    uint8_t byte3 = (uint8_t) (imm.val & 0x00FF);
                    WriteByte2File(byte1);
                    WriteByte2File(byte2);
                    WriteByte2File(byte3);
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }
            break;
        case MODE_MEM_IMM:
            sgx = CheckSignExtension(imm.val);
            if( (mem.size == SZ_BYTE) && (imm.size == SZ_BYTE) ){
                if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) ){
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 6;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = 0x80;
                        uint8_t byte3;
                        switch(inst){
                            case ADC_INST:
                                byte3 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                break;
                            case ADD_INST:
                                byte3 = (mem.mod << 6) | 0b00000000 | mem.rm;
                                break;
                            case AND_INST:
                                byte3 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                break;
                            case CMP_INST:
                                byte3 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                break;
                            case OR_INST:
                                byte3 = (mem.mod << 6) | 0b00001000 | mem.rm;
                                break;
                            case SBB_INST:
                                byte3 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                break;
                            case SUB_INST:
                                byte3 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                break;
                            case XOR_INST:
                                byte3 = (mem.mod << 6) | 0b00110000 | mem.rm;
                                break;
                        }
                        uint8_t byte4 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte5 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        uint8_t byte6 = (uint8_t) (imm.val & 0x00FF);
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                        WriteByte2File(byte5);
                        WriteByte2File(byte6);
                    }else{
                        SegmentTable[stsize-1].LC += 5;
                        uint8_t byte1 = 0x80;
                        uint8_t byte2;
                        switch(inst){
                            case ADC_INST:
                                byte2 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                break;
                            case ADD_INST:
                                byte2 = (mem.mod << 6) | 0b00000000 | mem.rm;
                                break;
                            case AND_INST:
                                byte2 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                break;
                            case CMP_INST:
                                byte2 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                break;
                            case OR_INST:
                                byte2 = (mem.mod << 6) | 0b00001000 | mem.rm;
                                break;
                            case SBB_INST:
                                byte2 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                break;
                            case SUB_INST:
                                byte2 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                break;
                            case XOR_INST:
                                byte2 = (mem.mod << 6) | 0b00110000 | mem.rm;
                                break;
                        }
                        uint8_t byte3 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        uint8_t byte5 = (uint8_t) (imm.val & 0x00FF);
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                        WriteByte2File(byte5);
                    }
                }else{
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 4;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = 0x80;
                        uint8_t byte3;
                        switch(inst){
                            case ADC_INST:
                                byte3 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                break;
                            case ADD_INST:
                                byte3 = (mem.mod << 6) | 0b00000000 | mem.rm;
                                break;
                            case AND_INST:
                                byte3 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                break;
                            case CMP_INST:
                                byte3 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                break;
                            case OR_INST:
                                byte3 = (mem.mod << 6) | 0b00001000 | mem.rm;
                                break;
                            case SBB_INST:
                                byte3 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                break;
                            case SUB_INST:
                                byte3 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                break;
                            case XOR_INST:
                                byte3 = (mem.mod << 6) | 0b00110000 | mem.rm;
                                break;
                        }
                        uint8_t byte4 = (uint8_t) (imm.val & 0x00FF);
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                    }else{
                        SegmentTable[stsize-1].LC += 3;
                        uint8_t byte1 = 0x80;
                        uint8_t byte2;
                        switch(inst){
                            case ADC_INST:
                                byte2 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                break;
                            case ADD_INST:
                                byte2 = (mem.mod << 6) | 0b00000000 | mem.rm;
                                break;
                            case AND_INST:
                                byte2 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                break;
                            case CMP_INST:
                                byte2 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                break;
                            case OR_INST:
                                byte2 = (mem.mod << 6) | 0b00001000 | mem.rm;
                                break;
                            case SBB_INST:
                                byte2 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                break;
                            case SUB_INST:
                                byte2 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                break;
                            case XOR_INST:
                                byte2 = (mem.mod << 6) | 0b00110000 | mem.rm;
                                break;
                        }
                        uint8_t byte3 = (uint8_t) (imm.val & 0x00FF);
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                    }
                }
            }else if( (mem.size == SZ_WORD) && (imm.size == SZ_BYTE) ){
                if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) ){
                    if(sgx == TRUE){
                        if(isSOP == SET){
                            SegmentTable[stsize-1].LC += 6;
                            uint8_t byte1 = SOP;
                            uint8_t byte2 = 0x83;
                            uint8_t byte3;
                            switch(inst){
                                case ADC_INST:
                                    byte3 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                    break;
                                case ADD_INST:
                                    byte3 = (mem.mod << 6) | 0b00000000 | mem.rm;
                                    break;
                                case AND_INST:
                                    byte3 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                    break;
                                case CMP_INST:
                                    byte3 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                    break;
                                case OR_INST:
                                    byte3 = (mem.mod << 6) | 0b00001000 | mem.rm;
                                    break;
                                case SBB_INST:
                                    byte3 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                    break;
                                case SUB_INST:
                                    byte3 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                    break;
                                case XOR_INST:
                                    byte3 = (mem.mod << 6) | 0b00110000 | mem.rm;
                                    break;
                            }
                            uint8_t byte4 = (uint8_t) (mem.disp & 0x00FF);
                            uint8_t byte5 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                            uint8_t byte6 = (uint8_t) (imm.val & 0x00FF);
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                            WriteByte2File(byte4);
                            WriteByte2File(byte5);
                            WriteByte2File(byte6);
                        }else{
                            SegmentTable[stsize-1].LC += 5;
                            uint8_t byte1 = 0x83;
                            uint8_t byte2;
                            switch(inst){
                                case ADC_INST:
                                    byte2 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                    break;
                                case ADD_INST:
                                    byte2 = (mem.mod << 6) | 0b00000000 | mem.rm;
                                    break;
                                case AND_INST:
                                    byte2 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                    break;
                                case CMP_INST:
                                    byte2 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                    break;
                                case OR_INST:
                                    byte2 = (mem.mod << 6) | 0b00001000 | mem.rm;
                                    break;
                                case SBB_INST:
                                    byte2 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                    break;
                                case SUB_INST:
                                    byte2 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                    break;
                                case XOR_INST:
                                    byte2 = (mem.mod << 6) | 0b00110000 | mem.rm;
                                    break;
                            }
                            uint8_t byte3 = (uint8_t) (mem.disp & 0x00FF);
                            uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                            uint8_t byte5 = (uint8_t) (imm.val & 0x00FF);
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                            WriteByte2File(byte4);
                            WriteByte2File(byte5);
                        }
                    }else{
                        if(isSOP == SET){
                            SegmentTable[stsize-1].LC += 7;
                            uint8_t byte1 = SOP;
                            uint8_t byte2 = 0x81;
                            uint8_t byte3;
                            switch(inst){
                                case ADC_INST:
                                    byte3 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                    break;
                                case ADD_INST:
                                    byte3 = (mem.mod << 6) | 0b00000000 | mem.rm;
                                    break;
                                case AND_INST:
                                    byte3 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                    break;
                                case CMP_INST:
                                    byte3 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                    break;
                                case OR_INST:
                                    byte3 = (mem.mod << 6) | 0b00001000 | mem.rm;
                                    break;
                                case SBB_INST:
                                    byte3 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                    break;
                                case SUB_INST:
                                    byte3 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                    break;
                                case XOR_INST:
                                    byte3 = (mem.mod << 6) | 0b00110000 | mem.rm;
                                    break;
                            }
                            uint8_t byte4 = (uint8_t) (mem.disp & 0x00FF);
                            uint8_t byte5 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                            uint8_t byte6 = (uint8_t) (imm.val & 0x00FF);
                            uint8_t byte7 = (uint8_t) ( (imm.val >> 8) & 0x00FF );
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                            WriteByte2File(byte4);
                            WriteByte2File(byte5);
                            WriteByte2File(byte6);
                            WriteByte2File(byte7);
                        }else{
                            SegmentTable[stsize-1].LC += 6;
                            uint8_t byte1 = 0x81;
                            uint8_t byte2;
                            switch(inst){
                                case ADC_INST:
                                    byte2 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                    break;
                                case ADD_INST:
                                    byte2 = (mem.mod << 6) | 0b00000000 | mem.rm;
                                    break;
                                case AND_INST:
                                    byte2 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                    break;
                                case CMP_INST:
                                    byte2 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                    break;
                                case OR_INST:
                                    byte2 = (mem.mod << 6) | 0b00001000 | mem.rm;
                                    break;
                                case SBB_INST:
                                    byte2 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                    break;
                                case SUB_INST:
                                    byte2 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                    break;
                                case XOR_INST:
                                    byte2 = (mem.mod << 6) | 0b00110000 | mem.rm;
                                    break;
                            }
                            uint8_t byte3 = (uint8_t) (mem.disp & 0x00FF);
                            uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                            uint8_t byte5 = (uint8_t) (imm.val & 0x00FF);
                            uint8_t byte6 = (uint8_t) ( (imm.val >> 8) & 0x00FF );
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                            WriteByte2File(byte4);
                            WriteByte2File(byte5);
                            WriteByte2File(byte6);
                        }
                    }
                }else{
                    if(sgx == TRUE){
                        if(isSOP == SET){
                            SegmentTable[stsize-1].LC += 4;
                            uint8_t byte1 = SOP;
                            uint8_t byte2 = 0x83;
                            uint8_t byte3;
                            switch(inst){
                                case ADC_INST:
                                    byte3 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                    break;
                                case ADD_INST:
                                    byte3 = (mem.mod << 6) | 0b00000000 | mem.rm;
                                    break;
                                case AND_INST:
                                    byte3 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                    break;
                                case CMP_INST:
                                    byte3 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                    break;
                                case OR_INST:
                                    byte3 = (mem.mod << 6) | 0b00001000 | mem.rm;
                                    break;
                                case SBB_INST:
                                    byte3 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                    break;
                                case SUB_INST:
                                    byte3 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                    break;
                                case XOR_INST:
                                    byte3 = (mem.mod << 6) | 0b00110000 | mem.rm;
                                    break;
                            }
                            uint8_t byte4 = (uint8_t) (imm.val & 0x00FF);
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                            WriteByte2File(byte4);
                        }else{
                            SegmentTable[stsize-1].LC += 3;
                            uint8_t byte1 = 0x83;
                            uint8_t byte2;
                            switch(inst){
                                case ADC_INST:
                                    byte2 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                    break;
                                case ADD_INST:
                                    byte2 = (mem.mod << 6) | 0b00000000 | mem.rm;
                                    break;
                                case AND_INST:
                                    byte2 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                    break;
                                case CMP_INST:
                                    byte2 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                    break;
                                case OR_INST:
                                    byte2 = (mem.mod << 6) | 0b00001000 | mem.rm;
                                    break;
                                case SBB_INST:
                                    byte2 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                    break;
                                case SUB_INST:
                                    byte2 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                    break;
                                case XOR_INST:
                                    byte2 = (mem.mod << 6) | 0b00110000 | mem.rm;
                                    break;
                            }
                            uint8_t byte3 = (uint8_t) (imm.val & 0x00FF);
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                        }
                    }else{
                        if(isSOP == SET){
                            SegmentTable[stsize-1].LC += 5;
                            uint8_t byte1 = SOP;
                            uint8_t byte2 = 0x81;
                            uint8_t byte3;
                            switch(inst){
                                case ADC_INST:
                                    byte3 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                    break;
                                case ADD_INST:
                                    byte3 = (mem.mod << 6) | 0b00000000 | mem.rm;
                                    break;
                                case AND_INST:
                                    byte3 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                    break;
                                case CMP_INST:
                                    byte3 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                    break;
                                case OR_INST:
                                    byte3 = (mem.mod << 6) | 0b00001000 | mem.rm;
                                    break;
                                case SBB_INST:
                                    byte3 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                    break;
                                case SUB_INST:
                                    byte3 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                    break;
                                case XOR_INST:
                                    byte3 = (mem.mod << 6) | 0b00110000 | mem.rm;
                                    break;
                            }
                            uint8_t byte4 = (uint8_t) (imm.val & 0x00FF);
                            uint8_t byte5 = (uint8_t) ( (imm.val >> 8) & 0x00FF );
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                            WriteByte2File(byte4);
                            WriteByte2File(byte5);
                        }else{
                            SegmentTable[stsize-1].LC += 4;
                            uint8_t byte1 = 0x81;
                            uint8_t byte2;
                            switch(inst){
                                case ADC_INST:
                                    byte2 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                    break;
                                case ADD_INST:
                                    byte2 = (mem.mod << 6) | 0b00000000 | mem.rm;
                                    break;
                                case AND_INST:
                                    byte2 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                    break;
                                case CMP_INST:
                                    byte2 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                    break;
                                case OR_INST:
                                    byte2 = (mem.mod << 6) | 0b00001000 | mem.rm;
                                    break;
                                case SBB_INST:
                                    byte2 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                    break;
                                case SUB_INST:
                                    byte2 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                    break;
                                case XOR_INST:
                                    byte2 = (mem.mod << 6) | 0b00110000 | mem.rm;
                                    break;
                            }
                            uint8_t byte3 = (uint8_t) (imm.val & 0x00FF);
                            uint8_t byte4 = (uint8_t) ( (imm.val >> 8) & 0x00FF );
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                            WriteByte2File(byte4);
                        }
                    }
                }
            }else if( (mem.size == SZ_WORD) && (imm.size == SZ_WORD) ){
                if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) ){
                    if(sgx == TRUE){
                        if(isSOP == SET){
                            SegmentTable[stsize-1].LC += 6;
                            uint8_t byte1 = SOP;
                            uint8_t byte2 = 0x83;
                            uint8_t byte3;
                            switch(inst){
                                case ADC_INST:
                                    byte3 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                    break;
                                case ADD_INST:
                                    byte3 = (mem.mod << 6) | 0b00000000 | mem.rm;
                                    break;
                                case AND_INST:
                                    byte3 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                    break;
                                case CMP_INST:
                                    byte3 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                    break;
                                case OR_INST:
                                    byte3 = (mem.mod << 6) | 0b00001000 | mem.rm;
                                    break;
                                case SBB_INST:
                                    byte3 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                    break;
                                case SUB_INST:
                                    byte3 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                    break;
                                case XOR_INST:
                                    byte3 = (mem.mod << 6) | 0b00110000 | mem.rm;
                                    break;
                            }
                            uint8_t byte4 = (uint8_t) (mem.disp & 0x00FF);
                            uint8_t byte5 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                            uint8_t byte6 = (uint8_t) (imm.val & 0x00FF);
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                            WriteByte2File(byte4);
                            WriteByte2File(byte5);
                            WriteByte2File(byte6);
                        }else{
                            SegmentTable[stsize-1].LC += 5;
                            uint8_t byte1 = 0x83;
                            uint8_t byte2;
                            switch(inst){
                                case ADC_INST:
                                    byte2 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                    break;
                                case ADD_INST:
                                    byte2 = (mem.mod << 6) | 0b00000000 | mem.rm;
                                    break;
                                case AND_INST:
                                    byte2 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                    break;
                                case CMP_INST:
                                    byte2 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                    break;
                                case OR_INST:
                                    byte2 = (mem.mod << 6) | 0b00001000 | mem.rm;
                                    break;
                                case SBB_INST:
                                    byte2 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                    break;
                                case SUB_INST:
                                    byte2 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                    break;
                                case XOR_INST:
                                    byte2 = (mem.mod << 6) | 0b00110000 | mem.rm;
                                    break;
                            }
                            uint8_t byte3 = (uint8_t) (mem.disp & 0x00FF);
                            uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                            uint8_t byte5 = (uint8_t) (imm.val & 0x00FF);
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                            WriteByte2File(byte4);
                            WriteByte2File(byte5);
                        }
                    }else{
                        if(isSOP == SET){
                            SegmentTable[stsize-1].LC += 7;
                            uint8_t byte1 = SOP;
                            uint8_t byte2 = 0x81;
                            uint8_t byte3;
                            switch(inst){
                                case ADC_INST:
                                    byte3 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                    break;
                                case ADD_INST:
                                    byte3 = (mem.mod << 6) | 0b00000000 | mem.rm;
                                    break;
                                case AND_INST:
                                    byte3 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                    break;
                                case CMP_INST:
                                    byte3 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                    break;
                                case OR_INST:
                                    byte3 = (mem.mod << 6) | 0b00001000 | mem.rm;
                                    break;
                                case SBB_INST:
                                    byte3 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                    break;
                                case SUB_INST:
                                    byte3 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                    break;
                                case XOR_INST:
                                    byte3 = (mem.mod << 6) | 0b00110000 | mem.rm;
                                    break;
                            }
                            uint8_t byte4 = (uint8_t) (mem.disp & 0x00FF);
                            uint8_t byte5 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                            uint8_t byte6 = (uint8_t) (imm.val & 0x00FF);
                            uint8_t byte7 = (uint8_t) ( (imm.val >> 8) & 0x00FF );
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                            WriteByte2File(byte4);
                            WriteByte2File(byte5);
                            WriteByte2File(byte6);
                            WriteByte2File(byte7);
                        }else{
                            SegmentTable[stsize-1].LC += 6;
                            uint8_t byte1 = 0x81;
                            uint8_t byte2;
                            switch(inst){
                                case ADC_INST:
                                    byte2 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                    break;
                                case ADD_INST:
                                    byte2 = (mem.mod << 6) | 0b00000000 | mem.rm;
                                    break;
                                case AND_INST:
                                    byte2 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                    break;
                                case CMP_INST:
                                    byte2 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                    break;
                                case OR_INST:
                                    byte2 = (mem.mod << 6) | 0b00001000 | mem.rm;
                                    break;
                                case SBB_INST:
                                    byte2 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                    break;
                                case SUB_INST:
                                    byte2 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                    break;
                                case XOR_INST:
                                    byte2 = (mem.mod << 6) | 0b00110000 | mem.rm;
                                    break;
                            }
                            uint8_t byte3 = (uint8_t) (mem.disp & 0x00FF);
                            uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                            uint8_t byte5 = (uint8_t) (imm.val & 0x00FF);
                            uint8_t byte6 = (uint8_t) ( (imm.val >> 8) & 0x00FF );
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                            WriteByte2File(byte4);
                            WriteByte2File(byte5);
                            WriteByte2File(byte6);
                        }
                    }
                }else{
                    if(sgx == TRUE){
                        if(isSOP == SET){
                            SegmentTable[stsize-1].LC += 4;
                            uint8_t byte1 = SOP;
                            uint8_t byte2 = 0x83;
                            uint8_t byte3;
                            switch(inst){
                                case ADC_INST:
                                    byte3 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                    break;
                                case ADD_INST:
                                    byte3 = (mem.mod << 6) | 0b00000000 | mem.rm;
                                    break;
                                case AND_INST:
                                    byte3 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                    break;
                                case CMP_INST:
                                    byte3 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                    break;
                                case OR_INST:
                                    byte3 = (mem.mod << 6) | 0b00001000 | mem.rm;
                                    break;
                                case SBB_INST:
                                    byte3 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                    break;
                                case SUB_INST:
                                    byte3 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                    break;
                                case XOR_INST:
                                    byte3 = (mem.mod << 6) | 0b00110000 | mem.rm;
                                    break;
                            }
                            uint8_t byte4 = (uint8_t) (imm.val & 0x00FF);
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                            WriteByte2File(byte4);
                        }else{
                            SegmentTable[stsize-1].LC += 3;
                            uint8_t byte1 = 0x83;
                            uint8_t byte2;
                            switch(inst){
                                case ADC_INST:
                                    byte2 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                    break;
                                case ADD_INST:
                                    byte2 = (mem.mod << 6) | 0b00000000 | mem.rm;
                                    break;
                                case AND_INST:
                                    byte2 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                    break;
                                case CMP_INST:
                                    byte2 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                    break;
                                case OR_INST:
                                    byte2 = (mem.mod << 6) | 0b00001000 | mem.rm;
                                    break;
                                case SBB_INST:
                                    byte2 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                    break;
                                case SUB_INST:
                                    byte2 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                    break;
                                case XOR_INST:
                                    byte2 = (mem.mod << 6) | 0b00110000 | mem.rm;
                                    break;
                            }
                            uint8_t byte3 = (uint8_t) (imm.val & 0x00FF);
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                        }
                    }else{
                        if(isSOP == SET){
                            SegmentTable[stsize-1].LC += 5;
                            uint8_t byte1 = SOP;
                            uint8_t byte2 = 0x81;
                            uint8_t byte3;
                            switch(inst){
                                case ADC_INST:
                                    byte3 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                    break;
                                case ADD_INST:
                                    byte3 = (mem.mod << 6) | 0b00000000 | mem.rm;
                                    break;
                                case AND_INST:
                                    byte3 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                    break;
                                case CMP_INST:
                                    byte3 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                    break;
                                case OR_INST:
                                    byte3 = (mem.mod << 6) | 0b00001000 | mem.rm;
                                    break;
                                case SBB_INST:
                                    byte3 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                    break;
                                case SUB_INST:
                                    byte3 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                    break;
                                case XOR_INST:
                                    byte3 = (mem.mod << 6) | 0b00110000 | mem.rm;
                                    break;
                            }
                            uint8_t byte4 = (uint8_t) (imm.val & 0x00FF);
                            uint8_t byte5 = (uint8_t) ( (imm.val >> 8) & 0x00FF );
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                            WriteByte2File(byte4);
                            WriteByte2File(byte5);
                        }else{
                            SegmentTable[stsize-1].LC += 4;
                            uint8_t byte1 = 0x81;
                            uint8_t byte2;
                            switch(inst){
                                case ADC_INST:
                                    byte2 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                    break;
                                case ADD_INST:
                                    byte2 = (mem.mod << 6) | 0b00000000 | mem.rm;
                                    break;
                                case AND_INST:
                                    byte2 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                    break;
                                case CMP_INST:
                                    byte2 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                    break;
                                case OR_INST:
                                    byte2 = (mem.mod << 6) | 0b00001000 | mem.rm;
                                    break;
                                case SBB_INST:
                                    byte2 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                    break;
                                case SUB_INST:
                                    byte2 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                    break;
                                case XOR_INST:
                                    byte2 = (mem.mod << 6) | 0b00110000 | mem.rm;
                                    break;
                            }
                            uint8_t byte3 = (uint8_t) (imm.val & 0x00FF);
                            uint8_t byte4 = (uint8_t) ( (imm.val >> 8) & 0x00FF );
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                            WriteByte2File(byte4);
                        }
                    }
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }
            if(isSOP == SET)
                isSOP = NSET;
            break;
        default:
            PrintError(COLOR_BOLDRED, "Line %d :: Instruction-Operand mismatch!\n", LN);
            return FALSE;
            break;
    }

    return TRUE;
}

Boolean_t EncodeShiftRotateBlock(uint8_t mode, uint8_t inst, Register_t regd, Register_t regs, Memory_t mem)
{
    switch(mode){
        case MODE_REG:
            if( (regd.size == SZ_BYTE) || (regd.size == SZ_WORD) ){
                SegmentTable[stsize-1].LC += 2;
                uint8_t byte1 = (regd.size == SZ_BYTE) ? 0xD0 : 0xD1;
                uint8_t byte2;
                switch(inst){
                    case RCL_INST:
                        byte2 = 0b11000000 | 0b00010000 | regd.id;
                        break;
                    case RCR_INST:
                        byte2 = 0b11000000 | 0b00011000 | regd.id;
                        break;
                    case ROL_INST:
                        byte2 = 0b11000000 | 0b00000000 | regd.id;
                        break;
                    case ROR_INST:
                        byte2 = 0b11000000 | 0b00001000 | regd.id;
                        break;
                    case SAL_INST:
                        byte2 = 0b11000000 | 0b00100000 | regd.id;
                        break;
                    case SAR_INST:
                        byte2 = 0b11000000 | 0b00111000 | regd.id;
                        break;
                    case SHL_INST:
                        byte2 = 0b11000000 | 0b00100000 | regd.id;
                        break;
                    case SHR_INST:
                        byte2 = 0b11000000 | 0b00101000 | regd.id;
                        break;
                }
                WriteByte2File(byte1);
                WriteByte2File(byte2);
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }
            break;
        case MODE_REG_REG:
            if( (regd.size == SZ_BYTE) || (regd.size == SZ_WORD) ){
                if( (regs.id == GPR_CLCX) && (regs.size == SZ_BYTE) ){
                    SegmentTable[stsize-1].LC += 2;
                    uint8_t byte1 = (regd.size == SZ_BYTE) ? 0xD2 : 0xD3;
                    uint8_t byte2;
                    switch(inst){
                        case RCL_INST:
                            byte2 = 0b11000000 | 0b00010000 | regd.id;
                            break;
                        case RCR_INST:
                            byte2 = 0b11000000 | 0b00011000 | regd.id;
                            break;
                        case ROL_INST:
                            byte2 = 0b11000000 | 0b00000000 | regd.id;
                            break;
                        case ROR_INST:
                            byte2 = 0b11000000 | 0b00001000 | regd.id;
                            break;
                        case SAL_INST:
                            byte2 = 0b11000000 | 0b00100000 | regd.id;
                            break;
                        case SAR_INST:
                            byte2 = 0b11000000 | 0b00111000 | regd.id;
                            break;
                        case SHL_INST:
                            byte2 = 0b11000000 | 0b00100000 | regd.id;
                            break;
                        case SHR_INST:
                            byte2 = 0b11000000 | 0b00101000 | regd.id;
                            break;
                    }
                    WriteByte2File(byte1);
                    WriteByte2File(byte2);
                }else{
                    PrintError(COLOR_BOLDRED, "Line %d :: Operand type mismatch!\n", LN);
                    return FALSE;
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }
            break;
        case MODE_MEM:
            if( (mem.size == SZ_BYTE) || (mem.size == SZ_WORD) ){
                if( ((mem.mod == 0) && (mem.rm == 6)) || (mem.mod != 0) ){
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 5;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = (mem.size == SZ_BYTE) ? 0xD0 : 0xD1;
                        uint8_t byte3;
                        switch(inst){
                            case RCL_INST:
                                byte3 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                break;
                            case RCR_INST:
                                byte3 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                break;
                            case ROL_INST:
                                byte3 = (mem.mod << 6) | 0b00000000 | mem.rm;
                                break;
                            case ROR_INST:
                                byte3 = (mem.mod << 6) | 0b00001000 | mem.rm;
                                break;
                            case SAL_INST:
                                byte3 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                break;
                            case SAR_INST:
                                byte3 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                break;
                            case SHL_INST:
                                byte3 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                break;
                            case SHR_INST:
                                byte3 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                break;
                        }
                        uint8_t byte4 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte5 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                        WriteByte2File(byte5);
                    }else{
                        SegmentTable[stsize-1].LC += 4;
                        uint8_t byte1 = (mem.size == SZ_BYTE) ? 0xD0 : 0xD1;
                        uint8_t byte2;
                        switch(inst){
                            case RCL_INST:
                                byte2 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                break;
                            case RCR_INST:
                                byte2 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                break;
                            case ROL_INST:
                                byte2 = (mem.mod << 6) | 0b00000000 | mem.rm;
                                break;
                            case ROR_INST:
                                byte2 = (mem.mod << 6) | 0b00001000 | mem.rm;
                                break;
                            case SAL_INST:
                                byte2 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                break;
                            case SAR_INST:
                                byte2 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                break;
                            case SHL_INST:
                                byte2 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                break;
                            case SHR_INST:
                                byte2 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                break;
                        }
                        uint8_t byte3 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                    }
                }else{
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 3;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = (mem.size == SZ_BYTE) ? 0xD0 : 0xD1;
                        uint8_t byte3;
                        switch(inst){
                            case RCL_INST:
                                byte3 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                break;
                            case RCR_INST:
                                byte3 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                break;
                            case ROL_INST:
                                byte3 = (mem.mod << 6) | 0b00000000 | mem.rm;
                                break;
                            case ROR_INST:
                                byte3 = (mem.mod << 6) | 0b00001000 | mem.rm;
                                break;
                            case SAL_INST:
                                byte3 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                break;
                            case SAR_INST:
                                byte3 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                break;
                            case SHL_INST:
                                byte3 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                break;
                            case SHR_INST:
                                byte3 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                break;
                        }
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                    }else{
                        SegmentTable[stsize-1].LC += 2;
                        uint8_t byte1 = (mem.size == SZ_BYTE) ? 0xD0 : 0xD1;
                        uint8_t byte2;
                        switch(inst){
                            case RCL_INST:
                                byte2 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                break;
                            case RCR_INST:
                                byte2 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                break;
                            case ROL_INST:
                                byte2 = (mem.mod << 6) | 0b00000000 | mem.rm;
                                break;
                            case ROR_INST:
                                byte2 = (mem.mod << 6) | 0b00001000 | mem.rm;
                                break;
                            case SAL_INST:
                                byte2 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                break;
                            case SAR_INST:
                                byte2 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                break;
                            case SHL_INST:
                                byte2 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                break;
                            case SHR_INST:
                                byte2 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                break;
                        }
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                    }
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }
            if(isSOP == SET)
                isSOP = NSET;
            break;
        case MODE_MEM_REG:
            if( (mem.size == SZ_BYTE) || (mem.size == SZ_WORD) ){
                if( (regs.id == GPR_CLCX) && (regs.size == SZ_BYTE) ){
                    if( ((mem.mod == 0) && (mem.rm == 6)) || (mem.mod != 0) ){
                        if(isSOP == SET){
                            SegmentTable[stsize-1].LC += 5;
                            uint8_t byte1 = SOP;
                            uint8_t byte2 = (mem.size == SZ_BYTE) ? 0xD2 : 0xD3;
                            uint8_t byte3;
                            switch(inst){
                                case RCL_INST:
                                    byte3 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                    break;
                                case RCR_INST:
                                    byte3 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                    break;
                                case ROL_INST:
                                    byte3 = (mem.mod << 6) | 0b00000000 | mem.rm;
                                    break;
                                case ROR_INST:
                                    byte3 = (mem.mod << 6) | 0b00001000 | mem.rm;
                                    break;
                                case SAL_INST:
                                    byte3 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                    break;
                                case SAR_INST:
                                    byte3 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                    break;
                                case SHL_INST:
                                    byte3 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                    break;
                                case SHR_INST:
                                    byte3 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                    break;
                            }
                            uint8_t byte4 = (uint8_t) (mem.disp & 0x00FF);
                            uint8_t byte5 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                            WriteByte2File(byte4);
                            WriteByte2File(byte5);
                        }else{
                            SegmentTable[stsize-1].LC += 4;
                            uint8_t byte1 = (mem.size == SZ_BYTE) ? 0xD2 : 0xD3;
                            uint8_t byte2;
                            switch(inst){
                                case RCL_INST:
                                    byte2 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                    break;
                                case RCR_INST:
                                    byte2 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                    break;
                                case ROL_INST:
                                    byte2 = (mem.mod << 6) | 0b00000000 | mem.rm;
                                    break;
                                case ROR_INST:
                                    byte2 = (mem.mod << 6) | 0b00001000 | mem.rm;
                                    break;
                                case SAL_INST:
                                    byte2 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                    break;
                                case SAR_INST:
                                    byte2 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                    break;
                                case SHL_INST:
                                    byte2 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                    break;
                                case SHR_INST:
                                    byte2 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                    break;
                            }
                            uint8_t byte3 = (uint8_t) (mem.disp & 0x00FF);
                            uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                            WriteByte2File(byte4);
                        }
                    }else{
                        if(isSOP == SET){
                            SegmentTable[stsize-1].LC += 3;
                            uint8_t byte1 = SOP;
                            uint8_t byte2 = (mem.size == SZ_BYTE) ? 0xD2 : 0xD3;
                            uint8_t byte3;
                            switch(inst){
                                case RCL_INST:
                                    byte3 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                    break;
                                case RCR_INST:
                                    byte3 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                    break;
                                case ROL_INST:
                                    byte3 = (mem.mod << 6) | 0b00000000 | mem.rm;
                                    break;
                                case ROR_INST:
                                    byte3 = (mem.mod << 6) | 0b00001000 | mem.rm;
                                    break;
                                case SAL_INST:
                                    byte3 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                    break;
                                case SAR_INST:
                                    byte3 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                    break;
                                case SHL_INST:
                                    byte3 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                    break;
                                case SHR_INST:
                                    byte3 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                    break;
                            }
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                            WriteByte2File(byte3);
                        }else{
                            SegmentTable[stsize-1].LC += 2;
                            uint8_t byte1 = (mem.size == SZ_BYTE) ? 0xD2 : 0xD3;
                            uint8_t byte2;
                            switch(inst){
                                case RCL_INST:
                                    byte2 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                    break;
                                case RCR_INST:
                                    byte2 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                    break;
                                case ROL_INST:
                                    byte2 = (mem.mod << 6) | 0b00000000 | mem.rm;
                                    break;
                                case ROR_INST:
                                    byte2 = (mem.mod << 6) | 0b00001000 | mem.rm;
                                    break;
                                case SAL_INST:
                                    byte2 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                    break;
                                case SAR_INST:
                                    byte2 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                    break;
                                case SHL_INST:
                                    byte2 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                    break;
                                case SHR_INST:
                                    byte2 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                    break;
                            }
                            WriteByte2File(byte1);
                            WriteByte2File(byte2);
                        }
                    }
                }else{
                    PrintError(COLOR_BOLDRED, "Line %d :: Operand type mismatch!\n", LN);
                    return FALSE;
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }
            if(isSOP == SET)
                isSOP = NSET;
            break;
        default:
            PrintError(COLOR_BOLDRED, "Line %d :: Instruction-Operand mismatch!\n", LN);
            return FALSE;
            break;
    }
    return TRUE;
}

Boolean_t EncodeInterrupt(Immediate_t imm)
{
    if(imm.size == SZ_BYTE){
        if(imm.val == 3){
            SegmentTable[stsize-1].LC += 1;
            uint8_t byte1 = 0xCC;
            WriteByte2File(byte1);
        }else{
            SegmentTable[stsize-1].LC += 2;
            uint8_t byte1 = 0xCD;
            uint8_t byte2 = (uint8_t) (imm.val & 0x00FF);
            WriteByte2File(byte1);
            WriteByte2File(byte2);
        }
    }else{
        PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
        return FALSE;
    }
    return TRUE;
}

Boolean_t EncodeReturnBlock(uint8_t mode, uint8_t inst, Immediate_t imm)
{
    switch(mode){
        case MODE_NO_OPERAND:
            SegmentTable[stsize-1].LC += 1;
            uint8_t byte1 = (inst == RETN_INST) ? 0xC3 : 0xCB;
            WriteByte2File(byte1);
            break;
        case MODE_IMM:
            if(imm.size == SZ_WORD){
                SegmentTable[stsize-1].LC += 3;
                uint8_t byte1 = (inst == RETN_INST) ? 0xC2 : 0xCA;
                uint8_t byte2 = (uint8_t) (imm.val & 0x00FF);
                uint8_t byte3 = (uint8_t) ( (imm.val >> 8) & 0x00FF );
                WriteByte2File(byte1);
                WriteByte2File(byte2);
                WriteByte2File(byte3);
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }
        default:
            PrintError(COLOR_BOLDRED, "Line %d :: Instruction-Operand Mismatch!\n", LN);
            return FALSE;
    }

    return TRUE;
}

Boolean_t EncodeTest(uint8_t mode, Register_t regd, Register_t regs, Memory_t mem, Immediate_t imm)
{
    switch(mode){
        case MODE_REG_REG:
            if( regd.size == regs.size ){
                SegmentTable[stsize-1].LC += 2;
                uint8_t byte1 = (regd.size == SZ_BYTE) ? 0x84 : 0x85;
                uint8_t byte2 = 0b11000000 | (regs.id << 3) | regd.id;
                WriteByte2File(byte1);
                WriteByte2File(byte2);
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }
            break;
        case MODE_REG_MEM:
            if( regd.size == mem.size ){
                if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) ){
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 5;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = (regd.size == SZ_BYTE) ? 0x84 : 0x85;
                        uint8_t byte3 = (mem.mod << 6) | (regd.id << 3) | mem.rm;
                        uint8_t byte4 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte5 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                        WriteByte2File(byte5);
                    }else{
                        SegmentTable[stsize-1].LC += 4;
                        uint8_t byte1 = (regd.size == SZ_BYTE) ? 0x84 : 0x85;
                        uint8_t byte2 = (mem.mod << 6) | (regd.id << 3) | mem.rm;
                        uint8_t byte3 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                    }
                }else{
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 3;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = (regd.size == SZ_BYTE) ? 0x84 : 0x85;
                        uint8_t byte3 = (mem.mod << 6) | (regd.id << 3) | mem.rm;
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                    }else{
                        SegmentTable[stsize-1].LC += 2;
                        uint8_t byte1 = (regd.size == SZ_BYTE) ? 0x84 : 0x85;
                        uint8_t byte2 = (mem.mod << 6) | (regd.id << 3) | mem.rm;
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                    }
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }
            if(isSOP == SET)
                isSOP = NSET;
            break;
        case MODE_REG_IMM:
            if(regd.size == SZ_BYTE){
                if(imm.size == SZ_BYTE){
                    if(regd.id == GPR_ALAX){
                        SegmentTable[stsize-1].LC += 2;
                        uint8_t byte1 = 0xA8;
                        uint8_t byte2 = (uint8_t) (imm.val & 0x00FF);
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                    }else{
                        SegmentTable[stsize-1].LC += 3;
                        uint8_t byte1 = 0xF6;
                        uint8_t byte2 = 0b11000000 | regd.id;
                        uint8_t byte3 = (uint8_t) (imm.val & 0x00FF);
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                    }
                }else{
                    PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                    return FALSE;
                }
            }else if(regd.size == SZ_WORD){
                if(regd.id == GPR_ALAX){
                    SegmentTable[stsize-1].LC += 3;
                    uint8_t byte1 = 0xA9;
                    uint8_t byte2 = (uint8_t) (imm.val & 0x00FF);
                    uint8_t byte3 = (imm.size == SZ_BYTE) ? 0 : (uint8_t) ( (imm.val >> 8) & 0x00FF );
                    WriteByte2File(byte1);
                    WriteByte2File(byte2);
                    WriteByte2File(byte3);
                }
                else{
                    SegmentTable[stsize-1].LC += 4;
                    uint8_t byte1 = 0xF7;
                    uint8_t byte2 = 0b11000000 | regd.id;
                    uint8_t byte3 = (uint8_t) (imm.val & 0x00FF);
                    uint8_t byte4 = (imm.size == SZ_BYTE) ? 0 : (uint8_t) ( (imm.val >> 8) & 0x00FF );
                    WriteByte2File(byte1);
                    WriteByte2File(byte2);
                    WriteByte2File(byte3);
                    WriteByte2File(byte4);
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Internal Error!\n", LN);
                return FALSE;
            }
            break;
        case MODE_MEM_IMM:
            if( (mem.size == SZ_BYTE) && (imm.size == SZ_BYTE) ){
                if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) ){
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 6;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = 0xF6;
                        uint8_t byte3 = (mem.mod << 6) | mem.rm;
                        uint8_t byte4 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte5 = (uint8_t) ( (mem.disp >>8) & 0x00FF );
                        uint8_t byte6 = (uint8_t) (imm.val & 0x00FF);
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                        WriteByte2File(byte5);
                        WriteByte2File(byte6);
                    }else{
                        SegmentTable[stsize-1].LC += 5;
                        uint8_t byte1 = 0xF6;
                        uint8_t byte2 = (mem.mod << 6) | mem.rm;
                        uint8_t byte3 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte4 = (uint8_t) ( (mem.disp >>8) & 0x00FF );
                        uint8_t byte5 = (uint8_t) (imm.val & 0x00FF);
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                        WriteByte2File(byte5);
                    }
                }else{
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 4;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = 0xF6;
                        uint8_t byte3 = (mem.mod << 6) | mem.rm;
                        uint8_t byte4 = (uint8_t) (imm.val & 0x00FF);
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                    }else{
                        SegmentTable[stsize-1].LC += 3;
                        uint8_t byte1 = 0xF6;
                        uint8_t byte2 = (mem.mod << 6) | mem.rm;
                        uint8_t byte3 = (uint8_t) (imm.val & 0x00FF);
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                    }
                }
            }else if( ((mem.size == SZ_WORD) && (imm.size == SZ_BYTE)) || ((mem.size == SZ_WORD) && (imm.size == SZ_WORD)) ){
                if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) ){
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 7;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = 0xF7;
                        uint8_t byte3 = (mem.mod << 6) | mem.rm;
                        uint8_t byte4 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte5 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        uint8_t byte6 = (uint8_t) (imm.val & 0x00FF);
                        uint8_t byte7 = (uint8_t) ( (imm.val >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                        WriteByte2File(byte5);
                        WriteByte2File(byte6);
                        WriteByte2File(byte7);
                    }else{
                        SegmentTable[stsize-1].LC += 6;
                        uint8_t byte1 = 0xF7;
                        uint8_t byte2 = (mem.mod << 6) | mem.rm;
                        uint8_t byte3 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        uint8_t byte5 = (uint8_t) (imm.val & 0x00FF);
                        uint8_t byte6 = (uint8_t) ( (imm.val >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                        WriteByte2File(byte5);
                        WriteByte2File(byte6);
                    }
                }
                else
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 5;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = 0xF7;
                        uint8_t byte3 = (mem.mod << 6) | mem.rm;
                        uint8_t byte4 = (uint8_t) (imm.val & 0x00FF);
                        uint8_t byte5 = (uint8_t) ( (imm.val >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                        WriteByte2File(byte5);
                    }else{
                        SegmentTable[stsize-1].LC += 4;
                        uint8_t byte1 = 0xF7;
                        uint8_t byte2 = (mem.mod << 6) | mem.rm;
                        uint8_t byte3 = (uint8_t) (imm.val & 0x00FF);
                        uint8_t byte4 = (uint8_t) ( (imm.val >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                    }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }
            if(isSOP == SET)
                isSOP = NSET;
            break;
        default:
            PrintError(COLOR_BOLDRED, "Line %d :: Instruction-Operand mismatch!\n", LN);
            return FALSE;
            break;
    }

    return TRUE;
}

Boolean_t EncodeArithmetic2Block(uint8_t mode, uint8_t inst, Register_t reg, Memory_t mem)
{
    switch(mode){
        case MODE_REG:
            if( (reg.size == SZ_BYTE) || (reg.size == SZ_WORD) ){
                SegmentTable[stsize-1].LC += 2;
                uint8_t byte1 = (reg.size == SZ_BYTE) ? 0xF6 : 0xF7;
                uint8_t byte2;
                switch(inst){
                    case DIV_INST:
                        byte2 = 0b11110000 | reg.id;
                        break;
                    case IDIV_INST:
                        byte2 = 0b11111000 | reg.id;
                        break;
                    case IMUL_INST:
                        byte2 = 0b11101000 | reg.id;
                        break;
                    case MUL_INST:
                        byte2 = 0b11100000 | reg.id;
                        break;
                    case NEG_INST:
                        byte2 = 0b11011000 | reg.id;
                        break;
                    case NOT_INST:
                        byte2 = 0b11010000 | reg.id;
                        break;
                }
                WriteByte2File(byte1);
                WriteByte2File(byte2);
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }
            break;
        case MODE_MEM:
            if( (mem.size == SZ_BYTE) || (mem.size == SZ_WORD) ){
                if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) ){
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 5;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = (mem.size == SZ_BYTE) ? 0xF6 : 0xF7;
                        uint8_t byte3;
                        switch(inst){
                            case DIV_INST:
                                byte3 = (mem.mod << 6) | 0b00110000 | mem.rm;
                                break;
                            case IDIV_INST:
                                byte3 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                break;
                            case IMUL_INST:
                                byte3 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                break;
                            case MUL_INST:
                                byte3 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                break;
                            case NEG_INST:
                                byte3 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                break;
                            case NOT_INST:
                                byte3 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                break;
                        }
                        uint8_t byte4 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte5 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                        WriteByte2File(byte5);
                    }else{
                        SegmentTable[stsize-1].LC += 4;
                        uint8_t byte1 = (mem.size == SZ_BYTE) ? 0xF6 : 0xF7;
                        uint8_t byte2;
                        switch(inst){
                            case DIV_INST:
                                byte2 = (mem.mod << 6) | 0b00110000 | mem.rm;
                                break;
                            case IDIV_INST:
                                byte2 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                break;
                            case IMUL_INST:
                                byte2 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                break;
                            case MUL_INST:
                                byte2 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                break;
                            case NEG_INST:
                                byte2 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                break;
                            case NOT_INST:
                                byte2 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                break;
                        }
                        uint8_t byte3 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                    }
                }else{
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 3;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = (mem.size == SZ_BYTE) ? 0xF6 : 0xF7;
                        uint8_t byte3;
                        switch(inst){
                            case DIV_INST:
                                byte3 = (mem.mod << 6) | 0b00110000 | mem.rm;
                                break;
                            case IDIV_INST:
                                byte3 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                break;
                            case IMUL_INST:
                                byte3 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                break;
                            case MUL_INST:
                                byte3 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                break;
                            case NEG_INST:
                                byte3 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                break;
                            case NOT_INST:
                                byte3 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                break;
                        }
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                    }else{
                        SegmentTable[stsize-1].LC += 2;
                        uint8_t byte1 = (mem.size == SZ_BYTE) ? 0xF6 : 0xF7;
                        uint8_t byte2;
                        switch(inst){
                            case DIV_INST:
                                byte2 = (mem.mod << 6) | 0b00110000 | mem.rm;
                                break;
                            case IDIV_INST:
                                byte2 = (mem.mod << 6) | 0b00111000 | mem.rm;
                                break;
                            case IMUL_INST:
                                byte2 = (mem.mod << 6) | 0b00101000 | mem.rm;
                                break;
                            case MUL_INST:
                                byte2 = (mem.mod << 6) | 0b00100000 | mem.rm;
                                break;
                            case NEG_INST:
                                byte2 = (mem.mod << 6) | 0b00011000 | mem.rm;
                                break;
                            case NOT_INST:
                                byte2 = (mem.mod << 6) | 0b00010000 | mem.rm;
                                break;
                        }
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                    }
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }
            if(isSOP == SET)
                isSOP = NSET;
            break;
        default:
            PrintError(COLOR_BOLDRED, "Line %d :: Instruction-Operand mismatch!\n", LN);
            return FALSE;
            break;
    }

    return FALSE;
}

Boolean_t EncodeIncDecBlock(uint8_t mode, uint8_t inst, Register_t reg, Memory_t mem)
{
    switch(mode){
        case MODE_REG:
            if(reg.size == SZ_BYTE){
                SegmentTable[stsize-1].LC += 2;
                uint8_t byte1 = 0xFE;
                uint8_t byte2 = (inst == INC_INST) ? (0b11000000 | reg.id) : (0b11001000 | reg.id);
                WriteByte2File(byte1);
                WriteByte2File(byte2);
            }else{
                SegmentTable[stsize-1].LC += 1;
                uint8_t byte1 = (inst == INC_INST) ? (0b01000000 | reg.id) : (0b01001000 | reg.id);
                WriteByte2File(byte1);
            }
            break;
        case MODE_MEM:
            if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) ){
                if(isSOP == SOP){
                    SegmentTable[stsize-1].LC += 5;
                    uint8_t byte1 = SOP;
                    uint8_t byte2 = (mem.size == SZ_BYTE) ? 0xFE : 0xFF;
                    uint8_t byte3 = (mem.mod << 6) | ( (inst == INC_INST) ? 0b00000000 : 0b00001000) | mem.rm;
                    
                    uint8_t byte4 = (uint8_t) (mem.disp & 0x00FF);
                    uint8_t byte5 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                    WriteByte2File(byte1);
                    WriteByte2File(byte2);
                    WriteByte2File(byte3);
                    WriteByte2File(byte4);
                    WriteByte2File(byte5);
                }else{
                    SegmentTable[stsize-1].LC += 4;
                    uint8_t byte1 = (mem.size == SZ_BYTE) ? 0xFE : 0xFF;
                    uint8_t byte2 = (mem.mod << 6) | ((inst == INC_INST) ? 0b00000000 : 0b00001000) | mem.rm;
                    uint8_t byte3 = (uint8_t) (mem.disp & 0x00FF);
                    uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                    WriteByte2File(byte1);
                    WriteByte2File(byte2);
                    WriteByte2File(byte3);
                    WriteByte2File(byte4);
                }
            }else{
                if(isSOP == SOP){
                    SegmentTable[stsize-1].LC += 3;
                    uint8_t byte1 = SOP;
                    uint8_t byte2 = (mem.size == SZ_BYTE) ? 0xFE : 0xFF;
                    uint8_t byte3 = (mem.mod << 6) | ((inst == INC_INST) ? 0b00000000 : 0b00001000) | mem.rm;
                    WriteByte2File(byte1);
                    WriteByte2File(byte2);
                    WriteByte2File(byte3);
                }else{
                    SegmentTable[stsize-1].LC += 2;
                    uint8_t byte1 = (mem.size == SZ_BYTE) ? 0xFE : 0xFF;
                    uint8_t byte2 = (mem.mod << 6) | ((inst == INC_INST) ? 0b00000000 : 0b00001000) | mem.rm;
                    WriteByte2File(byte1);
                    WriteByte2File(byte2);
                }
            }
            if(isSOP == SET)
                isSOP = NSET;
            break;
        default:
            PrintError(COLOR_BOLDRED, "Line %d :: Instruction-Operand mismatch!\n", LN);
            return FALSE;
            break;
    }
    return TRUE;
}

Boolean_t EncodeSingleByteInst(uint8_t byte)
{
    SegmentTable[stsize-1].LC += 1;
    WriteByte2File(byte);
    return TRUE;
}

Boolean_t EncodeTwoByteInst(uint8_t byte1, uint8_t byte2)
{
    SegmentTable[stsize-1].LC += 2;
    WriteByte2File(byte1);
    WriteByte2File(byte2);
    return TRUE;
}

Boolean_t EncodeJccBlock(uint8_t byte1, Immediate_t imm)
{
    if(imm.size == SZ_BYTE){
        SegmentTable[stsize-1].LC += 2;
        uint8_t byte2 = (uint8_t) (imm.val & 0x00FF);
        WriteByte2File(byte1);
        WriteByte2File(byte2);
    }else{
        PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
        return FALSE;
    }
    return TRUE;
}

Boolean_t EncodeFarOp(uint8_t mode, uint8_t inst, Memory_t mem, Immediate_t imm1, Immediate_t imm2)
{
    switch(mode){
        case MODE_IMM_IMM:
            SegmentTable[stsize-1].LC += 5;
            uint8_t byte1 = (inst == CALLF_INST) ? 0x9A : 0xEA;
            uint8_t byte2 = (uint8_t) (imm2.val & 0x00FF);
            uint8_t byte3 = (uint8_t) ( (imm2.val >> 8) & 0x00FF );
            uint8_t byte4 = (uint8_t) (imm1.val & 0x00FF);
            uint8_t byte5 = (uint8_t) ( (imm1.val >> 8) & 0x00FF );
            WriteByte2File(byte1);
            WriteByte2File(byte2);
            WriteByte2File(byte3);
            WriteByte2File(byte4);
            WriteByte2File(byte5);
            break;
        case MODE_MEM:
            if( mem.size == SZ_DWORD ){
                if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) ){
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 5;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = 0xFF;
                        uint8_t byte3 = (mem.mod << 6) | ( (inst == CALLF_INST) ? 0b00011000 : 0b00101000 ) | mem.rm;
                        uint8_t byte4 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte5 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                        WriteByte2File(byte5);
                    }else{
                        SegmentTable[stsize-1].LC += 4;
                        uint8_t byte1 = 0xFF;
                        uint8_t byte2 = (mem.mod << 6) | ( (inst == CALLF_INST) ? 0b00011000 : 0b00101000 ) | mem.rm;
                        uint8_t byte3 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                    }
                }else{
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 3;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = 0xFF;
                        uint8_t byte3 = (mem.mod << 6) | ( (inst == CALLF_INST) ? 0b00011000 : 0b00101000 ) | mem.rm;
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                    }else{
                        SegmentTable[stsize-1].LC += 2;
                        uint8_t byte1 = 0xFF;
                        uint8_t byte2 = (mem.mod << 6) | ( (inst == CALLF_INST) ? 0b00011000 : 0b00101000 ) | mem.rm;
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                    }
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch\n", LN);
                return FALSE;
            }
            if(isSOP == SET)
                isSOP = NSET;
            break;
        default:
            PrintError(COLOR_BOLDRED, "Line %d :: Instruction-Operand mismatch!\n", LN);
            return FALSE;
            break;
    }

    return TRUE;
}

Boolean_t EncodeNearOp(uint8_t mode, uint8_t inst, Register_t reg, Memory_t mem, Immediate_t imm)
{
    switch(mode){
        case MODE_IMM:
            SegmentTable[stsize-1].LC += 3;
            uint8_t byte1 = (inst == CALLN_INST) ? 0xE8 : 0xE9;
            uint8_t byte2 = (uint8_t) (imm.val & 0x00FF);
            uint8_t byte3 = (uint8_t) ( (imm.val >> 8) & 0x00FF );
            WriteByte2File(byte1);
            WriteByte2File(byte2);
            WriteByte2File(byte3);
            break;
        case MODE_MEM:
            if(mem.size == SZ_WORD){
                if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) ){
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 5;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = 0xFF;
                        uint8_t byte3 = (mem.mod << 6) | ( (inst == CALLN_INST) ? 0b00010000 : 0b00100000 ) | mem.rm;
                        uint8_t byte4 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte5 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                        WriteByte2File(byte5);
                    }else{
                        SegmentTable[stsize-1].LC += 4;
                        uint8_t byte1 = 0xFF;
                        uint8_t byte2 = (mem.mod << 6) | ( (inst == CALLN_INST) ? 0b00010000 : 0b00100000 ) | mem.rm;
                        uint8_t byte3 = (uint8_t) (mem.disp & 0x00FF);
                        uint8_t byte4 = (uint8_t) ( (mem.disp >> 8) & 0x00FF );
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                        WriteByte2File(byte4);
                    }
                }else{
                    if(isSOP == SET){
                        SegmentTable[stsize-1].LC += 5;
                        uint8_t byte1 = SOP;
                        uint8_t byte2 = 0xFF;
                        uint8_t byte3 = (mem.mod << 6) | ( (inst == CALLN_INST) ? 0b00010000 : 0b00100000 ) | mem.rm;
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                        WriteByte2File(byte3);
                    }else{
                        SegmentTable[stsize-1].LC += 2;
                        uint8_t byte1 = 0xFF;
                        uint8_t byte2 = (mem.mod << 6) | ( (inst == CALLN_INST) ? 0b00010000 : 0b00100000 ) | mem.rm;
                        WriteByte2File(byte1);
                        WriteByte2File(byte2);
                    }
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }
            if(isSOP == SET)
                isSOP = NSET;
            break;
        case MODE_REG:
            if(reg.size == SZ_WORD){
                SegmentTable[stsize-1].LC += 2;
                uint8_t byte1 = 0xFF;
                uint8_t byte2 = (inst == CALLN_INST) ? 0b11010000 : 0b11100000;
                byte2 = byte2 | reg.id;
                WriteByte2File(byte1);
                WriteByte2File(byte2);
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return FALSE;
            }
            break;
        default:
            PrintError(COLOR_BOLDRED, "Line %d :: Instruction-Operand mismatch!\n", LN);
            return FALSE;
            break;
    }

    return TRUE;
}

Boolean_t EncodeEscapeBlock(void)
{
    return TRUE;
}
