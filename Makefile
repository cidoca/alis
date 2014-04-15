TARGET=alis
OBJECTS=main.o
COREDIR=core
LIBCORE=$(COREDIR)/libcore.a

CC=gcc
CFLAGS=-m32 -O2 -Wall `sdl2-config --cflags`
LDFLAGS=-m32
LIBS=-lSDL2

$(TARGET): $(LIBCORE) $(OBJECTS)
	@echo Linking executable $@
	@$(CC) $(LDFLAGS) -o $@ $(OBJECTS) $(LIBCORE) $(LIBS)

main.o: main.c core.h
	@echo Compiling $<
	@$(CC) $(CFLAGS) -c $< -o $@

$(LIBCORE): $(COREDIR)
	@$(MAKE) -C $(COREDIR)

clean:
	@rm -f $(TARGET) $(OBJECTS)
	@$(MAKE) -C $(COREDIR) clean


