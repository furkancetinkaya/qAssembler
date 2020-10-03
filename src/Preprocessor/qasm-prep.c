
/*#=========================================================================###
##                                                                           ##
##        Author:  Furkan Çetinkaya <furkan.cetinkaya@outlook.com.tr>        ##
##                                                                           ##
###=========================================================================#*/

#define YASM_PREPROCESSOR

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "../../include/Definitions.h"
#include "../../include/Errors.h"
#include "PrepScan.h"

LCounter_t LN;
FILE *fdest;
Fname_t dest;

extern uint8_t errcode;
extern void PrintError(char *color, char *format, ...);
extern void InternalError(char *format, ...);
extern void ExternalError(char *format, ...);
extern int yylex();
extern int yyparse();
extern FILE *yyin;

void WriteToFile(char *str);

int main(int argc, char **argv)
{
    //printf("Prep: Source File: %s\n", argv[1]);
    //printf("Prep: Dest File: %s\n", argv[2]);
    strcpy(dest, argv[2]);
    FILE *fsrc = fopen(argv[1], "r");
    if(!fsrc){
        ExternalError("Failed to read preprocessor source file: ");
        remove(dest);
        exit(EXIT_FAILURE);
    }
    yyin = fsrc;
    fdest = fopen(argv[2], "w");
    if(!fdest){
        ExternalError("Failed to open preprocessor destination file: ");
        remove(dest);
        exit(EXIT_FAILURE);
    }
    LN = 1;
    yyparse();

    fclose(fdest);
    return EXIT_SUCCESS;
}


void WriteToFile(char *str)
{
    fprintf(fdest, "%s", str);
}