
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
#include "../../include/Errors.h"
#include "../../include/Assembler.h"

/* Assembler Variables */
/* Parser Variables */
extern Flag_t isSOP;                     // Is segment is overwritten
extern Flag_t isORG;                     // Is ORG directive used
extern uint8_t SOP;
extern LCounter_t LN;
extern MCounter_t LC;

/* Tables */
extern Segment_t *SegmentTable;
extern Label_t *LabelTable;
extern size_t ltsize;
extern size_t stsize;

/* Error Variables */
extern Boolean_t erroneous;
extern uint8_t errcode;

/* Error Functions */
extern void PrintError(char *color, char *format, ...);
extern void InternalError(char *format, ...);
extern void ExternalError(char *format, ...);

/* Function Declerations */
size_t CheckSegmentExistence(char *sname);
size_t CheckLabelExistence(char *lname);
Boolean_t RegisterLabel(char *str);
Boolean_t RegisterSegment(char *str);




/*          FUNCTION DEFINITIONS             */
Boolean_t RegisterSegment(char *str)
{
    //printf("Register Segment : %s\n", str);
    size_t ret = CheckSegmentExistence(str);
    if(ret != -1){
        errcode = ERR_SEGALRDEXST;  // Segment Already Exist
        InternalError("Line %d :: Segment Registration Error: ", LN);
        return FALSE;
    }

    if( SegmentTable == NULL ){
        stsize = 0;
        SegmentTable = malloc(sizeof(Segment_t));
        strcpy(SegmentTable[stsize].name, str); // Segment name
        SegmentTable[stsize].LC = 0;    // Local LC
        SegmentTable[stsize].loc = LC;  // Global LC
        stsize++;
    }else{
        SegmentTable = realloc(SegmentTable, (stsize+1)*sizeof(Segment_t));
        strcpy(SegmentTable[stsize].name, str); // Segment name
        SegmentTable[stsize].LC = 0;    // Local LC
        SegmentTable[stsize].loc = LC;  // Global LC
        stsize++;
    }

    return TRUE;
}

Boolean_t RegisterLabel(char *str)
{
    size_t ret = CheckLabelExistence(str);
    if(ret != -1){
        errcode = ERR_LABALRDEXST;  // Label Already Exist
        InternalError("Line %d :: Label Registration Error: ", LN);
        return FALSE;
    }

    if( LabelTable == NULL ){
        ltsize = 0;
        LabelTable = malloc(sizeof(Label_t));
        strcpy(LabelTable[ltsize].name, str);                       // Label name
        strcpy(LabelTable[ltsize].segname, SegmentTable[stsize-1].name); // Segment Name
        SegmentTable[ltsize].loc = SegmentTable[stsize-1].LC;         // Location within Segment
        ltsize++;
    }else{
        LabelTable = realloc(LabelTable, (ltsize+1)*sizeof(Label_t));
        strcpy(LabelTable[ltsize].name, str);                       // Label name
        strcpy(LabelTable[ltsize].segname, SegmentTable[stsize-1].name); // Segment Name
        LabelTable[ltsize].loc = SegmentTable[stsize-1].LC;         // Location within Segment
        ltsize++;
    }

    return TRUE;
}


size_t CheckSegmentExistence(char *sname)
{
    if(SegmentTable == NULL)
        return -1;
    
    size_t ctr;
    for(ctr=0; ctr<stsize; ctr++){
        if( strcmp(SegmentTable[stsize].name, sname) == 0 ){
            return ctr;
        }
    }
    return -1;
}

size_t CheckLabelExistence(char *lname)
{
    if(LabelTable == NULL)
        return -1;
    
    size_t ctr;
    for(ctr=0; ctr<ltsize; ctr++){
        if( (strcmp(LabelTable[ctr].name, lname) == 0) && (strcmp(LabelTable[ctr].segname, SegmentTable[stsize-1].name) == 0) ){
            return ctr;
        }
    }
    return -1;
}