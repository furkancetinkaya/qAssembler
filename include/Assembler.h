#ifndef ASSEMBLER_DEFINITIONS
#define ASSEMBLER_DEFINITIONS
#include "Definitions.h"

#define SZ_ERR   0
#define SZ_BYTE  1      // Byte
#define SZ_WORD  2      // Word
#define SZ_DWORD 4      // Double Word

#define SIGN_NEGATIVE 0
#define SIGN_POSITIVE 1

#define SREG_CODE    1  // CS
#define SREG_DATA    3  // DS
#define SREG_EXTRA   0  // ES
#define SREG_SEGMENT 2  // SS

#define GPR_AHSP  4
#define GPR_ALAX  0
#define GPR_BHDI  7
#define GPR_BLBX  3
#define GPR_CHBP  5
#define GPR_CLCX  1
#define GPR_DHSI  6
#define GPR_DLDX  2

#define IDX_SOURCE       1  // SI
#define IDX_DESTINATION  2  // DI

#define BASE_REG 1   // BX
#define BASE_PTR 2   // BP

#define ACC_BYTE 1   // AL
#define ACC_WORD 2   // AX

//-------------------------------------------------------

typedef struct{
    short int  val;
    SCounter_t size;
    Boolean_t  isSym;
}Immediate_t;

typedef struct{
    SCounter_t size;
    SCounter_t id;
}Register_t;

typedef struct{
    SCounter_t size;
    Boolean_t  isSym;
    SCounter_t mod;
    SCounter_t rm;
    short int  disp;
}Memory_t;


/* Definitions for the Symbol Table */

#define SEGNAMEMAX 120
#define LABNAMEMAX 120
#define TYPE_SEGMENT 1
#define TYPE_LABEL   2

typedef struct{
    char name[SEGNAMEMAX];     // The name of the segment
    LCounter_t loc;            // The location within the source file
    MCounter_t LC;             // Own location counter of the segment
}Segment_t;

typedef struct{
    char name[LABNAMEMAX];      // The name of the label
    char segname[SEGNAMEMAX];   // The name of the segment which it is contained from
    MCounter_t loc;             // Index within the segment
}Label_t;

/* Symbol Table Structure */
typedef struct{
    uint8_t type;               // TYPE_SEGMENT, TYPE_LABEL
    char lname[LABNAMEMAX];     // Label name if type is TYPE_LABEL
    char sname[SEGNAMEMAX];     // Segment name for both types
    MCounter_t LC;              // Location counter within the current segment of TYPE_LABEL
    LCounter_t loc;             // Global Location Counter for both of the types
}Symbol_t;

#endif