CC = gcc
FF = flex
BB = bison

CFLAGS += -Wall -Werror -Wno-unused-function -lfl -lm
FFLAGS += --header-file=PrepScan.h
BFLAGS += -v -d

CREQS += lex.yy.c   \
		Prep-Parser.tab.c \
		qasm-prep.c \
		PrepScan.h
FREQS += Prep-Scanner.l \
		Prep-Parser.tab.h
BREQS += Prep-Parser.y

CFILES += lex.yy.c Prep-Parser.tab.c qasm-prep.c ../Utility/ErrorHandler.c
FFILES += Prep-Scanner.l
BFILES += Prep-Parser.y

RMFILES += PrepScan.h \
		   lex.yy.c \
		   Prep-Parser.tab.c \
		   Prep-Parser.tab.h \
		   ../../bin/qasm-prep \
		   Prep-Parser.output

all: clean build_preprocessor

build_parser: $(BREQS)
	$(BB) $(BFLAGS) $(BFILES)

build_lexer: build_parser $(FREQS)
	$(FF) $(FFLAGS) $(FFILES)

build_preprocessor: build_lexer $(CREQS)
	$(CC) $(CFLAGS) $(CFILES) -o ../../bin/qasm-prep

clean:
	rm -f $(RMFILES)