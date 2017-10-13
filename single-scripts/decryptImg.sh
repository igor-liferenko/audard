
#  use --force-mdc on encrypt to avoid warning
#  (http://lists.gnupg.org/pipermail/gnupg-users/2004-October/023502.html)
# To encrypt single file, use command
# gpg --force-mdc -c mypass.png  # generates mypass.png.gpg

URLFILE="http://www.somesite.com/path/mypass.png.gpg"

# download, decrypt in memory and pipe
# options to gpg must be before filename
#  it is not necesarry to specify --decrypt to gpg
#  gpg needs `--output -` to write to stdout, 
#  and one more `-` to read from stdin
# note, eog cannot display stdin image content
#  so use gv (ghostview) or imagemagick `display`
wget --no-verbose "$URLFILE" -O - | gpg --output - - | display

