%{

/*#=========================================================================###
##                                                                           ##
##        Author:  Furkan Çetinkaya <furkan.cetinkaya@outlook.com.tr>        ##
##                                                                           ##
###=========================================================================#*/

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
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

extern SCounter_t CalculateSize(short int val);
extern Boolean_t CheckSignExtension(short int val);
extern short int ComputeFactorial(short int number);
extern Boolean_t RegisterLabel(char *str);
extern void ExitSafely(int retcode);

/* Functions */
extern SCounter_t GetMovBlockSize(uint8_t mode, Register_t regd, Register_t regs, Memory_t mem, Immediate_t imm, uint8_t sreg); // MOV
extern SCounter_t GetStackBlockSize(uint8_t mode, uint8_t inst, Register_t reg, uint8_t sreg, Memory_t mem);              // POP, PUSH
extern SCounter_t GetXchgBlockSize(uint8_t mode, Register_t regd, Register_t regs, Memory_t mem);                         // XCHG
extern SCounter_t GetIOBlockSize(uint8_t mode, Register_t reg, Immediate_t imm);                                          // INB, INW, OUTB, OUTW
extern SCounter_t GetAddressBlockSize(uint8_t inst, Register_t reg, Memory_t mem);                                                      // LEA, LES, LDS
extern SCounter_t GetArithmeticBlockSize(uint8_t mode, Register_t regd, Register_t regs, Memory_t mem, Immediate_t imm);  // ADC, ADD, AND, CMP, OR, SBB, SUB, XOR
extern SCounter_t GetShiftRotateBlockSize(uint8_t mode, Register_t regd, Register_t regs, Memory_t mem);                  // RCL, RCR, ROL, ROR, SAL, SAR, SHL, SHR
extern SCounter_t GetIncDecBlockSize(uint8_t mode, Register_t reg, Memory_t mem);                                         // INC, DEC
extern SCounter_t GetArithmetic2Size(uint8_t mode, Register_t reg, Memory_t mem);                                         // DIV, IDIV, MUL, IMUL, NEG, NOT
extern SCounter_t GetReturnBlockSize(uint8_t mode, Immediate_t imm);                                                      // RETN, RETF
extern SCounter_t GetTestSize(uint8_t mode, Register_t regd, Register_t regs, Memory_t mem, Immediate_t imm);             // TEST
extern SCounter_t GetFarOpSize(uint8_t mode, Memory_t mem, Immediate_t imm1, Immediate_t imm2);                           // JMPF, CALLF
extern SCounter_t GetNearOpSize(uint8_t mode, Register_t reg, Memory_t mem, Immediate_t imm);                             // JMPN, CALLN
extern SCounter_t GetInterruptSize(Immediate_t imm);                                                                      // INT
extern SCounter_t GetEscapeBlockSize(void);                                                                               // ESC0-7


/* Error Variables */
extern Boolean_t erroneous;
extern uint8_t errcode;
extern void PrintError(char *color, char *format, ...);
extern void InternalError(char *format, ...);
extern void ExternalError(char *format, ...);


/* Bison/Flex Functions */
void yyerror(const char *s);
extern int yylex();

%}

%union{
    struct{
        short int val;
        uint8_t   isSym;
    }imm_t;

    struct{
        uint8_t size;
        uint8_t id;
    }reg_t;

    struct{
        uint8_t size;
        uint8_t isSym;
        uint8_t mod;
        uint8_t rm;
        short int disp;
    }mem_t;

    int   ival;     // Decimal Values
    char *sval;     // String  Values
    size_t szval;
}

%token INST_AAA    INST_AAD     INST_AAM     INST_AAS     INST_ADC     INST_ADD     INST_AND   
%token INST_CALLF  INST_CALLN   INST_CBW     INST_CLC     INST_CLD     INST_CLI     INST_CMC     INST_CMP
%token INST_CMPSB  INST_CMPSW   INST_CWD
%token INST_DAA    INST_DAS     INST_DEC     INST_DIV   
%token INST_ESC0   INST_ESC1    INST_ESC2    INST_ESC3    INST_ESC4    INST_ESC5    INST_ESC6    INST_ESC7
%token INST_HLT
%token INST_IDIV   INST_IMUL    INST_INB     INST_INW     INST_INC     INST_INT     INST_INTO    INST_IRET
%token INST_JA     INST_JAE     INST_JB      INST_JBE     INST_JC      INST_JCXZ    INST_JE      INST_JG
%token INST_JGE    INST_JL      INST_JLE     INST_JMPF    INST_JMPN    INST_JNA     INST_JNAE    INST_JNB
%token INST_JNBE   INST_JNC     INST_JNE     INST_JNG     INST_JNGE    INST_JNL     INST_JNLE    INST_JNO
%token INST_JNP    INST_JNS     INST_JNZ     INST_JO      INST_JP      INST_JPO     INST_JPE     INST_JS
%token INST_JZ
%token INST_LAHF   INST_LDS     INST_LEA     INST_LES     INST_LOCK    INST_LODSB   INST_LODSW   INST_LOOP
%token INST_LOOPE  INST_LOOPNE  INST_LOOPNZ  INST_LOOPZ 
%token INST_MOV    INST_MOVSB   INST_MOVSW   INST_MUL
%token INST_NEG    INST_NOP     INST_NOT
%token INST_OR     INST_OUTB    INST_OUTW
%token INST_POP    INST_POPF    INST_PUSH    INST_PUSHF
%token INST_RCL    INST_RCR     INST_REP     INST_REPE    INST_REPNE   INST_REPNZ   INST_REPZ    INST_RETF
%token INST_RETN   INST_ROL     INST_ROR   
%token INST_SAHF   INST_SAL     INST_SAR     INST_SBB     INST_SCASB   INST_SCASW   INST_SEG     INST_SHL
%token INST_SHR    INST_STC     INST_STD     INST_STI     INST_STOSB   INST_STOSW   INST_SUB
%token INST_TEST
%token INST_WAIT
%token INST_XCHG   INST_XLAT    INST_XOR
%token REG_AH      REG_AL       REG_AX       REG_BH       REG_BL       REG_BP       REG_BX       REG_CH
%token REG_CL      REG_CX       REG_DH       REG_DI       REG_DL       REG_DX       REG_SI       REG_SP
%token SREG_CS     SREG_DS      SREG_ES      SREG_SS
%token SIZE_BYTE   SIZE_DWORD   SIZE_WORD
%token DIR_PUT     DIR_TIMES    DIR_ORG      DIR_SEGMENT  DIR_HERE
%token NL

%token <sval> LABEL
%token <sval> SEGNAME
%token <sval> STRCONST
%token <imm_t> NUMBER

%left '>' '<' ','
%left '+' '-'
%left '*' '/'
%left '!' '^'

%start init

%%


init: %empty
    | init NL                                   { LN++; }
    | init asmdir NL                            { LN++; }
    | init asminst NL                           { /*printf("Line %d, LC %d :: Instruction\n", LN, SegmentTable[stsize-1].LC);*/  LN++; }
    | init DIR_ORG number NL                    { 
                                                    if(isORG == NSET){
                                                        LC = $<imm_t.val>3;
                                                    }else{
                                                        PrintError(COLOR_BOLDRED, "Line %d :: ORG directive can not be called multiple times!\n", LN);
                                                        erroneous = TRUE;
                                                    }
                                                    LN++; 
                                                }
    | init DIR_SEGMENT SEGNAME '{' init '}'     { LC += SegmentTable[stsize-1].LC; }
    | init LABEL ':' NL                         { 
                                                    Boolean_t retval = RegisterLabel($<sval>2);
                                                    if(retval == FALSE)
                                                        ExitSafely(EXIT_FAILURE);
                                                    LN++; 
                                                }
;

asmdir: DIR_PUT series                          { SegmentTable[stsize-1].LC += $<szval>2; }
      | DIR_TIMES number DIR_PUT series         { SegmentTable[stsize-1].LC += $<imm_t.val>2 * $<szval>4;  }
;

series: number              { $<szval>$ = CalculateSize($<imm_t.val>1); }
      | STRCONST            { $<szval>$ = strlen($<sval>1); }
      | series ',' series   { $<szval>$ = $<szval>1 + $<szval>3; }
;

asminst: INST_SEG sreg                      {
                                                SOP = $<ival>2;
                                                isSOP = SET;
                                            }
       | data_transfer
       | arithmetic
       | bit_manipulation
       | string_operation
       | program_transfer
       | processor_control
       | error
;

data_transfer: INST_MOV   reg  ',' reg      {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm; uint8_t sreg = 0;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                
                                                SCounter_t ret = GetMovBlockSize(MODE_REG_REG, regd, regs, mem, imm, sreg);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
             | INST_MOV   reg  ',' mem      {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm; uint8_t sreg = 0;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                mem.size = $<mem_t.size>4; mem.isSym = $<mem_t.isSym>4; mem.disp = $<mem_t.disp>4;
                                                mem.mod = $<mem_t.mod>4; mem.rm = $<mem_t.rm>4;

                                                SCounter_t ret = GetMovBlockSize(MODE_REG_MEM, regd, regs, mem, imm, sreg);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
             | INST_MOV   mem  ',' reg      {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm; uint8_t sreg = 0;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                
                                                SCounter_t ret = GetMovBlockSize(MODE_MEM_REG, regd, regs, mem, imm, sreg);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
             | INST_MOV   reg  ',' number   {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm; uint8_t sreg = 0;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                uint8_t sz = CalculateSize($<imm_t.val>4);
                                                if(sz != SZ_ERR){
                                                    imm.size = sz;
                                                    imm.isSym = $<imm_t.isSym>4;
                                                    imm.val = $<imm_t.val>4;
                                                }else
                                                    erroneous = TRUE;

                                                SCounter_t ret = GetMovBlockSize(MODE_REG_IMM, regd, regs, mem, imm, sreg);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
             | INST_MOV   mem  ',' number   {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm; uint8_t sreg = 0;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                uint8_t sz = CalculateSize($<imm_t.val>4);
                                                if(sz != SZ_ERR){
                                                    imm.size = sz;
                                                    imm.isSym = $<imm_t.isSym>4;
                                                    imm.val = $<imm_t.val>4;
                                                }else
                                                    erroneous = TRUE;

                                                SCounter_t ret = GetMovBlockSize(MODE_MEM_IMM, regd, regs, mem, imm, sreg);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
             | INST_MOV   sreg ',' reg      {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm; uint8_t sreg;
                                                sreg = $<ival>2;
                                                regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;

                                                SCounter_t ret = GetMovBlockSize(MODE_SREG_REG, regd, regs, mem, imm, sreg);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
             | INST_MOV   sreg ',' mem      {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm; uint8_t sreg;
                                                sreg = $<ival>2;
                                                mem.size = $<mem_t.size>4; mem.isSym = $<mem_t.isSym>4; mem.disp = $<mem_t.disp>4;
                                                mem.mod = $<mem_t.mod>4; mem.rm = $<mem_t.rm>4;

                                                SCounter_t ret = GetMovBlockSize(MODE_SREG_MEM, regd, regs, mem, imm, sreg);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
             | INST_MOV   reg  ',' sreg     {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm; uint8_t sreg;
                                                sreg = $<ival>4;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;

                                                SCounter_t ret = GetMovBlockSize(MODE_REG_SREG, regd, regs, mem, imm, sreg);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
             | INST_MOV   mem  ',' sreg     {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm; uint8_t sreg;
                                                sreg = $<ival>4;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                SCounter_t ret = GetMovBlockSize(MODE_MEM_SREG, regd, regs, mem, imm, sreg);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }

             | INST_PUSH  reg               {
                                                Register_t reg; Memory_t mem; uint8_t sreg=0;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                SCounter_t ret = GetStackBlockSize(MODE_REG, PUSH_INST, reg, sreg, mem);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
             | INST_PUSH  sreg              {
                                                Register_t reg; Memory_t mem; uint8_t sreg;
                                                sreg = $<ival>2;

                                                SCounter_t ret = GetStackBlockSize(MODE_SREG, PUSH_INST, reg, sreg, mem);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
             | INST_PUSH  mem               {
                                                Register_t reg; Memory_t mem; uint8_t sreg = 0;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                SCounter_t ret = GetStackBlockSize(MODE_MEM, PUSH_INST, reg, sreg, mem);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }

             | INST_POP   reg               {
                                                Register_t reg; Memory_t mem; uint8_t sreg=0;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                SCounter_t ret = GetStackBlockSize(MODE_REG, POP_INST, reg, sreg, mem);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
             | INST_POP   sreg              {
                                                Register_t reg; Memory_t mem; uint8_t sreg;
                                                sreg = $<ival>2;

                                                SCounter_t ret = GetStackBlockSize(MODE_SREG, POP_INST, reg, sreg, mem);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
             | INST_POP   mem               {
                                                Register_t reg; Memory_t mem; uint8_t sreg = 0;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                SCounter_t ret = GetStackBlockSize(MODE_MEM, POP_INST, reg, sreg, mem);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }

             | INST_XCHG  reg ',' reg       {
                                                Register_t regd, regs; Memory_t mem;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;

                                                SCounter_t ret = GetXchgBlockSize(MODE_REG_REG, regd, regs, mem);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
             | INST_XCHG  mem ',' reg       {
                                                Register_t regd, regs; Memory_t mem;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                
                                                SCounter_t ret = GetXchgBlockSize(MODE_MEM_REG, regd, regs, mem);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }

             | INST_XLAT                    { SegmentTable[stsize-1].LC += 1; }

             | INST_INB   number            {
                                                Register_t reg; Immediate_t imm;
                                                uint8_t sz = CalculateSize($<imm_t.val>2);
                                                if(sz != SZ_ERR){
                                                    imm.size = sz;
                                                    imm.isSym = $<imm_t.isSym>2;
                                                    imm.val = $<imm_t.val>2;
                                                }else
                                                    erroneous = TRUE;
                                                SCounter_t ret = GetIOBlockSize(MODE_IMM, reg, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
             | INST_INB   reg               {
                                                Register_t reg; Immediate_t imm;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                SCounter_t ret = GetIOBlockSize(MODE_REG, reg, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
             | INST_INW   number            {
                                                Register_t reg; Immediate_t imm;
                                                uint8_t sz = CalculateSize($<imm_t.val>2);
                                                if(sz != SZ_ERR){
                                                    imm.size = sz;
                                                    imm.isSym = $<imm_t.isSym>2;
                                                    imm.val = $<imm_t.val>2;
                                                }else
                                                    erroneous = TRUE;
                                                SCounter_t ret = GetIOBlockSize(MODE_IMM, reg, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
             | INST_INW   reg               {
                                                Register_t reg; Immediate_t imm;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                SCounter_t ret = GetIOBlockSize(MODE_REG, reg, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }

             | INST_OUTB   number           {
                                                Register_t reg; Immediate_t imm;
                                                uint8_t sz = CalculateSize($<imm_t.val>2);
                                                if(sz != SZ_ERR){
                                                    imm.size = sz;
                                                    imm.isSym = $<imm_t.isSym>2;
                                                    imm.val = $<imm_t.val>2;
                                                }else
                                                    erroneous = TRUE;
                                                SCounter_t ret = GetIOBlockSize(MODE_IMM, reg, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
             | INST_OUTB   reg              {
                                                Register_t reg; Immediate_t imm;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                SCounter_t ret = GetIOBlockSize(MODE_REG, reg, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
             | INST_OUTW   number           {
                                                Register_t reg; Immediate_t imm;
                                                uint8_t sz = CalculateSize($<imm_t.val>2);
                                                if(sz != SZ_ERR){
                                                    imm.size = sz;
                                                    imm.isSym = $<imm_t.isSym>2;
                                                    imm.val = $<imm_t.val>2;
                                                }else
                                                    erroneous = TRUE;
                                                SCounter_t ret = GetIOBlockSize(MODE_IMM, reg, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
             | INST_OUTW   reg              {
                                                Register_t reg; Immediate_t imm;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                SCounter_t ret = GetIOBlockSize(MODE_REG, reg, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }

             | INST_LEA   reg ',' mem       {
                                                Register_t reg; Memory_t mem;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;
                                                mem.size = $<mem_t.size>4; mem.isSym = $<mem_t.isSym>4; mem.disp = $<mem_t.disp>4;
                                                mem.mod = $<mem_t.mod>4; mem.rm = $<mem_t.rm>4;

                                                SCounter_t ret = GetAddressBlockSize(LEA_INST,  reg, mem);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
             | INST_LDS   reg ',' mem       {
                                                Register_t reg; Memory_t mem;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;
                                                mem.size = $<mem_t.size>4; mem.isSym = $<mem_t.isSym>4; mem.disp = $<mem_t.disp>4;
                                                mem.mod = $<mem_t.mod>4; mem.rm = $<mem_t.rm>4;

                                                SCounter_t ret = GetAddressBlockSize(LDS_INST, reg, mem);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
             | INST_LES   reg ',' mem       {
                                                Register_t reg; Memory_t mem;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;
                                                mem.size = $<mem_t.size>4; mem.isSym = $<mem_t.isSym>4; mem.disp = $<mem_t.disp>4;
                                                mem.mod = $<mem_t.mod>4; mem.rm = $<mem_t.rm>4;

                                                SCounter_t ret = GetAddressBlockSize(LES_INST, reg, mem);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }

             | INST_LAHF                    { SegmentTable[stsize-1].LC++; }
             | INST_SAHF                    { SegmentTable[stsize-1].LC++; }
             | INST_PUSHF                   { SegmentTable[stsize-1].LC++; }
             | INST_POPF                    { SegmentTable[stsize-1].LC++; }
;

arithmetic: INST_ADD  reg ',' reg           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                SCounter_t ret = GetArithmeticBlockSize(MODE_REG_REG, regd, regs, mem, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
          | INST_ADD  reg ',' mem           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                mem.size = $<mem_t.size>4; mem.isSym = $<mem_t.isSym>4; mem.disp = $<mem_t.disp>4;
                                                mem.mod = $<mem_t.mod>4; mem.rm = $<mem_t.rm>4;
                                                SCounter_t ret = GetArithmeticBlockSize(MODE_REG_MEM, regd, regs, mem, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
          | INST_ADD  mem ',' reg           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>4; regd.size = $<reg_t.size>4;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                SCounter_t ret = GetArithmeticBlockSize(MODE_MEM_REG, regd, regs, mem, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
          | INST_ADD  reg ',' number        {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                uint8_t sz = CalculateSize($<imm_t.val>4);
                                                if(sz != SZ_ERR){
                                                    imm.size = sz;
                                                    imm.isSym = $<imm_t.isSym>4;
                                                    imm.val = $<imm_t.val>4;
                                                }else
                                                    erroneous = TRUE;

                                                
                                                SCounter_t ret = GetArithmeticBlockSize(MODE_REG_IMM, regd, regs, mem, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
          | INST_ADD  mem ',' number        {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                uint8_t sz = CalculateSize($<imm_t.val>4);
                                                if(sz != SZ_ERR){
                                                    imm.size = sz;
                                                    imm.isSym = $<imm_t.isSym>4;
                                                    imm.val = $<imm_t.val>4;
                                                }else
                                                    erroneous = TRUE;

                                                SCounter_t ret = GetArithmeticBlockSize(MODE_MEM_IMM, regd, regs, mem, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }

          | INST_ADC  reg ',' reg           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                SCounter_t ret = GetArithmeticBlockSize(MODE_REG_REG, regd, regs, mem, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
          | INST_ADC  reg ',' mem           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                mem.size = $<mem_t.size>4; mem.isSym = $<mem_t.isSym>4; mem.disp = $<mem_t.disp>4;
                                                mem.mod = $<mem_t.mod>4; mem.rm = $<mem_t.rm>4;
                                                SCounter_t ret = GetArithmeticBlockSize(MODE_REG_MEM, regd, regs, mem, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
          | INST_ADC  mem ',' reg           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>4; regd.size = $<reg_t.size>4;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                SCounter_t ret = GetArithmeticBlockSize(MODE_MEM_REG, regd, regs, mem, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
          | INST_ADC  reg ',' number        {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                uint8_t sz = CalculateSize($<imm_t.val>4);
                                                if(sz != SZ_ERR){
                                                    imm.size = sz;
                                                    imm.isSym = $<imm_t.isSym>4;
                                                    imm.val = $<imm_t.val>4;
                                                }else
                                                    erroneous = TRUE;

                                                
                                                SCounter_t ret = GetArithmeticBlockSize(MODE_REG_IMM, regd, regs, mem, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
          | INST_ADC  mem ',' number        {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                uint8_t sz = CalculateSize($<imm_t.val>4);
                                                if(sz != SZ_ERR){
                                                    imm.size = sz;
                                                    imm.isSym = $<imm_t.isSym>4;
                                                    imm.val = $<imm_t.val>4;
                                                }else
                                                    erroneous = TRUE;

                                                SCounter_t ret = GetArithmeticBlockSize(MODE_MEM_IMM, regd, regs, mem, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }

          | INST_INC  reg                   {
                                                Register_t reg; Memory_t mem;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                SCounter_t ret = GetIncDecBlockSize(MODE_REG, reg, mem);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
          | INST_INC  mem                   {
                                                Register_t reg; Memory_t mem;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                SCounter_t ret = GetIncDecBlockSize(MODE_MEM, reg, mem);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }

          | INST_AAA                        { SegmentTable[stsize-1].LC++; }
          | INST_DAA                        { SegmentTable[stsize-1].LC++; }

          | INST_SUB  reg ',' reg           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                SCounter_t ret = GetArithmeticBlockSize(MODE_REG_REG, regd, regs, mem, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
          | INST_SUB  reg ',' mem           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                mem.size = $<mem_t.size>4; mem.isSym = $<mem_t.isSym>4; mem.disp = $<mem_t.disp>4;
                                                mem.mod = $<mem_t.mod>4; mem.rm = $<mem_t.rm>4;
                                                SCounter_t ret = GetArithmeticBlockSize(MODE_REG_MEM, regd, regs, mem, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
          | INST_SUB  mem ',' reg           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>4; regd.size = $<reg_t.size>4;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                SCounter_t ret = GetArithmeticBlockSize(MODE_MEM_REG, regd, regs, mem, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
          | INST_SUB  reg ',' number        {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                uint8_t sz = CalculateSize($<imm_t.val>4);
                                                if(sz != SZ_ERR){
                                                    imm.size = sz;
                                                    imm.isSym = $<imm_t.isSym>4;
                                                    imm.val = $<imm_t.val>4;
                                                }else
                                                    erroneous = TRUE;

                                                
                                                SCounter_t ret = GetArithmeticBlockSize(MODE_REG_IMM, regd, regs, mem, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
          | INST_SUB  mem ',' number        {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                uint8_t sz = CalculateSize($<imm_t.val>4);
                                                if(sz != SZ_ERR){
                                                    imm.size = sz;
                                                    imm.isSym = $<imm_t.isSym>4;
                                                    imm.val = $<imm_t.val>4;
                                                }else
                                                    erroneous = TRUE;

                                                SCounter_t ret = GetArithmeticBlockSize(MODE_MEM_IMM, regd, regs, mem, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }

          | INST_SBB  reg ',' reg           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                SCounter_t ret = GetArithmeticBlockSize(MODE_REG_REG, regd, regs, mem, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
          | INST_SBB  reg ',' mem           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                mem.size = $<mem_t.size>4; mem.isSym = $<mem_t.isSym>4; mem.disp = $<mem_t.disp>4;
                                                mem.mod = $<mem_t.mod>4; mem.rm = $<mem_t.rm>4;
                                                SCounter_t ret = GetArithmeticBlockSize(MODE_REG_MEM, regd, regs, mem, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
          | INST_SBB  mem ',' reg           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>4; regd.size = $<reg_t.size>4;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                SCounter_t ret = GetArithmeticBlockSize(MODE_MEM_REG, regd, regs, mem, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
          | INST_SBB  reg ',' number        {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                uint8_t sz = CalculateSize($<imm_t.val>4);
                                                if(sz != SZ_ERR){
                                                    imm.size = sz;
                                                    imm.isSym = $<imm_t.isSym>4;
                                                    imm.val = $<imm_t.val>4;
                                                }else
                                                    erroneous = TRUE;

                                                
                                                SCounter_t ret = GetArithmeticBlockSize(MODE_REG_IMM, regd, regs, mem, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
          | INST_SBB  mem ',' number        {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                uint8_t sz = CalculateSize($<imm_t.val>4);
                                                if(sz != SZ_ERR){
                                                    imm.size = sz;
                                                    imm.isSym = $<imm_t.isSym>4;
                                                    imm.val = $<imm_t.val>4;
                                                }else
                                                    erroneous = TRUE;

                                                SCounter_t ret = GetArithmeticBlockSize(MODE_MEM_IMM, regd, regs, mem, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }

          | INST_DEC  reg                   {
                                                Register_t reg; Memory_t mem;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                SCounter_t ret = GetIncDecBlockSize(MODE_REG, reg, mem);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
          | INST_DEC  mem                   {
                                                Register_t reg; Memory_t mem;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                SCounter_t ret = GetIncDecBlockSize(MODE_MEM, reg, mem);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }

          | INST_NEG  reg                   {
                                                Register_t reg; Memory_t mem;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                SCounter_t ret = GetArithmetic2Size(MODE_REG, reg, mem);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
          | INST_NEG  mem                   {
                                                Register_t reg; Memory_t mem;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                SCounter_t ret = GetArithmetic2Size(MODE_MEM, reg, mem);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }

          | INST_CMP  reg ',' reg           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                SCounter_t ret = GetArithmeticBlockSize(MODE_REG_REG, regd, regs, mem, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
          | INST_CMP  reg ',' mem           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                mem.size = $<mem_t.size>4; mem.isSym = $<mem_t.isSym>4; mem.disp = $<mem_t.disp>4;
                                                mem.mod = $<mem_t.mod>4; mem.rm = $<mem_t.rm>4;
                                                SCounter_t ret = GetArithmeticBlockSize(MODE_REG_MEM, regd, regs, mem, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
          | INST_CMP  mem ',' reg           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>4; regd.size = $<reg_t.size>4;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                SCounter_t ret = GetArithmeticBlockSize(MODE_MEM_REG, regd, regs, mem, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
          | INST_CMP  reg ',' number        {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                uint8_t sz = CalculateSize($<imm_t.val>4);
                                                if(sz != SZ_ERR){
                                                    imm.size = sz;
                                                    imm.isSym = $<imm_t.isSym>4;
                                                    imm.val = $<imm_t.val>4;
                                                }else
                                                    erroneous = TRUE;

                                                
                                                SCounter_t ret = GetArithmeticBlockSize(MODE_REG_IMM, regd, regs, mem, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
          | INST_CMP  mem ',' number        {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                uint8_t sz = CalculateSize($<imm_t.val>4);
                                                if(sz != SZ_ERR){
                                                    imm.size = sz;
                                                    imm.isSym = $<imm_t.isSym>4;
                                                    imm.val = $<imm_t.val>4;
                                                }else
                                                    erroneous = TRUE;

                                                SCounter_t ret = GetArithmeticBlockSize(MODE_MEM_IMM, regd, regs, mem, imm);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }

          | INST_AAS                        { SegmentTable[stsize-1].LC++; }
          | INST_DAS                        { SegmentTable[stsize-1].LC++; }

          | INST_MUL  reg                   {
                                                Register_t reg; Memory_t mem;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                SCounter_t ret = GetArithmetic2Size(MODE_REG, reg, mem);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
          | INST_MUL  mem                   {
                                                Register_t reg; Memory_t mem;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                SCounter_t ret = GetArithmetic2Size(MODE_MEM, reg, mem);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }

          | INST_IMUL reg                   {
                                                Register_t reg; Memory_t mem;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                SCounter_t ret = GetArithmetic2Size(MODE_REG, reg, mem);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
          | INST_IMUL mem                   {
                                                Register_t reg; Memory_t mem;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                SCounter_t ret = GetArithmetic2Size(MODE_MEM, reg, mem);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }

          | INST_AAM                        { SegmentTable[stsize-1].LC += 2; }

          | INST_DIV  reg                   {
                                                Register_t reg; Memory_t mem;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                SCounter_t ret = GetArithmetic2Size(MODE_REG, reg, mem);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
          | INST_DIV  mem                   {
                                                Register_t reg; Memory_t mem;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                SCounter_t ret = GetArithmetic2Size(MODE_MEM, reg, mem);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }

          | INST_IDIV reg                   {
                                                Register_t reg; Memory_t mem;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                SCounter_t ret = GetArithmetic2Size(MODE_REG, reg, mem);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }
          | INST_IDIV mem                   {
                                                Register_t reg; Memory_t mem;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                SCounter_t ret = GetArithmetic2Size(MODE_MEM, reg, mem);
                                                if(ret < 0) erroneous = TRUE;
                                                SegmentTable[stsize-1].LC += ret;
                                            }

          | INST_AAD                        { SegmentTable[stsize-1].LC += 2; }
          | INST_CBW                        { SegmentTable[stsize-1].LC++; }
          | INST_CWD                        { SegmentTable[stsize-1].LC++; }
;

bit_manipulation: INST_NOT  reg                 {
                                                    Register_t reg; Memory_t mem;
                                                    reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                    SCounter_t ret = GetArithmetic2Size(MODE_REG, reg, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_NOT  mem                 {
                                                    Register_t reg; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                    SCounter_t ret = GetArithmetic2Size(MODE_MEM, reg, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }

                | INST_AND  reg ',' reg         {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                    SCounter_t ret = GetArithmeticBlockSize(MODE_REG_REG, regd, regs, mem, imm);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_AND  reg ',' mem         {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    mem.size = $<mem_t.size>4; mem.isSym = $<mem_t.isSym>4; mem.disp = $<mem_t.disp>4;
                                                    mem.mod = $<mem_t.mod>4; mem.rm = $<mem_t.rm>4;
                                                    SCounter_t ret = GetArithmeticBlockSize(MODE_REG_MEM, regd, regs, mem, imm);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_AND  mem ',' reg         {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    regd.id = $<reg_t.id>4; regd.size = $<reg_t.size>4;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                    SCounter_t ret = GetArithmeticBlockSize(MODE_MEM_REG, regd, regs, mem, imm);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_AND  reg ',' number      {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    uint8_t sz = CalculateSize($<imm_t.val>4);
                                                    if(sz != SZ_ERR){
                                                        imm.size = sz;
                                                        imm.isSym = $<imm_t.isSym>4;
                                                        imm.val = $<imm_t.val>4;
                                                    }else
                                                        erroneous = TRUE;
                                                
                                                    SCounter_t ret = GetArithmeticBlockSize(MODE_REG_IMM, regd, regs, mem, imm);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_AND  mem ',' number      {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                    uint8_t sz = CalculateSize($<imm_t.val>4);
                                                    if(sz != SZ_ERR){
                                                        imm.size = sz;
                                                        imm.isSym = $<imm_t.isSym>4;
                                                        imm.val = $<imm_t.val>4;
                                                    }else
                                                        erroneous = TRUE;

                                                    SCounter_t ret = GetArithmeticBlockSize(MODE_MEM_IMM, regd, regs, mem, imm);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }

                | INST_OR   reg ',' reg         {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                    SCounter_t ret = GetArithmeticBlockSize(MODE_REG_REG, regd, regs, mem, imm);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_OR   reg ',' mem         {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    mem.size = $<mem_t.size>4; mem.isSym = $<mem_t.isSym>4; mem.disp = $<mem_t.disp>4;
                                                    mem.mod = $<mem_t.mod>4; mem.rm = $<mem_t.rm>4;
                                                    SCounter_t ret = GetArithmeticBlockSize(MODE_REG_MEM, regd, regs, mem, imm);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_OR   mem ',' reg         {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    regd.id = $<reg_t.id>4; regd.size = $<reg_t.size>4;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                    SCounter_t ret = GetArithmeticBlockSize(MODE_MEM_REG, regd, regs, mem, imm);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_OR   reg ',' number      {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    uint8_t sz = CalculateSize($<imm_t.val>4);
                                                    if(sz != SZ_ERR){
                                                        imm.size = sz;
                                                        imm.isSym = $<imm_t.isSym>4;
                                                        imm.val = $<imm_t.val>4;
                                                    }else
                                                        erroneous = TRUE;
                                                
                                                    SCounter_t ret = GetArithmeticBlockSize(MODE_REG_IMM, regd, regs, mem, imm);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_OR   mem ',' number      {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                    uint8_t sz = CalculateSize($<imm_t.val>4);
                                                    if(sz != SZ_ERR){
                                                        imm.size = sz;
                                                        imm.isSym = $<imm_t.isSym>4;
                                                        imm.val = $<imm_t.val>4;
                                                    }else
                                                        erroneous = TRUE;

                                                    SCounter_t ret = GetArithmeticBlockSize(MODE_MEM_IMM, regd, regs, mem, imm);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }

                | INST_XOR  reg ',' reg         {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                    SCounter_t ret = GetArithmeticBlockSize(MODE_REG_REG, regd, regs, mem, imm);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_XOR  reg ',' mem         {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    mem.size = $<mem_t.size>4; mem.isSym = $<mem_t.isSym>4; mem.disp = $<mem_t.disp>4;
                                                    mem.mod = $<mem_t.mod>4; mem.rm = $<mem_t.rm>4;
                                                    SCounter_t ret = GetArithmeticBlockSize(MODE_REG_MEM, regd, regs, mem, imm);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_XOR  mem ',' reg         {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    regd.id = $<reg_t.id>4; regd.size = $<reg_t.size>4;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                    SCounter_t ret = GetArithmeticBlockSize(MODE_MEM_REG, regd, regs, mem, imm);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_XOR  reg ',' number      {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    uint8_t sz = CalculateSize($<imm_t.val>4);
                                                    if(sz != SZ_ERR){
                                                        imm.size = sz;
                                                        imm.isSym = $<imm_t.isSym>4;
                                                        imm.val = $<imm_t.val>4;
                                                    }else
                                                        erroneous = TRUE;
                                                
                                                    SCounter_t ret = GetArithmeticBlockSize(MODE_REG_IMM, regd, regs, mem, imm);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_XOR  mem ',' number      {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                    uint8_t sz = CalculateSize($<imm_t.val>4);
                                                    if(sz != SZ_ERR){
                                                        imm.size = sz;
                                                        imm.isSym = $<imm_t.isSym>4;
                                                        imm.val = $<imm_t.val>4;
                                                    }else
                                                        erroneous = TRUE;

                                                    SCounter_t ret = GetArithmeticBlockSize(MODE_MEM_IMM, regd, regs, mem, imm);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }

                | INST_TEST reg ',' reg         {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                    SCounter_t ret = GetTestSize(MODE_REG_REG, regd, regs, mem, imm);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_TEST reg ',' mem         {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    mem.size = $<mem_t.size>4; mem.isSym = $<mem_t.isSym>4; mem.disp = $<mem_t.disp>4;
                                                    mem.mod = $<mem_t.mod>4; mem.rm = $<mem_t.rm>4;
                                                    SCounter_t ret = GetTestSize(MODE_REG_MEM, regd, regs, mem, imm);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_TEST reg ',' number      {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    uint8_t sz = CalculateSize($<imm_t.val>4);
                                                    if(sz != SZ_ERR){
                                                        imm.size = sz;
                                                        imm.isSym = $<imm_t.isSym>4;
                                                        imm.val = $<imm_t.val>4;
                                                    }else
                                                        erroneous = TRUE;
                                                
                                                    SCounter_t ret = GetTestSize(MODE_REG_IMM, regd, regs, mem, imm);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_TEST mem ',' number      {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                    uint8_t sz = CalculateSize($<imm_t.val>4);
                                                    if(sz != SZ_ERR){
                                                        imm.size = sz;
                                                        imm.isSym = $<imm_t.isSym>4;
                                                        imm.val = $<imm_t.val>4;
                                                    }else
                                                        erroneous = TRUE;

                                                    SCounter_t ret = GetTestSize(MODE_MEM_IMM, regd, regs, mem, imm);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }

                | INST_SHL reg                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;

                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_REG, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_SHL reg ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;

                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_REG_REG, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_SHL mem                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_MEM, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_SHL mem ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;

                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_MEM_REG, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }

                | INST_SAL reg                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;

                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_REG, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_SAL reg ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                    
                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_REG_REG, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_SAL mem                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_MEM, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_SAL mem ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;

                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_MEM_REG, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }

                | INST_SHR reg                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;

                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_REG, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_SHR reg ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                    
                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_REG_REG, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_SHR mem                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_MEM, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_SHR mem ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;

                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_MEM_REG, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }

                | INST_SAR reg                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;

                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_REG, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_SAR reg ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                    
                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_REG_REG, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_SAR mem                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_MEM, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_SAR mem ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;

                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_MEM_REG, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }

                | INST_ROL reg                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;

                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_REG, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_ROL reg ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                    
                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_REG_REG, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_ROL mem                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_MEM, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_ROL mem ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;

                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_MEM_REG, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }

                | INST_ROR reg                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;

                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_REG, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_ROR reg ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                    
                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_REG_REG, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_ROR mem                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_MEM, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_ROR mem ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;

                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_MEM_REG, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }

                | INST_RCL reg                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;

                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_REG, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_RCL reg ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                    
                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_REG_REG, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_RCL mem                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_MEM, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_RCL mem ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;

                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_MEM_REG, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }

                | INST_RCR reg                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;

                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_REG, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_RCR reg ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                    
                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_REG_REG, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_RCR mem                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_MEM, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
                | INST_RCR mem ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;

                                                    SCounter_t ret = GetShiftRotateBlockSize(MODE_MEM_REG, regd, regs, mem);
                                                    if(ret < 0) erroneous = TRUE;
                                                    SegmentTable[stsize-1].LC += ret;
                                                }
;

string_operation: INST_REP                      { SegmentTable[stsize-1].LC++; }
                | INST_REPE                     { SegmentTable[stsize-1].LC++; }
                | INST_REPNE                    { SegmentTable[stsize-1].LC++; }
                | INST_REPNZ                    { SegmentTable[stsize-1].LC++; }
                | INST_REPZ                     { SegmentTable[stsize-1].LC++; }
                | INST_MOVSB                    { SegmentTable[stsize-1].LC++; }
                | INST_MOVSW                    { SegmentTable[stsize-1].LC++; }
                | INST_CMPSB                    { SegmentTable[stsize-1].LC++; }
                | INST_CMPSW                    { SegmentTable[stsize-1].LC++; }
                | INST_SCASB                    { SegmentTable[stsize-1].LC++; }
                | INST_SCASW                    { SegmentTable[stsize-1].LC++; }
                | INST_LODSB                    { SegmentTable[stsize-1].LC++; }
                | INST_LODSW                    { SegmentTable[stsize-1].LC++; }
                | INST_STOSB                    { SegmentTable[stsize-1].LC++; }
                | INST_STOSW                    { SegmentTable[stsize-1].LC++; }
;

program_transfer: INST_CALLF  number ':' number     {
                                                        Memory_t mem; Immediate_t imm1, imm2;
                                                        imm1.size = SZ_WORD; imm1.isSym = $<imm_t.isSym>2; imm1.val = $<imm_t.val>2;
                                                        imm2.size = SZ_WORD; imm2.isSym = $<imm_t.isSym>4; imm2.val = $<imm_t.val>4;

                                                        SCounter_t ret = GetFarOpSize(MODE_IMM_IMM, mem, imm1, imm2);
                                                        if(ret < 0) erroneous = TRUE;
                                                        SegmentTable[stsize-1].LC += ret;
                                                    }
                | INST_CALLF  mem                   {
                                                        Memory_t mem; Immediate_t imm1, imm2;
                                                        mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                        mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                        SCounter_t ret = GetFarOpSize(MODE_MEM, mem, imm1, imm2);
                                                        if(ret < 0) erroneous = TRUE;
                                                        SegmentTable[stsize-1].LC += ret;
                                                    }

                | INST_CALLN  number                {
                                                        Register_t reg; Memory_t mem; Immediate_t imm;
                                                        uint8_t sz = CalculateSize($<imm_t.val>2);
                                                        if(sz != SZ_ERR){
                                                            imm.size = sz;
                                                            imm.isSym = $<imm_t.isSym>2;
                                                            imm.val = $<imm_t.val>2;
                                                        }else
                                                            erroneous = TRUE;
                                                        
                                                        SCounter_t ret = GetNearOpSize(MODE_IMM, reg, mem, imm);
                                                        if(ret < 0) erroneous = TRUE;
                                                        SegmentTable[stsize-1].LC += ret;
                                                    }
                | INST_CALLN  reg                   {
                                                        Register_t reg; Memory_t mem; Immediate_t imm;
                                                        reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                        SCounter_t ret = GetNearOpSize(MODE_REG, reg, mem, imm);
                                                        if(ret < 0) erroneous = TRUE;
                                                        SegmentTable[stsize-1].LC += ret;
                                                    }
                | INST_CALLN  mem                   {
                                                        Register_t reg; Memory_t mem; Immediate_t imm;
                                                        mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                        mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                        
                                                        SCounter_t ret = GetNearOpSize(MODE_MEM, reg, mem, imm);
                                                        if(ret < 0) erroneous = TRUE;
                                                        SegmentTable[stsize-1].LC += ret;
                                                    }

                | INST_RETN                         {
                                                        Immediate_t imm;
                                                        
                                                        SCounter_t ret = GetReturnBlockSize(MODE_NO_OPERAND, imm);
                                                        if(ret < 0) erroneous = TRUE;
                                                        SegmentTable[stsize-1].LC += ret;
                                                    }
                | INST_RETN  number                 {
                                                        Immediate_t imm;
                                                        uint8_t sz = CalculateSize($<imm_t.val>2);
                                                        if(sz != SZ_ERR){
                                                            imm.size = sz;
                                                            imm.isSym = $<imm_t.isSym>2;
                                                            imm.val = $<imm_t.val>2;
                                                        }else
                                                            erroneous = TRUE;
                                                        
                                                        SCounter_t ret = GetReturnBlockSize(MODE_IMM, imm);
                                                        if(ret < 0) erroneous = TRUE;
                                                        SegmentTable[stsize-1].LC += ret;
                                                    }

                | INST_RETF                         {
                                                        Immediate_t imm;
                                                        
                                                        SCounter_t ret = GetReturnBlockSize(MODE_NO_OPERAND, imm);
                                                        if(ret < 0) erroneous = TRUE;
                                                        SegmentTable[stsize-1].LC += ret;
                                                    }
                | INST_RETF  number                 {
                                                        Immediate_t imm;
                                                        uint8_t sz = CalculateSize($<imm_t.val>2);
                                                        if(sz != SZ_ERR){
                                                            imm.size = sz;
                                                            imm.isSym = $<imm_t.isSym>2;
                                                            imm.val = $<imm_t.val>2;
                                                        }else
                                                            erroneous = TRUE;
                                                        
                                                        SCounter_t ret = GetReturnBlockSize(MODE_IMM, imm);
                                                        if(ret < 0) erroneous = TRUE;
                                                        SegmentTable[stsize-1].LC += ret;
                                                    }

                | INST_JMPF  number ':' number      {
                                                        Memory_t mem; Immediate_t imm1, imm2;
                                                        imm1.size = SZ_WORD; imm1.isSym = $<imm_t.isSym>2; imm1.val = $<imm_t.val>2;
                                                        imm2.size = SZ_WORD; imm2.isSym = $<imm_t.isSym>4; imm2.val = $<imm_t.val>4;

                                                        SCounter_t ret = GetFarOpSize(MODE_IMM_IMM, mem, imm1, imm2);
                                                        if(ret < 0) erroneous = TRUE;
                                                        SegmentTable[stsize-1].LC += ret;
                                                    }
                | INST_JMPF  mem                    {
                                                        Memory_t mem; Immediate_t imm1, imm2;
                                                        mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                        mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                        SCounter_t ret = GetFarOpSize(MODE_MEM, mem, imm1, imm2);
                                                        if(ret < 0) erroneous = TRUE;
                                                        SegmentTable[stsize-1].LC += ret;
                                                    }

                | INST_JMPN  number                 {
                                                        Register_t reg; Memory_t mem; Immediate_t imm;
                                                        uint8_t sz = CalculateSize($<imm_t.val>2);
                                                        if(sz != SZ_ERR){
                                                            imm.size = sz;
                                                            imm.isSym = $<imm_t.isSym>2;
                                                            imm.val = $<imm_t.val>2;
                                                        }else
                                                            erroneous = TRUE;
                                                        
                                                        SCounter_t ret = GetNearOpSize(MODE_IMM, reg, mem, imm);
                                                        if(ret < 0) erroneous = TRUE;
                                                        SegmentTable[stsize-1].LC += ret;
                                                    }
                | INST_JMPN  reg                    {
                                                        Register_t reg; Memory_t mem; Immediate_t imm;
                                                        reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;
                                                        
                                                        SCounter_t ret = GetNearOpSize(MODE_REG, reg, mem, imm);
                                                        if(ret < 0) erroneous = TRUE;
                                                        SegmentTable[stsize-1].LC += ret;
                                                    }
                | INST_JMPN  mem                    {
                                                        Register_t reg; Memory_t mem; Immediate_t imm;
                                                        mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                        mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                        
                                                        SCounter_t ret = GetNearOpSize(MODE_MEM, reg, mem, imm);
                                                        if(ret < 0) erroneous = TRUE;
                                                        SegmentTable[stsize-1].LC += ret;
                                                    }

                | INST_JA    number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JNBE  number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JAE   number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JNB   number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JB    number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JNAE  number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JBE   number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JNA   number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JC    number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JE    number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JZ    number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JG    number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JNLE  number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JGE   number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JNL   number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JL    number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JNGE  number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JLE   number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JNG   number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JNC   number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JNE   number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JNZ   number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JNO   number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JNP   number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JPO   number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JNS   number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JO    number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JP    number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JPE   number                 { SegmentTable[stsize-1].LC += 2; }
                | INST_JS    number                 { SegmentTable[stsize-1].LC += 2; }

                | INST_LOOP    number               { SegmentTable[stsize-1].LC += 2; }
                | INST_LOOPE   number               { SegmentTable[stsize-1].LC += 2; }
                | INST_LOOPNE  number               { SegmentTable[stsize-1].LC += 2; }
                | INST_LOOPNZ  number               { SegmentTable[stsize-1].LC += 2; }
                | INST_LOOPZ   number               { SegmentTable[stsize-1].LC += 2; }

                | INST_JCXZ  number                 { SegmentTable[stsize-1].LC += 2; }

                | INST_INT   number                 {
                                                        Immediate_t imm;
                                                        uint8_t sz = CalculateSize($<imm_t.val>2);
                                                        if(sz != SZ_ERR){
                                                            imm.size = sz;
                                                            imm.isSym = $<imm_t.isSym>2;
                                                            imm.val = $<imm_t.val>2;
                                                        }else
                                                            erroneous = TRUE;
                                                        
                                                        SCounter_t ret = GetInterruptSize(imm);
                                                        if(ret < 0) erroneous = TRUE;
                                                        SegmentTable[stsize-1].LC += ret;
                                                    }

                | INST_INTO                     { SegmentTable[stsize-1].LC++; }
                | INST_IRET                     { SegmentTable[stsize-1].LC++; }
;

processor_control: INST_STC                     { SegmentTable[stsize-1].LC++; }
                 | INST_CLC                     { SegmentTable[stsize-1].LC++; }
                 | INST_CMC                     { SegmentTable[stsize-1].LC++; }
                 | INST_STD                     { SegmentTable[stsize-1].LC++; }
                 | INST_CLD                     { SegmentTable[stsize-1].LC++; }
                 | INST_STI                     { SegmentTable[stsize-1].LC++; }
                 | INST_CLI                     { SegmentTable[stsize-1].LC++; }
                 | INST_HLT                     { SegmentTable[stsize-1].LC++; }
                 | INST_WAIT                    { SegmentTable[stsize-1].LC++; }
                 | INST_ESC0
                 | INST_ESC1
                 | INST_ESC2
                 | INST_ESC3
                 | INST_ESC4
                 | INST_ESC5
                 | INST_ESC6
                 | INST_ESC7
                 | INST_LOCK                    { SegmentTable[stsize-1].LC++; }
                 | INST_NOP                     { SegmentTable[stsize-1].LC++; }
;


mem: size '['  number ']'                           {
                                                        $<mem_t.size>$  = $<ival>1;
                                                        $<mem_t.isSym>$ = $<imm_t.isSym>3;
                                                        $<mem_t.mod>$   = 0b00000000;           // Memory Mode
                                                        $<mem_t.rm>$    = 0b00000110;           // Direct Address 16-bit displacement
                                                        $<mem_t.disp>$ = $<imm_t.val>3;
                                                    }
   | size '['  base   ']'                           {
                                                        $<mem_t.size>$  = $<ival>1;
                                                        $<mem_t.isSym>$ = FALSE;
                                                        // Calculate Mod
                                                        // There is no disp except for BP. If BP, then mod = 01 and rm = 110, disp = 0x00
                                                        switch($<ival>3){
                                                            case BASE_REG:
                                                                $<mem_t.mod>$ = 0b00000000;
                                                                $<mem_t.rm>$  = 0b00000111;
                                                                break;
                                                            case BASE_PTR:
                                                                $<mem_t.mod>$ = 0b00000001;
                                                                $<mem_t.rm>$  = 0b00000110;
                                                                break;
                                                        }
                                                        $<mem_t.disp>$ = 0x0000;
                                                    }
   | size '['  index  ']'                           {
                                                        $<mem_t.size>$  = $<ival>1;
                                                        $<mem_t.isSym>$ = FALSE;
                                                        $<mem_t.mod>$   = 0b00000000;
                                                        switch($<ival>3){
                                                            case IDX_SOURCE:
                                                                $<mem_t.rm>$ = 0b00000100;
                                                                break;
                                                            case IDX_DESTINATION:
                                                                $<mem_t.rm>$ = 0b00000101;
                                                                break;
                                                            default:
                                                                PrintError(COLOR_BOLDRED, "Line %d, Internal Error!\n", LN);
                                                                erroneous = TRUE;
                                                                break;
                                                         }
                                                         $<mem_t.disp>$ = 0x0000;
                                                    }
   | size '['  index  ':'  number ']'               {
                                                        $<mem_t.size>$ = $<ival>1;
                                                        $<mem_t.isSym>$ = $<imm_t.isSym>3;
                                                        switch($<ival>3){
                                                            case IDX_SOURCE:
                                                                $<mem_t.rm>$ = 0b00000100;
                                                                break;
                                                            case IDX_DESTINATION:
                                                                $<mem_t.rm>$ = 0b00000101;
                                                                break;
                                                        }
                                                        short int tmp = $<imm_t.val>5;
                                                        uint8_t sz = CalculateSize(tmp);
                                                        if(sz == SZ_BYTE){
                                                            $<mem_t.mod>$ = 0x01;
                                                            $<mem_t.disp>$ = $<imm_t.val>5;
                                                        }else if(sz == SZ_WORD){
                                                            $<mem_t.mod>$ = 0x02;
                                                            $<mem_t.disp>$ = $<imm_t.val>5;
                                                        }else{
                                                            PrintError(COLOR_BOLDRED, "Line %d, Internal Error!\n", LN);
                                                            erroneous = TRUE;
                                                        }
                                                    }
   | size '['  base   ':'  number ']'               {
                                                        $<mem_t.size>$ = $<ival>1;
                                                        $<mem_t.isSym>$ = $<imm_t.isSym>3;
                                                        switch($<ival>3){
                                                            case BASE_REG:
                                                                $<mem_t.rm>$ = 0b00000111;
                                                                break;
                                                            case BASE_PTR:
                                                                $<mem_t.rm>$ = 0b00000110;
                                                                break;
                                                            default:
                                                                PrintError(COLOR_BOLDRED, "Line %d, Internal Error!\n", LN);
                                                                erroneous = TRUE;
                                                        }
                                                        short int tmp = $<imm_t.val>5;
                                                        uint8_t sz = CalculateSize(tmp);
                                                        if(sz == SZ_BYTE){
                                                            $<mem_t.mod>$ = 0x01;
                                                            $<mem_t.disp>$ = $<imm_t.val>5;
                                                        }else if( sz == SZ_WORD ){
                                                            $<mem_t.mod>$ = 0x02;
                                                            $<mem_t.disp>$ = $<imm_t.val>5;
                                                        }else{
                                                            PrintError(COLOR_BOLDRED, "Line %d, Internal Error!\n", LN);
                                                            erroneous = TRUE;
                                                        }
                                                    }
   | size '['  base   ':'  index  ']'               {
                                                        $<mem_t.size>$ = $<ival>1;
                                                        $<mem_t.isSym>$ = FALSE;
                                                        if( ($<ival>3 == BASE_REG) && ($<ival>5 == IDX_SOURCE) ){
                                                            $<mem_t.mod>$ = 0x00;
                                                            $<mem_t.rm>$  = 0x00;
                                                            $<mem_t.disp>$ = 0x00;
                                                        }else if( ($<ival>3 == BASE_REG) && ($<ival>5 == IDX_DESTINATION) ){
                                                            $<mem_t.mod>$ = 0x00;
                                                            $<mem_t.rm>$  = 0x01;
                                                            $<mem_t.disp>$ = 0x00;
                                                        }else if( ($<ival>3 == BASE_PTR) && ($<ival>5 == IDX_SOURCE) ){
                                                            $<mem_t.mod>$ = 0x00;
                                                            $<mem_t.rm>$  = 0x02;
                                                            $<mem_t.disp>$ = 0x00;
                                                        }else if( ($<ival>3 == BASE_PTR) && ($<ival>5 == IDX_DESTINATION) ){
                                                            $<mem_t.mod>$ = 0x00;
                                                            $<mem_t.rm>$  = 0x03;
                                                            $<mem_t.disp>$ = 0x00;
                                                        }else{
                                                            PrintError(COLOR_BOLDRED, "Line %d, Internal Error!\n", LN);
                                                            erroneous = TRUE;
                                                        }
                                                    }
   | size '['  base   ':'  index ':' number ']'     {
                                                        $<mem_t.size>$ = $<ival>1;
                                                        $<mem_t.isSym>$ = $<imm_t.isSym>7;
                                                        short int tmp = $<imm_t.val>7;
                                                        uint8_t sz = CalculateSize(tmp);
                                                        if( ($<ival>3 == BASE_REG) && ($<ival>5 == IDX_SOURCE) ){
                                                            $<mem_t.mod>$ = (sz == SZ_WORD) ? 0x02 : 0x01;
                                                            $<mem_t.rm>$  = 0x00;
                                                            $<mem_t.disp>$ = $<imm_t.val>7;
                                                        }else if( ($<ival>3 == BASE_REG) && ($<ival>5 == IDX_DESTINATION) ){
                                                            $<mem_t.mod>$ = (sz == SZ_WORD) ? 0x02 : 0x01;
                                                            $<mem_t.rm>$  = 0x01;
                                                            $<mem_t.disp>$ = $<imm_t.val>7;
                                                        }else if( ($<ival>3 == BASE_PTR) && ($<ival>5 == IDX_SOURCE) ){
                                                            $<mem_t.mod>$ = (sz == SZ_WORD) ? 0x02 : 0x01;
                                                            $<mem_t.rm>$  = 0x02;
                                                            $<mem_t.disp>$ = $<imm_t.val>7;
                                                        }else if( ($<ival>3 == BASE_PTR) && ($<ival>5 == IDX_DESTINATION) ){
                                                            $<mem_t.mod>$ = (sz == SZ_WORD) ? 0x02 : 0x01;
                                                            $<mem_t.rm>$  = 0x03;
                                                            $<mem_t.disp>$ = $<imm_t.val>7;
                                                        }else{
                                                            PrintError(COLOR_BOLDRED, "Line %d, Internal Error!\n", LN);
                                                            erroneous = TRUE;
                                                        }
                                                    }
;

size: %empty        { $<ival>$ = SZ_WORD;  }
    | SIZE_BYTE     { $<ival>$ = SZ_BYTE;  }
    | SIZE_DWORD    { $<ival>$ = SZ_DWORD; }
    | SIZE_WORD     { $<ival>$ = SZ_WORD;  }
;

base: REG_BX    { $<ival>$ = BASE_REG; }
    | REG_BP    { $<ival>$ = BASE_PTR; }
;

index: REG_SI   { $<ival>$ = IDX_SOURCE;      }
     | REG_DI   { $<ival>$ = IDX_DESTINATION; }
;


reg: REG_AH     {
        $<reg_t.id>$ = GPR_AHSP;    // General Purpose Register AH/SP
        $<reg_t.size>$ = SZ_BYTE;
    }
   | REG_AL     {
        $<reg_t.id>$ = GPR_ALAX;
        $<reg_t.size>$ = SZ_BYTE;
    }
   | REG_AX     {
        $<reg_t.id>$ = GPR_ALAX;
        $<reg_t.size>$ = SZ_WORD;
    }
   | REG_BH     {
        $<reg_t.id>$ = GPR_BHDI;
        $<reg_t.size>$ = SZ_BYTE;
    }
   | REG_BL     {
        $<reg_t.id>$ = GPR_BLBX;
        $<reg_t.size>$ = SZ_BYTE;
    }
   | REG_BX     {
        $<reg_t.id>$ = GPR_BLBX;
        $<reg_t.size>$ = SZ_WORD;
    }
   | REG_CH     {
        $<reg_t.id>$ = GPR_CHBP;
        $<reg_t.size>$ = SZ_BYTE;
    }
   | REG_CL     {
        $<reg_t.id>$ = GPR_CLCX;
        $<reg_t.size>$ = SZ_BYTE;
    }
   | REG_CX     {
        $<reg_t.id>$ = GPR_CLCX;
        $<reg_t.size>$ = SZ_WORD;
    }
   | REG_DH     {
        $<reg_t.id>$ = GPR_DHSI;
        $<reg_t.size>$ = SZ_BYTE;
    }
   | REG_DL     {
        $<reg_t.id>$ = GPR_DLDX;
        $<reg_t.size>$ = SZ_BYTE;
    }
   | REG_DX     {
        $<reg_t.id>$ = GPR_DLDX;
        $<reg_t.size>$ = SZ_WORD;
    }
   | REG_BP     {
        $<reg_t.id>$ = GPR_CHBP;
        $<reg_t.size>$ = SZ_WORD;
    }
   | REG_SP     {
        $<reg_t.id>$ = GPR_AHSP;
        $<reg_t.size>$ = SZ_WORD;
    }
   | REG_SI     {
        $<reg_t.id>$ = GPR_DHSI;
        $<reg_t.size>$ = SZ_WORD;
    }
   | REG_DI     {
        $<reg_t.id>$ = GPR_BHDI;
        $<reg_t.size>$ = SZ_WORD;
    }
;


sreg: SREG_CS   { $<ival>$ = SREG_CODE;    }
    | SREG_DS   { $<ival>$ = SREG_DATA;    }
    | SREG_ES   { $<ival>$ = SREG_EXTRA;   }
    | SREG_SS   { $<ival>$ = SREG_SEGMENT; }
;


number: NUMBER                  { $<imm_t.val>$ = $<imm_t.val>1; $<imm_t.isSym>$ = FALSE; }
      | SEGNAME                 { $<imm_t.val>$ = 0; $<imm_t.isSym>$ = TRUE; }
      | LABEL                   { $<imm_t.val>$ = 0; $<imm_t.isSym>$ = TRUE; }
      | DIR_HERE                { $<imm_t.val>$ = SegmentTable[stsize-1].LC; $<imm_t.isSym>$ = FALSE; }
      | number '+' number       {
                                    $<imm_t.val>$ = (short int) ( $<imm_t.val>1 + $<imm_t.val>3 );
                                    if(( ($<imm_t.isSym>1 == TRUE) || ($<imm_t.isSym>3 == TRUE) ))
                                        $<imm_t.isSym>$ = TRUE;
                                    else
                                        $<imm_t.isSym>$ = FALSE;
                                }
      | number '-' number       {
                                    $<imm_t.val>$ = (short int) ( $<imm_t.val>1 - $<imm_t.val>3 );
                                    if(( ($<imm_t.isSym>1 == TRUE) || ($<imm_t.isSym>3 == TRUE) ))
                                        $<imm_t.isSym>$ = TRUE;
                                    else
                                        $<imm_t.isSym>$ = FALSE;
                                }
      | number '*' number       {
                                    $<imm_t.val>$ = (short int) ( $<imm_t.val>1 * $<imm_t.val>3 );
                                    if(( ($<imm_t.isSym>1 == TRUE) || ($<imm_t.isSym>3 == TRUE) ))
                                        $<imm_t.isSym>$ = TRUE;
                                    else
                                        $<imm_t.isSym>$ = FALSE;
                                }
      | number '/' number       {
                                    if( $<imm_t.val>3 != 0 ){
                                        $<imm_t.val>$ = (short int) ( $<imm_t.val>1 / $<imm_t.val>3 );
                                        if(( ($<imm_t.isSym>1 == TRUE) || ($<imm_t.isSym>3 == TRUE) ))
                                        $<imm_t.isSym>$ = TRUE;
                                    else
                                        $<imm_t.isSym>$ = FALSE;
                                    }else{
                                        PrintError(COLOR_BOLDYELLOW, "Line %d :: Division by 0\n", LN);
                                        erroneous = TRUE;
                                    }
                                }
      | number '<' number       {
                                    $<imm_t.val>$ = (short int) ( $<imm_t.val>1 << $<imm_t.val>3 );
                                    if(( ($<imm_t.isSym>1 == TRUE) || ($<imm_t.isSym>3 == TRUE) ))
                                        $<imm_t.isSym>$ = TRUE;
                                    else
                                        $<imm_t.isSym>$ = FALSE;
                                }
      | number '>' number       {
                                    $<imm_t.val>$ = (short int) ( $<imm_t.val>1 >> $<imm_t.val>3 );
                                    if(( ($<imm_t.isSym>1 == TRUE) || ($<imm_t.isSym>3 == TRUE) ))
                                        $<imm_t.isSym>$ = TRUE;
                                    else
                                        $<imm_t.isSym>$ = FALSE;
                                }
      | number '^' number       {
                                    $<imm_t.val>$ = (short int) pow((double)$<imm_t.val>1, (double)$<imm_t.val>3);
                                    if( ($<imm_t.isSym>1 == TRUE) || ($<imm_t.isSym>3 == TRUE) )
                                        $<imm_t.isSym>$ = TRUE;
                                    else
                                        $<imm_t.isSym>$ = FALSE;
                                }
      | number '!'              {
                                    $<imm_t.isSym>$ = $<imm_t.isSym>1;
                                    $<imm_t.val>$ = ComputeFactorial($<imm_t.val>1);
                                }
;


%%

void yyerror(const char *s)
{
    PrintError(COLOR_BOLDYELLOW, "Line %d, %s\n", LN, s);
}
