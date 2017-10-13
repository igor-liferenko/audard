#!/bin/bash
# http://askubuntu.com/questions/31240/how-to-shift-applications-from-workspace-1-to-2-using-command
# http://stackoverflow.com/questions/73087/x-gnome-how-to-measure-the-geometry-of-an-open-window
# http://www.linuxquestions.org/questions/linux-newbie-8/how-do-i-resize-the-terminal-window-from-the-command-line-in-the-gnome-terminal-644048/
# EDIT: Theres also commands to change the window size of other applications, eg. wmctrl -r Firefox -e 1,-1,-1,500,300
# -e <MVARG>: resize and move; MVARG: 'g,x,y,w,h' (g - gravity)
# -r: specify target
# -i: interpret target as id
#  -t <DESK>: move a window to desktop
# "A gravity of 0 indicates that the Window Manager should use the gravity specified in WM_SIZE_HINTS.win_gravity" http://standards.freedesktop.org/wm-spec/wm-spec-latest.html
# http://askubuntu.com/questions/20399/position-at-center-workspace-when-login/20413#20413

#~ $ wmctrl -l
#~ 0x03a00026  0 ljutntcol Terminal
#~ 0x02400001  0       N/A N/A
#~ 0x02400002  0       N/A launcher
#~ 0x0220002d  0 ljutntcol <unknown>
#~ 0x02400003  0       N/A panel
#~ 0x01200024  0 ljutntcol x-nautilus-desktop
#~ 0x03c000ec  0 ljutntcol how to shift applications from workspace 1 to 2 using command - Ask Ubuntu - Stack Exchange - Minefield
#~ 0x012005d3  0 ljutntcol administrator
#~ 0x03e00026  0 ljutntcol Terminal
#~ 0x04000003  0 ljutntcol desk-workspace-startup.sh - SciTE
#~ 0x03e0020a  0 ljutntcol Terminal

#~ ~$ xwininfo -id 0x04000003

#~ xwininfo: Window id: 0x4000003 "desk-workspace-startup.sh - SciTE"

  #~ Absolute upper-left X:  1
  #~ Absolute upper-left Y:  52
  #~ Relative upper-left X:  0
  #~ Relative upper-left Y:  0
  #~ Width: 510
  #~ Height: 506
  #~ Depth: 24
#~ ...
  #~ Corners:  +1+52  -513+52  -513-42  +1-42
  #~ -geometry 510x506+-7+24

# info on desktop
#~ $ wmctrl -d
#~ # top left
#~ 0  * DG: 2048x1200  VP: 0,0  WA: 0,24 1024x576  Workspace 1
#~ # bottom left
#~ 0  * DG: 2048x1200  VP: 0,600  WA: 0,24 1024x576  Workspace 1
#~ # top right
#~ 0  * DG: 2048x1200  VP: 1024,0  WA: 0,24 1024x576  Workspace 1
#~ # bottom right
#~ 0  * DG: 2048x1200  VP: 1024,600  WA: 0,24 1024x576  Workspace 1

# Because compiz workspaces are actually viewport of a single desktop, so the solution is to move the current viewport to cover the center region of the desktop.
# First, call wmctrl -d to get the information of current desktop:

#~ read desktop_id _ast \
    #~ DG_ geometry \
    #~ VP_ viewport \
    #~ WA_ wa_off wa_size \
    #~ title \
    #~ < <(LANG=C wmctrl -d | grep '*')

SLEEPTIME=4

# go to init workspace - top left
wmctrl -o 0,0

# read as array instead - to avoid as multiple spaces
# but: Syntax error: redirection unexpected
#~ read -a DARR < <(wmctrl -d | grep '*')
# that's because dash is default shell in ubuntu - so must have bin/bash above?
# yup - then the exact same command line works
read -a DARR < <(wmctrl -d | grep '*')

# to view correctly:
#~ echo "${DARR[@]}"
# else the * is expanded by shell
geometry=$(echo "${DARR[3]}")
viewport=$(echo "${DARR[5]}")
wa_off=$(echo "${DARR[7]}")
wa_size=$(echo "${DARR[8]}")
# title as 'Workspace 1' - 9th elem 'Workspace'; so use ${DARR[@]:9} for 9th elem and after
title=$(echo "${DARR[@]:9}")

geom_w=${geometry%x*}
geom_h=${geometry#*x}

# The workarea size isn't accurate, because the top/bottom panel is excluded.
viewport_w=${wa_size%x*}
viewport_h=${wa_size#*x}

rows=$((geom_w / viewport_w))
cols=$((geom_h / viewport_h))

# Fix the viewport size
viewport_w=$((geom_w / rows))
viewport_h=$((geom_h / cols))

# Then, calculate the origin of the center viewport:

center_row=$((rows / 2))
center_col=$((cols / 2))

center_x=$((center_col * viewport_w))
center_y=$((center_row * viewport_h))

center_viewport=$center_x,$center_y
#~ echo $center_viewport

# And move the viewport there:

## wmctrl -o $center_viewport

# nah, just use:
#~ wmctrl -o 0,0
#~ wmctrl -o 0,600
#~ wmctrl -o 1024,0
#~ wmctrl -o 1024,600
# directly..

# show folder - nautilus - workspace 0 (don't move)
nautilus /media/nonos
sleep $SLEEPTIME

# go to workspace down
wmctrl -o 0,600

# start a terminal; it should automatically go to the home folder ~; start scite from there (for latex command)
# also: gnome-terminal --execute scite  / --command="scite"
#~ gnome-terminal --command="cd ~; scite" # NO
# also as process?! YES - as scite runs, it won't allow exit
# and better with bash as argument, so we can cd to ~ beforehand
# must source .bashrc here; see
## http://stackoverflow.com/questions/3896882/open-gnome-terminal-programmatically-and-execute-commands-after-bashrc-was-execut
## http://superuser.com/questions/198015/open-gnome-terminal-programmatically-and-execute-commands-after-bashrc-was-execut

## below cannot execute bashrc - and so no path to pdflatex
#~ (gnome-terminal --execute bash -c 'cd ~ ; . ~/.bashrc ; scite' &)
## ... so, must use eval "$BASH_POST_RC" in ~/.bashrc, and like this:
(gnome-terminal --execute bash -c "export BASH_POST_RC=\"cd ~; scite\"; exec bash" &)

sleep $SLEEPTIME # wait a bit for window to spawn

# get window IDs
TERMID=$(wmctrl -l | grep Terminal | cut -d' ' -f1)
SCITEID=$(wmctrl -l | grep SciTE | cut -d' ' -f1)

# get window geometries - not needed really (just for reference)
# xwininfo -id 0x3e0020a | grep 'Absolute upper-left X\|Absolute upper-left Y\|Width\|Height'
TERMGEOM=$(xwininfo -id "$TERMID")
TERMGEOM_X=$(echo "$TERMGEOM" | grep 'Absolute upper-left X' | cut -d' ' -f7)
TERMGEOM_Y=$(echo "$TERMGEOM" | grep 'Absolute upper-left Y' | cut -d' ' -f7)
TERMGEOM_W=$(echo "$TERMGEOM" | grep 'Width' | cut -d' ' -f4)
TERMGEOM_H=$(echo "$TERMGEOM" | grep 'Height' | cut -d' ' -f4)
SCITEGEOM=$(xwininfo -id "$SCITEID" | grep '\-geometry' | cut -d' ' -f4)
SCITEGEOM_X=$(echo "$SCITEGEOM" | grep 'Absolute upper-left X' | cut -d' ' -f7)
SCITEGEOM_Y=$(echo "$SCITEGEOM" | grep 'Absolute upper-left Y' | cut -d' ' -f7)
SCITEGEOM_W=$(echo "$SCITEGEOM" | grep 'Width' | cut -d' ' -f4)
SCITEGEOM_H=$(echo "$SCITEGEOM" | grep 'Height' | cut -d' ' -f4)

# set window geometries, and move to workspace (desktop) 'down' - workspace 1
# NOTE - -t seems not to work in Unity (everything is workspace 1)!
#~ wmctrl -i -r "$TERMID" -e 0,1,562,505,42
#~ wmctrl -i -r "$SCITEID" -e 0,1,52,510,506
# have to lift by 30 (add -30) to the orig values gotten by xwininfo for correct placement with bars, so:
wmctrl -i -r "$TERMID" -e 0,1,532,505,42
wmctrl -i -r "$SCITEID" -e 0,1,22,510,506

sleep 1

# all done - go to top rigth workspace, start firefox
wmctrl -o 1024,0

# as process so it exits
(/media/nonos/ebin/firefox4/firefox -P sdffoxprof &)

sleep $SLEEPTIME # wait a bit for window to spawn

# go back to main 'workspace'
wmctrl -o 0,0


