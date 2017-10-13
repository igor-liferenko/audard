/*
	asc2raw.c - read ascii real values, one value per line, 
	and output a raw binary stream of 32-bit floats 
	
	build with: gcc -o asc2raw -Wall -g asc2raw.c
	
	author: sdaau
	license: GPL
	
	call with: 
	LC_ALL=C ./asc2raw ascii-vals.dat 0.2 1>float-vals.dat
	
	WARNING - interpretation of decimal points may depend on locale; 
	use LC_ALL=C to force '.' as decimal point
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
	fprintf(stdout, "%s filename scalefactor\n", argv[0]); 
	fprintf(stdout, "%s test.dat 0.2\n", argv[0]); 
}

int main( int argc, char **argv ) 
{

	if( argc != 3 ) { 
		usage(argv);
		return 1; 
	}

	char *filename;
	int file_fd;
	struct stat st;
	char* fileContents;
	char* end; 
	//~ double theValue; 
	float theValue; 
	float scaleFactor; 
	
	// Get the value list filename
	filename = argv[1];
	fprintf(stderr, "Opening filename %s;\n", filename);
		
	//Get file or command;
	file_fd = open( filename, O_RDONLY );
	if (file_fd < 0) {
		fprintf(stderr, "Failed to open %s;\n", filename);
		return 1; 
	}
	
	scaleFactor = strtod(argv[2], &end);
	fprintf(stderr, "Scale factor: %f;\n", scaleFactor);
	
	// get file size
	stat(filename, &st);
	// allocate memory for storing the file
	fileContents = (char *)calloc(st.st_size, sizeof(char));
	// read the file into memory 
	read(file_fd, fileContents, st.st_size);
	fprintf(stderr, "opened as file (%ld).\n", st.st_size);
	
	// split string at linefeeds
	char * tok = strtok(fileContents, "\n");
	while (tok != NULL) {
		// parse value as double - works with float too 
		theValue = strtod(tok, &end);
		theValue *= scaleFactor; 
		//~ fprintf(stdout, "theValue = %lf\n", theValue);
		// write value as binary series of bytes to stdout
		//~ fwrite(&theValue, sizeof(double), 1, stdout);
		fwrite(&theValue, sizeof(float), 1, stdout);
		// move to next line 
		tok = strtok(NULL,"\n");
	}
	
	free(fileContents);
	
	fprintf(stderr, "\n+++DONE+++\n");
	
	return 0;
}
