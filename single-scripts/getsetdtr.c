/*
	getsetdtr.c
	
	build with: gcc -o getsetdtr -Wall -g getsetdtr.c
*/

#include <stdio.h>
#include <string.h>
#include <stddef.h>

#include <stdlib.h>

#include <fcntl.h>   /* File control definitions */
#include <sys/ioctl.h>


int serport_fd;


void usage(char **argv)
{
	fprintf(stdout, "Usage:\n"); 
	fprintf(stdout, "%s port [setting]\n", argv[0]); 
	fprintf(stdout, "Examples:\n"); 
	fprintf(stdout, "%s /dev/ttyUSB0 \n", argv[0]); 
	fprintf(stdout, "%s /dev/ttyUSB0 1\n", argv[0]); 
}


int main( int argc, char **argv ) 
{

	if (( argc < 2 ) || (argc > 3)) { 
		usage(argv);
		return 1; 
	}

	char *serport;
	int shouldSet = 0; 
	int set_value; 
	int status;
	
	// Get the PORT name
	serport = argv[1];
	fprintf(stdout, "Opening port %s;\n", serport);
	
	// See if we're setting
	if (argc == 3) {
		shouldSet = 1; 
		set_value = atoi(argv[2]);

	}
	
	
	// Open, but don't Initialise port
	serport_fd = open( serport, O_RDWR | O_NOCTTY | O_NONBLOCK );
	if ( serport_fd < 0 ) { perror(serport); return 1; }
	
	//http://www.linuxquestions.org/questions/programming-9/serial-port-how-do-i-raise-dtr-356930/
	
	// get DTR
    if (ioctl(serport_fd, TIOCMGET, &status) == -1) {
        perror("setDTR()");
        return 0;
    }
	
	fprintf(stdout, "Current DTR: %d.\n", status);
	
	// set DTR - if requested 
	if (shouldSet == 1) {
		fprintf(stdout, "Setting value %d;\n", set_value);
		if (set_value) {
			status |= TIOCM_DTR;
		} else {
			status &= ~TIOCM_DTR;
		}
		
		if (ioctl(serport_fd, TIOCMSET, &status) == -1) {
			perror("setDTR");
			return 0;
		}
		
		// re-read once more:
		if (ioctl(serport_fd, TIOCMGET, &status) == -1) {
			perror("setDTR()");
			return 0;
		}		
		fprintf(stdout, "Current DTR: %d.\n", status);
	}
	else {
		fprintf(stdout, "Not setting value.\n");
	}
	
	return 0;
}
