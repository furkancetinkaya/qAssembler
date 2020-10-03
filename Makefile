
all: clean src/Makefile
	make -C src/

build_qasm: src/Makefile
	make build_qasm -C src/

build_prep: src/Makefile
	make build_prep -C src/

build_pass1: src/Makefile
	make build_pass1 -C src/

build_pass1: src/Makefile
	make build_pass2 -C src/

clean: src/Makefile
	make clean -C src/