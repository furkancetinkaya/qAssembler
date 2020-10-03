CC = gcc
BB = bison
FF = flex

CFLAGS += -Wall -Werror -Wno-unused-function -lfl -lm
BFLAGS += -v -d
FFLAGS += --header-file=Pass2Scanner.h

CFILES += Pass2.c \
		  lex.yy.c \
		  Pass2-Parser.tab.c \
		  ../Utility/Encoder.c \
		  ../Utility/Miscellaneous.c \
		  ../Utility/TableOperations.c \
		  ../Utility/ErrorHandler.c
BFILES += Pass2-Parser.y
FFILES += Pass2-Scanner.l

RMFILES += ../../bin/qasm-pass2 \
		   lex.yy.c \
		   Pass2-Parser.tab.c \
		   Pass2-Parser.tab.h \
		   Pass2-Parser.output \
		   Pass2Scanner.h

all: clean build_pass2

build_parser: $(BFILES)
	$(BB) $(BFLAGS) $(BFILES)

build_lexer: build_parser $(FFILES)
	$(FF) $(FFLAGS) $(FFILES)

build_pass2: build_lexer $(CFILES)
	$(CC) $(CFLAGS) $(CFILES) -o ../../bin/qasm-pass2

clean:
	rm -f $(RMFILES)