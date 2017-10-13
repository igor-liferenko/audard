
# http://www.skorks.com/2010/03/how-to-quickly-generate-a-large-file-on-the-command-line-with-linux/
# http://administratosphere.wordpress.com/2007/11/23/quickly-creating-large-files/

python -c 'import sys; a1="abcdefghijklmnopqrstuvwxyz" ; a2=a1[::-1] ; a=a1+a2[1:] ; size=100000 ; for i in range(1,size,len(a)): sys.stdout.write(a)' # > myfile.dat

# saw wavez:
python -c 'import sys; size=100000 ; 
for i in range(1,size,1): 
 s2=size/2
 i2a=2*abs(i-s2)
 i2=float(i2a)/size
 i3=float(i%255)/255
 i4=(i2 + 0.5*i3)/1.5
 i5=int(round(255*i4))
 sys.stdout.write(chr(i5))' > myfile.dat

# no dd if=- in my version! 
# also - works only up to first page - 4096 bytes!
# so easiest to redirect python's  output to file directly > myfile.dat...
#
#~ $ python -c 'import sys; a1="abcdefghijklmnopqrstuvwxyz" ; a2=a1[::-1] ; a=a1+a2[1:] ; print a ; size=100000 ; 
#~ for i in range(1,size,len(a)): sys.stdout.write(a)' | dd of=myfile.dat bs=$(( 1024 * 1024 )) count=1
#~ 0+1 records in
#~ 0+1 records out
#~ 4096 bytes (4,1 kB) copied, 0,051914 s, 78,9 kB/s
#~ Traceback (most recent call last):
  #~ File "<string>", line 2, in <module>
#~ IOError: [Errno 32] Broken pipe
