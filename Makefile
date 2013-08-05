TARGET=alis
OBJECTS=main.o
COREDIR=core
LIBCORE=$(COREDIR)/libcore.a

CC=gcc
CFLAGS=-m32 -O2
LDFLAGS=-m32
LIBS=-lSDL-1.2

$(TARGET): $(LIBCORE) $(OBJECTS)
	@echo Linking executable $@
	@$(CC) $(LDFLAGS) -o $@ $(OBJECTS) $(LIBCORE) $(LIBS)

.c.o:
	@echo Compiling $<
	@$(CC) $(CFLAGS) -c $< -o $@

$(LIBCORE): $(COREDIR)
	@$(MAKE) -C $(COREDIR)

clean:
	@rm -f $(TARGET) $(OBJECTS)
	@$(MAKE) -C $(COREDIR) clean

