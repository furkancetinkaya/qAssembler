
/*#=========================================================================###
##                                                                           ##
##        Author:  Furkan Çetinkaya <furkan.cetinkaya@outlook.com.tr>        ##
##                                                                           ##
###=========================================================================#*/

#ifndef ERROR_HANDLER
#define ERROR_HANDLER

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <math.h>
#include "../../include/Errors.h"
#include "../../include/Definitions.h"
;
uint8_t errcode;

char *ConvertDectoString(int dec);
char *ConverHextoString(int hex);


void PrintError(char *color, char *format, ...)
{
    int dint;     // Decimal Integer
    int hint;     // Hexadecimal Integer
    char  cval;   // Character Value
    char *sval;   // String Value
    char *p;
    char buf[ERR_BUFFERSIZE];
    strncpy(buf, "\0", ERR_BUFFERSIZE);
    int bufidx = 0;

    va_list ArgList;
    va_start(ArgList, format);
    
    for(p=format; *p; p++){
        if(*p != '%'){
            buf[bufidx] = *p;
            bufidx++;
            continue;
        }
        switch(*++p){
            case 'd':
                dint = va_arg(ArgList, int);
                sval = ConvertDectoString(dint);
                strcat(buf, sval);
                bufidx += strlen(sval);
                break;
            case 'x':
                hint = va_arg(ArgList, int);
                sval = ConverHextoString(hint);
                strcat(buf, sval);
                bufidx += strlen(sval);
                break;
            case 'c':
                cval = (char) va_arg(ArgList, int);
                buf[bufidx] = cval;
                bufidx++;
                break;
            case 's':
                sval = va_arg(ArgList, char*);
                strcat(buf, sval);
                bufidx += strlen(sval);
                break;
            default:
                buf[bufidx] = *p;
                bufidx++;
                break;
        }
    }
    va_end(ArgList);

    // Print out buffer
    fprintf(stderr, "%s%s\033[0m", color, buf);
    return;
}

void InternalError(char *format, ...)
{
    int dint;     // Decimal Integer
    int hint;     // Hexadecimal Integer
    char  cval;   // Character Value
    char *sval;   // String Value
    char *p;
    char buf[ERR_BUFFERSIZE];
    strncpy(buf, "\0", ERR_BUFFERSIZE);
    int bufidx = 0;

    va_list ArgList;
    va_start(ArgList, format);
    
    for(p=format; *p; p++){
        if(*p != '%'){
            buf[bufidx] = *p;
            bufidx++;
            continue;
        }
        switch(*++p){
            case 'd':
                dint = va_arg(ArgList, int);
                sval = ConvertDectoString(dint);
                strcat(buf, sval);
                bufidx += strlen(sval);
                break;
            case 'x':
                hint = va_arg(ArgList, int);
                sval = ConverHextoString(hint);
                strcat(buf, sval);
                bufidx += strlen(sval);
                break;
            case 'c':
                cval = (char) va_arg(ArgList, int);
                buf[bufidx] = cval;
                bufidx++;
                break;
            case 's':
                sval = va_arg(ArgList, char*);
                strcat(buf, sval);
                bufidx += strlen(sval);
                break;
            default:
                buf[bufidx] = *p;
                bufidx++;
                break;
        }
    }
    va_end(ArgList);

    // Print Error Messages
    PrintError(COLOR_BOLDRED, buf);
    PrintError(COLOR_BLUE, ErrorMessages[errcode]);

    return;
}

void ExternalError(char *format, ...){

    int dint;     // Decimal Integer
    int hint;     // Hexadecimal Integer
    char  cval;   // Character Value
    char *sval;   // String Value
    char *p;
    char buf[ERR_BUFFERSIZE];
    strncpy(buf, "\0", ERR_BUFFERSIZE);
    int bufidx = 0;

    va_list ArgList;
    va_start(ArgList, format);
    
    for(p=format; *p; p++){
        if(*p != '%'){
            buf[bufidx] = *p;
            bufidx++;
            continue;
        }
        switch(*++p){
            case 'd':
                dint = va_arg(ArgList, int);
                sval = ConvertDectoString(dint);
                strcat(buf, sval);
                bufidx += strlen(sval);
                break;
            case 'x':
                hint = va_arg(ArgList, int);
                sval = ConverHextoString(hint);
                strcat(buf, sval);
                bufidx += strlen(sval);
                break;
            case 'c':
                cval = (char) va_arg(ArgList, int);
                buf[bufidx] = cval;
                bufidx++;
                break;
            case 's':
                sval = va_arg(ArgList, char*);
                strcat(buf, sval);
                bufidx += strlen(sval);
                break;
            default:
                buf[bufidx] = *p;
                bufidx++;
                break;
        }
    }
    va_end(ArgList);

    // Print Error Messages
    PrintError(COLOR_BOLDRED, buf);
    perror("");

    return;
}



/* There is problem with negative numbers */
char *ConvertDectoString(int dec)
{
    char *buf = (char*)malloc(11*sizeof(char));;
    uint8_t bufidx = 0;
    if(dec < 0){
        strcat(buf, "-");
        bufidx++;
    }
    
    int idx;
    for(idx=9; idx >= 0; idx--){
        int num = (int)pow(10.0, (double)idx);
        buf[bufidx++] = (int)(dec/num) + 48;
        dec = dec % num;
    }
    

    return buf;
}

char *ConverHextoString(int hex)
{
    /*
    char buf[11];
    strncpy(buf, "\0", 11);

    if(hex < 0)
        strcat(buf, "-");
    strcat(buf, "0x");

*/
    return "Hexadecimal";
}


#endif