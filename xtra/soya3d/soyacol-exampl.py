# -*- indent-tabs-mode: t -*-

INTRO = """
  You can also use Box Geometry for collision with GeomBox object
  NOTE: the actual sword model (blender) can be found in, e.g.:
  http://download.gna.org/soya/Soya-0.14rc1.tar.bz2
  (there is no direct download link for models)
  ...
  also, to generate material bitmap, note:
  "ValueError: Image dimensions must be power of 2 (dimensions are 150 x 150)" ... so use:
  convert -size 128x128 xc:white -pointsize 72 -draw "text 25,60 'test'" test.png
  ...
  NOTE: Under Ubuntu, if there is no explicit exit handler; window cannot be closed, unless by "Force Quit" button/kill!
"""

import sys, os
import soya
import soya.sphere, soya.cube

#evil hack

soya.init("ode-collision-9-box",width=800,height=600)
soya.path.append(os.path.join(os.path.dirname(sys.argv[0]), "data"))
# sys.argv[0] - just name; sys.path[0] - directory of script
# BUT - dirname cuts the final word - even if it is a directory name!
#  so - don't use dirname with sys.path[0]!
# but ANYWAYS, soya wants to read from path/images directory only!
# AND: ValueError: Image dimensions must be power of 2 (dimensions are 150 x 150)
print("AAA", os.path.dirname("./" + sys.argv[0]), sys.path[0], sys.argv)
soya.path.append(sys.path[0]+"/") #soya.path.append(os.path.dirname(sys.path[0]))
print(soya.path)

print INTRO

# create world
scene = soya.World()
# getting material
ground = soya.Material(soya.Image.get("/home/administrator/Desktop/test.png"))
metal  = soya.Material(soya.Image.get("test.png"))
cube_mat   = soya.Material(soya.Image.get("test.png"))
#blue_mat.separate_specular = 1
# creating Model
m_ball = soya.sphere.Sphere(None,metal).shapify()
m_cube = soya.cube.Cube(None, cube_mat,size=3).shapify()
m_ground = soya.cube.Cube(None, ground,size=78).shapify()
#creating Body
ground = soya.Body(scene,m_ground)
ball   = soya.Body(scene,m_ball)
cubes = []
for i in xrange(15):
	cubes.append(soya.Body(scene,m_cube))
## Adding a mass ##
ball_density = 50
ground.pushable = False
ground.gravity_mode = False
ground.mass     = soya.SphericalMass(1)
ball.mass       =soya.SphericalMass(ball_density)
for cube in cubes:
	cube.mass =soya.BoxedMass(0.01, 3, 3, 3)
scene.gravity = soya.Vector(scene,0,-9.8,0)
#Adding Geom
ball.bounciness = 1
soya.GeomSphere(ball)
for cube in cubes:
	soya.GeomBox(cube,(3,3,3))
soya.GeomBox(ground,(78,78,78))


######
#placing bodys
ground.y-= 39
ball.z   = 10
ball.y   = 0.6
ball.x   = -1

cubes[0].set_xyz(   0,14.0,0)
cubes[1].set_xyz(-1.6, 10.90,0)
cubes[2].set_xyz( 1.6, 10.90,0)
cubes[3].set_xyz(-3.2, 7.80,0)
cubes[4].set_xyz(   0, 7.80,0)
cubes[5].set_xyz( 3.2, 7.80,0)
cubes[6].set_xyz(-4.8, 4.70,0)
cubes[7].set_xyz(-1.6, 4.70,0)
cubes[8].set_xyz( 1.6, 4.70,0)
cubes[9].set_xyz( 4.8, 4.70,0)
cubes[10].set_xyz(-6.4,1.60,0)
cubes[11].set_xyz(-3.2,1.60,0)
cubes[12].set_xyz(   0,1.60,0)
cubes[13].set_xyz( 3.2,1.60,0)
cubes[14].set_xyz( 6.4,1.60,0)



ball.add_force(soya.Vector(scene,ball_density*-50,0,ball_density*-2500))

#placing light over the duel
light = soya.Light(scene)
light.set_xyz(-10, 45,45)
# adding camera
camera = soya.Camera(scene)
camera.set_xyz(13,15,30)
camera.look_at(cubes[4])
camera.back=300
#running soya
soya.set_root_widget(camera)
ml = soya.MainLoop(scene)
ml.main_loop()
"""

"""
#!python
# -*- indent-tabs-mode: t -*-

import sys, os

import soya
from soya import Vector


soya.init("first ODE test",width=1024,height=768)

soya.path.append(os.path.join(os.path.dirname(sys.argv[0]), "data"))


#create world

ode_world = soya.World()
#scene = ode_world
scene = soya.World(ode_world)
#activate ODE support



#~ sword_model = soya.Model.get("sword")
sword_model = soya.cube.Cube(None, soya.DEFAULT_MATERIAL,size=10).model
print dir(sword_model)
sword = soya.Body(scene,sword_model)
sword.ode = True
sword.x = 1.0
sword.z = -5

sword2 = soya.Body(scene,sword_model)
sword2.ode = True
sword2.x = 1.0
sword2.z = -3

blade = soya.BoxedMass(0.05,50,5,1)
pommeau = soya.SphericalMass(10,0.5)
pommeau.translate((2,0,0))
sword.mass = blade+pommeau

blade2 = soya.BoxedMass(0.015,50,5,1)
blade2.translate((1,0,0))
sword2.mass = blade2

joint1 = soya.HingeJoint(sword2)
joint2 = soya.HingeJoint(sword,sword2)



def v (x,y,z):
	return soya.Vector(sword,x,y,z)
sword2.add_force(v(-10,50,0),v(2,0.01,0.02))
sword.add_force(v(10,50,0),v(2,0.01,0.02))


light = soya.Light(scene)
light.set_xyz(0, 0, 15)

camera = soya.Camera(scene)
camera.set_xyz(10,1,2)
camera.look_at(sword)
camera.rotate_y(50)
camera.rotate_x(10)


scene.set_xyz(0.5,0.5,-5)

ode_world.gravity = Vector(ode_world,0,-5,0)
soya.set_root_widget(camera)
ml = soya.MainLoop(ode_world)
ml.main_loop()




