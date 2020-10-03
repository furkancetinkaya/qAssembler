
/*#=========================================================================###
##                                                                           ##
##        Author:  Furkan Çetinkaya <furkan.cetinkaya@outlook.com.tr>        ##
##                                                                           ##
###=========================================================================#*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include "../../include/Definitions.h"
#include "../../include/Errors.h"
#include "../../include/Assembler.h"
#include "Pass2Scanner.h"

/* Global Variables */
Boolean_t erroneous;                // Is there any error?
Fname_t SrcFile;                    // Source File to be scanned/parsed
LCounter_t LN;                      // Line Number
MCounter_t LC;                      // Global Location Counter
Flag_t isORG;                       // Is ORG directive used
Flag_t isSOP;                       // Is segment is overwridden
uint8_t SOP;                        // Overridden Segment
FILE *fdest;
char *dstfile;

/* Tables */
Segment_t *SegmentTable;            // Segments
Label_t *LabelTable;                // Labels
Symbol_t *SymbolTable;              // Temporary Table for both Segments and Labels
size_t CurrentSegment;              // Current Segment Index
size_t stsize;                      // Label Segment Size
size_t ltsize;                      // Segment Table Size

/* Error Functions/Variables */
extern uint8_t errcode;                                     // Error Code for Internal Errors
extern void PrintError(char *color, char *format, ...);     // Print Custom Error Message
extern void InternalError(char *format, ...);               // Print Internal Error Message
extern void ExternalError(char *format, ...);               // Print External Error Message

/* Flex/Bison Functions/Variables */
extern int yylex();                             // Flex Scanner Function
extern int yyparse();                           // Bison Parser Function
extern FILE *yyin;                              // Flex/Bison Input Buffer

void WriteByte2File(uint8_t byte);              // Write byte values to the destination file (srcfilename.bin)
int GetSymbolTable(long long int symtabsize);   // Create Segment and Label Tables via Symbol Table
void ExitSafely(int retcode);                   // Release resouces and Exit
void InitializePass2(void);                     // Initialize Global Variables
int main(int argc, char **argv);                // Main Function for Assembler Pass 2



/*      FUNCTION DEFINITIONS        */

int main(int argc, char **argv)
{
    --argc;
    ++argv;
    InitializePass2();                  // Initialize Variables
    strcpy(SrcFile, argv[1]);           // Register Source File
    GetSymbolTable(atoll(argv[0]));     // Get Symbol Table SHM

    size_t len = strlen(argv[1]);
    dstfile = malloc((len-1)*sizeof(char));
    size_t idx;
    for(idx=1; idx<len-3; idx++){
        dstfile[idx-1] = argv[1][idx];
    }
    strcat(dstfile, "bin");
    
    FILE *fd = fopen(argv[1], "r");
    if(!fd){
        ExternalError("Failed to open source file!\n");
        ExitSafely(EXIT_FAILURE);
    }
    fdest = fopen(dstfile, "wb");
    if(!fdest){
        ExternalError("Failed to open destination file: ");
        ExitSafely(EXIT_FAILURE);
    }

    yyin = fd;
    yyparse();


    ExitSafely(EXIT_SUCCESS);
}

//-----------------------------------------------------------------------------

void InitializePass2(void)
{
    SegmentTable = NULL;
    LabelTable   = NULL;
    SymbolTable  = NULL;
    strncpy(SrcFile, "\0", FILENAMEMAX);
    
    SOP    = 0;
    LN     = 0;
    LC     = 0;
    stsize = 0;
    ltsize = 0;
    CurrentSegment = 0;

    erroneous = FALSE;
    isSOP     = NSET;
    isORG     = NSET;

    return;
}

//-----------------------------------------------------------------------------

int GetSymbolTable(long long int symtabsize)
{
    key_t key;
    int shmid;

    // Create a unique temporary file name to use as shared memory via ftok()
    if ((key = ftok(SrcFile, 'R')) == -1) {
        ExternalError("Failed to get SHM key: ");
        ExitSafely(EXIT_FAILURE);
    }

    // Create the shared memory by calculating the size of Segment and Label Tables.
    if ((shmid = shmget(key, (symtabsize)*sizeof(Label_t), 0644 | IPC_CREAT)) == -1) {
        ExternalError("Failed to open SHM: ");
        ExitSafely(EXIT_FAILURE);
    }

    // Match the created shared memory with Symbol Table
    SymbolTable = shmat(shmid, (void *)0, 0);
    if (SymbolTable == (Symbol_t *)(-1)) {
        ExternalError("Failed to match SymbolTable with SHM: ");
        ExitSafely(EXIT_FAILURE);
    }

    // Create the tables
    size_t idx;
    for(idx=0; idx<symtabsize; idx++){
        if(SymbolTable[idx].type == TYPE_SEGMENT){
            if(SegmentTable == NULL){
                stsize = 0;
                SegmentTable = malloc(sizeof(Segment_t));
                strncpy(SegmentTable[stsize].name, SymbolTable[idx].sname, SEGNAMEMAX);
                SegmentTable[stsize].LC = 0; //SymbolTable[idx].LC;
                SegmentTable[stsize].loc = SymbolTable[idx].loc;
                stsize++; 
            }else{
                SegmentTable = realloc(SegmentTable, (stsize+1)*sizeof(Segment_t));
                strncpy(SegmentTable[stsize].name, SymbolTable[idx].sname, SEGNAMEMAX);
                SegmentTable[stsize].LC = 0; //SymbolTable[idx].LC;
                SegmentTable[stsize].loc = SymbolTable[idx].loc;
                stsize++;
            }
        }else if(SymbolTable[idx].type == TYPE_LABEL){
            if(LabelTable == NULL){
                ltsize = 0;
                LabelTable = malloc(sizeof(Label_t));
                strncpy(LabelTable[ltsize].name, SymbolTable[idx].lname, LABNAMEMAX);
                strncpy(LabelTable[ltsize].segname, SymbolTable[idx].sname, SEGNAMEMAX);
                LabelTable[ltsize].loc = SymbolTable[idx].LC;
                ltsize++;
            }else{
                LabelTable = realloc(LabelTable, (ltsize+1)*sizeof(Label_t));
                strncpy(LabelTable[ltsize].name, SymbolTable[idx].lname, LABNAMEMAX);
                strncpy(LabelTable[ltsize].segname, SymbolTable[idx].sname, SEGNAMEMAX);
                LabelTable[ltsize].loc = SymbolTable[idx].LC;
                ltsize++;
            }
        }else{
            errcode = ERR_SYMTABGET;
            InternalError("Error: ");
            ExitSafely(EXIT_FAILURE);
        }
    }

    // Detach the shared memory
    if (shmdt(SymbolTable) == -1) {
        ExternalError("Failed to detach SHM: ");
        ExitSafely(EXIT_FAILURE);
    }

    return RET_SUCCESS;
}

//-----------------------------------------------------------------------------

void WriteByte2File(uint8_t byte)
{
    uint8_t *buf = malloc(sizeof(uint8_t));
    buf[0] = byte;
    fwrite(buf, sizeof(uint8_t), 1, fdest);

    return;
}

//-----------------------------------------------------------------------------

void ExitSafely(int retcode)
{
    fclose(fdest);
    char *cmd;
    cmd = malloc( (strlen(SrcFile)+ strlen("rm -f "))*sizeof(char) );
    strcpy(cmd, "rm -f ");
    strcat(cmd, SrcFile);
    system(cmd);

    free(SymbolTable);
    free(SegmentTable);
    free(LabelTable);
    free(fdest);

    if(retcode == EXIT_FAILURE){
        strcpy(cmd, "rm -f ");
        strcat(cmd, dstfile);
        system(cmd);
    }
    free(dstfile);

    exit(retcode);
}