
/*#=========================================================================###
##                                                                           ##
##        Author:  Furkan Çetinkaya <furkan.cetinkaya@outlook.com.tr>        ##
##                                                                           ##
###=========================================================================#*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "../../include/Definitions.h"
#include "../../include/Assembler.h"
#include "../../include/Errors.h"

/* Error Variables */
extern Boolean_t erroneous;
extern uint8_t errcode;

/* Error Functions */
extern void PrintError(char *color, char *format, ...);
extern void InternalError(char *format, ...);
extern void ExternalError(char *format, ...);
extern void ExitSafely(int retcode);

/* Miscellaneous Functions Declerations */
char *RemoveQuotes(char *s);
SCounter_t CalculateSize(short int val);
Boolean_t CheckSignExtension(short int val);
short int ComputeFactorial(short int number);
long int ConvertHec2Dec(char *str);




/* Miscellaneous Functions Definitions */
char *RemoveQuotes(char *s){
    char *ret = malloc( (strlen(s)-2) * sizeof(char) );
    size_t idx;
    for(idx=0; idx < (strlen(s)-2); idx++)
        ret[idx] = s[idx+1];

    return ret;
}

SCounter_t CalculateSize(short int val){
    SCounter_t size = SZ_ERR;

    if( (val <= 127) && (val >= -128) ){
        size = SZ_BYTE;
    }else if( (val <= 32767) && (val >= -32768) ){
        size = SZ_WORD;
    }else{
        size = SZ_ERR;
    }

    return size;
}

Boolean_t CheckSignExtension(short int val){
    if( (val < 127) || (val > -126) )
        return TRUE;
    return FALSE;
}

short int ComputeFactorial(short int number)
{
    short int idx;
    for(idx=number-1; idx>0; idx-- )
        number *= idx;

    return number;
}

long int ConvertHec2Dec(char *str)
{
    uint8_t idx = 0;
    long int ret = 0;
    size_t len = strlen(str);
    uint8_t sign;   // 0 for positive, 1 for negative
    // Check the first char if it is a sign
    switch(str[idx]){
        case '+':
            sign = 0;
            idx += 3;
            break;
        case '-':
            sign = 1;
            idx += 3;
            break;
        default:
            sign = 0;
            idx += 2;
            break;
    }

    len--;
    if( str[len] == '\0' )
        len--;

    long int factor = 1;

    for(; len >= idx; len--){
        switch(str[len]){
            case '0':
                ret += factor * 0;
                break;
            case '1':
                ret += factor * 1;
                break;
            case '2':
                ret += factor * 2;
                break;
            case '3':
                ret += factor * 3;
                break;
            case '4':
                ret += factor * 4;
                break;
            case '5':
                ret += factor * 5;
                break;
            case '6':
                ret += factor * 6;
                break;
            case '7':
                ret += factor * 7;
                break;
            case '8':
                ret += factor * 8;
                break;
            case '9':
                ret += factor * 9;
                break;
            case 'a':
                ret += factor * 10;
                break;
            case 'b':
                ret += factor * 11;
                break;
            case 'c':
                ret += factor * 12;
                break;
            case 'd':
                ret += factor * 13;
                break;
            case 'e':
                ret += factor * 14;
                break;
            case 'f':
                ret += factor * 15;
                break;
            case 'A':
                ret += factor * 10;
                break;
            case 'B':
                ret += factor * 11;
                break;
            case 'C':
                ret += factor * 12;
                break;
            case 'D':
                ret += factor * 13;
                break;
            case 'E':
                ret += factor * 14;
                break;
            case 'F':
                ret += factor * 15;
                break;
            default:
                PrintError(COLOR_BOLDRED, "Error while hexadecimal conversion!\n");
                ExitSafely(EXIT_FAILURE);
                break;
        }
        factor = factor * 16;
    }

    if(sign == 0){
        if(ret > 32767){
            if((ret != 0) && (ret % 32768) == 0)
                ret = -32768;
            else{
                ret = ret % 32768;
                ret = 0 - (32768 - ret);
            }
        }
        
    }else{
        if(ret > 32767){
            if((ret != 0) && (ret % 32768) == 0)
                ret = -32768;
            else{
                ret = ret % 32768;
                ret = 0 - (32768 - ret);
            }
        }

        ret--;
        ret = ~ret;

        if(ret == 32768)
            ret = 0;
    }

    return ret;
}

uint8_t Convert2UnsignedByte(short int val)
{
    if(val < 0){
        PrintError(COLOR_BOLDRED, "Negative values can not be converted to unsigned int!\n");
        ExitSafely(EXIT_FAILURE);
    }
    if(val > 256)
        val = val % 256;
    
    val = val - 128;
    val = 0 - (128-val);

    return val;
}