
/*#=========================================================================###
##                                                                           ##
##        Author:  Furkan Çetinkaya <furkan.cetinkaya@outlook.com.tr>        ##
##                                                                           ##
###=========================================================================#*/

#define QASM_ASSEMBLER

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include "../include/Errors.h"
#include "../include/Definitions.h"

Fname_t SrcFile;   // Source File name

Flag_t helpArgument;   // Is help argment specified
Flag_t srcArgument;    // Is source file specified

extern uint8_t errcode;
extern void PrintError(char *color, char *format, ...);
extern void InternalError(char *format, ...);
extern void ExternalError(char *format, ...);

void Initialize();
Boolean_t CheckIfSource(char *str);
void DecodeArguments(int argc, char **argv);
void StartPreprocessor(char *prepd);
void StartAssembler(char *prepd);
void PrintHelp();
int main();



int main(int argc, char **argv)
{
    ++argv;
    --argc;
    Initialize();
    DecodeArguments(argc, argv);
    
    if(helpArgument == SET){   // If print help flag is set
        PrintHelp();           // Just print the help message
        exit(EXIT_SUCCESS);    // and exit ignoring other flags
    }

    if( srcArgument == NSET ){
        errcode = ERR_NOSRCFILE;
        InternalError("Error: ");
        exit(EXIT_FAILURE);
    }

    // Create the preprocessed file inside the current directory
    Fname_t prepd;
    strncpy(prepd, "\0", FILENAMEMAX);
    prepd[0] = '.';
    strcat(prepd, SrcFile);
    size_t len = strlen(prepd);
    prepd[len-1] = 'c';
    prepd[len-2] = 'r';
    prepd[len-3] = 's';
    /*String_t cmd = strdup("touch ");
    strcat(cmd, prepd);
    system(cmd);
*/

    StartPreprocessor(prepd);    // Place constants with their values and remove comments
    StartAssembler(prepd);       // Start pass1 and it will call pass2


    return EXIT_SUCCESS;
}


void Initialize()
{
    strncpy(SrcFile, "\0", FILENAMEMAX);
    
    helpArgument = NSET;
    srcArgument  = NSET;

    return;
}

void DecodeArguments(int argc, char **argv)
{
    if(argc > 0 && argv[0]){
        if(argc == 1){
            // Legal arguments: --help or srcfile
            if(strcmp(argv[0], "--help") == 0)
                helpArgument = SET;
            else if(CheckIfSource(argv[0]) == TRUE){
                if(strlen(argv[0]) > FILENAMEMAX){
                    errcode = ERR_SRCFNAMEOOB;
                    InternalError("Error: ");
                    exit(EXIT_FAILURE);
                }else{
                    strcpy(SrcFile, argv[0]);
                    srcArgument = SET;
                }
            }

        }else{
            errcode = ERR_SRCFOVERFLOW;
            InternalError("Error: ");
            exit(EXIT_FAILURE);
        }
    
    }else{
        errcode = ERR_NOARGUMENT;
        InternalError("Error: ");
        exit(EXIT_FAILURE);
    }
}

//---------------------------------------------------------------------------

void StartPreprocessor(char *prepd)
{
    int ret;
    int status;
    pid_t pid = fork();
    if(pid < 0){
        ExternalError("Failed to start preprocessing: ");
        exit(EXIT_FAILURE);
    }else if(pid == 0){
        char **argv = malloc(4*sizeof(char*));
        argv[0] = strdup("qasm-prep");
        argv[1] = strdup(SrcFile);
        argv[2] = strdup(prepd);
        argv[3] = NULL;

        ret = execvp(argv[0], argv);
        if(ret == -1){
            ExternalError("Failed to start preprocessing: ");
            exit(EXIT_FAILURE);
        }
    }else{
        waitpid(pid, &status, 0);
        if( WIFEXITED(status) )
            if(WEXITSTATUS(status) != EXIT_SUCCESS)
                exit(EXIT_FAILURE);                 // If preprocessor encountered an error, it displayed
                                                    // the error message. Just exit silently.
    }
}

//---------------------------------------------------------------------------

void StartAssembler(char *prepd)
{
    int ret;
    int status;
    pid_t pid = fork();
    if(pid < 0){
        ExternalError("Failed to start assembling: ");
        exit(EXIT_FAILURE);
    }else if(pid == 0){
        char **argv = malloc(4*sizeof(char*));
        argv[0] = strdup("qasm-pass1");
        argv[1] = strdup(SrcFile);
        argv[2] = strdup(prepd);
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
}

//---------------------------------------------------------------------------

void PrintHelp()
{
    printf("Help\n");
}

//----------------------------------------------------------------------------

Boolean_t CheckIfSource(char *str)
{
    size_t len = strlen(str);
    if(len <= 3) return FALSE;
    else{
        if( (str[len-4]) && (str[len-3]) && (str[len-2]) && (str[len-1]) )
            return TRUE;
        else
            return FALSE;
    }
}