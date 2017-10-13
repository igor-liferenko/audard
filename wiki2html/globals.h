/*
 * globals.h
 *
 * program-wide variables for wiki2html
 */

#ifndef GLOBALS_H
#define GLOBALS_H

#include <stdio.h>

struct Global_options
{
    char *base_url;
    char *image_url;
    char *document_title;
    char *program_name;
    char *stylesheet;

    FILE *input_file;
    FILE *output_file;

} Global;


#endif
