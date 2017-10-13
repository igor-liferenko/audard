/*
	asc2vcd.c - read ascii real values, one value per line, 
	and output a vcd (value change dump) format 
	
	build with: gcc -o asc2vcd -Wall -g asc2vcd.c
	
	author: sdaau
	license: GPL
	
	call with: 
	./asc2vcd ascii-vals.dat 0.2 1>float-vals.dat
	
*/

#include <stdio.h>   /* Standard input/output definitions */
#include <string.h>  /* String function definitions */
#include <stddef.h>
#include <unistd.h>  /* UNIX standard function definitions */
#include <fcntl.h>   /* File control definitions */
#include <errno.h>   /* Error number definitions */

#include <stdlib.h>
#include <sys/stat.h>

void usage(char **argv)
{
	fprintf(stdout, "Usage:\n"); 
	fprintf(stdout, "%s filename timescale label mark modulename\n", argv[0]); 
	fprintf(stdout, "%s test.dat 1ns ch1 ! ascii_signal\n", argv[0]); 
}

int main( int argc, char **argv ) 
{

	if( argc != 6 ) { 
		usage(argv);
		return 1; 
	}

	char *filename;
	int file_fd;
	struct stat st;
	char* fileContents;
	char *timescale; 
	char *label; 
	char *mark; 
	char *modulename; 
	int step;
	
	// Get the value list filename
	filename = argv[1];
	timescale = argv[2];
	label = argv[3];
	mark = argv[4];
	modulename = argv[5];
	fprintf(stderr, "Opening filename %s; timescale %s; label %s; mark %s; modulename %s\n", filename, timescale, label, mark, modulename);
		
	//Get file or command;
	file_fd = open( filename, O_RDONLY );
	if (file_fd < 0) {
		fprintf(stderr, "Failed to open %s;\n", filename);
		return 1; 
	}
		
	// get file size
	stat(filename, &st);
	// allocate memory for storing the file
	fileContents = (char *)calloc(st.st_size, sizeof(char));
	// read the file into memory 
	read(file_fd, fileContents, st.st_size);
	fprintf(stderr, "opened as file (%ld).\n", st.st_size);
	
	// output preamble
	fprintf(stdout, "$date\nTODO\n$end\n$version\n	%s\n$end\n$timescale\n	%s\n$end\n$scope module %s $end\n$var real 1 %s %s $end\n$upscope $end\n$enddefinitions $end\n$dumpvars\n", argv[0], timescale, modulename, mark, label); 
	
	// split string at linefeeds
	char * tok = strtok(fileContents, "\n");
	step = 0; 
	while (tok != NULL) {
		// parse value as double - works with float too 
		// theValue = strtod(tok, &end);
		// we don't need to parse, we'll just dump the original string.. 
		fprintf(stdout, "#%d\nr%s %s\n", step, tok, mark);
		
		// move to next line 
		tok = strtok(NULL,"\n");
		step++;
	}
	
	free(fileContents);
	
	fprintf(stderr, "\n+++DONE+++\n");
	
	return 0;
}
