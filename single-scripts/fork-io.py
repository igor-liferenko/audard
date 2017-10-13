#!/usr/bin/env python

# http://www.ibm.com/developerworks/aix/library/au-multiprocessing/
# http://stackoverflow.com/questions/6050187/write-to-file-descriptor-3-of-a-python-subprocess-popen-object
# [http://www.gidforums.com/t-3369.html [TUTORIAL] Calling an external program in C (Linux) - GIDForums]
# http://www.tutorialspoint.com/python/os_dup2.htm
# also. note os.fdopen() :
# http://stackoverflow.com/questions/6193779/python-readline-from-pipe-on-linux
# http://stackoverflow.com/questions/4022600/python-pty-fork-how-does-it-work/6953572#6953572


import sys
import os
import time
import pty

def my_os_fork():

  # create pipes first;

  # parent (out) to child (in) pipe // poci[0,1]
  in_poci_fd,out_poci_fd=os.pipe()
  # child (out) to parent (in) pipe // copi[0,1]
  in_copi_fd,out_copi_fd=os.pipe()

  # fork this bitch :)
  # will create another (child) copy of this program;
  # the child will have a pid of zero;
  # helps us determine which part of the code runs after fork
  child_pid = os.fork()

  # now both copies come to this line,
  # but will see a different value for child_pid
  # also, at start, fd's for stdin/out will be 0 and 1 for both
  #  (as initially they both live in the same terminal)
  # so, a close refers to the local copy!
  if child_pid == 0:
    # setup parent to child (poci) comm.
    print "In Child Process: PID# %s" % os.getpid()
    os.dup2(in_poci_fd,0);  # Replace stdin with the in side of the pipe; duplicate as 0
    os.close(out_poci_fd);  # Close unused side of pipe (out side)

    # test parent to child (poci) comm.
    # do .. while
    while True:
      tmps = os.read(in_poci_fd, 1)
      print tmps
      if tmps == "\0":
        break;

    # setup child to parent (copi) comm.
    # save "real" stdout
    fdtempout=1000
    os.dup2(1,fdtempout); # duplicate real stdout as fd=1000

    os.dup2(out_copi_fd,1);  # Replace stdout with out side of the pipe; duplicate as 1
    os.close(in_copi_fd);  # Close unused side of pipe (in side)

    # test child to parent (copi) comm.
    os.write(out_copi_fd, "hello\n");

    # note, with the changes to file descriptors so far;
    #   the data that child writes to parent here,
    #   is actually looped back to the child...
    time.sleep(0.5)
    os.write(out_copi_fd, "from child\n");
    time.sleep(0.5)
    os.write(out_copi_fd, "test\n");
    os.write(out_copi_fd, "\0");

    # therefore we run one more read + printout;
    #   (to drain/flush leftovers from previous write)
    #   however to the saved (real) stdout
    #   coz otherwise the pipes form a 'circle' now :)
    while True:
      tmps = os.read(in_poci_fd, 1)
      os.write(fdtempout, tmps)
      if tmps == "\0":
        break;

  else:
    print "In Parent Process: PID# %s" % os.getpid()
    # setup parent to child (poci) comm.
    os.dup2(out_poci_fd,1);  # Replace stdout with out side of the pipe; duplicate as 1
    os.close(in_poci_fd);  # Close unused side of pipe (in side)

    # test parent to child (poci) comm.
    os.write(out_poci_fd, "HELLO\n");
    time.sleep(0.5)
    os.write(out_poci_fd, "FROM PARENT\n");
    time.sleep(0.5)
    os.write(out_poci_fd, "TEST\n");
    os.write(out_poci_fd, "\0");

    # setup child to parent (copi) comm.
    os.dup2(in_copi_fd,0);  # Replace stdin with the in side of the pipe
    os.close(out_copi_fd);  # Close unused side of pipe (out side)

    # test child to parent (copi) comm.
    while True:
      tmps = os.read(in_copi_fd, 1)
      print tmps
      if tmps == "\0":
        break;


# http://stackoverflow.com/questions/864826/python-os-forkpty-why-cant-i-make-it-work
def my_pty_fork():

  # fork this bitch :)
  try:
    ( child_pid, fd ) = pty.fork()    # OK
    #~ child_pid, fd = os.forkpty()      # OK
  except OSError as e:
    print str(e)

  #~ print "%d - %d" % (fd, child_pid)
  # NOTE - unlike OS fork; in pty fork we MUST use the fd variable
  #   somewhere (i.e. in parent process; it does not exist for child)
  # ... actually, we must READ from fd in parent process...
  #   if we don't - child process will never be spawned!

  if child_pid == 0:
    print "In Child Process: PID# %s" % os.getpid()
    # note: fd for child is invalid (-1) for pty fork!
    #~ print "%d - %d" % (fd, child_pid)

    # the os.exec replaces the child process
    sys.stdout.flush()
    try:
      #Note: "the first of these arguments is passed to the new program as its own name"
      # so:: "python": actual executable; "ThePythonProgram": name of executable in process list (`ps axf`); "pyecho.py": first argument to executable..
      os.execlp("python","ThePythonProgram","pyecho.py")
    except:
      print "Cannot spawn execlp..."
  else:
    print "In Parent Process: PID# %s" % os.getpid()
    # MUST read from fd; else no spawn of child!
    print os.read(fd, 100) # in fact, this line prints out the "In Child Process..." sentence above!

    os.write(fd,"message one\n")
    print os.read(fd, 100)        # message one
    time.sleep(2)
    os.write(fd,"message two\n")
    print os.read(fd, 10000)      # pyecho starting...\n MESSAGE ONE
    time.sleep(2)
    print os.read(fd, 10000)      # message two \n MESSAGE TWO
    # uncomment to lock (can exit with Ctrl-C)
    #~ while True:
      #~ print os.read(fd, 10000)


if __name__ == "__main__":
    #~ my_os_fork()
    my_pty_fork()
