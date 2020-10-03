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
#include "../../include/Errors.h"

Variable_t *VariableTable;
MCounter_t VarTabIdx;
extern LCounter_t LN;
extern Fname_t dest;

extern uint8_t errcode;
extern void PrintError(char *color, char *format, ...);
extern void InternalError(char *format, ...);
extern void ExternalError(char *format, ...);

int CheckVariableExistence(char *name);
int RegisterVariable(char *name, char *value);

extern void WriteToFile(char *str);
extern int yylex();
void yyerror(const char *s);
extern FILE *fdest;
%}
%union{ 
    char *sval;
}

%token DEFINE
%token <sval> VARNAME
%token <sval> VALUE
%token <sval> INSTANCE
%token NL

%start exp

%%

exp: %empty
    | exp VALUE             { WriteToFile($<sval>2); }
    | exp NL                { /* Do nothing */ }
    | exp VARNAME VALUE NL  { 
        RegisterVariable($<sval>2, $<sval>3);
     }
    | exp VARNAME error NL  {
        yyerror("Syntax Error: No value for variable");
    }
    | exp INSTANCE      {
        int existence = CheckVariableExistence($<sval>2);
        if(existence == -1){
            yyerror("Variable is not defined");
            exit(EXIT_FAILURE);
        }
        WriteToFile(VariableTable[existence].value);
    }
    | error { yyerror("Syntax Error"); }
;

%%

void yyerror(const char *s){
    PrintError(COLOR_RED, "%s in line %d\n", s, LN);
    fclose(fdest);
    remove(dest);
    exit(EXIT_FAILURE);
}

int RegisterVariable(char *name, char *value)
{

    int existence = CheckVariableExistence(name);
    if(existence != -1){
        yyerror("Error: Multiple variable definition in source file!");
    }
    if(VariableTable == NULL){
        VarTabIdx = 0;
        VariableTable = (Variable_t*)malloc(sizeof(Variable_t));
        VariableTable[VarTabIdx].name = name;
        VariableTable[VarTabIdx].value = value;
        VarTabIdx++;
    }else{
        VariableTable = (Variable_t*) realloc(VariableTable, (VarTabIdx+1)*sizeof(Variable_t));
        VariableTable[VarTabIdx].name = name;
        VariableTable[VarTabIdx].value = value;
        VarTabIdx++;
    }

    return 0;
}

int CheckVariableExistence(char *name)
{
    if(VarTabIdx > 0){
        int idx;
        for(idx = 0; idx < VarTabIdx; idx++){
            if( strcmp(VariableTable[idx].name, name) == 0 ){
                return idx;
            }
        }
    }

    return -1;
}