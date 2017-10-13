"""
http://www.daniweb.com/forums/thread106935.html
also, using http://wm.ite.pl/proj/canvas2svg/canvasvg.py
however, tkinter still cannot get text width
http://www.velocityreviews.com/forums/t344274-tkinter-text-width.html
"""

from Tkinter import *
from canvasvg import *
import canvasvg

root = Tk()
def drawcircle(canv,x,y,rad):
    canv.create_oval(x-rad,y-rad,x+rad,y+rad,width=0,fill='blue')

canvas = Canvas(width=600, height=200, bg='white')  
canvas.pack(expand=YES, fill=BOTH) 

text = canvas.create_text(50,10, text="tk test")

#i'd like to recalculate these coordinates every frame
circ1=drawcircle(canvas,100,100,20)          
circ2=drawcircle(canvas,500,100,20)

doc = canvasvg.SVGdocument()
for element in canvasvg.convert(doc, canvas, tounicode=None):
	doc.documentElement.appendChild(element)

doc.documentElement.setAttribute('width',  str(400))
doc.documentElement.setAttribute('height', str(400))

f = open('out.svg', 'w')
if True: # pretty
	f.write(doc.toprettyxml())
else:
	f.write(doc.toxml())
f.close()

root.mainloop()




"""
#!/usr/bin/env python
import matplotlib
matplotlib.use('TkAgg')

from numpy import arange, sin, pi
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg, NavigationToolbar2TkAgg
from matplotlib.figure import Figure

import Tkinter as Tk
import sys

def destroy(e): sys.exit()

root = Tk.Tk()
root.wm_title("Embedding in TK")
#root.bind("<Destroy>", destroy)


f = Figure(figsize=(5,4), dpi=100)
a = f.add_subplot(111)
t = arange(0.0,3.0,0.01)
s = sin(2*pi*t)

a.plot(t,s)


# a tk.DrawingArea
canvas = FigureCanvasTkAgg(f, master=root)
canvas.show()
canvas.get_tk_widget().pack(side=Tk.TOP, fill=Tk.BOTH, expand=1)

text = canvas.create_text(50,10, text="tk test")

toolbar = NavigationToolbar2TkAgg( canvas, root )
toolbar.update()
canvas._tkcanvas.pack(side=Tk.TOP, fill=Tk.BOTH, expand=1)

#button = Tk.Button(master=root, text='Quit', command=sys.exit)
#button.pack(side=Tk.BOTTOM)

Tk.mainloop()
"""
