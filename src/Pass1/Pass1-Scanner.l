%{
/*#=========================================================================###
##                                                                           ##
##        Author:  Furkan Çetinkaya <furkan.cetinkaya@outlook.com.tr>        ##
##                                                                           ##
###=========================================================================#*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../../include/Definitions.h"
#include "../../include/Assembler.h"
#include "../../include/Errors.h"
#include "Pass1-Parser.tab.h"

extern LCounter_t LN;       // Line number
extern MCounter_t LC;       // Location counter
extern uint8_t errcode;
extern Boolean_t erroneous;

/* Tables */
extern Segment_t *SegmentTable;
extern Label_t *LabelTable;
extern size_t ltsize;
extern size_t stsize;

extern char *RemoveQuotes(char *s);
extern long int ConvertHec2Dec(char *str);
extern Boolean_t RegisterSegment(char *str);
extern void ExitSafely(int retcode);

extern void yyerror(const char *s);
extern void PrintError(char *color, char *format, ...);
extern void InternalError(char *format, ...);
extern void ExternalError(char *format, ...);


%}

%option case-insensitive noyywrap nodefault

%x SEGSTATE
%%

"ORG"           { return(DIR_ORG); }
[+-]?[0-9]+     { 
                  long int tmp = atol(yytext);
                  if(tmp > 32767 || tmp < -32768){
                      PrintError(COLOR_BOLDRED, "Line %d :: Number size overflow!\n", LN);
                      erroneous = TRUE;
                  }else{
                      yylval.imm_t.val = (short int) tmp;
                      yylval.imm_t.isSym = FALSE;
                  }
                  return(NUMBER);
                }
[+-]?"0x"[0-9a-f]+   {
                        long int tmp = ConvertHec2Dec(yytext);
                        if(tmp > 32767 || tmp < -32768){
                            PrintError(COLOR_BOLDRED, "Line %d :: Number size overflow!\n", LN);
                            erroneous = TRUE;
                        }else{
                            yylval.imm_t.val = (short int) tmp;
                            yylval.imm_t.isSym = FALSE;
                        }
                        return(NUMBER);
                     }
"SEGMENT"       { return(DIR_SEGMENT); }
"$"[a-z0-9_]+   { 
                    yylval.sval = strdup(yytext);
                    Boolean_t retval = RegisterSegment(yytext);
                    if(retval == FALSE)
                        ExitSafely(EXIT_FAILURE);
                    return(SEGNAME); }

"\n"            { return(NL); }
[ \t]           { /* Ignore Whitespaces */ }
"{"                     { BEGIN SEGSTATE; return('{'); }

<SEGSTATE>"AAA"         { return(INST_AAA); }
<SEGSTATE>"AAD"         { return(INST_AAD); }
<SEGSTATE>"AAM"         { return(INST_AAM); }
<SEGSTATE>"AAS"         { return(INST_AAS); }
<SEGSTATE>"ADC"         { return(INST_ADC); }
<SEGSTATE>"ADD"         { return(INST_ADD); }
<SEGSTATE>"AH"          { return(REG_AH); }
<SEGSTATE>"AL"          { return(REG_AL); }
<SEGSTATE>"AND"         { return(INST_AND); }
<SEGSTATE>"AX"          { return(REG_AX); }
<SEGSTATE>"BH"          { return(REG_BH); }
<SEGSTATE>"BL"          { return(REG_BL); }
<SEGSTATE>"BP"          { return(REG_BP); }
<SEGSTATE>"BX"          { return(REG_BX); }
<SEGSTATE>"BYTE"        { return(SIZE_BYTE); }
<SEGSTATE>"CALLN"       { return(INST_CALLN); }
<SEGSTATE>"CALLF"       { return(INST_CALLF); }
<SEGSTATE>"CBW"         { return(INST_CBW); }
<SEGSTATE>"CH"          { return(REG_CH); }
<SEGSTATE>"CL"          { return(REG_CL); }
<SEGSTATE>"CLC"         { return(INST_CLC); }
<SEGSTATE>"CLD"         { return(INST_CLD); }
<SEGSTATE>"CLI"         { return(INST_CLI); }
<SEGSTATE>"CMC"         { return(INST_CMC); }
<SEGSTATE>"CMP"         { return(INST_CMP); }
<SEGSTATE>"CMPSB"       { return(INST_CMPSB); }
<SEGSTATE>"CMPSW"       { return(INST_CMPSW); }
<SEGSTATE>"CS"          { return(SREG_CS); }
<SEGSTATE>"CWD"         { return(INST_CWD); }
<SEGSTATE>"CX"          { return(REG_CX); }
<SEGSTATE>"DAA"         { return(INST_DAA); }
<SEGSTATE>"DAS"         { return(INST_DAS); }
<SEGSTATE>"DEC"         { return(INST_DEC); }
<SEGSTATE>"DH"          { return(REG_DH); }
<SEGSTATE>"DI"          { return(REG_DI); }
<SEGSTATE>"DIV"         { return(INST_DIV); }
<SEGSTATE>"DL"          { return(REG_DL); }
<SEGSTATE>"DS"          { return(SREG_DS); }
<SEGSTATE>"DX"          { return(REG_DX); }
<SEGSTATE>"DWORD"       { return(SIZE_DWORD); }
<SEGSTATE>"ES"          { return(SREG_ES); }
<SEGSTATE>"ESC0"        { return(INST_ESC0); }
<SEGSTATE>"ESC1"        { return(INST_ESC1); }
<SEGSTATE>"ESC2"        { return(INST_ESC2); }
<SEGSTATE>"ESC3"        { return(INST_ESC3); }
<SEGSTATE>"ESC4"        { return(INST_ESC4); }
<SEGSTATE>"ESC5"        { return(INST_ESC5); }
<SEGSTATE>"ESC6"        { return(INST_ESC6); }
<SEGSTATE>"ESC7"        { return(INST_ESC7); }
<SEGSTATE>"HLT"         { return(INST_HLT); }
<SEGSTATE>"IDIV"        { return(INST_IDIV); }
<SEGSTATE>"IMUL"        { return(INST_IMUL); }
<SEGSTATE>"INB"         { return(INST_INB); }
<SEGSTATE>"INW"         { return(INST_INW); }
<SEGSTATE>"INC"         { return(INST_INC); }
<SEGSTATE>"INT"         { return(INST_INT); }
<SEGSTATE>"INTO"        { return(INST_INTO); }
<SEGSTATE>"IRET"        { return(INST_IRET); }
<SEGSTATE>"JA"          { return(INST_JA); }
<SEGSTATE>"JAE"         { return(INST_JAE); }
<SEGSTATE>"JB"          { return(INST_JB); }
<SEGSTATE>"JBE"         { return(INST_JBE); }
<SEGSTATE>"JC"          { return(INST_JC); }
<SEGSTATE>"JCXZ"        { return(INST_JCXZ); }
<SEGSTATE>"JE"          { return(INST_JE); }
<SEGSTATE>"JG"          { return(INST_JG); }
<SEGSTATE>"JGE"         { return(INST_JGE); }
<SEGSTATE>"JL"          { return(INST_JL); }
<SEGSTATE>"JLE"         { return(INST_JLE); }
<SEGSTATE>"JMPF"        { return(INST_JMPF); }
<SEGSTATE>"JMPN"        { return(INST_JMPN); }
<SEGSTATE>"JNA"         { return(INST_JNA); }
<SEGSTATE>"JNAE"        { return(INST_JNAE); }
<SEGSTATE>"JNB"         { return(INST_JNB); }
<SEGSTATE>"JNBE"        { return(INST_JNBE); }
<SEGSTATE>"JNC"         { return(INST_JNC); }
<SEGSTATE>"JNE"         { return(INST_JNE); }
<SEGSTATE>"JNG"         { return(INST_JNG); }
<SEGSTATE>"JNGE"        { return(INST_JNGE); }
<SEGSTATE>"JNL"         { return(INST_JNL); }
<SEGSTATE>"JNLE"        { return(INST_JNLE); }
<SEGSTATE>"JNO"         { return(INST_JNO); }
<SEGSTATE>"JNP"         { return(INST_JNP); }
<SEGSTATE>"JNS"         { return(INST_JNS); }
<SEGSTATE>"JNZ"         { return(INST_JNZ); }
<SEGSTATE>"JO"          { return(INST_JO); }
<SEGSTATE>"JP"          { return(INST_JP); }
<SEGSTATE>"JPE"         { return(INST_JPE); }
<SEGSTATE>"JPO"         { return(INST_JPO); }
<SEGSTATE>"JS"          { return(INST_JS); }
<SEGSTATE>"JZ"          { return(INST_JZ); }
<SEGSTATE>"LAHF"        { return(INST_LAHF); }
<SEGSTATE>"LDS"         { return(INST_LDS); }
<SEGSTATE>"LEA"         { return(INST_LEA); }
<SEGSTATE>"LES"         { return(INST_LES); }
<SEGSTATE>"LOCK"        { return(INST_LOCK); }
<SEGSTATE>"LODSB"       { return(INST_LODSB); }
<SEGSTATE>"LODSW"       { return(INST_LODSW); }
<SEGSTATE>"LOOP"        { return(INST_LOOP); }
<SEGSTATE>"LOOPE"       { return(INST_LOOPE); }
<SEGSTATE>"LOOPNE"      { return(INST_LOOPNE); }
<SEGSTATE>"LOOPNZ"      { return(INST_LOOPNZ); }
<SEGSTATE>"LOOPZ"       { return(INST_LOOPZ); }
<SEGSTATE>"MOV"         { return(INST_MOV); }
<SEGSTATE>"MOVSB"       { return(INST_MOVSB); }
<SEGSTATE>"MOVSW"       { return(INST_MOVSW); }
<SEGSTATE>"MUL"         { return(INST_MUL); }
<SEGSTATE>"NEG"         { return(INST_NEG); }
<SEGSTATE>"NOP"         { return(INST_NOP); }
<SEGSTATE>"NOT"         { return(INST_NOT); }
<SEGSTATE>"OR"          { return(INST_OR); }
<SEGSTATE>"OUTB"        { return(INST_OUTB); }
<SEGSTATE>"OUTW"        { return(INST_OUTW); }
<SEGSTATE>"POP"         { return(INST_POP); }
<SEGSTATE>"POPF"        { return(INST_POPF); }
<SEGSTATE>"PUSH"        { return(INST_PUSH); }
<SEGSTATE>"PUSHF"       { return(INST_PUSHF); }
<SEGSTATE>"PUT"         { return(DIR_PUT); }
<SEGSTATE>"RCL"         { return(INST_RCL); }
<SEGSTATE>"RCR"         { return(INST_RCR); }
<SEGSTATE>"REP"         { return(INST_REP); }
<SEGSTATE>"REPE"        { return(INST_REPE); }
<SEGSTATE>"REPNE"       { return(INST_REPNE); }
<SEGSTATE>"REPNZ"       { return(INST_REPNZ); }
<SEGSTATE>"REPZ"        { return(INST_REPZ); }
<SEGSTATE>"RETF"        { return(INST_RETF); }
<SEGSTATE>"RETN"        { return(INST_RETN); }
<SEGSTATE>"ROL"         { return(INST_ROL); }
<SEGSTATE>"ROR"         { return(INST_ROR); }
<SEGSTATE>"SAHF"        { return(INST_SAHF); }
<SEGSTATE>"SAL"         { return(INST_SAL); }
<SEGSTATE>"SAR"         { return(INST_SAR); }
<SEGSTATE>"SBB"         { return(INST_SBB); }
<SEGSTATE>"SCASB"       { return(INST_SCASB); }
<SEGSTATE>"SCASW"       { return(INST_SCASW); }
<SEGSTATE>"SEG"         { return(INST_SEG); }
<SEGSTATE>"SHL"         { return(INST_SHL); }
<SEGSTATE>"SHR"         { return(INST_SHR); }
<SEGSTATE>"SI"          { return(REG_SI); }
<SEGSTATE>"SP"          { return(REG_SP); }
<SEGSTATE>"SS"          { return(SREG_SS); }
<SEGSTATE>"STC"         { return(INST_STC); }
<SEGSTATE>"STD"         { return(INST_STD); }
<SEGSTATE>"STI"         { return(INST_STI); }
<SEGSTATE>"STOSB"       { return(INST_STOSB); }
<SEGSTATE>"STOSW"       { return(INST_STOSW); }
<SEGSTATE>"SUB"         { return(INST_SUB); }
<SEGSTATE>"TEST"        { return(INST_TEST); }
<SEGSTATE>"TIMES"       { return(DIR_TIMES); }
<SEGSTATE>"WAIT"        { return(INST_WAIT); }
<SEGSTATE>"WORD"        { return(SIZE_WORD); }
<SEGSTATE>"XCHG"        { return(INST_XCHG); }
<SEGSTATE>"XLAT"        { return(INST_XLAT); }
<SEGSTATE>"XOR"         { return(INST_XOR); }

<SEGSTATE>"+"                           { return('+'); }
<SEGSTATE>"-"                           { return('-'); }
<SEGSTATE>"*"                           { return('*'); }
<SEGSTATE>"/"                           { return('/'); }
<SEGSTATE>"!"                           { return('!'); }
<SEGSTATE>"^"                           { return('^'); }
<SEGSTATE>">"                           { return('>'); }
<SEGSTATE>"<"                           { return('<'); }
<SEGSTATE>"("                           { return('('); }
<SEGSTATE>")"                           { return(')'); }
<SEGSTATE>"["                           { return('['); }
<SEGSTATE>"]"                           { return(']'); }
<SEGSTATE>":"                           { return(':'); }
<SEGSTATE>","                           { return(','); }

<SEGSTATE>"@"                           { return(DIR_HERE); }

<SEGSTATE>[+-]?[0-9]+                   {
                                            long int tmp = atol(yytext);
                                            if(tmp > 32767 || tmp < -32768){
                                                PrintError(COLOR_BOLDRED, "Line %d :: Number size overflow!\n", LN);
                                                erroneous = TRUE;
                                            }else{
                                                yylval.imm_t.val = (short int) tmp;
                                                yylval.imm_t.isSym = FALSE;
                                            }
                                            return(NUMBER);
                                        }
<SEGSTATE>[+-]?"0x"[0-9a-f]+            {
                                            long int tmp = ConvertHec2Dec(yytext);
                                            if(tmp > 32767 || tmp < -32768){
                                                PrintError(COLOR_BOLDRED, "Line %d :: Number size overflow!\n", LN);
                                                erroneous = TRUE;
                                            }else{
                                                yylval.imm_t.val = (short int) tmp;
                                                yylval.imm_t.isSym = FALSE;
                                            }
                                            return(NUMBER);
                                        }
<SEGSTATE>"."[A-Z0-9_]+                 { yylval.sval = strdup(yytext); return(LABEL); }
<SEGSTATE>\"(([^\"]|\\\")*[^\\])?\"     { yylval.sval = strdup(RemoveQuotes(yytext)); return(STRCONST); }

<SEGSTATE>[ \t]                         { /* Ignore Whitespaces */ }
<SEGSTATE>[\n]                          { return(NL); }

<SEGSTATE>"}"                           { BEGIN INITIAL; return('}'); }

<SEGSTATE>.                             { yyerror("Unrecognized Character/Token"); }
.                                       { yyerror("Unrecognized Character/Token"); }


