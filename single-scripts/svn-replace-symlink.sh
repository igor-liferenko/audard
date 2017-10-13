# http://serverfault.com/questions/149609/replace-symbolic-link-with-target
# http://antoniolorusso.com/2008/09/29/svn-entry-has-unexpectedly-changed-special-status/

for ix in `find . -type l`; do ifl=$(readlink -f $ix); svn del $ix && cp $ifl $ix && svn add $ix && svn propdel svn:special $ix; done
