CC = gcc
FF = flex
BB = bison

CFLAGS += -Wall -Werror -Wno-unused-function -lm -lfl
BFLAGS += -Wall -Werror -v -d
FFLAGS += --header-file=Pass1-Scanner.h

CFILES += lex.yy.c \
		  ../Utility/ErrorHandler.c \
		  ../Utility/Miscellaneous.c \
		  ../Utility/TableOperations.c \
		  ../Utility/InstructionSizes.c \
		  Pass1-Parser.tab.c \
		  Pass1.c

BFILES += Pass1-Parser.y
FFILES += Pass1-Scanner.l

all: clean build_pass1

build_parser: $(BFILES)
	$(BB) $(BFLAGS) $(BFILES)

build_lexer: build_parser $(FFILES)
	$(FF) $(FFLAGS) $(FFILES)

build_pass1: build_lexer $(CFILES)
	$(CC) $(CFLAGS) $(CFILES) -o ../../bin/qasm-pass1

clean:
	rm -f lex.yy.c Pass1-Parser.tab.c Pass1-Parser.tab.h Pass1-Parser.output Pass1-Scanner.h ../../bin/qasm-pass1