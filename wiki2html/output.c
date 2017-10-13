/*
 * output.c
 *
 * print to output file.
 */



/*
 * Included headers:
 *
 * output: interface to the rest of the world
 * globals: Program_Name
 * stdio: fprintf(), fputc(), stderr
 * stdarg: va_list, va_start(), va_end(), vfprintf()
 */
#include "output.h"
#include "globals.h"
#include <stdio.h>
#include <stdarg.h>




/*
 * output()
 *
 * print the given stuff to the output file
 */
void output(char *fmt, ...)
{
    va_list args;
    va_start(args, fmt);

    vfprintf(Global.output_file, fmt, args);
    
    va_end(args);
}
