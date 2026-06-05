CC=gcc
LIBS=`sdl2-config --libs`
CFLAGS=-Wall `sdl2-config --cflags`

SRC=src
TARGET=alis
BUILD=/tmp/build-$(TARGET)
OBJECTS=$(BUILD)/main.o $(BUILD)/cpu.o $(BUILD)/io.o $(BUILD)/memory.o $(BUILD)/vdp.o $(BUILD)/psg.o $(BUILD)/ga.o $(BUILD)/sdl.o

ifdef RELEASE
    CFLAGS+=-O2 -flto
    LFLAGS+=-flto -s
else
    OBJECTS+=$(BUILD)/log.o
    CFLAGS+=-O0 -g -DDEBUG
endif

#ifdef FTDI
#    CFLAGS+=-DFTDI
#    OBJECTS+=$(BUILD)/ftdi.o
#    LIBS+=ftdi/libftd2xx.a
#endif

.PHONY: all
all: $(BUILD) $(TARGET)

$(BUILD):
	@mkdir $(BUILD)

$(TARGET): $(OBJECTS)
	@echo Linking executable $@
	@$(CC) $(LFLAGS) -o $@ $^ $(LIBS)

$(BUILD)/main.o: $(SRC)/main.c $(SRC)/cpu.h $(SRC)/memory.h $(SRC)/vdp.h $(SRC)/psg.h $(SRC)/sdl.h #$(SRC)/ftdi.h
	@echo Compiling $<
	@$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/cpu.o: $(SRC)/cpu.c $(SRC)/cpu.h $(SRC)/io.h $(SRC)/memory.h $(SRC)/log.h
	@echo Compiling $<
	@$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/io.o: $(SRC)/io.c $(SRC)/vdp.h $(SRC)/psg.h $(SRC)/ga.h $(SRC)/log.h #$(SRC)/ftdi.h
	@echo Compiling $<
	@$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/memory.o: $(SRC)/memory.c $(SRC)/cpu.h $(SRC)/memory.h $(SRC)/psg.h $(SRC)/vdp.h $(SRC)/log.h
	@echo Compiling $<
	@$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/vdp.o: $(SRC)/vdp.c $(SRC)/vdp.h $(SRC)/cpu.h $(SRC)/log.h #$(SRC)/ftdi.h
	@echo Compiling $<
	@$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/psg.o: $(SRC)/psg.c $(SRC)/psg.h $(SRC)/cpu.h $(SRC)/log.h
	@echo Compiling $<
	@$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/ga.o: $(SRC)/ga.c $(SRC)/log.h
	@echo Compiling $<
	@$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/sdl.o: $(SRC)/sdl.c $(SRC)/cpu.h $(SRC)/psg.h $(SRC)/vdp.h $(SRC)/memory.h $(SRC)/ga.h $(SRC)/log.h
	@echo Compiling $<
	@$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/log.o: $(SRC)/log.c $(SRC)/cpu.h $(SRC)/vdp.h $(SRC)/memory.h
	@echo Compiling $<
	@$(CC) $(CFLAGS) -c $< -o $@

#$(BUILD)/ftdi.o: $(SRC)/ftdi.c
#	@echo Compiling $<
#	@$(CC) $(CFLAGS) -c $< -o $@

.PHONY: clean
clean:
	@rm -rf $(TARGET) $(BUILD)

