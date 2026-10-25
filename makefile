# Build your functions with the local test harness.
ASM := $(wildcard task*.asm)
OBJ := $(ASM:.asm=.o)
dfa: $(OBJ) main.c
	gcc -no-pie main.c $(OBJ) -o dfa
%.o: %.asm
	yasm -f elf64 -g dwarf2 $< -o $@
clean:
	rm -f dfa *.o
