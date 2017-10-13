#!/usr/bin/awk -f

# run with:
# awk -f script.awk testfile.txt
# ./script.awk testfile.txt

# http://www.computing.net/answers/unix/retrieve-text-between-two-strings-/8136.html
# encapsulate all in main awk brackets {}!
# no specific pattern, so do on every line:
{
  p1="enddefinitions"
  p2="end"
  if (newgroup=="") { # init variable
    newgroup=0
  }

  # this condition [ if (newgroup==1) ] must be first;
  # otherwise, newgroup will be set to 1; and this will overwrite in next step!
  if (newgroup==1) {
    if (match($0,p2)) {
      if (1) { # if 1 (true) - don't ignore newgroup reset to 0
        newgroup=0 # ignoring this, will print to end of file
        print # ignoring the newgroup=0, we don't need this
      }
    }
  }

  if (match($0,p1)) {
    if (newgroup==0) {
      newgroup=1
    }
  }

  if (newgroup==1) {
    print
  }
  #~ print match($0,p1), match($0,p2), newgroup  # dbg printout
}