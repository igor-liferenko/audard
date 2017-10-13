/*
 * transforms.h
 *
 * functions to turn wikitext into HTML
 */

#ifndef DEBUG_H
#define DEBUG_H


#include "boolean.h"

void barelink(char *link);
void blank_line(void);
void bold(void);
void heading(int new_level, boolean start);
void hr(void);
void hyperlink(char *link);
void image(char *link);
void init_lexer(void);
void italic(void);
void make_list(char *list);
void paragraph(char *text);
void plaintext(char *text);
void preformat(void);
void wikilink(char *link);


#endif
