CC = gcc
CFLAGS += -Wall -Werror -lm
CFILES += qasm.c \
		  Utility/ErrorHandler.c

all: clean build_qasm build_prep build_pass1 build_pass2

build_qasm: $(CFILES)
	$(CC) $(CFLAGS) $(CFILES) -o ../bin/qasm

build_prep: Preprocessor/Makefile
	make -C Preprocessor/

build_pass1: Pass1/Makefile
	make -C Pass1/

build_pass2: Pass2/Makefile
	make -C Pass2/

clean:
	rm -f ../bin/qasm
	make clean -C Pass1/
	make clean -C Pass2/
	make clean -C Preprocessor/