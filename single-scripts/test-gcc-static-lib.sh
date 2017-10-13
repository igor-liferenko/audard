
# sdaau, 2013

cat > utilA.h <<"EOF"
#include <stdio.h>

char* getStrHexA(int arg);
EOF

cat > utilA.c <<"EOF"
#include <utilA.h>

char mystringA[16];

char* getStrHexA(int arg){
  //char mystringA[16]; // not local
  snprintf(mystringA, 15, "0x%08x", arg);
  return &mystringA[0];
}

EOF

cat > utilB.h <<"EOF"
#include <stdio.h>
#include <utilA.h>

char* getStrB(int arg);
EOF

cat > utilB.c <<"EOF"
#include <utilB.h>

char mystringB[32];

char* getStrB(int arg){
  //char mystringB[32]; // not local
  char* retA;
  retA = getStrHexA(arg);
  snprintf(mystringB, 31, "A: B says %s", retA);
  return &mystringB[0];
}

EOF

cat > tester.c <<"EOF"
#include <utilB.h>
#include <stdlib.h> // atoi

int main(int argc, char *argv[]){
  //char mystringB[32]; // not local
  int val = 42;
  char* retB;
  if (argc == 2) val = atoi(argv[1]);
  retB = getStrB(val);
  printf("Got: %s\n\n", retB);
  return 0;
}

EOF

FILTER="2>&1 | grep getStr"


# http://stackoverflow.com/questions/2734719/howto-compile-a-static-library-in-linux
# gcc "-c"  Compile or assemble the source files, but do not link.  The linking stage simply is not done.  The ultimate output is in the form  of an object file for each source file.
# ar rcs: r means to insert with replacement, c means to create a new archive, and s means to write an index.


set -x

######################################
echo "Creating manual static library A"

gcc -c -I. -o utilA.o utilA.c
ar rcs libutilA1.a utilA.o

# list contents
ar -tv libutilA1.a

# nm -a utilA.o - same output as:
eval nm -a libutilA1.a $FILTER

## objdump ... utilA.o: the same as below; xcept also shows In archive libutilA1.a: ....
eval objdump --archive-headers --private-headers --dynamic-syms --syms --reloc libutilA1.a $FILTER
#~ readelf --syms --dyn-syms --relocs --dynamic libutilA1.a


######################################
echo -e "\nCreating manual static library B 1"

# here we forget to link utilA (in ar); so getStrHexA is undefined symbol in libutilB1.a

gcc -c -I. -o utilB.o utilB.c
ar rcs libutilB1.a utilB.o
# list contents
ar -tv libutilB1.a

eval nm -a libutilB1.a $FILTER
eval objdump --archive-headers --private-headers --dynamic-syms --syms --reloc libutilB1.a $FILTER
#~ readelf --syms --dyn-syms --relocs --dynamic libutilB1.a

# for the executable building: we can use the
# --trace option of `ld`, which will show library files as they are used;
#  for shared libraries, easy test is, say: ld --trace -lc
#  but it doesn't work if the .so is not present in /usr/lib dir.
#  (even if the .a may be present)
# using -Wl we tell gcc we want that option for linker (ld) step only
# without -static, ‘atoi’ cannot be found during link (exe's work though), it #include <stdlib.h> is missing

# undefined reference to `getStrHexA':
gcc -Wall -Wl,--trace -I. -o testerb1.exe tester.c libutilB1.a


######################################
echo -e "\nCreating manual static library B 2"

# here we do link utilA (in ar) last; but still getStrHexA is undefined
# NOTE: if using `--dynamic-reloc` on objdump here, it will fail with "objdump: utilA/B.o: Invalid operation"; and it will NOT list the second object, as expected (man objdump: "objdump -a shows the object file format of each archive member")
# if that is proper; readelf gives nearly the same info (differently formatted) - else readelf (seemingly) always reads all objects
# also objdump --section-headers are too verbose - remove

ar rcs libutilB2.a utilB.o utilA.o
# list contents
ar -tv libutilB2.a

eval nm -a libutilB2.a $FILTER
eval objdump --archive-headers --private-headers --dynamic-syms --syms --reloc libutilB2.a $FILTER
#~ readelf --syms --dyn-syms --relocs --dynamic libutilB2.a

# for this executable, we try -static, so we can see in trace
# how the gcc static libraries are loaded (so, static executable)
# also, du -b *.exe: 632365	testerb2.exe; 7317	testerb21.exe and rest

gcc -Wall -Wl,--trace -static -I. -o testerb2.exe tester.c libutilB2.a
./testerb2.exe 100


######################################
echo -e "\nCreating manual static library B 3"

# here we do link utilA (in ar) first; objdump: getStrHexA is found, but getStrB isn't:

ar rcs libutilB3.a utilA.o utilB.o
# list contents
ar -tv libutilB3.a

eval nm -a libutilB3.a $FILTER
eval objdump --archive-headers --private-headers --dynamic-syms --syms --reloc libutilB3.a $FILTER
#~ readelf --syms --dyn-syms --relocs --dynamic libutilB3.a

gcc -Wall -Wl,--trace -I. -o testerb3.exe tester.c libutilB3.a
./testerb3.exe 100


######################################
echo -e "\nTrying ranlib on B 2 as B 21"

# here still still getStrHexA is undefined

cp libutilB2.a libutilB21.a
ranlib libutilB21.a
# list contents
ar -tv libutilB21.a


eval nm -a libutilB21.a $FILTER
eval objdump --archive-headers --private-headers --dynamic-syms --syms --reloc libutilB21.a $FILTER
#~ readelf --syms --dyn-syms --relocs --dynamic libutilB21.a

gcc -Wall -Wl,--trace -I. -o testerb21.exe tester.c libutilB21.a
./testerb21.exe 100


######################################
echo -e "\nTrying ranlib on B 3 as B 31"

cp libutilB3.a libutilB31.a
ranlib libutilB31.a
# list contents
ar -tv libutilB31.a

eval nm -a libutilB31.a $FILTER
eval objdump --archive-headers --private-headers --dynamic-syms --syms --reloc libutilB31.a $FILTER
#~ readelf --syms --dyn-syms --relocs --dynamic libutilB31.a

gcc -Wall -Wl,--trace -I. -o testerb31.exe tester.c libutilB31.a
./testerb31.exe 100

# so, apparently as long as undefined symbols in one .o file in
# an .a archive, have a definition in some other .o file (in the
# same archive) - static linking goes well;
# and the order in which the .o files are packed into .a archive
# seems not to even matter (at least here)


######################################
echo -e "\nTrying libtool merge A1 and B1"

# on Mac's libtool, one can do:
#~ libtool -static -o libmergeBA1.a libutilB1.a libutilA1.a
# and have static libraries' objects merged in a new one;
# On Linux, the command format is different,
# and it will NOT merge the libraries correctly:
# http://stackoverflow.com/questions/11344547/how-do-i-compile-a-static-library/16070483#16070483

libtool --mode=link --tag=CC ar -o libmergeAB1.a -static libutilA1.a libutilB1.a

readelf --syms libmergeAB1.a

set +x
echo -e "to clean, execute:\nrm *.c *.h *.o *.a *.exe"


