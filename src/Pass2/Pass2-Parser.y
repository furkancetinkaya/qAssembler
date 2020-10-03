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


/* Global Variables */
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

/* Miscellaneous Functions */
extern uint8_t Convert2UnsignedByte(short int val);
extern SCounter_t CalculateSize(short int val);         // Calculate the size of a number
extern Boolean_t CheckSignExtension(short int val);     // Check a number if it's sign extended
extern short int ComputeFactorial(short int number);    // Do factorial computation
extern size_t CheckLabelExistence(char *sname);         // Get the index of a label
extern size_t CheckSegmentExistence(char *sname);       // Get the index of a segment
extern void ExitSafely(int retcode);                    // Safe Exit Function

/* Error Variables */
extern uint8_t errcode;                                     // Error Codes for Internal Errors
extern void PrintError(char *color, char *format, ...);     // Print Custom Error Message
extern void InternalError(char *format, ...);               // Print Internal Error
extern void ExternalError(char *format, ...);               // Print External Error

/* Encoder Functions */
extern void WriteByte2File(uint8_t byte);
extern Boolean_t EncodeArithmeticBlock(uint8_t mode, uint8_t inst, Register_t regd, Register_t regs, Memory_t mem, Immediate_t imm);  // ADC, ADD, AND, CMP, OR, SBB, SUB, XOR
extern Boolean_t EncodeMov(uint8_t mode, Register_t regd, Register_t regs, Memory_t mem, Immediate_t imm, uint8_t sreg);              // MOV
extern Boolean_t EncodeShiftRotateBlock(uint8_t mode, uint8_t inst, Register_t regd, Register_t regs, Memory_t mem);                  // RCL, RCR, ROL, ROR, SAL, SAR, SHL, SHR
extern Boolean_t EncodeTest(uint8_t mode, Register_t regd, Register_t regs, Memory_t mem, Immediate_t imm);                           // TEST
extern Boolean_t EncodeFarOp(uint8_t mode, uint8_t inst, Memory_t mem, Immediate_t imm1, Immediate_t imm2);                           // JMPF, CALLF
extern Boolean_t EncodeStackBlock(uint8_t mode, uint8_t inst, Register_t reg, uint8_t sreg, Memory_t mem);                            // POP, PUSH
extern Boolean_t EncodeNearOp(uint8_t mode, uint8_t inst, Register_t reg, Memory_t mem, Immediate_t imm);                             // JMPN, CALLN
extern Boolean_t EncodeArithmetic2Block(uint8_t mode, uint8_t inst, Register_t reg, Memory_t mem);                                    // DIV, IDIV, MUL, IMUL, NEG, NOT
extern Boolean_t EncodeIncDecBlock(uint8_t mode, uint8_t inst, Register_t reg, Memory_t mem);                                         // INC, DEC
extern Boolean_t EncodeIOBlock(uint8_t mode, uint8_t inst, Register_t reg, Immediate_t imm);                                          // INB, INW, OUTB, OUTW
extern Boolean_t EncodeXchg(uint8_t mode, Register_t regd, Register_t regs, Memory_t mem);                                            // XCHG
extern Boolean_t EncodeReturnBlock(uint8_t mode, uint8_t inst, Immediate_t imm);                                                      // RETN, RETF
extern Boolean_t EncodeAddressBlock(uint8_t inst, Register_t reg, Memory_t mem);                                                      // LEA, LES, LDS
extern Boolean_t EncodeTwoByteInst(uint8_t byte1, uint8_t byte2);
extern Boolean_t EncodeJccBlock(uint8_t byte1, Immediate_t imm);
extern Boolean_t EncodeSingleByteInst(uint8_t byte);
extern Boolean_t EncodeInterrupt(Immediate_t imm);                                                                                    // INT
extern Boolean_t EncodeEscapeBlock(void);                                                                                             // ESC0-7

/* Bison/Flex Functions */
void yyerror(const char *s);                            // Flex/Bison Error Function
extern int yylex();                                     // Flex Scanner Function

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

    struct{
        size_t szval;
        uint8_t *arr;
    }arr_t;
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
    | init asminst NL                           { LN++; }
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
    | init DIR_SEGMENT error    { printf("Error in Segment\n"); }
    | init LABEL ':' NL                         { 
                                                    size_t tmp = CheckLabelExistence($<sval>2);
                                                    if(tmp < 0){
                                                        PrintError(COLOR_BOLDRED, "Line %d :: Label Registration Error!\n", LN);
                                                        ExitSafely(EXIT_FAILURE);
                                                    }
                                                    LN++; 
                                                }
;

asmdir: DIR_PUT series                          {
                                                    SegmentTable[stsize-1].LC += $<arr_t.szval>2;
                                                    size_t sz = $<arr_t.szval>2;
                                                    size_t idx;
                                                    for(idx=0; idx<sz; idx++)
                                                        WriteByte2File($<arr_t.arr[idx]>2);
                                                }
      | DIR_TIMES number DIR_PUT series         {
                                                    SegmentTable[stsize-1].LC += $<imm_t.val>2 * $<arr_t.szval>4;
                                                    size_t sz = $<arr_t.szval>4;
                                                    size_t idx;
                                                    short int repeat = $<imm_t.val>2;
                                                    short int t;
                                                    for(t=0; t<repeat; t++){
                                                        for(idx=0; idx<sz; idx++){
                                                            WriteByte2File($<arr_t.arr[idx]>4);
                                                        }
                                                    }
                                                }
;
series: number              {
                                uint8_t *tmp = malloc(sizeof(uint8_t));
                                tmp[0] = Convert2UnsignedByte($<imm_t.val>1);
                                $<arr_t.szval>$ = 1;
                                $<arr_t.arr>$ = tmp;
                            }
      | STRCONST            {
                                char *s = strdup($<sval>1);
                                size_t sz = strlen(s);
                                $<arr_t.szval>$ = sz;
                                uint8_t *tmp = malloc(sz*sizeof(uint8_t));
                                size_t idx;
                                for(idx=0; idx<sz; idx++)
                                    tmp[idx] = (uint8_t) s[idx];
                                $<arr_t.arr>$ = tmp;
                            }
      | series ',' series   {
                                size_t sz1 = $<arr_t.szval>1;
                                size_t sz2 = $<arr_t.szval>3;
                                uint8_t *tmp = malloc( (sz1+sz2)*sizeof(uint8_t) );
                                size_t idx;
                                for(idx=0; idx<sz1; idx++)
                                    tmp[idx] = $<arr_t.arr[idx]>1;
                                for(; idx<(sz1+sz2); idx++)
                                    tmp[idx] = $<arr_t.arr[idx - sz1]>3;
                                
                                $<arr_t.szval>$ = (sz1+sz2);
                                $<arr_t.arr>$ = tmp;
                            }
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
                                                
                                                Boolean_t ret = EncodeMov(MODE_REG_REG, regd, regs, mem, imm, sreg);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
             | INST_MOV   reg  ',' mem      {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm; uint8_t sreg = 0;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                mem.size = $<mem_t.size>4; mem.isSym = $<mem_t.isSym>4; mem.disp = $<mem_t.disp>4;
                                                mem.mod = $<mem_t.mod>4; mem.rm = $<mem_t.rm>4;

                                                Boolean_t ret = EncodeMov(MODE_REG_MEM, regd, regs, mem, imm, sreg);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
             | INST_MOV   mem  ',' reg      {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm; uint8_t sreg = 0;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                
                                                Boolean_t ret = EncodeMov(MODE_MEM_REG, regd, regs, mem, imm, sreg);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
             | INST_MOV   reg  ',' number   {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm; uint8_t sreg = 0;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                uint8_t sz = CalculateSize($<imm_t.val>4);
                                                if(sz != SZ_ERR){
                                                    imm.size = sz;
                                                    imm.isSym = $<imm_t.isSym>4;
                                                    imm.val = $<imm_t.val>4;
                                                }else{
                                                    erroneous = TRUE;
                                                    imm.size = SZ_ERR;
                                                }
                                                
                                                Boolean_t ret = EncodeMov(MODE_REG_IMM, regd, regs, mem, imm, sreg);
                                                if(ret == FALSE) erroneous = TRUE;
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

                                                Boolean_t ret = EncodeMov(MODE_MEM_IMM, regd, regs, mem, imm, sreg);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
             | INST_MOV   sreg ',' reg      {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm; uint8_t sreg;
                                                sreg = $<ival>2;
                                                regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;

                                                Boolean_t ret = EncodeMov(MODE_SREG_REG, regd, regs, mem, imm, sreg);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
             | INST_MOV   sreg ',' mem      {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm; uint8_t sreg;
                                                sreg = $<ival>2;
                                                mem.size = $<mem_t.size>4; mem.isSym = $<mem_t.isSym>4; mem.disp = $<mem_t.disp>4;
                                                mem.mod = $<mem_t.mod>4; mem.rm = $<mem_t.rm>4;

                                                Boolean_t ret = EncodeMov(MODE_SREG_MEM, regd, regs, mem, imm, sreg);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
             | INST_MOV   reg  ',' sreg     {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm; uint8_t sreg;
                                                sreg = $<ival>4;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;

                                                Boolean_t ret = EncodeMov(MODE_REG_SREG, regd, regs, mem, imm, sreg);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
             | INST_MOV   mem  ',' sreg     {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm; uint8_t sreg;
                                                sreg = $<ival>4;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                Boolean_t ret = EncodeMov(MODE_MEM_SREG, regd, regs, mem, imm, sreg);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }

             | INST_PUSH  reg               {
                                                Register_t reg; Memory_t mem; uint8_t sreg=0;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                Boolean_t ret = EncodeStackBlock(MODE_REG, PUSH_INST, reg, sreg, mem);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
             | INST_PUSH  sreg              {
                                                Register_t reg; Memory_t mem; uint8_t sreg;
                                                sreg = $<ival>2;

                                                Boolean_t ret = EncodeStackBlock(MODE_SREG, PUSH_INST, reg, sreg, mem);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
             | INST_PUSH  mem               {
                                                Register_t reg; Memory_t mem; uint8_t sreg = 0;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                Boolean_t ret = EncodeStackBlock(MODE_MEM, PUSH_INST, reg, sreg, mem);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }

             | INST_POP   reg               {
                                                Register_t reg; Memory_t mem; uint8_t sreg=0;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                Boolean_t ret = EncodeStackBlock(MODE_REG, POP_INST, reg, sreg, mem);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
             | INST_POP   sreg              {
                                                Register_t reg; Memory_t mem; uint8_t sreg;
                                                sreg = $<ival>2;

                                                Boolean_t ret = EncodeStackBlock(MODE_SREG, POP_INST, reg, sreg, mem);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
             | INST_POP   mem               {
                                                Register_t reg; Memory_t mem; uint8_t sreg = 0;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                Boolean_t ret = EncodeStackBlock(MODE_MEM, POP_INST, reg, sreg, mem);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }

             | INST_XCHG  reg ',' reg       {
                                                Register_t regd, regs; Memory_t mem;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;

                                                Boolean_t ret = EncodeXchg(MODE_REG_REG, regd, regs, mem);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
             | INST_XCHG  mem ',' reg       {
                                                Register_t regd, regs; Memory_t mem;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                
                                                Boolean_t ret = EncodeXchg(MODE_MEM_REG, regd, regs, mem);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }

             | INST_XLAT                    { 
                                                Boolean_t ret = EncodeSingleByteInst((uint8_t) 0xD7);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }

             | INST_INB   number            {
                                                Register_t reg; Immediate_t imm;
                                                uint8_t sz = CalculateSize($<imm_t.val>2);
                                                if(sz != SZ_ERR){
                                                    imm.size = sz;
                                                    imm.isSym = $<imm_t.isSym>2;
                                                    imm.val = $<imm_t.val>2;
                                                }else
                                                    erroneous = TRUE;
                                                
                                                Boolean_t ret = EncodeIOBlock(MODE_IMM, INB_INST, reg, imm);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
             | INST_INB   reg               {
                                                Register_t reg; Immediate_t imm;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                Boolean_t ret = EncodeIOBlock(MODE_REG, INB_INST, reg, imm);
                                                if(ret == FALSE) erroneous = TRUE;
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
                                                
                                                Boolean_t ret = EncodeIOBlock(MODE_IMM, INW_INST, reg, imm);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
             | INST_INW   reg               {
                                                Register_t reg; Immediate_t imm;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                Boolean_t ret = EncodeIOBlock(MODE_REG, INW_INST, reg, imm);
                                                if(ret == FALSE) erroneous = TRUE;
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
                                                
                                                Boolean_t ret = EncodeIOBlock(MODE_IMM, OUTB_INST, reg, imm);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
             | INST_OUTB   reg              {
                                                Register_t reg; Immediate_t imm;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                Boolean_t ret = EncodeIOBlock(MODE_REG, OUTB_INST, reg, imm);
                                                if(ret == FALSE) erroneous = TRUE;
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
                                                
                                                Boolean_t ret = EncodeIOBlock(MODE_IMM, OUTW_INST, reg, imm);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
             | INST_OUTW   reg              {
                                                Register_t reg; Immediate_t imm;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                Boolean_t ret = EncodeIOBlock(MODE_REG, OUTW_INST, reg, imm);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }

             | INST_LEA   reg ',' mem       {
                                                Register_t reg; Memory_t mem;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;
                                                mem.size = $<mem_t.size>4; mem.isSym = $<mem_t.isSym>4; mem.disp = $<mem_t.disp>4;
                                                mem.mod = $<mem_t.mod>4; mem.rm = $<mem_t.rm>4;

                                                Boolean_t ret = EncodeAddressBlock(LEA_INST,  reg, mem);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
             | INST_LDS   reg ',' mem       {
                                                Register_t reg; Memory_t mem;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;
                                                mem.size = $<mem_t.size>4; mem.isSym = $<mem_t.isSym>4; mem.disp = $<mem_t.disp>4;
                                                mem.mod = $<mem_t.mod>4; mem.rm = $<mem_t.rm>4;

                                                Boolean_t ret = EncodeAddressBlock(LDS_INST,  reg, mem);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
             | INST_LES   reg ',' mem       {
                                                Register_t reg; Memory_t mem;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;
                                                mem.size = $<mem_t.size>4; mem.isSym = $<mem_t.isSym>4; mem.disp = $<mem_t.disp>4;
                                                mem.mod = $<mem_t.mod>4; mem.rm = $<mem_t.rm>4;

                                                Boolean_t ret = EncodeAddressBlock(LES_INST,  reg, mem);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }

             | INST_LAHF                    {
                                                Boolean_t ret = EncodeSingleByteInst((uint8_t) 0x9F);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
             | INST_SAHF                    {
                                                Boolean_t ret = EncodeSingleByteInst((uint8_t) 0x9E);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
             | INST_PUSHF                   {
                                                Boolean_t ret = EncodeSingleByteInst((uint8_t) 0x9C);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
             | INST_POPF                    {
                                                Boolean_t ret = EncodeSingleByteInst((uint8_t) 0x9D);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
;
arithmetic: INST_ADD  reg ',' reg           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                
                                                Boolean_t ret = EncodeArithmeticBlock(MODE_REG_REG, ADD_INST, regd, regs, mem, imm);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
          | INST_ADD  reg ',' mem           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                mem.size = $<mem_t.size>4; mem.isSym = $<mem_t.isSym>4; mem.disp = $<mem_t.disp>4;
                                                mem.mod = $<mem_t.mod>4; mem.rm = $<mem_t.rm>4;
                                                
                                                Boolean_t ret = EncodeArithmeticBlock(MODE_REG_MEM, ADD_INST, regd, regs, mem, imm);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
          | INST_ADD  mem ',' reg           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>4; regd.size = $<reg_t.size>4;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                
                                                Boolean_t ret = EncodeArithmeticBlock(MODE_MEM_REG, ADD_INST, regd, regs, mem, imm);
                                                if(ret == FALSE) erroneous = TRUE;
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

                                                
                                                Boolean_t ret = EncodeArithmeticBlock(MODE_REG_IMM, ADD_INST, regd, regs, mem, imm);
                                                if(ret == FALSE) erroneous = TRUE;
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

                                                Boolean_t ret = EncodeArithmeticBlock(MODE_MEM_IMM, ADD_INST, regd, regs, mem, imm);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }

          | INST_ADC  reg ',' reg           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                
                                                Boolean_t ret = EncodeArithmeticBlock(MODE_REG_REG, ADC_INST, regd, regs, mem, imm);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
          | INST_ADC  reg ',' mem           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                mem.size = $<mem_t.size>4; mem.isSym = $<mem_t.isSym>4; mem.disp = $<mem_t.disp>4;
                                                mem.mod = $<mem_t.mod>4; mem.rm = $<mem_t.rm>4;
                                                
                                                Boolean_t ret = EncodeArithmeticBlock(MODE_REG_MEM, ADC_INST, regd, regs, mem, imm);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
          | INST_ADC  mem ',' reg           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>4; regd.size = $<reg_t.size>4;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                
                                                Boolean_t ret = EncodeArithmeticBlock(MODE_MEM_REG, ADC_INST, regd, regs, mem, imm);
                                                if(ret == FALSE) erroneous = TRUE;
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

                                                Boolean_t ret = EncodeArithmeticBlock(MODE_REG_IMM, ADC_INST, regd, regs, mem, imm);
                                                if(ret == FALSE) erroneous = TRUE;
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

                                                Boolean_t ret = EncodeArithmeticBlock(MODE_MEM_IMM, ADC_INST, regd, regs, mem, imm);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }

          | INST_INC  reg                   {
                                                Register_t reg; Memory_t mem;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                Boolean_t ret = EncodeIncDecBlock(MODE_REG, INC_INST, reg, mem);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
          | INST_INC  mem                   {
                                                Register_t reg; Memory_t mem;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                Boolean_t ret = EncodeIncDecBlock(MODE_MEM, INC_INST, reg, mem);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }

          | INST_AAA                        {
                                                Boolean_t ret = EncodeSingleByteInst((uint8_t) 0x37);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
          | INST_DAA                        {
                                                Boolean_t ret = EncodeSingleByteInst((uint8_t) 0x27);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }

          | INST_SUB  reg ',' reg           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                
                                                Boolean_t ret = EncodeArithmeticBlock(MODE_REG_REG, SUB_INST, regd, regs, mem, imm);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
          | INST_SUB  reg ',' mem           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                mem.size = $<mem_t.size>4; mem.isSym = $<mem_t.isSym>4; mem.disp = $<mem_t.disp>4;
                                                mem.mod = $<mem_t.mod>4; mem.rm = $<mem_t.rm>4;
                                                
                                                Boolean_t ret = EncodeArithmeticBlock(MODE_REG_MEM, SUB_INST, regd, regs, mem, imm);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
          | INST_SUB  mem ',' reg           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>4; regd.size = $<reg_t.size>4;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                
                                                Boolean_t ret = EncodeArithmeticBlock(MODE_MEM_REG, SUB_INST, regd, regs, mem, imm);
                                                if(ret == FALSE) erroneous = TRUE;
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

                                                Boolean_t ret = EncodeArithmeticBlock(MODE_REG_IMM, SUB_INST, regd, regs, mem, imm);
                                                if(ret == FALSE) erroneous = TRUE;
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

                                                Boolean_t ret = EncodeArithmeticBlock(MODE_MEM_IMM, SUB_INST, regd, regs, mem, imm);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }

          | INST_SBB  reg ',' reg           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                
                                                Boolean_t ret = EncodeArithmeticBlock(MODE_REG_REG, SBB_INST, regd, regs, mem, imm);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
          | INST_SBB  reg ',' mem           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                mem.size = $<mem_t.size>4; mem.isSym = $<mem_t.isSym>4; mem.disp = $<mem_t.disp>4;
                                                mem.mod = $<mem_t.mod>4; mem.rm = $<mem_t.rm>4;
                                                
                                                Boolean_t ret = EncodeArithmeticBlock(MODE_REG_MEM, SBB_INST, regd, regs, mem, imm);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
          | INST_SBB  mem ',' reg           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>4; regd.size = $<reg_t.size>4;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                
                                                Boolean_t ret = EncodeArithmeticBlock(MODE_MEM_REG, SBB_INST, regd, regs, mem, imm);
                                                if(ret == FALSE) erroneous = TRUE;
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

                                                Boolean_t ret = EncodeArithmeticBlock(MODE_REG_IMM, SBB_INST, regd, regs, mem, imm);
                                                if(ret == FALSE) erroneous = TRUE;
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

                                                Boolean_t ret = EncodeArithmeticBlock(MODE_MEM_IMM, SBB_INST, regd, regs, mem, imm);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }

          | INST_DEC  reg                   {
                                                Register_t reg; Memory_t mem;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                Boolean_t ret = EncodeIncDecBlock(MODE_REG, DEC_INST, reg, mem);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
          | INST_DEC  mem                   {
                                                Register_t reg; Memory_t mem;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                Boolean_t ret = EncodeIncDecBlock(MODE_MEM, DEC_INST, reg, mem);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }

          | INST_NEG  reg                   {
                                                Register_t reg; Memory_t mem;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                Boolean_t ret = EncodeArithmetic2Block(MODE_REG, NEG_INST, reg, mem);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
          | INST_NEG  mem                   {
                                                Register_t reg; Memory_t mem;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                Boolean_t ret = EncodeArithmetic2Block(MODE_MEM, NEG_INST, reg, mem);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }

          | INST_CMP  reg ',' reg           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                
                                                Boolean_t ret = EncodeArithmeticBlock(MODE_REG_REG, CMP_INST, regd, regs, mem, imm);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
          | INST_CMP  reg ',' mem           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                mem.size = $<mem_t.size>4; mem.isSym = $<mem_t.isSym>4; mem.disp = $<mem_t.disp>4;
                                                mem.mod = $<mem_t.mod>4; mem.rm = $<mem_t.rm>4;
                                                
                                                Boolean_t ret = EncodeArithmeticBlock(MODE_REG_MEM, CMP_INST, regd, regs, mem, imm);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
          | INST_CMP  mem ',' reg           {
                                                Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                regd.id = $<reg_t.id>4; regd.size = $<reg_t.size>4;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                
                                                Boolean_t ret = EncodeArithmeticBlock(MODE_MEM_REG, CMP_INST, regd, regs, mem, imm);
                                                if(ret == FALSE) erroneous = TRUE;
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

                                                Boolean_t ret = EncodeArithmeticBlock(MODE_REG_IMM, CMP_INST, regd, regs, mem, imm);
                                                if(ret == FALSE) erroneous = TRUE;
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

                                                Boolean_t ret = EncodeArithmeticBlock(MODE_MEM_IMM, CMP_INST, regd, regs, mem, imm);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }

          | INST_AAS                        {
                                                Boolean_t ret = EncodeSingleByteInst((uint8_t) 0x3F);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
          | INST_DAS                        {
                                                Boolean_t ret = EncodeSingleByteInst((uint8_t) 0x2F);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }

          | INST_MUL  reg                   {
                                                Register_t reg; Memory_t mem;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                Boolean_t ret = EncodeArithmetic2Block(MODE_REG, MUL_INST, reg, mem);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
          | INST_MUL  mem                   {
                                                Register_t reg; Memory_t mem;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                Boolean_t ret = EncodeArithmetic2Block(MODE_MEM, MUL_INST, reg, mem);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }

          | INST_IMUL reg                   {
                                                Register_t reg; Memory_t mem;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                Boolean_t ret = EncodeArithmetic2Block(MODE_REG, IMUL_INST, reg, mem);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
          | INST_IMUL mem                   {
                                                Register_t reg; Memory_t mem;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                Boolean_t ret = EncodeArithmetic2Block(MODE_MEM, IMUL_INST, reg, mem);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }

          | INST_AAM                        {
                                                Boolean_t ret = EncodeTwoByteInst((uint8_t) 0xD4, (uint8_t) 0x0A);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }

          | INST_DIV  reg                   {
                                                Register_t reg; Memory_t mem;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                Boolean_t ret = EncodeArithmetic2Block(MODE_REG, DIV_INST, reg, mem);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
          | INST_DIV  mem                   {
                                                Register_t reg; Memory_t mem;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                Boolean_t ret = EncodeArithmetic2Block(MODE_MEM, DIV_INST, reg, mem);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }

          | INST_IDIV reg                   {
                                                Register_t reg; Memory_t mem;
                                                reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                Boolean_t ret = EncodeArithmetic2Block(MODE_REG, IDIV_INST, reg, mem);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
          | INST_IDIV mem                   {
                                                Register_t reg; Memory_t mem;
                                                mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                Boolean_t ret = EncodeArithmetic2Block(MODE_MEM, IDIV_INST, reg, mem);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }

          | INST_AAD                        {
                                                Boolean_t ret = EncodeTwoByteInst((uint8_t) 0xD5, (uint8_t) 0x0A);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
          | INST_CBW                        {
                                                Boolean_t ret = EncodeSingleByteInst((uint8_t) 0x98);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
          | INST_CWD                        {
                                                Boolean_t ret = EncodeSingleByteInst((uint8_t) 0x99);
                                                if(ret == FALSE) erroneous = TRUE;
                                            }
;
bit_manipulation: INST_NOT  reg                 {
                                                    Register_t reg; Memory_t mem;
                                                    reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                    Boolean_t ret = EncodeArithmetic2Block(MODE_REG, NOT_INST, reg, mem);
                                                if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_NOT  mem                 {
                                                    Register_t reg; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                    Boolean_t ret = EncodeArithmetic2Block(MODE_MEM, NOT_INST, reg, mem);
                                                if(ret == FALSE) erroneous = TRUE;
                                                }

                | INST_AND  reg ',' reg         {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                    
                                                    Boolean_t ret = EncodeArithmeticBlock(MODE_REG_REG, AND_INST, regd, regs, mem, imm);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_AND  reg ',' mem         {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    mem.size = $<mem_t.size>4; mem.isSym = $<mem_t.isSym>4; mem.disp = $<mem_t.disp>4;
                                                    mem.mod = $<mem_t.mod>4; mem.rm = $<mem_t.rm>4;
                                                    
                                                    Boolean_t ret = EncodeArithmeticBlock(MODE_REG_MEM, AND_INST, regd, regs, mem, imm);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_AND  mem ',' reg         {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    regd.id = $<reg_t.id>4; regd.size = $<reg_t.size>4;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                    
                                                    Boolean_t ret = EncodeArithmeticBlock(MODE_MEM_REG, AND_INST, regd, regs, mem, imm);
                                                    if(ret == FALSE) erroneous = TRUE;
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
                                                
                                                    Boolean_t ret = EncodeArithmeticBlock(MODE_REG_IMM, AND_INST, regd, regs, mem, imm);
                                                    if(ret == FALSE) erroneous = TRUE;
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

                                                    Boolean_t ret = EncodeArithmeticBlock(MODE_MEM_IMM, AND_INST, regd, regs, mem, imm);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }

                | INST_OR   reg ',' reg         {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                    
                                                    Boolean_t ret = EncodeArithmeticBlock(MODE_REG_REG, OR_INST, regd, regs, mem, imm);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_OR   reg ',' mem         {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    mem.size = $<mem_t.size>4; mem.isSym = $<mem_t.isSym>4; mem.disp = $<mem_t.disp>4;
                                                    mem.mod = $<mem_t.mod>4; mem.rm = $<mem_t.rm>4;
                                                    
                                                    Boolean_t ret = EncodeArithmeticBlock(MODE_REG_MEM, OR_INST, regd, regs, mem, imm);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_OR   mem ',' reg         {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    regd.id = $<reg_t.id>4; regd.size = $<reg_t.size>4;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                    
                                                    Boolean_t ret = EncodeArithmeticBlock(MODE_MEM_REG, OR_INST, regd, regs, mem, imm);
                                                    if(ret == FALSE) erroneous = TRUE;
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
                                                
                                                    Boolean_t ret = EncodeArithmeticBlock(MODE_REG_IMM, OR_INST, regd, regs, mem, imm);
                                                    if(ret == FALSE) erroneous = TRUE;
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

                                                    Boolean_t ret = EncodeArithmeticBlock(MODE_MEM_IMM, OR_INST, regd, regs, mem, imm);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }

                | INST_XOR  reg ',' reg         {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                    
                                                    Boolean_t ret = EncodeArithmeticBlock(MODE_REG_REG, XOR_INST, regd, regs, mem, imm);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_XOR  reg ',' mem         {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    mem.size = $<mem_t.size>4; mem.isSym = $<mem_t.isSym>4; mem.disp = $<mem_t.disp>4;
                                                    mem.mod = $<mem_t.mod>4; mem.rm = $<mem_t.rm>4;
                                                    
                                                    Boolean_t ret = EncodeArithmeticBlock(MODE_REG_MEM, XOR_INST, regd, regs, mem, imm);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_XOR  mem ',' reg         {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    regd.id = $<reg_t.id>4; regd.size = $<reg_t.size>4;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                    
                                                    Boolean_t ret = EncodeArithmeticBlock(MODE_MEM_REG, XOR_INST, regd, regs, mem, imm);
                                                    if(ret == FALSE) erroneous = TRUE;
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
                                                
                                                    Boolean_t ret = EncodeArithmeticBlock(MODE_REG_IMM, XOR_INST, regd, regs, mem, imm);
                                                    if(ret == FALSE) erroneous = TRUE;
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

                                                    Boolean_t ret = EncodeArithmeticBlock(MODE_MEM_IMM, XOR_INST, regd, regs, mem, imm);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }

                | INST_TEST reg ',' reg         {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                    
                                                    Boolean_t ret = EncodeTest(MODE_REG_REG, regd, regs, mem, imm);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_TEST reg ',' mem         {
                                                    Register_t regd, regs; Memory_t mem; Immediate_t imm;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    mem.size = $<mem_t.size>4; mem.isSym = $<mem_t.isSym>4; mem.disp = $<mem_t.disp>4;
                                                    mem.mod = $<mem_t.mod>4; mem.rm = $<mem_t.rm>4;
                                                    
                                                    Boolean_t ret = EncodeTest(MODE_REG_MEM, regd, regs, mem, imm);
                                                    if(ret == FALSE) erroneous = TRUE;
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
                                                
                                                    Boolean_t ret = EncodeTest(MODE_REG_IMM, regd, regs, mem, imm);
                                                    if(ret == FALSE) erroneous = TRUE;
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

                                                    Boolean_t ret = EncodeTest(MODE_MEM_IMM, regd, regs, mem, imm);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }

                | INST_SHL reg                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;

                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_REG, SHL_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_SHL reg ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;

                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_REG_REG, SHL_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_SHL mem                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_MEM, SHL_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_SHL mem ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;

                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_MEM_REG, SHL_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }

                | INST_SAL reg                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;

                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_REG, SAL_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_SAL reg ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                    
                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_REG_REG, SAL_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_SAL mem                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_MEM, SAL_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_SAL mem ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;

                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_MEM_REG, SAL_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }

                | INST_SHR reg                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;

                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_REG, SHR_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_SHR reg ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                    
                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_REG_REG, SHR_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_SHR mem                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_MEM, SHR_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_SHR mem ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;

                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_MEM_REG, SHR_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }

                | INST_SAR reg                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;

                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_REG, SAR_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_SAR reg ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                    
                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_REG_REG, SAR_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_SAR mem                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_MEM, SAR_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_SAR mem ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;

                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_MEM_REG, SAR_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }

                | INST_ROL reg                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;

                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_REG, ROL_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_ROL reg ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                    
                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_REG_REG, ROL_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_ROL mem                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_MEM, ROL_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_ROL mem ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;

                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_MEM_REG, ROL_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }

                | INST_ROR reg                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;

                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_REG, ROR_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_ROR reg ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                    
                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_REG_REG, ROR_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_ROR mem                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_MEM, ROR_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_ROR mem ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;

                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_MEM_REG, ROR_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }

                | INST_RCL reg                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;

                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_REG, RCL_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_RCL reg ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                    
                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_REG_REG, RCL_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_RCL mem                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_MEM, RCL_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_RCL mem ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;

                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_MEM_REG, RCL_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }

                | INST_RCR reg                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;

                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_REG, RCR_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_RCR reg ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    regd.id = $<reg_t.id>2; regd.size = $<reg_t.size>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;
                                                    
                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_REG_REG, RCR_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_RCR mem                  {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_MEM, RCR_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_RCR mem ',' reg          {
                                                    Register_t regd, regs; Memory_t mem;
                                                    mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                    mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                    regs.id = $<reg_t.id>4; regs.size = $<reg_t.size>4;

                                                    Boolean_t ret = EncodeShiftRotateBlock(MODE_MEM_REG, RCR_INST, regd, regs, mem);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
;
string_operation: INST_REP                      {
                                                    Boolean_t ret = EncodeSingleByteInst((uint8_t) 0xF3);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_REPE                     {
                                                    Boolean_t ret = EncodeSingleByteInst((uint8_t) 0xF3);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_REPNE                    {
                                                    Boolean_t ret = EncodeSingleByteInst((uint8_t) 0xF2);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_REPNZ                    {
                                                    Boolean_t ret = EncodeSingleByteInst((uint8_t) 0xF2);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_REPZ                     {
                                                    Boolean_t ret = EncodeSingleByteInst((uint8_t) 0xF3);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_MOVSB                    {
                                                    Boolean_t ret = EncodeSingleByteInst((uint8_t) 0xA4);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_MOVSW                    {
                                                    Boolean_t ret = EncodeSingleByteInst((uint8_t) 0xA5);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_CMPSB                    {
                                                    Boolean_t ret = EncodeSingleByteInst((uint8_t) 0xA6);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_CMPSW                    {
                                                    Boolean_t ret = EncodeSingleByteInst((uint8_t) 0xA7);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_SCASB                    {
                                                    Boolean_t ret = EncodeSingleByteInst((uint8_t) 0xAE);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_SCASW                    {
                                                    Boolean_t ret = EncodeSingleByteInst((uint8_t) 0xAF);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_LODSB                    {
                                                    Boolean_t ret = EncodeSingleByteInst((uint8_t) 0xAC);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_LODSW                    {
                                                    Boolean_t ret = EncodeSingleByteInst((uint8_t) 0xAD);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_STOSB                    {
                                                    Boolean_t ret = EncodeSingleByteInst((uint8_t) 0xAA);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_STOSW                    {
                                                    Boolean_t ret = EncodeSingleByteInst((uint8_t) 0xAB);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
;
program_transfer: INST_CALLF  number ':' number     {
                                                        Memory_t mem; Immediate_t imm1, imm2;
                                                        imm1.size = SZ_WORD; imm1.isSym = $<imm_t.isSym>2; imm1.val = $<imm_t.val>2;
                                                        imm2.size = SZ_WORD; imm2.isSym = $<imm_t.isSym>4; imm2.val = $<imm_t.val>4;

                                                        Boolean_t ret = EncodeFarOp(MODE_IMM_IMM, CALLF_INST, mem, imm1, imm2);
                                                        if(ret == TRUE) erroneous = TRUE;
                                                    }
                | INST_CALLF  mem                   {
                                                        Memory_t mem; Immediate_t imm1, imm2;
                                                        mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                        mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                        Boolean_t ret = EncodeFarOp(MODE_MEM, CALLF_INST, mem, imm1, imm2);
                                                        if(ret == TRUE) erroneous = TRUE;
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
                                                        
                                                        Boolean_t ret = EncodeNearOp(MODE_IMM, CALLN_INST, reg, mem, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_CALLN  reg                   {
                                                        Register_t reg; Memory_t mem; Immediate_t imm;
                                                        reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;

                                                        Boolean_t ret = EncodeNearOp(MODE_REG, CALLN_INST, reg, mem, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_CALLN  mem                   {
                                                        Register_t reg; Memory_t mem; Immediate_t imm;
                                                        mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                        mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                        
                                                        Boolean_t ret = EncodeNearOp(MODE_MEM, CALLN_INST, reg, mem, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }

                | INST_RETN                         {
                                                        Immediate_t imm;
                                                        
                                                        Boolean_t ret = EncodeReturnBlock(MODE_NO_OPERAND, RETN_INST, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
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
                                                        
                                                        Boolean_t ret = EncodeReturnBlock(MODE_IMM, RETN_INST, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }

                | INST_RETF                         {
                                                        Immediate_t imm;
                                                        
                                                        Boolean_t ret = EncodeReturnBlock(MODE_NO_OPERAND, RETF_INST, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
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
                                                        
                                                        Boolean_t ret = EncodeReturnBlock(MODE_IMM, RETF_INST, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }

                | INST_JMPF  number ':' number      {
                                                        Memory_t mem; Immediate_t imm1, imm2;
                                                        imm1.size = SZ_WORD; imm1.isSym = $<imm_t.isSym>2; imm1.val = $<imm_t.val>2;
                                                        imm2.size = SZ_WORD; imm2.isSym = $<imm_t.isSym>4; imm2.val = $<imm_t.val>4;

                                                        Boolean_t ret = EncodeFarOp(MODE_IMM_IMM, JMPF_INST, mem, imm1, imm2);
                                                        if(ret == TRUE) erroneous = TRUE;
                                                    }
                | INST_JMPF  mem                    {
                                                        Memory_t mem; Immediate_t imm1, imm2;
                                                        mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                        mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;

                                                        Boolean_t ret = EncodeFarOp(MODE_MEM, JMPF_INST, mem, imm1, imm2);
                                                        if(ret == TRUE) erroneous = TRUE;
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
                                                        
                                                        Boolean_t ret = EncodeNearOp(MODE_IMM, JMPN_INST, reg, mem, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JMPN  reg                    {
                                                        Register_t reg; Memory_t mem; Immediate_t imm;
                                                        reg.id = $<reg_t.id>2; reg.size = $<reg_t.size>2;
                                                        
                                                        Boolean_t ret = EncodeNearOp(MODE_REG, JMPN_INST, reg, mem, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JMPN  mem                    {
                                                        Register_t reg; Memory_t mem; Immediate_t imm;
                                                        mem.size = $<mem_t.size>2; mem.isSym = $<mem_t.isSym>2; mem.disp = $<mem_t.disp>2;
                                                        mem.mod = $<mem_t.mod>2; mem.rm = $<mem_t.rm>2;
                                                        
                                                        Boolean_t ret = EncodeNearOp(MODE_MEM, JMPN_INST, reg, mem, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }

                | INST_JA    number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x77, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JNBE  number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x76, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JAE   number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x73, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JNB   number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x73, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JB    number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x72, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JNAE  number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x72, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JBE   number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x76, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JNA   number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x76, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JC    number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x72, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JE    number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x74, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JZ    number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x74, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JG    number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x7F, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JNLE  number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x7F, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JGE   number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x7D, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JNL   number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x7D, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JL    number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x7C, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JNGE  number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x7C, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JLE   number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x7E, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JNG   number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x7E, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JNC   number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x73, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JNE   number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x75, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JNZ   number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x75, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JNO   number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x71, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JNP   number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x73, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JPO   number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x73, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JNS   number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x71, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JO    number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x70, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JP    number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x7A, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JPE   number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x7A, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_JS    number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0x78, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }

                | INST_LOOP    number               {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0xE2, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_LOOPE   number               {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0xE1, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_LOOPNE  number               {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0xE0, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_LOOPNZ  number               {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0xE0, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }
                | INST_LOOPZ   number               {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0xE1, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }

                | INST_JCXZ  number                 {
                                                        Immediate_t imm;
                                                        imm.isSym = $<imm_t.isSym>2; imm.size = CalculateSize($<imm_t.val>2);
                                                        imm.val = $<imm_t.val>2;

                                                        Boolean_t ret = EncodeJccBlock((uint8_t) 0xE3, imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }

                | INST_INT   number                 {
                                                        Immediate_t imm;
                                                        uint8_t sz = CalculateSize($<imm_t.val>2);
                                                        if(sz != SZ_ERR){
                                                            imm.size = sz;
                                                            imm.isSym = $<imm_t.isSym>2;
                                                            imm.val = $<imm_t.val>2;
                                                        }else
                                                            erroneous = TRUE;
                                                        
                                                        Boolean_t ret = EncodeInterrupt(imm);
                                                        if(ret == FALSE) erroneous = TRUE;
                                                    }

                | INST_INTO                     {
                                                    Boolean_t ret = EncodeSingleByteInst((uint8_t) 0xCE);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                | INST_IRET                     {
                                                    Boolean_t ret = EncodeSingleByteInst((uint8_t) 0xCF);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
;
processor_control: INST_STC                     {
                                                    Boolean_t ret = EncodeSingleByteInst((uint8_t) 0xF9);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                 | INST_CLC                     {
                                                    Boolean_t ret = EncodeSingleByteInst((uint8_t) 0xF8);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                 | INST_CMC                     {
                                                    Boolean_t ret = EncodeSingleByteInst((uint8_t) 0xF5);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                 | INST_STD                     {
                                                    Boolean_t ret = EncodeSingleByteInst((uint8_t) 0xFD);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                 | INST_CLD                     {
                                                    Boolean_t ret = EncodeSingleByteInst((uint8_t) 0xFC);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                 | INST_STI                     {
                                                    Boolean_t ret = EncodeSingleByteInst((uint8_t) 0xFB);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                 | INST_CLI                     {
                                                    Boolean_t ret = EncodeSingleByteInst((uint8_t) 0xFA);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                 | INST_HLT                     {
                                                    Boolean_t ret = EncodeSingleByteInst((uint8_t) 0xF4);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                 | INST_WAIT                    {
                                                    Boolean_t ret = EncodeSingleByteInst((uint8_t) 0x9B);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                 | INST_ESC0
                 | INST_ESC1
                 | INST_ESC2
                 | INST_ESC3
                 | INST_ESC4
                 | INST_ESC5
                 | INST_ESC6
                 | INST_ESC7
                 | INST_LOCK                    {
                                                    Boolean_t ret = EncodeSingleByteInst((uint8_t) 0xF0);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
                 | INST_NOP                     {
                                                    Boolean_t ret = EncodeSingleByteInst((uint8_t) 0x90);
                                                    if(ret == FALSE) erroneous = TRUE;
                                                }
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
      | SEGNAME                 { 
                                    size_t tmp = CheckSegmentExistence($<sval>1);
                                    if(tmp < 0){
                                        PrintError(COLOR_BOLDRED, "Line %d :: Segment Registration Error!\n", LC);
                                        ExitSafely(EXIT_FAILURE);
                                    }
                                    $<imm_t.val>$   = SegmentTable[tmp].loc;
                                    $<imm_t.isSym>$ = TRUE;
                                }
      | LABEL                   {
                                    size_t tmp = CheckLabelExistence($<sval>1);
                                    if(tmp < 0){
                                        PrintError(COLOR_BOLDRED, "Line %d :: Label Registration Error!\n", LC);
                                        ExitSafely(EXIT_FAILURE);
                                    }
                                    $<imm_t.val>$   = LabelTable[tmp].loc;
                                    $<imm_t.isSym>$ = TRUE;
                                }
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