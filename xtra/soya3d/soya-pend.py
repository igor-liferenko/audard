# -*- indent-tabs-mode: t -*-


import sys, os
import soya
import soya.sphere, soya.cube
import soya.ray
import soya.laser
import soya.gui
import soya.widget
import soya.sdlconst as sdlconst


from soya       import PythonCoordSyst, Point, Vector, DEFAULT_MATERIAL
from soya.opengl import *

# too slow to capture realtime video
# recordmydesktop --no-sound --fps 30 --windowid $(xwininfo | awk '/Window id:/ {print $4}')
grabScreens = False
frNum = 0

pauseState = 0

class LineLazer(PythonCoordSyst):
  def __init__(self, parent = None, color = (1.0, 0.0, 0.0, 1.0), endp=(0,0,1)):
    PythonCoordSyst.__init__(self, parent)
    # instead of startp, we have the 'position'
    self.color   = color
    self.endp    = endp
    self.points  = []

  def batch(self):
    if self.color[3] < 1.0: return 2, self, None
    else:                   return 1, self, None

  def render(self):
    global scene
    self.points = []
    #list containing points
    to_draw = []
    pos   = self.position()
    #~ direc = Vector(self, 0.0, 0.0, -1.0)
    #~ pos   = pos + (direc * 32000.0)
    # if it is endp(oint), then you want to set
    #  it explicitly = do not do pos+Vector!
    #~ to_draw.append(pos+Vector(self, self.endp[0], self.endp[1], self.endp[2]) )
    # AND, in reference to scene, not self!
    to_draw.append(Vector(scene, self.endp[0], self.endp[1], self.endp[2]) )

    #rendering part
    DEFAULT_MATERIAL.activate()
    glDisable(GL_TEXTURE_2D)
    glDisable(GL_LIGHTING)

    glColor4f(*self.color)
    glBegin(GL_LINE_STRIP)
    glVertex3f(0.0, 0.0, 0.0) # at position
    for pos in to_draw:
      glVertex3f(*self.transform_point(pos.x, pos.y, pos.z, pos.parent))

    glEnd()

    glEnable(GL_LIGHTING)
    glEnable(GL_TEXTURE_2D)



class TimedWorld(soya.World):
  def __init__(self):
    soya.World.__init__(self)
    # self.speed = soya.Vector(self, 0.0, 0.0, -0.2)
    self.left_key_down = self.right_key_down = self.up_key_down = self.down_key_down = 0
    self.j1f = self.dj1fp = self.j2f = 0
    self.bp = 0
    self.coordViewState = self.coordMpState = 0
  # Like advance_time, begin_round is called by the main_loop.
  # But contrary to advance_time, begin_round is called regularly, at the beginning of each
  # round ; thus it receive no 'proportion' argument.
  # Decision process should occurs in begin_round.

  def bumpCoordViewState(self):
    self.coordViewState += 1
    if self.coordViewState >= 4:
      self.coordViewState = 0

  def bumpRenderMpCoords(self):
    self.coordMpState += 1
    if self.coordMpState >= 2:
      self.coordMpState = 0

  def bumpPauseState(self):
    global pauseState
    pauseState += 1
    if pauseState >= 2:
      pauseState = 0

  def next(self):
    #Returns the next action
    for event in soya.MAIN_LOOP.events:
      if   event[0] == sdlconst.KEYDOWN:
        if   (event[1] == sdlconst.K_q) or (event[1] == sdlconst.K_ESCAPE):
          sys.exit() # Quit the game
        elif event[1] == sdlconst.K_LEFT:  self.left_key_down  = 1
        elif event[1] == sdlconst.K_RIGHT: self.right_key_down = 1
        elif event[1] == sdlconst.K_UP:    self.up_key_down    = 1
        elif event[1] == sdlconst.K_DOWN:  self.down_key_down  = 1
        elif event[1] == sdlconst.K_a:     self.bumpCoordViewState()
        elif event[1] == sdlconst.K_z:     self.bumpRenderMpCoords()
        elif event[1] == sdlconst.K_p:     self.bumpPauseState()

      elif event[0] == sdlconst.KEYUP:
        if   event[1] == sdlconst.K_LEFT:  self.left_key_down  = 0
        elif event[1] == sdlconst.K_RIGHT: self.right_key_down = 0
        elif event[1] == sdlconst.K_UP:    self.up_key_down    = 0
        elif event[1] == sdlconst.K_DOWN:  self.down_key_down  = 0

  def vecProjectionAontoB(self,A,B):
    #~ print(A,B)
    normB=B.copy()
    normB.normalize() # unit vector, IN PLACE (must separately)
    AdotnormB = A.dot_product(normB)
    C=normB.__mul__(AdotnormB)
    return C

  def begin_round(self):
    global j1,j2, pend, scene, pole, ball, grabScreens, frNum
    global pauseState
    damping = 0.1

    if (pauseState == 1):
      self.next()
      return

    # Calls the super implementation.
    soya.World.begin_round(self)
    #~ print(j1.getFeedback(), "#", j2.getFeedback()) # (force1, torque1, force2, torque2) : ((0.0, 332.9216613769531, -257.0126647949219), (180.77870178222656, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)) ..... (((0.0, 426.10772705078125, -1055.581298828125), (-5704.71435546875, 0.0, 0.0), (1.1854985008187952e-42, 2.312142466135948e-43, 9.164491956684304e-43), (1.4461400151832112e-42, 7.777206477002735e-43, 7.903323338791968e-43)), '#', ((0.0, 173.71861267089844, -6280.154296875), (-96.6642074584961, 0.0, 0.0), (0.0, -173.71861267089844, 6280.154296875), (-504.1296081542969, 0.0, 0.0)))

    self.j1f = j1.getFeedback()
    self.j2f = j2.getFeedback()
    frc1 = self.j2f[0]#[0]
    # note - vector should be referenced to scene, NOT pend,
    #   for the damping to work!
    dampvect = Vector(scene, -damping*frc1[0],-damping*frc1[1],-damping*frc1[2])
    pend.add_force(dampvect)
    #~ j1fp = j1.getFeedback() # same as j1f
    #~ print(frc1, "#", j1fp[0])
    self.dj1fp = Vector(scene, frc1[0], frc1[1], frc1[2]) + dampvect
    #~ print(frc1, "#", self.dj1fp)

    #~ print(bp)
    #~ frep=bp+0.1*self.dj1fp # float required; no parse
    #~ frep=bp.add_mul_vector(0.1, self.dj1fp) # awful
    #~ frep=bp+self.dj1fp.__mul__(0.000001) # ??
    #~ frep=Vector(ball,0,0,2) # ref to ball don't seem to matter!
    # AH - for these kind of transform with convert_to, should have Point, not Vector!
    # frcpball coord syst: 2 units in each direction, moved 1 unit along x so as not to be hidden by ball
    movx=0
    if (self.coordViewState == 0):
      self.bp=ball.position().add_vector(soya.Vector(ball,movx,0,0))
      self.bp1=self.bp
      self.bp2=self.bp1
    if (self.coordViewState == 1):
      movx=1
      self.bp=ball.position().add_vector(soya.Vector(ball,movx,0,0))
      self.bp1=self.bp
      self.bp2=self.bp1
    elif (self.coordViewState == 2):
      movx=1
      self.bp=ball.position().add_vector(soya.Vector(ball,movx,0,0))
      self.bp1=ball.position().add_vector(soya.Vector(ball,2,0,1))
      self.bp2=self.bp1
    elif (self.coordViewState == 3):
      movx=1
      self.bp=ball.position().add_vector(soya.Vector(ball,movx,0,0))
      self.bp1=ball.position().add_vector(soya.Vector(ball,2,0,1))
      self.bp2=ball.position().add_vector(soya.Vector(ball,3,0,2))

    self.bp1b = self.bp1.copy().add_vector(soya.Vector(ball,-0.5,0,0))

    self.frepx=Point(ball,2+movx,0,0)
    self.frepy=Point(ball,movx  ,2,0)
    self.frepz=Point(ball,movx  ,0,2)
    self.frepx.convert_to(scene)
    self.frepy.convert_to(scene)
    self.frepz.convert_to(scene)

    # scaled so they're approx the same
    scale_grav = scene.gravity.__mul__(0.5)
    scale_dfor = self.dj1fp.__mul__(0.03)
    self.epg=self.bp1+scale_grav
    self.epfor=self.bp2+scale_dfor

    tp=Vector(ball,2,0,0) # convert_to must go separate! can be vector
    tp.convert_to(scene) # IN PLACE
    grav_lx=self.vecProjectionAontoB(scale_grav, tp)
    tp=Vector(ball,0,2,0) ; tp.convert_to(scene)
    grav_ly=self.vecProjectionAontoB(scale_grav, tp)
    tp=Vector(ball,0,0,2) ; tp.convert_to(scene)
    grav_lz=self.vecProjectionAontoB(scale_grav, tp)
    self.epgx=self.bp1+grav_lx
    self.epgy=self.bp1+grav_ly
    self.epgz=self.bp1+grav_lz

    tp=Vector(ball,2,0,0) ; tp.convert_to(scene)
    dfor_lx=self.vecProjectionAontoB(scale_dfor, tp)
    tp=Vector(ball,0,2,0) ; tp.convert_to(scene)
    dfor_ly=self.vecProjectionAontoB(scale_dfor, tp)
    tp=Vector(ball,0,0,2) ; tp.convert_to(scene)
    dfor_lz=self.vecProjectionAontoB(scale_dfor, tp)
    self.epforx=self.bp2+dfor_lx
    self.epfory=self.bp2+dfor_ly
    self.epforz=self.bp2+dfor_lz

    tp=Vector(scene,2,0,0)
    grav_lz_mx = self.vecProjectionAontoB(grav_lz, tp)
    tp=Vector(scene,0,2,0)
    grav_lz_my = self.vecProjectionAontoB(grav_lz, tp)
    tp=Vector(scene,0,0,2)
    grav_lz_mz = self.vecProjectionAontoB(grav_lz, tp)
    self.epglzx=self.bp1b+grav_lz_mx
    self.epglzy=self.bp1b+grav_lz_my
    self.epglzz=self.bp1b+grav_lz_mz

    if (grabScreens):
      frNum += 1
      tfname = "/dev/shm/soya-pend%05d.png" % (frNum)
      soya.screenshot(filename = tfname, use_back_buffer=False)

    #~ print(ball.position())
    # Computes the new rotation speed: a random angle between -25.0 and 25.0 degrees.
    #~ self.rotation_speed = random.uniform(-25.0, 25.0)
    # The speed vector doesn't need to be recomputed, since it is expressed in the Head
    # CoordSyst.


  def advance_time(self, proportion):
    global z_ax_glob, camera, v_orig, scene, pole, ball
    global frcpball, vecgrav, vecfor, vecgravlp, vecforlp, vecgravlzMp
    global pauseState
    yrotaxVect = soya.Vector(scene,0,1,0)

    if (pauseState == 1):
      self.next()
      return

    # Calls the super implementation of advance_time.
    soya.World.advance_time(self, proportion)

    frcpball[0].set_xyz(self.bp.x, self.bp.y, self.bp.z)
    frcpball[0].endp=(self.frepx.x, self.frepx.y, self.frepx.z)
    frcpball[1].set_xyz(self.bp.x, self.bp.y, self.bp.z)
    frcpball[1].endp=(self.frepy.x, self.frepy.y, self.frepy.z)
    frcpball[2].set_xyz(self.bp.x, self.bp.y, self.bp.z)
    frcpball[2].endp=(self.frepz.x, self.frepz.y, self.frepz.z)

    vecgrav.set_xyz(self.bp1.x, self.bp1.y, self.bp1.z)
    vecgrav.endp=(self.epg.x, self.epg.y, self.epg.z)

    vecfor.set_xyz(self.bp2.x, self.bp2.y, self.bp2.z)
    vecfor.endp=(self.epfor.x, self.epfor.y, self.epfor.z)

    vecgravlp[0].set_xyz(self.bp1.x, self.bp1.y, self.bp1.z)
    vecgravlp[0].endp=(self.epgx.x, self.epgx.y, self.epgx.z)
    vecgravlp[1].set_xyz(self.bp1.x, self.bp1.y, self.bp1.z)
    vecgravlp[1].endp=(self.epgy.x, self.epgy.y, self.epgy.z)
    vecgravlp[2].set_xyz(self.bp1.x, self.bp1.y, self.bp1.z)
    vecgravlp[2].endp=(self.epgz.x, self.epgz.y, self.epgz.z)

    vecforlp[0].set_xyz(self.bp2.x, self.bp2.y, self.bp2.z)
    vecforlp[0].endp=(self.epforx.x, self.epforx.y, self.epforx.z)
    vecforlp[1].set_xyz(self.bp2.x, self.bp2.y, self.bp2.z)
    vecforlp[1].endp=(self.epfory.x, self.epfory.y, self.epfory.z)
    vecforlp[2].set_xyz(self.bp2.x, self.bp2.y, self.bp2.z)
    vecforlp[2].endp=(self.epforz.x, self.epforz.y, self.epforz.z)

    if (self.coordMpState == 1):
      vecgravlzMp[0].visible = 1
      vecgravlzMp[1].visible = 1
      vecgravlzMp[2].visible = 1
      vecgravlzMp[0].set_xyz(self.bp1b.x, self.bp1b.y, self.bp1b.z)
      vecgravlzMp[0].endp=(self.epglzx.x, self.epglzx.y, self.epglzx.z)
      vecgravlzMp[1].set_xyz(self.bp1b.x, self.bp1b.y, self.bp1b.z)
      vecgravlzMp[1].endp=(self.epglzy.x, self.epglzy.y, self.epglzy.z)
      vecgravlzMp[2].set_xyz(self.bp1b.x, self.bp1b.y, self.bp1b.z)
      vecgravlzMp[2].endp=(self.epglzz.x, self.epglzz.y, self.epglzz.z)
    elif (self.coordMpState == 0):
      vecgravlzMp[0].visible = 0
      vecgravlzMp[1].visible = 0
      vecgravlzMp[2].visible = 0


    # Rotates the object around Y axis.
    #~ self.rotate_y(proportion * 2.0)
    #~ z_ax_glob.x += proportion*0.1;
    #~ camera.rotate_z(proportion)
    # rotate_axis - vector via 0,0,0; but local
    # rotate is ok - around a point; not even look_at needed!
    self.next()
    if (self.right_key_down):
      camera.rotate(proportion, Point(scene, 0,0,0), yrotaxVect)
      camera.look_at(pole) #(v_orig)
    elif (self.left_key_down):
      camera.rotate(-proportion, Point(scene, 0,0,0), yrotaxVect)
      camera.look_at(pole) #(v_orig)
    elif (self.up_key_down): # translate
      camera.add_mul_vector(0.5*proportion, Vector(camera, 0,0,-1))
      camera.look_at(pole) #(v_orig)
    elif (self.down_key_down): # translate
      camera.add_mul_vector(0.5*proportion, Vector(camera, 0,0,1))
      camera.look_at(pole) #(v_orig)



def GetMaterials():
  global blue_mat, gnd_mat, wht_mat
  # Creates the material
  blue_mat = soya.Material()

  # 0.0 is the most metallic / shiny, and 128.0 is the most plastic.
  blue_mat.shininess = 0.5

  # Sets the material's diffuse color. The diffuse color is the basic color.
  # In Soya 3D, colors are tuples of 4 floats: (red, green, blue, alpha),
  blue_mat.diffuse   = (0.0, 0.2, 0.7, 1.0)

  # The specular color is the one used for the specular / shiny effects.
  blue_mat.specular  = (0.2, 0.7, 1.0, 1.0)

  # Activates the separate specular. This results in a brighter specular effect.
  blue_mat.separate_specular = 1

  gnd_mat = soya.Material()
  gnd_mat.shininess = 0.5
  gnd_mat.diffuse   = (0.25, 0.2, 0.1, 1.0)
  gnd_mat.specular  = (0.25, 0.2, 0.1, 1.0)

  wht_mat = soya.Material()
  wht_mat.shininess = 0.5
  wht_mat.diffuse   = (0.5, 0.5, 0.5, 0.99)
  wht_mat.specular  = (0.5, 0.5, 0.5, 0.99)


def GetMainCoordSystemLazers():
  global x_ax_glob, y_ax_glob, z_ax_glob
  #~ Provide a Ray -- a line that draw a fading trace behind it when it moves.
  #~ Rays are usually used for sword or reactor. The line starts at the ray position and ends at "endpoint"
  # ray just blinks on change - laser is the line
  #~ ray = soya.ray.Ray(m_ground, length = 20)
  #~ ray.z = -0.2
  #~ ray.endpoint = soya.Point(ball)
  #~ ray.material = blue_mat

  # only ends when bumps into an object
  #~ lazr = soya.laser.Laser(parent=scene, color=(1.0, 0.0, 0.0, 1.0), reflect=0, collide=False, max_reflect=50)
  #~ lazr.set_xyz(0,0,0)

  # NOTE: this is xz coord system, with y going up (XZY), not XYZ!
  x_ax_glob = LineLazer(parent=scene, color=(1.0, 0.0, 0.0, 1.0), endp=(10,0,0))
  x_ax_glob.set_xyz(0,0,0)
  y_ax_glob = LineLazer(parent=scene, color=(0.0, 1.0, 0.0, 1.0), endp=(0,10,0))
  y_ax_glob.set_xyz(0,0,0)
  z_ax_glob = LineLazer(parent=scene, color=(0.0, 0.0, 1.0, 1.0), endp=(0,0,10))
  z_ax_glob.set_xyz(0,0,0)

def getCoordLazers():
  # here get the other coord LAZAHS!1!
  global frcpball, vecgrav, vecfor, vecgravlp, vecforlp, vecgravlzMp
  frcpball = []
  frcpball.append(LineLazer(parent=scene, color=(1.0, 0.0, 1.0, 1.0), endp=(0,0,0))) #x
  frcpball.append(LineLazer(parent=scene, color=(1.0, 0.0, 1.0, 1.0), endp=(0,0,0))) #y
  frcpball.append(LineLazer(parent=scene, color=(1.0, 0.0, 1.0, 1.0), endp=(0,0,0))) #z
  frcpball[0].set_xyz(0,0,0)
  frcpball[1].set_xyz(0,0,0)
  frcpball[2].set_xyz(0,0,0)

  vecgrav=LineLazer(parent=scene, color=(1.0, 1.0, 1.0, 1.0), endp=(0,0,0))
  vecgrav.set_xyz(0,0,0)
  vecfor=LineLazer(parent=scene, color=(0.0, 1.0, 1.0, 1.0), endp=(0,0,0))
  vecfor.set_xyz(0,0,0)

  vecgravlp = []
  pcol=(0.8, 0.8, 0.8, 1.0)
  vecgravlp.append(LineLazer(parent=scene, color=pcol, endp=(0,0,0))) #x
  vecgravlp.append(LineLazer(parent=scene, color=pcol, endp=(0,0,0))) #y
  vecgravlp.append(LineLazer(parent=scene, color=pcol, endp=(0,0,0))) #z
  vecgravlp[0].set_xyz(0,0,0)
  vecgravlp[1].set_xyz(0,0,0)
  vecgravlp[2].set_xyz(0,0,0)

  vecforlp = []
  pcol=(0.0, 0.8, 0.8, 1.0)
  vecforlp.append(LineLazer(parent=scene, color=pcol, endp=(0,0,0))) #x
  vecforlp.append(LineLazer(parent=scene, color=pcol, endp=(0,0,0))) #y
  vecforlp.append(LineLazer(parent=scene, color=pcol, endp=(0,0,0))) #z
  vecforlp[0].set_xyz(0,0,0)
  vecforlp[1].set_xyz(0,0,0)
  vecforlp[2].set_xyz(0,0,0)

  vecgravlzMp = []
  vecgravlzMp.append(LineLazer(parent=scene, color=(1.0, 0.0, 0.0, 0.8), endp=(0,0,0))) #x
  vecgravlzMp.append(LineLazer(parent=scene, color=(0.0, 1.0, 0.0, 0.8), endp=(0,0,0))) #y
  vecgravlzMp.append(LineLazer(parent=scene, color=(0.0, 0.0, 1.0, 0.8), endp=(0,0,0))) #z
  vecgravlzMp[0].set_xyz(0,0,0)
  vecgravlzMp[1].set_xyz(0,0,0)
  vecgravlzMp[2].set_xyz(0,0,0)



def SetWindowOverlay():
  global root, camera, window, table, layer
  soya.gui.CameraViewport(root, camera)
  window = soya.gui.Window(root, u"Soya3D GUI demo", #: window over camera",
    closable = 0)
  window.move(0,0)
  table = soya.gui.VTable(window)
  soya.gui.CancelButton(table, u"Quit", on_clicked = sys.exit)
  layer = soya.gui.Layer(root)
  soya.gui.FPSLabel(layer)

def SetLight():
  global light, scene
  #placing light over the duel
  light = soya.Light(scene)
  #~ light.set_xyz(-10, 45,45)
  light.set_xyz(2, 100, 2)
  #~ light.directional=True #like the sun; BUT The position of a directional light doesn't matter
  light.cast_shadow = 1
  light.shadow_color = (0.0, 0.0, 0.0, 0.5)
  light2 = soya.Light(scene)
  #~ light.set_xyz(-10, 45,45)
  light2.set_xyz(20, 15, -4)
  light2.cast_shadow = 0
  light2.constant = 0.0
  light2.linear = 0.5
  light2.diffuse = (0.7, 0.7, 0.7, 1.0)
  #~ light2.shadow_color = (0.0, 0.0, 0.0, 0.5)


def SetCamera():
  global camera, scene, pole
  # adding camera
  camera = soya.Camera(scene)
  camera.set_xyz(25,15,0)#(15,15,30)
  camera.partial = 1
  #~ camera.rotate_z(180)
  camera.look_at(pole)#(v_orig)
  #~ camera.back=300


################## MAIN

#evil hack

# Initializes Soya (creates and displays the 3D window).
soya.init("soya-pend",width=600,height=480)

soya.path.append(os.path.join(os.path.dirname(sys.argv[0]), "data"))
# careful: sys.path instead of sys.argv - and hack to avoid images subdir only
soya.path.append(sys.path[0]) #soya.path.append(os.path.dirname(sys.path[0]))
print(soya.path)

# for window overlay
root  = soya.gui.RootLayer(None)


# Creates a simple model model_builder object. (that does  include shadows).
model_builder = soya.SimpleModelBuilder()

# Sets the 'shadow' model_builder property to true.
model_builder.shadow = 1


# create world - main scene
scene = TimedWorld() #soya.World()

# Set up an atmosphere, so as the background is gray
scene.atmosphere = soya.Atmosphere()
scene.atmosphere.bg_color = (0.4, 0.4, 0.4, 1.0)

v_orig=Point(scene, 0, 0, 0) # this is better ?! Yes - the previous one w/ Vector does not refer to the right point!


GetMaterials()
GetMainCoordSystemLazers()
getCoordLazers()


# creating Models
m_ground = soya.cube.Cube(None, gnd_mat,size=78)

m_pole = soya.World()
m_pole1 = soya.cube.Cube(m_pole, wht_mat,size=1)
m_pole2 = soya.cube.Cube(m_pole, wht_mat,size=1)
m_pole1.scale(1,10,1)
m_pole2.scale(2,1,1)
m_pole1.set_xyz(0,0,0)
m_pole2.set_xyz(0.5,4.5,0)

m_ball = soya.sphere.Sphere(None,blue_mat)
m_ball.scale(0.6,0.2,1) # flatten like ellipsoid a bit

m_pend = soya.World()
m_arm = soya.cube.Cube(m_pend, wht_mat,size=1)
m_arm.scale(0.2,5,0.2)

hsz=0.2
m_hing = soya.sphere.Sphere(None,wht_mat)
m_hing.scale(hsz,hsz,hsz)

# Assigns the model_builder to the models (ball).
m_ball.model_builder = model_builder
m_pole.model_builder = model_builder

# Compiles the models (ball) model to a shadowed model.
ball_model = m_ball.to_model()
pole_model = m_pole.to_model()

m_ball_s = m_ball.shapify() # no need to shapify the ball_model - just the above is enough for casting shadows; and can keep m_ball here!
m_ground_s = m_ground.shapify()
m_pole_s = m_pole.shapify()
m_pend_s = m_pend.shapify()
m_hing_s = m_hing.shapify()

#creating Body
ground = soya.Body(scene,m_ground_s)
pole   = soya.Body(scene,m_pole_s)
pend   = soya.Body(scene,m_pend_s)
ball   = soya.Body(scene,m_ball_s) # dissapears w m_pend parent; unless it is parent during instant: 'Sphere(m_pole' (in which case, scene as parent here will double the object)
# however, that kind of parenting doesn't help with ode! the ball will simply stay still, while pendulum will move .. so must add joint - and  with m_pend parent: RuntimeError: two body must be into the same world to be jointed
hing   = soya.Body(scene,m_hing_s)

# set shadows
ball.shadow = 1 # enable shadow
pole.shadow = 1 # enable shadow
ground.shadow = 1 # enable shadow

# set up for collisions:
# GeomSphere/GeomBox must be there for collisions!
ball.bounciness = 1
soya.GeomSphere(ball)
soya.GeomBox(ground,(78,78,78))
#~ soya.GeomBox(pole, (1.5,10,1)) # this one, for some reason, seems too wide? prevented the pendulum #~ soya.GeomBox(m_pole1) # does nothing
soya.GeomBox(pole) #~ soya.GeomBox(m_pole1) # does nothing

# set masses - also for hinges
ball_density = 50

ground.mass     = soya.SphericalMass(1)
ball.mass       = soya.SphericalMass(20,0.6)
hing.mass       = soya.SphericalMass(1,hsz) #

# adding the hinge masses stabilises hinging - even without them being placed (transl) specifically anywhere?!
pole_mass_main = soya.BoxedMass(100,1,10,1)
pend_mass_main = soya.BoxedMass(5,0.2,5,0.2)
pole_mass_hinge = soya.SphericalMass(1)
pend_mass_hinge = soya.SphericalMass(3,1)
pend_mass_hinge2 = soya.SphericalMass(3,1)
# sizes 10,5 - so half of size translate, for correct!
pole_mass_hinge.translate((1.1,4.2,0))
pend_mass_hinge.translate((0,2.5,0))
pend_mass_hinge2.translate((0,-2.5,0))
pole.mass       = pole_mass_main + pole_mass_hinge
pend.mass       = pend_mass_main + pend_mass_hinge + pend_mass_hinge2

# set gravity
scene.gravity = soya.Vector(scene,0,-9.8,0)
pole.ode = True
pend.ode = True
hing.ode = True
ball.ode = True


######
#placing bodys
# note: #~ pole.translate((0,-1,0)) # Body' object has no attribute 'translate
# also note - if body enters hinge point, it starts to "oscillate"
# actually that seems to happen due collision?

hgxpos = 3.5
ground.set_xyz(0,-40,0)   #~ ground.y-= 39; push down (y axis) else we're probably inside this cube :)
ball.x   = hgxpos
ball.y   = 6.5 # at least 7.3 - on 7.2, the FixedJoint fails!
ball.z   = 0
pole.set_xyz(2.2,8,0)
pend.set_xyz(hgxpos,9,0)
hing.set_xyz(hgxpos,12,0)


# we attach pend to pole - so pend should go first?!
#~ joint1 = soya.HingeJoint(pend)
#~ joint1.anchor = Point(scene, 7, 5, 0)
#~ joint2 = soya.HingeJoint(pole,pend) # hinge is wherever is 'xyz' of respective objects!?

# hinge point seems to try to preserve initially set positions
# without the lone HingePoint, pole falls due gravity (if in gravity_mode)
# but even without gravity_mode, if pend which is in gravity_mode is hinged to it - then it shall fail!
#~ joint1 = soya.HingeJoint(pole)
#~ joint2 = soya.HingeJoint(hing,pole)
#~ joint3 = soya.HingeJoint(pole,pend)
#~ joint5 = soya.FixedJoint(pole,hing) # here hing snaps to the pole_mass_hinge!
#~ joint2 = soya.HingeJoint(pole,pend)
#~ joint4 = soya.FixedJoint(pend,ball) # Fixed is the right for this connection
#~ joint4.setFixed()

# now through ode tutorial
## It's important to place the bodies at their desired position before connecting them with joints!
## Connect body1 (pend) with the static environment
#~ print(ode.environment) # not present
## Here we create a ball joint and connect body1 with the static environment.
## The joint is placed at position (0,2,0).
## So far body1 ALREADY FORMS A PENDULUM!!
j1 = soya.HingeJoint(pend) #ode.World() in ode, here the matching scene cannot go - must be body
j1.attach(pend, None)#, ode.environment)
j1.anchor = Point(scene, hgxpos, 12, 0) #setAnchor( (3,10,0) )
j1.setFeedback(flag=True) # for getFeedback

## Connect body2 with body1
## We create another ball joint and connect body2 with body1.
## The joint is placed at the same position than body1.
## So this means we have another pendulum which we attach to the first pendulum.
# anchor at ball pos
# NOTE: force bump MUST be oriented correctly when hitting ball: ie. if it hits up for a left right hinge, nothing will happen (shaking!)
#~ j2 = soya.HingeJoint(ball)
#~ j2.attach(ball, pend)
#~ j2.anchor = Point(scene, 3, 7.4, 0) #.setAnchor( (3,2,0) ) # '_soya.FixedJoint' object has no attribute 'anchor'
j2 = soya.FixedJoint(ball,pend)
j2.setFixed()
j2.setFeedback(flag=True) # for getFeedback


# these seem irrelevant after hinge?
ground.pushable = False
ground.gravity_mode = False
hing.pushable = False
hing.gravity_mode = False
pole.pushable = False
pole.gravity_mode = False


print(pole.num_joints, pole.joints) # dir(pole), dir(pole.joints[0]))
#~ print(joint1.anchor, joint1.anchor2, joint2.anchor, joint2.anchor2)


# bump with init force
#~ ball.add_force(soya.Vector(scene,0,ball_density*3000,0))
ball.add_force(soya.Vector(scene,0,0,10000))
#~ pend.add_force(soya.Vector(scene,0,0,5000))


SetLight()
SetCamera()
SetWindowOverlay()

#running soya
soya.set_root_widget(root) #(camera); must be root for overlays
ml = soya.MainLoop(scene)
ml.main_loop()

