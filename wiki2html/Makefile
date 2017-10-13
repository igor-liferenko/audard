# makefile for wiki2html

## Variables

OBJECT_FILES = \
               debug.o \
               error.o \
               lexer.o \
               main.o \
               output.o \
               stringutils.o\
               transforms.o \

GENERATED_FILES = *.o lexer.c 

COMPILE = gcc -c -ansi

EXECUTABLE_NAME = wiki2html



## Rules to build the program

all: $(OBJECT_FILES)
	gcc -o $(EXECUTABLE_NAME) $(OBJECT_FILES)

debug.o: debug.c
	$(COMPILE) debug.c

error.o: error.c
	$(COMPILE) error.c

lexer.c: lexer.l
	flex -olexer.c lexer.l 

lexer.o: lexer.c
	$(COMPILE) lexer.c

main.o: main.c
	$(COMPILE) main.c

output.o: output.c
	$(COMPILE) output.c

stringutils.o: stringutils.c
	$(COMPILE) stringutils.c

transforms.o: transforms.c
	$(COMPILE) transforms.c



## Rules for cleanup and rebuilding

clean:
	rm -f $(GENERATED_FILES)

spotless: clean
	rm -f $(EXECUTABLE_NAME)

# Recompile from scratch
new: spotless all
	
	
