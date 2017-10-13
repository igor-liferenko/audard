# wxt - run gnuplot from command line, and in terminal:
# load "./basic-labels.gnuplot"
# note - above will fail without quote marks!

# load interaction (download locally first)
load "http://sdaaubckp.svn.sourceforge.net/viewvc/sdaaubckp/single-scripts/interaction.gnuplot"

# generate data
system "cat > ./inline.dat <<EOF\n\
10.0 1 a 2\n\
10.2 2 b 2\n\
10.4 3 a 2\n\
10.6 4 b 2\n\
10.8 5 c 7\n\
11.0 5 c 7\n\
EOF\n"

# ranges -- leave space for labels below
set yrange [-5:8]
set xrange [9.5:11.5]

# do NOT issue plot one after another,
# next will replace previous plot!
#plot "rep.txt" using 1:3
#plot "rep.txt" using 1:4

# define line styles - can call them up later
# 'w l ls 1' = with line linestyle 1
set style line 1 lt 1 lw 1 pt 3 linecolor rgb "black"
set style line 2 lt 1 lw 3 pt 3 linecolor rgb "light-red"
set style line 3 lt 1 lw 2 pt 3 linecolor rgb "dark-red"
set style line 4 lt 1 lw 2 pt 3 linecolor rgb "magenta"
set style line 5 lt 1 lw 3 pt 3 linecolor rgb "light-green"
set style line 6 lt 1 lw 2 pt 3 linecolor rgb "dark-green"
set style line 7 lt 1 lw 2 pt 3 linecolor rgb "blue"

# point type 5 is filled rectangle (4 is white w border)! (using as background for labels)
set style line 8 lt 1 lw 3 pointtype 4 pointsize 5 linecolor rgb "light-gray"
set style line 9 lt 1 lw 1.5 linecolor rgb "light-gray"

# linetype 2 - maybe dashed
set style line 10 lt 2 lw 1 linecolor rgb "black"


# offset integer - see first timestamp entry in file

# a function (gnuplot docs for labels)
# must set enhanced to be able to use {/= for font size
# but it also messes centering of labels
# actually, centering of labels is messed even without enhanced (or with) - each time the font size is changed!
# at least, it seems to position on y=3; have to enter y=3.5 as column data, and for size 20; go down vertical offset in "fraction of current fontsize" of -.35; note that can go down -2, -3.. but can go up max to defined to the y=column data, regardless how much is added to push up ; for negative pos, say at y=-1, must set column data to y=-0.5
# ... but that calc depends on range (and rotation)!
set termoption enhanced
# note that setting terminal to either png or pdfcairo will differ much from the wxt result!
#Stringer(String) = sprintf("{/=20 %s}", String)
Stringer(String) = sprintf("{/=12 {~&{%s-lab}{2.1%s-lab}}}", String, String)
#Stringer(String) = sprintf("{%s}", String)
#Stringer(String) = sprintf("%s", String)

# actually, first "parse": split data into tables locally (with set table); then plot?
# cannot - columns that are output depend on the type of plot

#     "" using (strcol(3) eq 'a' ? $1 : 1/0):(2):("a") notitle with labels
# note that:
# :2 means `in respect to elements of second column of data`
# :(2) means `use a column made up of number 2`
# :("a") means `use a column made up of string "a"`
# :(Stringer(stringcolumn(2))) means `use the return of function, fed by respective elements of second column of data, interpreted as string`

# http://gnuplot-surprising.blogspot.com/2011/08/advanced-background-color-0.html
# http://objectmix.com/graphics/139827-gnuplot-4-0-labels-boxes.html

# first, plot black horizontal line at 0
# then for 'a' red impulses (vertical lines only)
# then for 'a' red points (dots on top of impulses)
# then for 'a' background for labels
# then for 'a' the label "a" at y=-1
# then for 'a' red impulses (vertical lines only)
# then for 'a' red points (dots on top of impulses)
# then for 'a' background for labels
# then for 'a' the label "a" at y=-1

plot 0 notitle with lines linestyle 1,\
    -1.5 notitle with lines linestyle 10,\
    -2.5 notitle with lines linestyle 10,\
    "inline.dat" using (strcol(3) eq 'a' ? $1 : 1/0):2 title "a" with impulses linestyle 2,\
     "" using (strcol(3) eq 'a' ? $1 : 1/0):2 notitle with points linestyle 2,\
     "" using (strcol(3) eq 'a' ? $1 : 1/0):4 notitle with points linestyle 6,\
     "" using (strcol(3) eq 'a' ? $1 : 1/0):(-1) notitle with points linestyle 8,\
     "" using (strcol(3) eq 'a' ? $1 : 1/0):(-0.6) notitle with impulses linestyle 9,\
     "" using (strcol(3) eq 'a' ? $1 : 1/0):(-0.5):(Stringer(stringcolumn(3))) notitle with labels rotate by -90 offset 1,-0.9 left,\
    "" using (strcol(3) eq 'b' ? $1 : 1/0):2 title "b" with impulses linestyle 3,\
     "" using (strcol(3) eq 'b' ? $1 : 1/0):2 notitle with points linestyle 3,\
     "" using (strcol(3) eq 'b' ? $1 : 1/0):4 notitle with points linestyle 6,\
     "" using (strcol(3) eq 'b' ? $1 : 1/0):(-2) notitle with points linestyle 8,\
     "" using (strcol(3) eq 'b' ? $1 : 1/0):(-1.6) notitle with impulses linestyle 9,\
     "" using (strcol(3) eq 'b' ? $1 : 1/0):(-1.5):(Stringer(stringcolumn(3))) notitle with labels rotate by -90 offset 1,-0.9 left,\
    "" using (strcol(3) eq 'c' ? $1 : 1/0):2 title "c" with impulses linestyle 7,\
     "" using (strcol(3) eq 'c' ? $1 : 1/0):2 notitle with points linestyle 7,\
     "" using (strcol(3) eq 'c' ? $1 : 1/0):4 notitle with points linestyle 6,\
     "" using (strcol(3) eq 'c' ? $1 : 1/0):(-3) notitle with points linestyle 8,\
     "" using (strcol(3) eq 'c' ? $1 : 1/0):(-2.6) notitle with impulses linestyle 9,\
     "" using (strcol(3) eq 'c' ? $1 : 1/0):(-2.5):(Stringer(stringcolumn(3))) notitle with labels rotate by -90 offset 1,-0.9 left




