#!/usr/env/bin python
"""
http://projects.gnome.org/dia/python.html
http://projects.gnome.org/dia/pydia.html

make a symlink:
mkdir $HOME/.dia/python
ln -s $(pwd)/dia_python.py $HOME/.dia/python

for object generation, see: /usr/share/dia/python/aobjects.py

note, also for newer Dia; there is "PyDia Object Export", "diapyo", ObjRenderer() - i.e. Export: file type: PyDia Code Generation (python)!. But should enable the Python (Python Scripting support) in the Plug-ins (File/Plugins.. on toolbox_window)? nope, that is by default.. 
BUT:
$ dia --verbose -l
sys:1: RuntimeWarning: DiaPyRenderer.draw_line() implmentation missing. (seemingly, just for UML - see /usr/share/dia/python/codegen.py)

Try to copy export-object.py manually...  http://www.koders.com/python/fid015F215EEDB745CC80EA8B35E04EDCA1663E0DC6.aspx?s=%22slant%22 
Then getting: export file type: PyDia Object Export (.diapyo)

see Log from Dia/Dialogs/Python Console below...


## when scripts starts generating - remember you must still refresh the screen manually to see results! 

## for quick copypaste in Python Dia Console: 

import dia_python
dia_python.genObjects()

## To avoid restarting Dia 
## when modifying this python script [after import], 
## use 'reload' from the Python Dia Console: 
dia_python = reload(dia_python) 

"""

# example from page 
import sys, dia

# make a tml line; extract props as 'default' style
tline, th1, th2 = dia.get_object_type("Standard - Line").create (10.0, 10.0)
dia.active_display().diagram.data.active_layer.add_object(tline)
dia.active_display().diagram.data.active_layer.update_extents()

linepropsA = tline.properties # <DiaProperty at 0x8c156c0, "obj_pos", point>
print dir(linepropsA.get('obj_pos').value) # ['x', 'y']
print tline.properties["obj_pos"] 
## see wrong syntax (#A1) below (was here)

dia.active_display().diagram.data.active_layer.remove_object(tline)

lpaStyle={
'line_width':0.5,
'line_colour':(0.000000,0.500000,0.000000),
'line_style':(0, 1.0),
## see wrong syntax (#A2) below (was here).. 
## specify arrows directly as tuple (type, length, width):
'start_arrow':(8, 0.6, 0.6),
'end_arrow':(22, 0.6, 0.6)
}

def applyStyle(dobj, styleProps):
	for key in dobj.properties.keys(): 
		#~ print key, sl.properties.get(key).name, sl.properties.get(key).type, sl.properties.get(key).value, sl.properties.get(key).visible 
		if styleProps.has_key(key):
			#~ dobj.properties.get(key).value = styleProps[key]
			dpk = dobj.properties[key]
			dval = dobj.properties[key].value
			spk = styleProps[key]
			print key, dval, dir(dval), spk
			## see wrong syntax (#A3) below (was here)
			# do NOT assign to dpk as variable - only direct to .properties[key]! 
			dobj.properties[key] = spk			
			print "post", dobj.properties[key].value



def genObjects():
	# usualyrly alyr is 'Background' on empty diagram 
	alyr = dia.active_display().diagram.data.active_layer
	print alyr, dir(alyr) 
	obj, h1, h2 = dia.get_object_type("Standard - Polygon").create (10.0, 10.0)
	w = obj.bounding_box.right - obj.bounding_box.left
	h = obj.bounding_box.bottom - obj.bounding_box.top
	obj.move (w, h)

	alyr.add_object (obj)
	alyr.update_extents()
	
	obj2, h1, h2 = dia.get_object_type("Standard - Line").create (4.0, 1.0) # x,y - arrow seems always to be sqrt(2) long, at 45 degrees angle, when generated like this
	applyStyle(obj2, lpaStyle)
	
	alyr.add_object (obj2)
	alyr.update_extents()
	
	obj3a = dia.get_object_type("Standard - Text").create (8.0, 1.0)
	alyr.add_object (obj3a)
	alyr.update_extents()

	
	

def center_objects (objs) :
        r = objs[0].bounding_box
        cx = (r.right + r.left) / 2
        cy = (r.bottom + r.top) / 2
        for o in objs[1:] :
                r = o.bounding_box
                (x, y) = o.properties["obj_pos"].value
                dx = (r.right + r.left) / 2 - cx
                dy = (r.bottom + r.top) / 2 - cy
                o.move (x - dx, y - dy)

def dia_objects_center_cb (data, flags) :
        grp = data.get_sorted_selected()
        if (len(grp) > 1) :
                center_objects (grp)
                data.update_extents ()
        dia.active_display().diagram.add_update_all()
        
dia.register_callback ("Center Objects",
                       "<Display>/Objects/Center",
                       dia_objects_center_cb)




"""

## wrong syntax (#A1) notes: 
#~ tline.properties["obj_pos"] = dia.Point(0,000000,1,000000) # cannot create 'dia.Point' instances
#~ tline.properties["obj_pos"] = (0,000000,1,000000) # TypeError: prop type mis-match.
#~ tline.properties["obj_pos"] = (0.000000,1.000000) # TypeError: 'dia.Object' object has only read-only attributes (assign to .obj_pos)
#~ tline.obj_pos = (0,000000,1,000000) #  'dia.Object' object has only read-only attributes (assign to .obj_pos)
#~ tline.obj_pos = (0.000000,1.000000) # ... read-only
#~ linepropsA.get('obj_pos').value = (0,000000,1,000000) # AttributeError: 'dia.Property' object has no attribute 'value' ???
# nope - "TypeError: 'dia.Property' object has only read-only attributes (assign to .value)"


## see wrong syntax (#A2) notes: 
#~ 'start_arrow':((0.500000,0.500000), 8),
#  dia.Arrow: length (dbl) type (int) width (dbl)
#			['length', 'type', 'width'] 
#~ 'start_arrow':(0.500000, 8, 0.500000),
#~ 'start_arrow':(0.600000, 0.600000, 8),
#~ 'start_arrow':(0,600000,0,600000, 8),
#~ 'start_arrow':[('length', 0.6), ('type', 8), ('width', 0.6)], # turns obj in array..
## specify arrows separately as dict
'start_arrow':{'length':0.6, 'type':8, 'width':0.6}, # at least here can specify them separately, although it don't work directly
#~ 'end_arrow':((0.500000,0.500000), 22)
#~ 'end_arrow':(0.500000, 22, 0.500000)
'end_arrow':{'length':0.6, 'type':22, 'width':0.6}
#--
## if dict format: here can specify them separately, but it don't work directly:
# 'start_arrow':{'length':0.6, 'type':8, 'width':0.6},  
## so must if Arrow - and permute manually:
## dobj.properties[key] = (spk['type'], spk['length'], spk['width'])
## else -- directly as tuple (type, length, width):
'start_arrow':(8, 0.6, 0.6),
'end_arrow':(22, 0.6, 0.6)
}
#--
# BUT, if we: 
## specify arrows directly as tuple (type, length, width):
'start_arrow':(8, 0.6, 0.6),
'end_arrow':(22, 0.6, 0.6)
# and just use for #A3:
	#~ dpk = dobj.properties[key]
	#~ dval = dobj.properties[key].value
	#~ spk = styleProps[key]
	#~ print key, dval, dir(dval), spk
	#~ ## see wrong syntax (#A3) below (was here)
	#~ dpk = spk
# ... assignment fails again! So - MUST handle it separately! 
## NOPE - problem is, we must NEVER assing to the 'replacement' variable dpk - only directly to dobj.properties[key]!!


## see wrong syntax (#A3) notes:
if type(dval) is dia.Arrow:
	#~ dval.length, dval.type, dval.width = spk['length'], spk['type'], spk['width'] # nowork
	#~ dval = (spk['type'], spk['length'], spk['width']) # passes, but no effect
	dobj.properties[key] = (spk['type'], spk['length'], spk['width']) # THIS WORKS!! 
	dobj.properties[key] = spk # THIS WORKS TOO (for spk not dict, but tuple)!! 
	#~ dpk = (spk['type'], spk['length'], spk['width']) # but this doesn't
else:
	dpk = styleProps[key]
... BUT - even with this:
	#~ if type(dval) is dia.Arrow:
		#~ dobj.properties[key] = spk # THIS WORKS!! 
	#~ else:
		#~ dpk = spk
... not all props are correct - so go always with dobj.properties[key] = spk!!!



Log from Dia/Dialogs/Python Console: 

>>> import os
>>> print os.getcwd()
/home/$USER
>>> import sys
>>> print sys.path
['/usr/share/dia/python', '/home/$USER/.dia/python', '/usr/local/lib/python2.6/dist-packages/dot2tex-2.8.7-py2.6.egg', '/usr/local/lib/python2.6/dist-packages/pysvg-0.2.1-py2.6.egg', '/usr/local/lib/python2.6/dist-packages/pycairo-1.8.11-py2.6-linux-i686.egg', '/usr/lib/python2.6', '/usr/lib/python2.6/plat-linux2', '/usr/lib/python2.6/lib-tk', '/usr/lib/python2.6/lib-old', '/usr/lib/python2.6/lib-dynload', '/usr/lib/python2.6/dist-packages', '/usr/lib/python2.6/dist-packages/PIL', '/usr/lib/python2.6/dist-packages/gst-0.10', '/usr/lib/pymodules/python2.6', '/usr/lib/python2.6/dist-packages/gtk-2.0', '/usr/lib/pymodules/python2.6/gtk-2.0', '/usr/lib/python2.6/dist-packages/wx-2.8-gtk2-unicode', '/usr/local/lib/python2.6/dist-packages']

>>> import dia_python
>>> dia_python.dia_objects_center_cb()
Traceback ..
TypeError: dia_objects_center_cb() takes exactly 2 arguments (0 given)
>>> import dia_python
>>> dia_python.genObjects()
AttributeError: 'module' object has no attribute 'genObjects'


>>> print dia
<module 'dia' (built-in)>
>>> print dia
<module 'dia' (built-in)>
>>> print dia.active_display()
/home/$USER/Diagram1.dia
>>> print dia.active_display().diagram
/home/$USER/Diagram1.dia
>>> print dir(dia.active_display().diagram)
['add_update', 'add_update_all', 'connect_after', 'data', 'display', 'displays', 'filename', 'find_clicked_object', 'find_closest_connectionpoint', 'find_closest_handle', 'flush', 'get_sorted_selected', 'get_sorted_selected_remove', 'group_selected', 'is_selected', 'modified', 'remove_all_selected', 'save', 'select', 'selected', 'ungroup_selected', 'unselect', 'update_connections', 'update_extents']
>>> print dir(dia.active_display())
['add_update_all', 'close', 'diagram', 'flush', 'origin', 'resize_canvas', 'scroll', 'scroll_down', 'scroll_left', 'scroll_right', 'scroll_up', 'set_origion', 'set_title', 'visible', 'zoom', 'zoom_factor']
>>> print dir(dia.active_display().diagram.data)
['active_layer', 'add_layer', 'bg_color', 'connect_after', 'delete_layer', 'extents', 'get_sorted_selected', 'grid_visible', 'grid_width', 'hguides', 'layers', 'lower_layer', 'paper', 'raise_layer', 'selected', 'set_active_layer', 'update_extents', 'vguides']
>>> print dir(dia.active_display().diagram.data.active_layer)
['add_object', 'destroy', 'extents', 'find_closest_connection_point', 'find_closest_object', 'find_objects_in_rectangle', 'name', 'object_index', 'objects', 'remove_object', 'update_extents', 'visible']

>>> oType = dia.get_object_type ("UML - Class")
>>> print oType
UML - Class

>>> print dia.active_display().diagram.data.active_layer.objects
>>> print dia.active_display().diagram.data.active_layer.objects[0]
(<DiaObject of type "Standard - Polygon" at b0fff20>,)

>>> alo=dia.active_display().diagram.data.active_layer.objects
>>> print alo[0]
<DiaObject of type "Standard - Line" at 9604118>
>>> sl=alo[0]
>>> dir(sl)
['bounding_box', 'connections', 'copy', 'destroy', 'distance_from', 'handles', 'move', 'move_handle', 'parent', 'properties']
>>> print dir(sl.properties)
['get', 'has_key', 'keys']
>>> for key in sl.properties.keys(): print key, sl.properties.get(key).name, sl.properties.get(key).type, sl.properties.get(key).value, sl.properties.get(key).visible 

obj_pos obj_pos point (0,000000,1,000000) 0
obj_bb obj_bb rect ((-0,212132,0,414590),(3,335410,1,585410)) 0
meta meta dict {} 0
line_width line_width length 0.300000011921 1
line_colour line_colour colour (0,000000,0,000000,0,000000) 1
line_style line_style linestyle (0, 1.0) 1
start_arrow start_arrow arrow (0,500000,0,500000, 8) 1
end_arrow end_arrow arrow (0,500000,0,500000, 22) 1
start_point start_point point (0,000000,1,000000) 0
end_point end_point point (3,000000,1,000000) 0
absolute_start_gap absolute_start_gap real 0.0 1
absolute_end_gap absolute_end_gap real 0.0 1

>>> print sl.properties['obj_pos']
<DiaProperty at 0x92ec680, "obj_pos", point>
>>> print dir(sl.properties['obj_pos'])
['name', 'type', 'value', 'visible']
>>> print sl.properties['obj_pos'].name
obj_pos
>>> print sl.properties['obj_pos'].value
(0,000000,1,000000)

>>> print tline.properties['start_arrow'].length
AttributeError: length
>>> tline.properties['start_arrow'].value['length']
TypeError: 'dia.Arrow' object is unsubscriptable
>>> tline.properties['start_arrow'].value.length
0.5
>>> type(tline.properties['start_arrow'].value)
<type 'dia.Arrow'>
>>> dir(tline.properties['start_arrow'].value)
['length', 'type', 'width']
>>> dia.get_object_type("Arrow/arrow/dia.Arrow")  
KeyError: 'unknown object type'
>>> t = dia.Arrow()
TypeError: cannot create 'dia.Arrow' instances
>>> tarr=tline.properties['start_arrow'].value
>>> print inspect.getmembers(tarr)
[('length', 0.5), ('type', 0), ('width', 0.5)]
>>> print inspect.getmro(dia.Arrow)
(<type 'dia.Arrow'>, <type 'object'>)
>>> print dia.Arrow.__dict__ 
{'__hash__': <slot wrapper '__hash__' of 'dia.Arrow' objects>, '__str__': <slot wrapper '__str__' of 'dia.Arrow' objects>, '__doc__': "Dia's line objects usually ends with an dia.Arrow", '__cmp__': <slot wrapper '__cmp__' of 'dia.Arrow' objects>}
>>> print tarr.__dict__
AttributeError: __dict__
>>> import copy
>>> print copy.copy(tarr)
Error: un(shallow)copyable object of type <type 'dia.Arrow'>
>>> print copy.deepcopy(tarr)
Error: un(deep)copyable object of type <type 'dia.Arrow'>
>>> import pickle
>>> pickle.dumps(tarr)
PicklingError: Can't pickle 'Arrow' object: <dia.Arrow object at 0x9e63320>
>>> print type(tarr) is dia.Arrow
True
>>> print tarr.length
0.5
>>> tarr.length = 0.6
AttributeError: 'dia.Arrow' object has no attribute 'length'

from changelog 2009-03-08 (ends in 2009-04-21, from  dia-0.97.tar.gz 03-May-2009 / dia-0.97-pre3 update listed on 2009-04-13) ;;; 
	* plug-ins/python/pydia-property.c : implement PyDia_set_Arrow() to
	allow modification of line ends from python scripts, like:
			o.properties["start_arrow"] = (17, .5, .5)
* I have 0.97.1 - dia website says: dia-0.97-pre3.tar.gz 13-Apr-2009; dia-0.97.1.tar.gz  24-Jan-2010; LATEST-IS-0.97.1... 


# note:
http://stackoverflow.com/questions/623520/why-cant-i-directly-add-attributes-to-any-python-object
>>> bz = object()
>>> bz.length=0.5
AttributeError: 'object' object has no attribute 'length'
>>> setattr(bz,'length',0.5)
AttributeError: 'object' object has no attribute 'length'

# text
>>> print tp.properties['text'].value.text
ewfdsd
>>> tp.properties['text'].value.text = "dsfsdf"
TypeError: 'dia.Text' object has only read-only attributes (assign to .text)
>>> tp.properties['text'].text = "dsfsdf"
TypeError: 'dia.Property' object has only read-only attributes (assign to .text)
>>> tp.text = "dsfsdf"
TypeError: 'dia.Object' object has only read-only attributes (assign to .text)
>>> 
>>> tp.properties['text'] = "dsfsdf"
# ok
>>> tp.properties['text_font'].value.family
'sans'
>>> tp.properties['text_font'].value.name
'Helvetica'
>>> tp.properties['text_font'].value.style
0
>>> dir(tp.properties['text_font'])
['name', 'type', 'value', 'visible']
>>> dir(tp.properties['text_font'].value)
['family', 'name', 'style']
>>> type(tp.properties['text_font'].value)
<type 'dia.Font'>
>>> tpfv=tp.properties['text_font'].value
>>> tpfv['style']=1
TypeError: 'dia.Font' object does not support item assignment
>>> inspect.getmembers(tpfv)
[('family', 'sans'), ('name', 'Helvetica'), ('style', 0)]

>>> tp.properties.get("text_font")
<dia.Property object at 0xb71f56d0>
>>> tp.properties["text_font"]
<dia.Property object at 0xb71f56d0>

>>> print tpfv ###
sans normal normal
>>> type(tpfv)
<type 'dia.Font'>
>>> tpfv.family
'sans'
>>> dir(tpfv)
['family', 'name', 'style']
>>> tpfv.name
'Helvetica'
>>> tpfv.style
0

** (dia:16800): DEBUG: Setter for 'font' not implemented.
** (dia:16800): DEBUG: PyDiaProperty_ApplyToObject : no conversion text_font -> font

Ahm: dia-0.97.1/plug-ins/python/pydia-property.c

} prop_type_map [] =
{
  { PROP_TYPE_CHAR, PyDia_get_Char },						<+++ NO 
  { PROP_TYPE_BOOL, PyDia_get_Bool, PyDia_set_Bool },
  { PROP_TYPE_INT,  PyDia_get_Int, PyDia_set_Int },
  { PROP_TYPE_INTARRAY, PyDia_get_IntArray, PyDia_set_IntArray },
  { PROP_TYPE_ENUM, PyDia_get_Enum, PyDia_set_Enum },
  { PROP_TYPE_ENUMARRAY, PyDia_get_IntArray, PyDia_set_IntArray }, /* Enum == Int */
  { PROP_TYPE_LINESTYLE, PyDia_get_LineStyle, PyDia_set_LineStyle },
  { PROP_TYPE_REAL, PyDia_get_Real, PyDia_set_Real },
  { PROP_TYPE_LENGTH, PyDia_get_Length, PyDia_set_Length },
  { PROP_TYPE_FONTSIZE, PyDia_get_Fontsize, PyDia_set_Fontsize },
  { PROP_TYPE_STRING, PyDia_get_String, PyDia_set_String },
  { PROP_TYPE_STRINGLIST, PyDia_get_StringList },			<+++ NO 
  { PROP_TYPE_FILE, PyDia_get_String, PyDia_set_String },
  { PROP_TYPE_MULTISTRING, PyDia_get_String },				<+++ NO 
  { PROP_TYPE_TEXT, PyDia_get_Text, PyDia_set_Text },
  { PROP_TYPE_POINT, PyDia_get_Point, PyDia_set_Point },
  { PROP_TYPE_POINTARRAY, PyDia_get_PointArray, PyDia_set_PointArray },
  { PROP_TYPE_BEZPOINT, PyDia_get_BezPoint },				<+++ NO 
  { PROP_TYPE_BEZPOINTARRAY, PyDia_get_BezPointArray, PyDia_set_BezPointArray },
  { PROP_TYPE_RECT, PyDia_get_Rect, PyDia_set_Rect },
  { PROP_TYPE_ARROW, PyDia_get_Arrow, PyDia_set_Arrow },
  { PROP_TYPE_COLOUR, PyDia_get_Color, PyDia_set_Color },
  { PROP_TYPE_FONT, PyDia_get_Font }, 						<+++ NO 
  { PROP_TYPE_SARRAY, PyDia_get_Array, PyDia_set_Array },
  { PROP_TYPE_DARRAY, PyDia_get_Array, PyDia_set_Array },
  { PROP_TYPE_DICT, PyDia_get_Dict, PyDia_set_Dict }
};



"""

