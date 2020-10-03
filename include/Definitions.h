#ifndef DEFINITIONS_HEADER
#define DEFINITIONS_HEADER

#include <stdint.h>

/* Constant Definitions */
#define SET  1
#define NSET 0

#define TRUE  1
#define FALSE 0

/* Limit Definitions */
#define FILENAMEMAX 255
#define ERR_BUFFERSIZE 1024

/* Return Values */
#define RET_SUCCESS 0
#define RET_FAILURE 1


/* Color Definitions */
#define COLOR_BLACK         "\033[30m"
#define COLOR_BOLDBLACK     "\033[1;30m"
#define COLOR_RED           "\033[31m"
#define COLOR_BOLDRED       "\033[1;31m"
#define COLOR_GREEN         "\033[32m"
#define COLOR_BOLDGREEN     "\033[1;32m"
#define COLOR_YELLOW        "\033[33m"
#define COLOR_BOLDYELLOW    "\033[1;33m"
#define COLOR_BLUE          "\033[34m"
#define COLOR_BOLDBLUE      "\033[1;34m"
#define COLOR_MAGENTA       "\033[35m"
#define COLOR_BOLDMAGENTA   "\033[1;35m"
#define COLOR_CYAN          "\033[36m"
#define COLOR_BOLDCYAN      "\033[1;36m"
#define COLOR_WHITE         "\033[37m"
#define COLOR_BOLDWHITE     "\033[1;37m"


/* Type Definitions */
typedef char     *String_t;                 // String Type
typedef char      Fname_t[FILENAMEMAX];     // FileName Type
typedef uint8_t  Boolean_t;
typedef uint8_t  SCounter_t;
typedef uint16_t MCounter_t;
typedef uint32_t LCounter_t;
typedef uint8_t  Flag_t;

/* Structures */
typedef struct{
    String_t name;
    String_t value;
}Variable_t;

#endif