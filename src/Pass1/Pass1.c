
/*#=========================================================================###
##                                                                           ##
##        Author:  Furkan Çetinkaya <furkan.cetinkaya@outlook.com.tr>        ##
##                                                                           ##
###=========================================================================#*/

#define QASM_PASS1

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include "../../include/Definitions.h"
#include "../../include/Errors.h"
#include "../../include/Assembler.h"
#include "Pass1-Scanner.h"

/* Global Variables */
LCounter_t LN;
MCounter_t LC;
Boolean_t erroneous;
Flag_t isSOP;                     // Is segment is overwritten
Flag_t isORG;                     // Is ORG directive used
uint8_t SOP;
Fname_t SrcFile;
FILE *fdest;

/* Tables */
Segment_t *SegmentTable;
Label_t *LabelTable;
size_t ltsize;
size_t stsize;
Symbol_t *SymbolTable;

/* Error Functions/Variables */
extern uint8_t errcode;
extern void PrintError(char *color, char *format, ...);
extern void InternalError(char *format, ...);
extern void ExternalError(char *format, ...);

/* Flex/Bison Functions/Variables */
extern int yylex();
extern int yyparse();
extern FILE *yyin;

/* Pass1 Function Declerations */
void InitializePass1(void);
void ExitSafely(int retcode);
void StartPass2(void);
int main(int argc, char **argv);

/* Pass1 Function Definitions */
int main(int argc, char **argv)
{
    InitializePass1();

    fdest = fopen(argv[2], "r");
    if(!fdest){
        ExternalError("Failed to open source file: ");
        exit(EXIT_FAILURE);
    }
    strcpy(SrcFile, argv[2]);

    yyin = fdest;
    yyparse();

    
    /* Call Pass2 Assembler */
    StartPass2();

    ExitSafely(EXIT_SUCCESS);
    return EXIT_SUCCESS;
}


void InitializePass1(void)
{
    errcode = 0;            // Err_Success
    erroneous = FALSE;      // No Error

    LN = 1;                 // Line Number initially 1
    LC = 0;                 // Location Counter initially 0

    isSOP = NSET;           // is there a Segment Overrride Prefix
    isORG = NSET;           // is ORG directive called
    SOP = 0;                // Segment Override Prefix

    LabelTable = NULL;      // Label Table is empty, initially
    SegmentTable = NULL;    // Segment Table is empty, initially
    ltsize = 0;             // Label Table index is 0, initially
    stsize = 0;             // Segment Table index is 0, initially

    SymbolTable = NULL;

    return;
}

void StartPass2(void)
{
    key_t key;
    int shmid;


    // Create a unique temporary file name to use as shared memory via ftok()
    if ((key = ftok(SrcFile, 'R')) == -1) {
        ExternalError("Failed to create SHM key: ");
        ExitSafely(EXIT_FAILURE);
    }

    // Create the shared memory by calculating the size of Segment and Label Tables.
    if ((shmid = shmget(key, (stsize+ltsize)*sizeof(Symbol_t) , IPC_CREAT | 0644)) == -1) {
        ExternalError("Failed to create SHM: ");
        ExitSafely(EXIT_FAILURE);
    }

    SymbolTable = malloc((ltsize+stsize)*sizeof(Symbol_t));

    // Match the created shared memory with Symbol Table
    SymbolTable = (Symbol_t*) shmat(shmid, NULL, 0);
    if (SymbolTable == (Symbol_t *)(-1)) {
        ExternalError("Failed to match SymbolTable with SHM: ");
        ExitSafely(EXIT_FAILURE);
    }

    // Write the entries of Symbol Table into memory
    //SymbolTable = malloc( (stsize+ltsize)*sizeof(Symbol_t) );
    size_t index;
    for(index=0; index<stsize; index++){
        SymbolTable[index].type = TYPE_SEGMENT;
        strncpy(SymbolTable[index].lname, "\0", LABNAMEMAX);
        strncpy(SymbolTable[index].sname, SegmentTable[index].name, SEGNAMEMAX);
        SymbolTable[index].LC = SegmentTable[index].LC;
        SymbolTable[index].loc = SegmentTable[index].loc;
    }
    for(; (index-stsize)<ltsize; index++){
        SymbolTable[index].type = TYPE_LABEL;
        strncpy(SymbolTable[index].lname, LabelTable[index-stsize].name, LABNAMEMAX);
        strncpy(SymbolTable[index].sname, LabelTable[index-stsize].segname, SEGNAMEMAX);
        SymbolTable[index].LC = LabelTable[index-stsize].loc;
        SymbolTable[index].loc = 0;
    }

    // Start Pass2
    int ret;
    int status;
    
    char symtabsize[50];
    sprintf(symtabsize, "%ld", (stsize+ltsize));

    pid_t pid = fork();
    if(pid < 0){
        ExternalError("Failed to start assembling: ");
        exit(EXIT_FAILURE);
    }else if(pid == 0){
        char **argv = malloc(4*sizeof(char*));
        argv[0] = strdup("qasm-pass2");
        argv[1] = strdup(symtabsize);
        argv[2] = strdup(SrcFile);
        argv[3] = NULL;

        ret = execvp(argv[0], argv);
        if(ret == -1){
            ExternalError("Failed to start assembling: ");
            exit(EXIT_FAILURE);
        }
    }else{
        waitpid(pid, &status, 0);
        if( WIFEXITED(status) )
            if(WEXITSTATUS(status) != EXIT_SUCCESS)
                exit(EXIT_FAILURE);                 // If assembler encountered an error, it displayed
                                                    // the error message. Just exit silently.
    }
    


    // Detach the shared memory
    if (shmdt(SymbolTable) == -1) {
        ExternalError("Failed to detach SHM: ");
        ExitSafely(EXIT_FAILURE);
    }

    // Remove the shared memory
    shmctl(shmid, IPC_RMID, NULL);

    return;
}


void ExitSafely(int retcode)
{
    fclose(yyin);           // Close the flex/bison buffer
    free(SegmentTable);     // Remove Segment Table
    free(LabelTable);       // Remove Label Table
    //free(fdest);            // Remove formerly used file descriptor
    // Remove the created shared memory

    exit(retcode);
}