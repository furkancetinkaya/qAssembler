
/*#=========================================================================###
##                                                                           ##
##        Author:  Furkan Çetinkaya <furkan.cetinkaya@outlook.com.tr>        ##
##                                                                           ##
###=========================================================================#*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "../../include/Definitions.h"
#include "../../include/Errors.h"
#include "../../include/Assembler.h"
#include "../../include/Encoding.h"

/* Parser Variables */
extern Flag_t isSOP;                     // Is segment is overwritten
extern Flag_t isORG;                     // Is ORG directive used
extern uint8_t SOP;
extern LCounter_t LN;
extern MCounter_t LC;

/* Tables */
extern Segment_t *SegmentTable;
extern Label_t *LabelTable;
extern size_t ltsize;
extern size_t stsize;

/* Error Variables */
extern Boolean_t erroneous;
extern uint8_t errcode;

/* Error Functions */
extern void PrintError(char *color, char *format, ...);
extern void InternalError(char *format, ...);
extern void ExternalError(char *format, ...);

/* Miscellaneous Functions Declerations */
char *RemoveQuotes(char *s);
SCounter_t CalculateSize(short int val);
Boolean_t CheckSignExtension(short int val);
short int ComputeFactorial(short int number);

/* Function Declerations */
SCounter_t GetMovBlockSize(uint8_t mode, Register_t regd, Register_t regs, Memory_t mem, Immediate_t imm, uint8_t sreg);   // MOV
SCounter_t GetStackBlockSize(uint8_t mode, uint8_t inst, Register_t reg, uint8_t sreg, Memory_t mem);              // POP, PUSH
SCounter_t GetXchgBlockSize(uint8_t mode, Register_t regd, Register_t regs, Memory_t mem);                         // XCHG
SCounter_t GetIOBlockSize(uint8_t mode, Register_t reg, Immediate_t imm);                                          // INB, INW, OUTB, OUTW
SCounter_t GetAddressBlockSize(uint8_t inst, Register_t reg, Memory_t mem);                                                      // LEA, LES, LDS
SCounter_t GetArithmeticBlockSize(uint8_t mode, Register_t regd, Register_t regs, Memory_t mem, Immediate_t imm);  // ADC, ADD, AND, CMP, OR, SBB, SUB, XOR
SCounter_t GetShiftRotateBlockSize(uint8_t mode, Register_t regd, Register_t regs, Memory_t mem);                  // RCL, RCR, ROL, ROR, SAL, SAR, SHL, SHR
SCounter_t GetIncDecBlockSize(uint8_t mode, Register_t reg, Memory_t mem);                                         // INC, DEC
SCounter_t GetArithmetic2Size(uint8_t mode, Register_t reg, Memory_t mem);                                         // DIV, IDIV, MUL, IMUL, NEG, NOT
SCounter_t GetReturnBlockSize(uint8_t mode, Immediate_t imm);                                                      // RETN, RETF
SCounter_t GetTestSize(uint8_t mode, Register_t regd, Register_t regs, Memory_t mem, Immediate_t imm);             // TEST
SCounter_t GetFarOpSize(uint8_t mode, Memory_t mem, Immediate_t imm1, Immediate_t imm2);                           // JMPF, CALLF
SCounter_t GetNearOpSize(uint8_t mode, Register_t reg, Memory_t mem, Immediate_t imm);                             // JMPN, CALLN
SCounter_t GetInterruptSize(Immediate_t imm);                                                                      // INT
SCounter_t GetEscapeBlockSize(void);                                                                               // ESC0-7

/* FUNCTION DEFINITIONS */
SCounter_t GetMovBlockSize(uint8_t mode, Register_t regd, Register_t regs, Memory_t mem, Immediate_t imm, uint8_t sreg){
    SCounter_t ret;
    switch(mode){
        case MODE_REG_REG:
            if( (regd.size == SZ_BYTE) && (regs.size == SZ_BYTE) ){              // Reg8, Reg8
                ret = 2;
            }else if( (regd.size == SZ_WORD) && (regs.size == SZ_WORD) ){      // Reg16, Reg16
                ret = 2;
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }
            break;
        case MODE_REG_MEM:
            if( (mem.size == SZ_BYTE) &&(regd.size == SZ_BYTE) ){
                if( (mem.mod == 0) && (mem.rm == 6) && (regd.id == GPR_ALAX) ){     // Acc8, Mem8
                    ret = 3;
                }else{
                    if( ((mem.mod == 0) && (mem.rm == 6)) || (mem.mod != 0) ){      // Reg8, Mem8
                        ret = 4;
                    }else{
                        ret = 2;
                    }
                }
            }else if( (mem.size == SZ_WORD) && (regd.size == SZ_WORD) ){
                if( (mem.mod == 0) && (mem.rm == 6) && (regd.id == GPR_ALAX) ){     // Acc16, Mem16
                    ret = 3;
                }else{
                    if( ((mem.mod == 0) && (mem.rm == 6)) || (mem.mod != 0) ){      // Reg16, Mem16
                        ret = 4;
                    }else{
                        ret = 2;
                    }
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }

            if(isSOP == SET){
                ret++;
                isSOP = NSET;
            }
            break;
        case MODE_MEM_REG:
            if( (mem.size == SZ_BYTE) && (regs.size == SZ_BYTE) ){
                if( (mem.mod == 0) && (mem.rm == 6) && (regs.id == GPR_ALAX) ){
                    ret = 3;
                }else{
                    if( ((mem.mod == 0) && (mem.rm == 6)) || (mem.mod != 0) ){      // Reg16, Mem16
                        ret = 4;
                    }else{
                        ret = 2;
                    }
                }
            }else if( (mem.size == SZ_WORD) && (regs.size == SZ_WORD) ){
                if( (mem.mod == 0) && (mem.rm == 6) && (regs.id == GPR_ALAX) ){     // Acc16, Mem16
                    ret = 3;
                }else{
                    if( ((mem.mod == 0) && (mem.rm == 6)) || (mem.mod != 0) ){      // Reg16, Mem16
                        ret = 4;
                    }else{
                        ret = 2;
                    }
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }

            if(isSOP == SET){
                ret++;
                isSOP = NSET;
            }
            break;
        case MODE_REG_IMM:
            if( (regd.size == SZ_BYTE) && (imm.size == SZ_BYTE) ){
                ret = 2;
            }else if( (regd.size == SZ_WORD) && ( (imm.size == SZ_BYTE) || (imm.size == SZ_WORD) ) ){
                ret = 3;
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }
            break;
        case MODE_MEM_IMM:
            if( (mem.size == SZ_BYTE) && (imm.size == SZ_BYTE) ){
                if( ((mem.mod == 0) && (mem.rm == 6)) || (mem.mod != 0) ){
                    ret = 5;
                }else{
                    ret = 3;
                }
            }else if( (mem.size == SZ_WORD) && ( (imm.size == SZ_BYTE) || (imm.size == SZ_WORD) ) ){
                if( ((mem.mod == 0) && (mem.rm == 6)) || (mem.mod != 0) ){
                    ret = 6;
                }else{
                    ret = 4;
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }

            if(isSOP == SET){
                ret++;
                isSOP = NSET;
            }
            break;
        case MODE_SREG_REG:
            if(regs.size == SZ_WORD){
                ret = 2;
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }
            break;
        case MODE_SREG_MEM:
            if( mem.size == SZ_WORD ){
                if( ((mem.mod == 0) && (mem.rm == 6)) || (mem.mod != 0) ){
                    ret = 4;
                }else{
                    ret = 2;
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }

            if(isSOP == SET){
                ret++;
                isSOP = NSET;
            }
            break;
        case MODE_REG_SREG:
            if(regd.size == SZ_WORD){
                ret = 2;
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }
            break;
        case MODE_MEM_SREG:
            if( mem.size == SZ_WORD ){
                if( ((mem.mod == 0) && (mem.rm == 6)) || (mem.mod != 0) ){
                    ret = 4;
                }else{
                    ret = 2;
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }

            if(isSOP == SET){
                ret++;
                isSOP = NSET;
            }
            break;
        default:
            PrintError(COLOR_BOLDRED, "Line %d :: Instruction-Operand mismatch!\n", LN);
            return -1;
            break;
    }

    return ret;
}

SCounter_t GetStackBlockSize(uint8_t mode, uint8_t inst, Register_t reg, uint8_t sreg, Memory_t mem){
    SCounter_t ret;
    switch(mode){
        case MODE_REG:
            if(reg.size == SZ_WORD){
                ret = 1;
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand Size Mismatch!\n", LN);
                return -1;
            }
            break;
        case MODE_SREG:
            if(inst == PUSH_INST)
                ret = 1;
            else{
                if( sreg != SREG_CODE )
                    ret = 1;
                else{
                    PrintError(COLOR_BOLDRED, "Line %d :: CS is illegal with POP instruction!\n", LN);
                    return -1;
                }
            }
            break;
        case MODE_MEM:
            if(mem.size == SZ_WORD){
                if( ((mem.mod == 0) && (mem.rm == 6)) || (mem.mod != 0) )
                    ret = 4;
                else
                    ret = 2;
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand Size Mismatch!\n", LN);
                return -1;
            }
            
            if(isSOP == SET){
                ret++;
                isSOP = NSET;
            }
            break;
        default:
            PrintError(COLOR_BOLDRED, "Line %d :: Instruction-Operand mismatch!\n", LN);
            return -1;
            break;
    }

    return ret;
}

SCounter_t GetXchgBlockSize(uint8_t mode, Register_t regd, Register_t regs, Memory_t mem){
    SCounter_t ret;
    switch(mode){
        case MODE_REG_REG:
            if( (regd.id == GPR_ALAX) && (regd.size == SZ_WORD) && (regs.size == SZ_WORD) ){
                ret = 1;
            }else if( (regd.size == SZ_BYTE) && (regs.size == SZ_BYTE) ){
                ret = 2;
            }else if( (regd.size == SZ_WORD) && (regs.size == SZ_WORD) ){
                ret = 2;
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }
            break;
        case MODE_MEM_REG:
            if( mem.size == regs.size ){
                if( ((mem.mod == 0) && (mem.rm == 6)) || (mem.mod != 0) )
                    ret = 4;
                else
                    ret = 2;
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }
            if(isSOP == SET){
                ret++;
                isSOP = NSET;
            }
            break;
    }

    return ret;
}

SCounter_t GetIOBlockSize(uint8_t mode, Register_t reg, Immediate_t imm){
    SCounter_t ret;
    switch(mode){
        case MODE_IMM:
            if( imm.size == SZ_BYTE ){
                ret = 2;
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }
            break;
        case MODE_REG:
            if( reg.size == SZ_WORD ){
                if( reg.id == GPR_DLDX ){
                    ret = 1;
                }else{
                    PrintError(COLOR_BOLDRED, "Line %d :: Instruction-Operand mismatch!\n", LN);
                    return -1;
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }
            break;
        default:
            PrintError(COLOR_BOLDRED, "Line %d :: Instruction-Operand mismatch!\n", LN);
            return -1;
            break;
    }

    return ret;
}

SCounter_t GetAddressBlockSize(uint8_t inst, Register_t reg, Memory_t mem){
    SCounter_t ret;
    switch(inst){
        case LEA_INST:
            if( (reg.size == SZ_WORD) && (mem.size == SZ_WORD) ){
                if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) ){
                    ret = 4;
                }else{
                    ret = 2;
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }
            break;
        case LDS_INST:
            if( (reg.size == SZ_WORD) && (mem.size == SZ_DWORD) ){
                if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) ){
                    ret = 4;
                }else{
                    ret = 2;
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }
            break;
        case LES_INST:
            if( (reg.size == SZ_WORD) && (mem.size == SZ_DWORD) ){
                if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) ){
                    ret = 4;
                }else{
                    ret = 2;
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }
            break;
        default:
            PrintError(COLOR_BOLDRED, "Line %d :: Instruction-Operand mismatch!\n", LN);
            return -1;
    }
    if(isSOP == SET){
        ret++;
        isSOP = NSET;
    }

    return ret;
}

SCounter_t GetArithmeticBlockSize(uint8_t mode, Register_t regd, Register_t regs, Memory_t mem, Immediate_t imm){
    SCounter_t ret;
    Boolean_t sgx;
    switch(mode){
        case MODE_REG_REG:
            if(regd.size == regs.size){
                ret = 2;
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }
            break;
        case MODE_REG_MEM:
            if(regd.size == mem.size){
                if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) ){
                    ret = 4;
                }else{
                    ret = 2;
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }
            if(isSOP == SET){
                ret++;
                isSOP = NSET;
            }
            break;
        case MODE_MEM_REG:
            if(regs.size == mem.size){
                if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) ){
                    ret = 4;
                }else{
                    ret = 2;
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }
            if(isSOP == SET){
                ret++;
                isSOP = NSET;
            }
            break;
        case MODE_REG_IMM:
            sgx = CheckSignExtension(imm.val);
            if( (regd.size == SZ_BYTE) && (imm.size == SZ_BYTE) ){
                if(regd.id == GPR_ALAX){
                    ret = 2;    // Acc8, imm8
                }else{
                    ret = 3;    // Reg8, Imm8
                }
            }else if( (regd.size == SZ_WORD) && (imm.size == SZ_BYTE) ){
                if( (regd.id == GPR_ALAX) && (sgx == FALSE) ){
                    ret = 3;    // Acc16, imm8
                }else if( (regd.id != GPR_ALAX) && (sgx == FALSE) ){
                    ret = 4;    // Reg16, imm8
                }else{
                    ret = 3;    // Reg16, imm8_sgx
                }
            }else if( (regd.size == SZ_WORD) && (imm.size == SZ_WORD) ){
                if( (regd.id == GPR_ALAX) && (sgx == FALSE) ){
                    ret = 2;    // Acc16, imm16
                }else if( (regd.id != GPR_ALAX) && (sgx == FALSE) ){
                    ret = 4;    // Reg16, imm16
                }else{
                    ret = 3;    // Reg16, imm16_sgx
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }
            break;
        case MODE_MEM_IMM:
            sgx = CheckSignExtension(imm.val);
            if( (mem.size == SZ_BYTE) && (imm.size == SZ_BYTE) ){
                if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) ){
                    ret = 5;
                }else{
                    ret = 3;
                }
            }else if( (mem.size == SZ_WORD) && (imm.size == SZ_BYTE) ){
                if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) ){
                    ret = (sgx == TRUE) ? 5 : 6;
                }else{
                    ret = (sgx == TRUE) ? 3 : 4;
                }
            }else if( (mem.size == SZ_WORD) && (imm.size == SZ_WORD) ){
                if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) ){
                    ret = (sgx == TRUE) ? 5 : 6;
                }else{
                    ret = (sgx == TRUE) ? 3 : 4;
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }
            if(isSOP == SET){
                ret++;
                isSOP = NSET;
            }
            break;
        default:
            PrintError(COLOR_BOLDRED, "Line %d :: Instruction-Operand mismatch!\n", LN);
            return -1;
            break;
    }

    return ret;
}

SCounter_t GetShiftRotateBlockSize(uint8_t mode, Register_t regd, Register_t regs, Memory_t mem){
    SCounter_t ret;
    switch(mode){
        case MODE_REG:
            if( (regd.size == SZ_BYTE) || (regd.size == SZ_WORD) )
                ret = 2;
            else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }
            break;
        case MODE_REG_REG:
            if( (regd.size == SZ_BYTE) || (regd.size == SZ_WORD) )
                if( (regs.id == GPR_CLCX) && (regs.size == SZ_BYTE) )
                    ret = 2;
                else{
                    PrintError(COLOR_BOLDRED, "Line %d :: Operand type mismatch!\n", LN);
                    return -1;
                }
            else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }
            break;
        case MODE_MEM:
            if( (mem.size == SZ_BYTE) || (mem.size == SZ_WORD) ){
                if( ((mem.mod == 0) && (mem.rm == 6)) || (mem.mod != 0) )
                    ret = 4;
                else
                    ret = 2;
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }
            if(isSOP == SET){
                ret++;
                isSOP = NSET;
            }
            break;
        case MODE_MEM_REG:
            if( (mem.size == SZ_BYTE) || (mem.size == SZ_WORD) ){
                if( (regs.id == GPR_CLCX) && (regs.size == SZ_BYTE) ){
                    if( ((mem.mod == 0) && (mem.rm == 6)) || (mem.mod != 0) )
                        ret = 4;
                    else
                        ret = 2;
                }else{
                    PrintError(COLOR_BOLDRED, "Line %d :: Operand type mismatch!\n", LN);
                    return -1;
                }
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }
            if(isSOP == SET){
                ret++;
                isSOP = NSET;
            }
            break;
        default:
            PrintError(COLOR_BOLDRED, "Line %d :: Instruction-Operand mismatch!\n", LN);
            return -1;
            break;
    }
    return ret;
}

SCounter_t GetIncDecBlockSize(uint8_t mode, Register_t reg, Memory_t mem){
    SCounter_t ret;
    switch(mode){
        case MODE_REG:
            if(reg.size == SZ_BYTE){
                ret = 2;
            }else{
                ret = 1;
            }
            break;
        case MODE_MEM:
            if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) ){
                ret = 4;
            }else{
                ret = 2;
            }
            if(isSOP == SET){
                ret++;
                isSOP = NSET;
            }
            break;
        default:
            PrintError(COLOR_BOLDRED, "Line %d :: Instruction-Operand mismatch!\n", LN);
            return -1;
            break;
    }
    return ret;
}

SCounter_t GetArithmetic2Size(uint8_t mode, Register_t reg, Memory_t mem){
    SCounter_t ret;
    switch(mode){
        case MODE_REG:
            if( (reg.size == SZ_BYTE) || (reg.size == SZ_WORD) )
                ret = 2;
            else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }
            break;
        case MODE_MEM:
            if( (mem.size == SZ_BYTE) || (mem.size == SZ_WORD) )
                if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) )
                    ret = 4;
                else
                    ret = 2;
            else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }
            if(isSOP == SET){
                ret++;
                isSOP = NSET;
            }
            break;
        default:
            PrintError(COLOR_BOLDRED, "Line %d :: Instruction-Operand mismatch!\n", LN);
            return -1;
            break;
    }

    return ret;
}

SCounter_t GetReturnBlockSize(uint8_t mode, Immediate_t imm){
    SCounter_t size;
    switch(mode){
        case MODE_NO_OPERAND:
            size = 1;
            break;
        case MODE_IMM:
            if(imm.size == SZ_WORD){
                size = 3;
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }
        default:
            PrintError(COLOR_BOLDRED, "Line %d :: Instruction-Operand Mismatch!\n", LN);
            return -1;
    }

    return size;
}

SCounter_t GetTestSize(uint8_t mode, Register_t regd, Register_t regs, Memory_t mem, Immediate_t imm){
    SCounter_t ret;
    switch(mode){
        case MODE_REG_REG:
            if( regd.size == regs.size ){
                ret = 2;
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }
            break;
        case MODE_REG_MEM:
            if( regd.size == mem.size ){
                if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) )
                    ret = 4;
                else
                    ret = 2;
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }
            if(isSOP == SET){
                ret++;
                isSOP = NSET;
            }
            break;
        case MODE_REG_IMM:
            if(regd.size == SZ_BYTE){
                if(imm.size == SZ_BYTE){
                    ret = (regd.id == GPR_ALAX) ? 2 : 3;
                }else{
                    PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                    return -1;
                }
            }else if(regd.size == SZ_WORD){
                if(regd.id == GPR_ALAX) ret = 3;
                else ret = 4;
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Internal Error!\n", LN);
                return -1;
            }
            break;
        case MODE_MEM_IMM:
            if( (mem.size == SZ_BYTE) && (imm.size == SZ_BYTE) ){
                if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) )
                    ret = 5;
                else
                    ret = 3;
            }else if( ((mem.size == SZ_WORD) && (imm.size == SZ_BYTE)) || ((mem.size == SZ_WORD) && (imm.size == SZ_WORD)) ){
                if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) )
                    ret = 6;
                else
                    ret = 4;
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }
            if(isSOP == SET){
                ret++;
                isSOP = NSET;
            }
            break;
        default:
            PrintError(COLOR_BOLDRED, "Line %d :: Instruction-Operand mismatch!\n", LN);
            return -1;
            break;
    }

    return ret;
}

SCounter_t GetFarOpSize(uint8_t mode, Memory_t mem, Immediate_t imm1, Immediate_t imm2){
    SCounter_t ret;
    switch(mode){
        case MODE_IMM_IMM:
            ret = 5;
            break;
        case MODE_MEM:
            if( mem.size == SZ_DWORD ){
                if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) )
                    ret = 4;
                else
                    ret = 2;
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch\n", LN);
                return -1;
            }
            if(isSOP == SET){
                ret++;
                isSOP = NSET;
            }
            break;
        default:
            PrintError(COLOR_BOLDRED, "Line %d :: Instruction-Operand mismatch!\n", LN);
            return -1;
            break;
    }

    return ret;
}

SCounter_t GetNearOpSize(uint8_t mode, Register_t reg, Memory_t mem, Immediate_t imm){
    SCounter_t ret;
    switch(mode){
        case MODE_IMM:
            ret = 3;
            break;
        case MODE_MEM:
            if(mem.size == SZ_WORD){
                if( ( (mem.mod == 0) && (mem.rm == 6) ) || (mem.mod != 0) )
                    ret = 4;
                else
                    ret = 2;
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }
            if(isSOP == SET){
                ret++;
                isSOP = NSET;
            }
            break;
        case MODE_REG:
            if(reg.size == SZ_WORD){
                ret = 2;
            }else{
                PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
                return -1;
            }
            break;
        default:
            PrintError(COLOR_BOLDRED, "Line %d :: Instruction-Operand mismatch!\n", LN);
            return -1;
            break;
    }

    return ret;
}

SCounter_t GetInterruptSize(Immediate_t imm){
    if(imm.size == SZ_BYTE){
        return (imm.val == 3) ? 1 : 2;
    }else{
        PrintError(COLOR_BOLDRED, "Line %d :: Operand size mismatch!\n", LN);
        return -1;
    }
}

SCounter_t GetEscapeBlockSize(void){
    return 1;
}
