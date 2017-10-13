    /*
     * lexer.l
     *
     * lexical analyzer for wikicode
     */

%{

#include "boolean.h"
#include "debug.h"
#include "error.h"
#include "globals.h"
#include "transforms.h"
#include "yyexternals.h"

%}


ALPHANUM    ([a-z]|[A-Z]|[1-9])
LINK_TEXT   [^\]]+
SPACE       (\t|\n|" ")
NOT_SPECIAL [^\n\[=\*#\-]

HYPERLINK   "[http://"{LINK_TEXT}"]"
BARELINK    "http://"[^[:blank:]\n]+
IMAGE       "[["[iI]"mage:"{LINK_TEXT}"]]"
WIKILINK    "[["{LINK_TEXT}"]]"{ALPHANUM}*
BOLD        '''
ITALIC      ''
H1_START    ^=
H2_START    ^==
H3_START    ^===
H4_START    ^====
H1          =
H2          ==
H3          ===
H4          ====
BULLET      ^\*
NUMBER      ^#
INDENT      ^\:
HR          ^"----"-*
LIST        ^[\*#:]+
PRE         ^" "

%option noyywrap

%%

{LIST}          { make_list(yytext); }
{BOLD}          { bold();            }
{ITALIC}        { italic();          }
{PRE}           { preformat(yytext); }
{H4_START}      { heading(4, TRUE);  }
{H3_START}      { heading(3, TRUE);  }
{H2_START}      { heading(2, TRUE);  }
{H1_START}      { heading(1, TRUE);  }
{H4}            { heading(4, FALSE); }
{H3}            { heading(3, FALSE); }
{H2}            { heading(2, FALSE); }
{H1}            { heading(1, FALSE); }
{HR}            { hr();              }
{BARELINK}      { barelink(yytext);  }
{IMAGE}         { image(yytext);     }
{WIKILINK}      { wikilink(yytext);  }
{HYPERLINK}     { hyperlink(yytext); }
^{NOT_SPECIAL}  { paragraph(yytext); }
\n\n            { blank_line();      }
{SPACE}         { plaintext(yytext); }
.               { plaintext(yytext); }
