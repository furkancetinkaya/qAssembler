#define ERR_SUCCESS      0
#define ERR_SRCFOVERFLOW 1
#define ERR_NOSRCFILE    2
#define ERR_NOARGUMENT   3
#define ERR_SEGALRDEXST  4
#define ERR_LABALRDEXST  5
#define ERR_SRCFNAMEOOB  6
#define ERR_SYMTABGET    7

#ifdef ERROR_HANDLER

    #include "Definitions.h"
    #define LENERRMSG 100

    String_t ErrorMessages[LENERRMSG] = {
        "Success\n",
        "Only one source file is accepted!\n",
        "No source file specified!\n",
        "No argument specified!\n",
        "Segment name already exists!\n",
        "Label name already exists!\n",
        "Source file name is out of boundary!\n",
        "Problem while receiving symboltable!\n",
        ""
    }

#endif