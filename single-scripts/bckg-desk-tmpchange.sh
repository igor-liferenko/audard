#!/usr/bin/env bash

# sdaau, 2015
# change (Gnome2) desktop background temporarily from command line

# modify this as you find fitting:
#replace_image="/usr/share/backgrounds/warty-final-ubuntu.png"
replace_image="/usr/share/backgrounds/space-02.jpg"

# Ubuntu 11.04, Gnome 2 - get initial settings:
orig_pic_fn=$(gconftool-2 --get  "/desktop/gnome/background/picture_filename")
orig_show_desk=$(gconftool-2 --get  "/apps/nautilus/preferences/show_desktop")
# might be useful, but unused:
orig_draw_bckg=$(gconftool-2 --get  "/desktop/gnome/background/draw_background")

# must be after orig_* vars, so it can refer to them:
restore_originals() {
  echo
  echo "  Restoring original show_desktop: ${orig_show_desk} and original picture_filename: ${orig_pic_fn}"
  gconftool-2 --set "/desktop/gnome/background/picture_filename" --type string ${orig_pic_fn}
  # here sleep seems not strictly necessarry, but still, add it:
  sleep 1
  gconftool-2 --set "/apps/nautilus/preferences/show_desktop" --type bool ${orig_show_desk}
  gconftool-2 --set "/desktop/gnome/background/draw_background" --type bool ${orig_draw_bckg}
}
# Ctrl-C trap. Catches INT signal
trap "restore_originals; echo; exit 0" INT

# -------------

echo "Original show_desktop (icons): ${orig_show_desk}"
echo "Original (desktop) picture_filename: ${orig_pic_fn}"

echo
echo "Setting temporary desktop settings: no icons, custom image ${replace_image}"
echo

#~ gconftool-2 --set "/desktop/gnome/background/picture_filename" --type string ${replace_image}
gconftool-2 --set "/desktop/gnome/background/draw_background" --type bool false
# must sleep for a while, for Gnome2 to make transition to the new image
sleep 1
gconftool-2 --set "/apps/nautilus/preferences/show_desktop" --type bool false

# if you type enter here, the `read` will simply start again,
# hit Ctrl-C to exit.
while [ 1 ]; do
  read -p "Blocking with read, and waiting for a Ctrl-C interrupt... " dontcare
done
