#ifndef ENCODING_HEADER
#define ENCODING_HEADER

#define MODE_NO_OPERAND 0
#define MODE_REG        1
#define MODE_MEM        2
#define MODE_IMM        3
#define MODE_REG_REG    4
#define MODE_REG_MEM    5
#define MODE_MEM_REG    6
#define MODE_REG_IMM    7
#define MODE_MEM_IMM    8
#define MODE_SREG_REG   9
#define MODE_SREG_MEM   10
#define MODE_REG_SREG   11
#define MODE_MEM_SREG   12
#define MODE_SREG       13
#define MODE_IMM_IMM    14

#define POP_INST  1
#define PUSH_INST 2
#define LEA_INST  3
#define LDS_INST  4
#define LES_INST  5
#define INB_INST  6
#define INW_INST  7
#define OUTB_INST 8
#define OUTW_INST 9
#define ADD_INST  10
#define ADC_INST  11
#define INC_INST  12
#define SUB_INST  13
#define SBB_INST  14
#define DEC_INST  15
#define NEG_INST  16
#define CMP_INST  17
#define MUL_INST  18
#define IMUL_INST 19
#define DIV_INST  20
#define IDIV_INST 21
#define NOT_INST  22
#define AND_INST  23
#define OR_INST   24
#define XOR_INST  25
#define SHL_INST  26
#define SAL_INST  27
#define SHR_INST  28
#define SAR_INST  29
#define ROL_INST  30
#define ROR_INST  31
#define RCL_INST  32
#define RCR_INST  33
#define CALLF_INST 34
#define CALLN_INST 35
#define JMPF_INST  36
#define JMPN_INST  37
#define RETN_INST  38
#define RETF_INST  39



#endif