/*
 * avr-cycles.c - process stdin to stdout (pipe from avr-objdump -d)
 *                    and add byte counts and cycles to the output
 *
 * $Id: avr-cycles.c,v 1.6 2005/08/07 18:02:20 tomdean Exp $
 *
 *
 * Syntax:
 *   avr-cycles.c
 *
 * Example:
 *   avr-objdump -d ../ldivide/ldivide.o | ./avr-cycles
 *
 * gcc -g -Wall -I. -o avr-cycles avr-cycles.c
 *
 *
 * original: http://www.speakeasy.org/~tomdean/c-source/avr-cycles.c
 * getline edit: sdaau Dec 01, 2010
 * Note: http://wakaba.c3.cx/soc/kareha.pl/1100499906/359-390:
 * "It needs to use getline instead of fgetln with glibc"
 * else, on Ubuntu Lucid: "undefined reference to `fgetln'"
 */

#include <stdio.h>       /* printf, fgetln/getline */
#include <stdlib.h>      /* exit */
#include <unistd.h>      /* getopt */
#include <string.h>      /* strcmp */

struct avr_opcodes_s
{
  char *name;
  char *constraints;
  int insn_size;                /* In words.  */
  int cycles_low;
  int cycles_high;
  int isa;
  unsigned int bin_opcode;
};

#define AVR_INSN(NAME, CONSTR, OPCODE, SIZE, CYC_LO, CYC_HI, ISA, BIN) \
{#NAME, CONSTR, SIZE, CYC_LO, CYC_HI, ISA, BIN},

struct avr_opcodes_s avr_opcodes[] =
{
  #include "avr.h"
  {NULL, NULL, 0, 0, 0, 0, 0}
};

void syntax(char *argv) {
  printf("\nUsage: %s\n", argv);
  exit(-1);
}


int main(int argc, char **argv) {
  char *file_buf;       /* pointer to the return from fgetln(3) */
  int len;              /* length of buffer from fgetln(3) */
  int lineno;           /* input lineno */
  int idx;              /* loop variable */
  char opcode_name[80]; /* for the opcode name */
  size_t thesize;	/* getline needs this*/

  printf(
	"[bytes cycle_lo cycle_hi] address opcode operands instruction <loc>\n");
  printf(
	"or avr_opcodes[idx].[insn_size cycle_low cycle_high] address opcode operands instruction <loc>\n");

  /* process stdin to stdout until eof */
  lineno = 0;
  thesize = 0;
  // while ((file_buf = fgetln(stdin, &len)) != NULL) {
  while ((len = getline (&file_buf, &thesize, stdin)) > 0) {
	lineno++;
	/* ignore blank lines - maybe we should print them */
	if (len > 1) {
	  /*
	   * ---------------------------------------
	   * if objdump changes, this needs changing
	   * ---------------------------------------
	   */
	  if (lineno == 3) {
		file_buf[len-1] = '\0';
		if (strcmp(file_buf,"Disassembly of section") != 0) {
		  printf("Error in header, line 4 should be Disassembly of section\n");
		  exit(-1);
		}
	  } else if (lineno < 6) {
		/* ignore these */
	  } else {
		/* maybe we have a line to process */
		file_buf[len-1] = '\0';
		if (*file_buf != ' ') {
		  /* this is a label */
		  printf("%s\n",file_buf);
		} else {
		  /* this is a real line process it */
#ifdef DEBUG
		  printf("line %03d: <%d> %s\n", lineno, len, file_buf);
#endif
		  /*
		   * find the opcode name
		   * the output of objdump has tabs and spaces in it
		   * sscanf is an easy way to skip these
		   * make sure check longest possible case first,
		   * because if the longer case is true, the shorter one
		   * will be true also.
		   */
		  {
			int o1, sslen;
			if ((sslen =
				 sscanf(file_buf,"%x: %x %x %x %x %s",
						&o1, &o1, &o1, &o1, &o1, &opcode_name[0])) == 6);
			else if ((sslen =
					  sscanf(file_buf,"%x: %x %x %s",
							 &o1, &o1, &o1, &opcode_name[0])) == 4);
			else printf("unknown line %03d: <%d> %s\n",lineno, len, file_buf);
#ifdef DEBUG
			printf("Scanned %d items <%s>\n", sslen, op_str);
#endif
			
		  } /* end of group to find the opcode name */

#ifdef DEBUG
		  printf("line %03d: <%d> [%s] %s\n",
				 lineno, len, opcode_name, file_buf);
#endif

		  /*
		   * look thru the opcode structure for the opcode name
		   */
		  for (idx = 0;
			   (avr_opcodes[idx].name != NULL)
				&&(strcmp(opcode_name, avr_opcodes[idx].name) != 0);
			   idx++);
		  /* if we found one, this will not be null */
		  if (avr_opcodes[idx].name == NULL) {
			/* invalid opcode */
			printf("*** opcode not found at line %03d: %s\n",
				   lineno, opcode_name);
			printf("        %s\n", file_buf);
		  } else {
			/*
			 * found one, display it.
			 *
			 * use FMT1 is cycles_high < 9
			 */
#define FMT1 "[%d %d %d ] %s\n"
#define FMT2 "[%d %d %d] %s\n"

#ifndef DEBUG
			/* normal output */
			printf(avr_opcodes[idx].cycles_high>9 ?FMT2:FMT1,
				   avr_opcodes[idx].insn_size,
				   avr_opcodes[idx].cycles_low,
				   avr_opcodes[idx].cycles_high,
				   file_buf);
#else
			/* debug output is > 80 char */
			printf("[%d %d %d %x %x] %s\n",
				   avr_opcodes[idx].insn_size,
				   avr_opcodes[idx].cycles_low,
				   avr_opcodes[idx].cycles_high,
				   avr_opcodes[idx].isa,
				   avr_opcodes[idx].bin_opcode,
				   file_buf);
#endif
		  }  /* found one */
		}    /* fuile_buf[0] == ' ' */
	  }      /* lineno > 6 */
	}        /* if len > 1 */
  }          /* read input and process it */

  return 0;
}
