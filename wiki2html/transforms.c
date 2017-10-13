/*
 * transforms.c
 *
 * functions called by the lexer
 * to transform wikicode into HTML
 */

#include <string.h>
#include <stdlib.h>

#include "transforms.h"
#include "boolean.h"
#include "debug.h"
#include "globals.h"
#include "output.h"
#include "stringutils.h"


typedef enum { blank, para, list, pre, done } status_t;
typedef enum { start, end, next } list_t;


char *disambiguate(char *link_text);
void prepare_status(status_t new);
void close_tags(char *tags);
void list_tag(char c, list_t type);


/* A signal sent to make_list() */
#define CLOSE_TAGS "close tags"

/* Define a lexer object, available or functions in this file */
typedef struct {
    status_t status;
} lexer_t;
static lexer_t Lexer;




/*
 * wikilink()
 *
 * turns a wikilink into an HTML link.
 * Assumes string starts with [[ and ends with ]]
 *
 * Split the strings at the |
 * link_text gets the stuff to the left
 * alt_text gets the stuff to the right
 */
void wikilink(char *wiki_text)
{
    char *full_text;
    char *link_text;
    char *alt_text;
    char *ending;
    char *end_link;

    full_text = duplicate_cstring(wiki_text);

    ending = strstr(wiki_text, "]]");
    ending = &ending[2];

    end_link = strstr(full_text, "]]");
    end_link[2] = '\0';

    full_text = strip_surrounding_chars(full_text, 2);
    link_text = full_text;

    alt_text = strchr(link_text, '|');
    if (alt_text == NULL) {
        alt_text = link_text;
    }
    else {
        *alt_text = '\0';
        alt_text = &alt_text[1];
        if (*alt_text == '\0') {
            alt_text = disambiguate(link_text);
        }
    }

    /*check if it is maybe a local anchor link,
       in which case we don't want global base url*/
    if (link_text[0] == '#')
    {
    output( "<a class=\"internal\" href=\"%s\">%s%s</a>",
            link_text, alt_text, ending);
    } else {
    output( "<a class=\"internal\" href=\"%s/%s\">%s%s</a>",
            Global.base_url, link_text, alt_text, ending);
    }

    free (full_text);
}




/*
 * disambiguate()
 *
 * disambiguates a wikilink: placeholder for now
 */
char *disambiguate(char *link_text)
{
    DEBUG("disambiguate: yep");
    return link_text;
}




/*
 * bold()
 *
 * convert '''text''' into <b>text</b>
 */
void bold(void)
{
    static boolean bold_on = FALSE;

    if (bold_on) {
       output( "</b>");
       bold_on = FALSE;
    }
    else {
       output( "<b>");
       bold_on = TRUE;
    }
}




/*
 * italic()
 *
 * convert ''text'' into <i>text</i>
 */
void italic(void)
{
    static boolean italic_on = FALSE;

    if (italic_on) {
       output( "</i>");
       italic_on = FALSE;
    }
    else {
       output( "<i>");
       italic_on = TRUE;
    }
}




/*
 * heading()
 *
 * number of heading must be specified.
 *
 * If the heading is at the beginning of the line:
 *     close the old one (if it's open)
 *     and start the new one.
 *
 * If the heading is not at the beginning:
 *     close the matching one if it's open
 *     print the leftover = signs
 *
 */
void heading(int new_level, boolean start)
{
    static int level = 0;
    int i;

    if (start) {
        if (level != 0) {
            output( "</h%d>\n", level);
        }
        output( "<h%d>", new_level);
        level = new_level;
    }
    else {
        if (level == new_level) {
            output( "</h%d>\n", level);
            level = 0;
        }
        else if (level < new_level) {
            for (i=0; i<new_level; ++i) {
                fputc('=', Global.output_file);
            }
        }
        else {
            output( "</h%d>\n", level);
            for (i=0; i<level-new_level; ++i) {
                fputc('=', Global.output_file);
            }
            level = 0;
        }
    }
}




/*
 * paragraph()
 *
 * start a new paragraph if necessary, then print what we saw
 */
void paragraph(char *stuff)
{
    prepare_status(para);

    if (Lexer.status == para) {
        plaintext(stuff);
    }
    else {
        output( "<p>");
        Lexer.status = para;
        plaintext(stuff);
    }
}




/*
 * preformat()
 *
 * start a preformatted section
 * called when a line starts with a space
 */
void preformat(void)
{
    prepare_status(pre);

    if (Lexer.status != pre) {
        output("<pre>");
        Lexer.status = pre;
    }
}




/*
 * plaintext()
 *
 * dump the given string to the output file.
 */
void plaintext(char *text)
{
    output( "%s", text);
}




/*
 * hyperlink()
 *
 * turn [http://foo fubar] --> <a href="http://foo">fubar</a>
 */
void hyperlink(char *link)
{
    char *link_text;
    char *alt_text;

    link_text = strip_surrounding_chars(link, 1);
    alt_text = strchr(link_text, ' ');
    if (alt_text) {
        *alt_text = '\0';
        alt_text = &alt_text[1];
        if (alt_text == '\0') {
            alt_text = "\"*\"";
        }
    }
    else {
        alt_text = link_text;
    }

    /* making the links open in target _blank*/
    output( "<a class=\"extlink\" href=\"%s\" target=\"_blank\">%s</a>", link_text, alt_text);

    free(link_text);
}




/*
 * image()
 *
 * turn [[image:foo.jpg|few]] --> <img src="foo.jpg" alt="few">
 */
void image(char *link)
{
    char *link_text;
    char *alt_text;
    char *caption;

    link_text = strip_surrounding_chars(link, 2);

    alt_text = strchr(link_text, '|');
    if (alt_text) {
        *alt_text = '\0';
        alt_text = &alt_text[1];
        if (alt_text == '\0') {
            alt_text = "\"*";
        }

	/*try thumb - caption will be left of |,
	/ the string before itshould remain in alt_text, and could be "thumb"*/
	caption = strchr(alt_text, '|');
        if (caption) {
	    *caption = '\0';
	    caption = &caption[1];
	    if (caption == '\0') {
	        caption = "\"*";
	    }
        }
    }
    else {
        alt_text = "image";
    }

    /*ok we should be checking for equality with "thumb",
       but for now just checking if first letter is 't' */
    if (caption && (alt_text[0] == 't')) {
    output( "<a href=\"%s/%s\" target=\"_blank\"><img src=\"%s/%s\" alt=\"[ %s ]\" width=\"30%\"></a>",
            Global.image_url, &link_text[6], Global.image_url, &link_text[6], caption);
    }
    else
    {
    output( "<img src=\"%s/%s\" alt=\"[ %s ]\">",
            Global.image_url, &link_text[6], alt_text);
    }
    free(link_text);
}




/*
 * hr()
 *
 * turn ----(...) --> <hr>
 */
void hr (void)
{
    prepare_status(blank);
    output( "\n<hr>\n");
}




/*
 * init_lexer()
 *
 * Set up all the variables to their initial values.
 * Currently it's only the status variable.
 */
void init_lexer(void)
{
    Lexer.status = blank;
}




/*
 * prepare_status()
 *
 * print some closing tags, depending on the current and new status
 */
void prepare_status(status_t new)
{
    status_t current = Lexer.status;

    if (current != new) {
        switch (current)
        {
            case para:
                output( "</p>\n");
                break;

            case pre:
                output( "</pre>\n");
                break;

            case list:
                make_list(CLOSE_TAGS);
                break;

            case blank:
                break;

            default:
                error("prepare_status: unknown status: %d\n", Lexer.status);
                break;
        }
    }
}




/*
 * blank_line()
 *
 * saw a blank line, set the status
 */
void blank_line(void)
{
    prepare_status(blank);
    Lexer.status = blank;
}




/*
 * make_list()
 *
 * deal with list items
 *
 * called when the lexer sees a * # or :
 * at the beginning of a line
 *
 * can handle nested/mixed lists
 */
void make_list(char *new)
{
    static char *current_list = NULL;
    static int current_len = 0;

    char *new_list;
    int new_len;

    int differ;
    int i;

    /* prepare_status sends this: close all open tags and bail */
    if (strings_equal(new, CLOSE_TAGS)) {
        close_tags(current_list);
        current_list = NULL;
        current_len = 0;
        Lexer.status = blank;
        return;
    }
    else {
        Lexer.status = list;
    }

    new_list = duplicate_cstring(new);
    new_len = strlen(new_list);

    prepare_status(list);
    Lexer.status = list;

    /* Find out where they differ */
    differ=0;
    while (differ < new_len
           && differ < current_len
           && current_list[differ] == new_list[differ])
    {
        ++differ;
    }

    /* If they are the same, make another list item */
    if (new_len == current_len  &&  differ == current_len) {
        list_tag(current_list[current_len-1], next);
    }
    else
    {
        /* Close up the different tags */
        if (differ < current_len  &&  current_list) {
            close_tags(&current_list[differ]);
        }

        if (new_len < current_len) {
            list_tag(new_list[new_len-1], next);
        }

        /* Start new lists */
        while (differ < new_len) {
            list_tag(new_list[differ], start);
            ++differ;
        }
    }

    free(current_list);
    current_list = new_list;
    current_len = new_len;
}




/*
 * list_tag()
 *
 * take care of printing starting, ending, and list item tags
 * given a char one of * # or : print the corresponding tag
 * type is one of start, end, or next
 */
void list_tag(char c, list_t type)
{
    char *list_type;
    char *list_item;

    list_item = (c == ':') ? "dd" : "li";

    switch(c) {
        case ':': list_type = "dl"; break;
        case '*': list_type = "ul"; break;
        case '#': list_type = "ol"; break;
        default:
            fatal_error("list_tag: bad list char: %c", c);
            break;
    }

    switch (type) {
        case start:
            output("<%s>", list_type);
            output("<%s>", list_item);
            break;

        case end:
            output("</%s>", list_item);
            output("</%s>", list_type);
            break;

        case next:
            output("</%s>", list_item);
            output("<%s>", list_item);
            break;

        default:
            fatal_error("list_tag: bad list type: %d", type);
            break;
    }
}




/*
 * close_tags()
 *
 * Given a string of tag chars (* # or :)
 * Close up the different tags in reverse order
 */
void close_tags(char *tags)
{
    int tag;
    int len = strlen(tags);

    for (tag = len-1; tag >= 0; --tag) {
        list_tag(tags[tag], end);
    }
}




/*
 * barelink()
 *
 * turn a bare url into a hyperlink
 */
void barelink(char *link)
{
    output("<a class=\"external\" href=\"%s\">%s</a>", link, link);
}
