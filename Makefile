TARGET=alis
OBJECTS=main.o cpu.o io.o memory.o vdp.o psg.o ga.o

CC=gcc
LIBS=`sdl2-config --libs`
CFLAGS=-Wall `sdl2-config --cflags`

ifdef RELEASE
    CFLAGS+=-O2 -flto
    LFLAGS+=-flto
else
    OBJECTS+=log.o
    CFLAGS+=-O0 -g -DDEBUG
endif

ifdef FTDI
    CFLAGS+=-DFTDI
    LIBS+=ftdi/libftd2xx.a
endif

$(TARGET): $(OBJECTS)
	@echo Linking executable $@
	@$(CC) $(LFLAGS) -o $@ $(OBJECTS) $(LIBS)

main.o: main.c cpu.h
	@echo Compiling $<
	@$(CC) $(CFLAGS) -c $< -o $@

cpu.o: cpu.c cpu.h io.h memory.h log.h
	@echo Compiling $<
	@$(CC) $(CFLAGS) -c $< -o $@

io.o: io.c vdp.h psg.h ga.h log.h
	@echo Compiling $<
	@$(CC) $(CFLAGS) -c $< -o $@

memory.o: memory.c log.h
	@echo Compiling $<
	@$(CC) $(CFLAGS) -c $< -o $@

vdp.o: vdp.c log.h
	@echo Compiling $<
	@$(CC) $(CFLAGS) -c $< -o $@

psg.o: psg.c log.h
	@echo Compiling $<
	@$(CC) $(CFLAGS) -c $< -o $@

ga.o: ga.c log.h
	@echo Compiling $<
	@$(CC) $(CFLAGS) -c $< -o $@

log.o: log.c cpu.h memory.h
	@echo Compiling $<
	@$(CC) $(CFLAGS) -c $< -o $@

clean:
	@rm -f $(TARGET) *.o

