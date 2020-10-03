%{
/*#=========================================================================###
##                                                                           ##
##        Author:  Furkan Çetinkaya <furkan.cetinkaya@outlook.com.tr>        ##
##                                                                           ##
###=========================================================================#*/

#include "../../include/Definitions.h"
#include "Prep-Parser.tab.h"

extern uint8_t errcode;
extern void PrintError(char *color, char *format, ...);
extern void InternalError(char *format, ...);
extern void ExternalError(char *format, ...);

extern void WriteToFile(char *str);
extern void yyerror(const char *s);
extern LCounter_t LN;
%}

%option case-insensitive noyywrap nodefault

%x SEGMENT
%%

"@"[a-z0-9_]+               { yylval.sval = strdup(yytext); return(VARNAME); }
[+-]?"0x"[0-9a-f]+          { yylval.sval = strdup(yytext); return(VALUE);   }
[+-]?[0-9]+                 { yylval.sval = strdup(yytext); return(VALUE);   }
\"(([^\"]|\\\")*[^\\])?\"   { yylval.sval = strdup(yytext); return(VALUE);   }
"\n"                        { WriteToFile(yytext); LN++; return(NL); }
;.*                         { /* Ignore comments */ }

"{"             { WriteToFile(yytext); BEGIN SEGMENT; }
<SEGMENT>"}"    { WriteToFile(yytext); BEGIN INITIAL; }
<SEGMENT>"@"[a-z0-9_]+  { yylval.sval = strdup(yytext); return(INSTANCE); }
<SEGMENT>"\n"   { WriteToFile(yytext); LN++; }
<SEGMENT>;.*    { /* Ignore comments */ }
<SEGMENT>.      { WriteToFile(yytext); }
.       { WriteToFile(yytext); }


%%

// No code needed!