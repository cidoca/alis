AR=ar
ASM=nasm
OBJECTS=banks.o cpu.o data.o io.o psg.o vdp.o text.o

libcore.a: $(OBJECTS)
	@echo Generating static library $@
	@$(AR) rcs $@ $(OBJECTS)

%.o: %.asm
	@echo Compiling $<
	@$(ASM) -felf $<

clean:
	@rm -f *.a *.o
