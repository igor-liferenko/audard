#!/usr/bin/env bash

# quoted EOF in here documents - prevent shell expansion
# instead of noweb (literate programming)
# have first line start on 10 - to easier read compiler warnings



cat > test-hex.c <<"EOF"
#include "stdio.h"
#include "inttypes.h"
#include "stdlib.h" //atoi

#include <signal.h>
#define BREAK_HERE raise(SIGINT)

// http://www.linuxquestions.org/questions/programming-9/how-to-programmatically-break-into-gdb-from-gcc-c-source-230854/
int value=1023;


//~ void doHex(void) {
//~ }

int main(int argc, char *argv[]) {
  register int r, k;
  int flag = 0;
  int next = 0; //must be inited to zero, because of bitshifts!
  char qbuf[8];

  if (argc > 1) value = atoi(argv[1]);

  // hex conversion - split in nibbles; max 4 nibbles (16 bit) unsigned
  for (k=0;k<4;k++) {
    next = (uint8_t) (value>>(4*(3-k)) & 0b00001111); // nb: bitshift 0 makes no difference
                                                      // !: MUST have parens around expr!
                                                      //   (else fail on nibble calc!)
    r = (uint8_t) (next - 10);
    if (r>127) { //negative difference; next < 10
      flag = '0';
      r = next;
    } else {
      flag = 'A';
    }
    qbuf[k] = flag+r;
  }
  qbuf[4] = 0;
  fputs (qbuf, stdout);
  fputs ("\n", stdout);

  // from http://www.raspberryginger.com/jbailey/minix/html/itoa_8c-source.html
  // decimal conversion
  next = 0;
  if (value < 0) {
    qbuf[next++] = '-';
    value = -value;
  }
  if (value == 0) {
    qbuf[next++] = '0';
  } else {
    k = 10000;
    while (k > 0) {
      r = value / k;
      if (flag || r > 0) {
        qbuf[next++] = '0' + r;
        flag = 1;
      }
      value -= r * k;
      k = k / 10;
    }
  }
  qbuf[next] = 0;
  fputs (qbuf, stdout);
  fputs ("\n", stdout);

  return 0;
}
EOF

cat > test-hex.gdb <<"EOF"
define sap
  step
  printf "value: %d r: %d k: %d flag: %d next: %d qbuf: ", value, r, k, flag, next
  set $ix = 0
  while ($ix < 8)
    printf "%c,", qbuf[$ix]
    set $ix=$ix+1
  end
  printf "\n"
end

break main
run
sap
EOF

# have 'sap' in gdb command history
echo "sap" > .gdb_history

# compile / build -- and stop on warnings
# http://stackoverflow.com/questions/962255/redirecting-stderr
exec 3>&1  #set up extra file descriptors ; 4>&2
# the local stderr(2) of gcc gets redirected to local stdout(1) of gcc shell, then getting captured by variable
# the local stdout(1) of gcc gets redirected to (master fd)3, [which is otherwise redirected to the "main" stdout(1)] - so it would end up on stdout
warnings=$( { gcc -g -Wall test-hex.c -o test-hex.exe 2>&1 1>&3; } )
exec 3>&- # release the extra file descriptors 4>&-

# is not empty?
if [ -n "${warnings}" ] ; then
  echo "The message is \"${warnings}.\""
  exit 1
fi

echo "No warnings".
chmod +x test-hex.exe

# run debugger
gdb -x test-hex.gdb -se test-hex.exe




