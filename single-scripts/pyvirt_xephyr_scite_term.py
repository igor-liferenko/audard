from easyprocess import EasyProcess
from pyvirtualdisplay import Display
#~ from pyvirtualdisplay.smartdisplay import SmartDisplay # needs pyscreenshot
import logging
logging.basicConfig(level=logging.DEBUG)
import time

_W = 700
_H = 600
# height percents
hp1 = 0.6
hp2 = 1-hp1


Display(visible=1, size=(_W , _H)).start()

# EasyProcess.start() # spawns process in background
# EasyProcess.check() # loops process in foreground


try:
  EasyProcess('awesome -c rc.lua').start() 
except Exception, detail:
  print  detail

time.sleep(2)

try:
  EasyProcess('bash -c "cd $HOME && scite"').start() 
except Exception, detail:
  print  detail

time.sleep(2)

try:
  # 0,x,y,w,h
  EasyProcess(['wmctrl', '-r', 'SciTE', '-e', '0,0,0,'+str(_W)+','+str(int(_H*hp1))]).start() 
except Exception, detail:
  print  detail

# gnome-terminal -e 'bash -c "bash --rcfile <(echo source $HOME/.bashrc ; echo PS1=\\\"\$ \\\") -i"'
# first `bash` needed, otherwise cannot do process substitution as file

try:
  EasyProcess(['gnome-terminal', '-e', 'bash -c "bash --rcfile <(echo source $HOME/.bashrc ; echo tmpbash) -i"']).start() # --maximize is Gnome, nowork # ; echo PS1=\\\"\$\ \\\"
except Exception, detail:
  print  detail

time.sleep(0.5)

try:
  # 0,x,y,w,h
  EasyProcess(['wmctrl', '-r', 'Terminal', '-e', '0,0,'+str(int(_H*hp1))+','+str(_W)+','+str(int(_H*hp2))]).start() 
except Exception, detail:
  print  detail

