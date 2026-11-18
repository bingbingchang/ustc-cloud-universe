"""East library: measured-by-reference exterior, actual geometry, reproducible glTF.

Working coordinates X right, Y toward back, Z up; exported glTF X,Y-up,Z-out.
All dimensions are photograph-derived estimates except the retained game doorway.
No scene photo is projected onto the building. Texture maps are generated materials.
"""
from pathlib import Path
import json, struct, math, io, argparse
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT=Path(__file__).resolve().parent
GROUPS={}; MATS=[]; TEX=[]
def texture(kind,base,tiles=8):
    rng=np.random.default_rng(17)
    a=np.clip(np.array(base)[None,None,:]+rng.normal(0,1.5,(1024,1024,1)),0,255).astype('uint8')
    im=Image.fromarray(a); d=ImageDraw.Draw(im)
    if kind=='brick':
        for y in range(0,1024,32):
            d.line((0,y,1024,y),fill=(157,74,32),width=2)
            d.line((0,y+2,1024,y+2),fill=(239,133,68),width=1)
            for x in range(0,1152,128):
                xx=x+(64 if y//32%2 else 0)
                d.line((xx,y,xx,y+32),fill=(181,87,36),width=1)
    else:
        for p in range(0,1024,1024//tiles):
            dark=tuple(max(0,int(v*.74)) for v in base)
            light=tuple(min(255,int(v*1.06)) for v in base)
            d.line((p,0,p,1024),fill=dark,width=2)
            d.line((0,p,1024,p),fill=dark,width=2)
            d.line((p+2,0,p+2,1024),fill=light,width=1)
            d.line((0,p+2,1024,p+2),fill=light,width=1)
    return im
def mat(name,c=(1,1,1,1),rough=.65,metal=0,tex=None,alpha=None,emission=None,scale=1):
    m={'name':'PhotoLibraryReplica_'+name,'pbrMetallicRoughness':{'baseColorFactor':list(c),'metallicFactor':metal,'roughnessFactor':rough},'doubleSided':False}
    if tex is not None:
        ix=len(TEX); TEX.append(tex); m['pbrMetallicRoughness']['baseColorTexture']={'index':ix}
        # Fine mortar relief remains visible under grazing game lights.
        ht=np.asarray(tex.convert('L').filter(ImageFilter.GaussianBlur(.7)),dtype=float)/255
        gy,gx=np.gradient(ht); normal=np.dstack((-gx*5,-gy*5,np.ones_like(ht)))
        normal/=np.linalg.norm(normal,axis=2)[:,:,None]
        m['normalTexture']={'index':len(TEX),'scale':.55}
        TEX.append(Image.fromarray(np.clip((normal*.5+.5)*255,0,255).astype('uint8')))
    if alpha:m['alphaMode']=alpha; m['doubleSided']=True
    if emission:m['emissiveFactor']=emission
    MATS.append(m); return (len(MATS)-1,scale)
brick=mat('TerracottaBrick',tex=texture('brick',(222,104,46)),scale=1/4)
stone=mat('SilverPanel',tex=texture('tile',(202,201,194)),rough=.48,metal=.15,scale=1/9.6)
rose=mat('RoseStone',tex=texture('tile',(183,137,113)),scale=1/9.6)
roof=mat('RoofPaver',tex=texture('tile',(195,192,182)),scale=1/12)
concrete=mat('StairStone',tex=texture('tile',(185,184,174)),scale=1/9.6)
white=mat('IvoryAluminum',(.69,.70,.67,1),.4,.35)
metal=mat('GraphiteMullions',(.078,.12,.13,1),.29,.7)
rail=mat('SteelRail',(.32,.34,.33,1),.28,.8)
glass=mat('BlueGlazing',(.023,.073,.10,.66),.15,.22,alpha='BLEND')
dark=mat('InteriorShadow',(.009,.019,.024,1),.9)
warm=mat('Ceiling',(.47,.49,.46,1),.75)
light=mat('InteriorLight',(.92,.88,.65,1),.4,emission=[.8,.75,.48])
teal=mat('RoofTeal',(.017,.38,.36,1),.7)
fanmat=mat('FanDark',(.028,.039,.037,1),.65,.5)
blue=mat('DoorSafetyStripe',(.02,.27,.62,1),.4)
gold=mat('Gold',(.66,.40,.075,1),.25,.75)

def group(name,material):
    k=(name,material[0]);
    if k not in GROUPS:GROUPS[k]={'p':[],'n':[],'uv':[],'ix':[]}
    return GROUPS[k]
def quad(name,material,vs,uv=None):
    g=group(name,material); p=np.array(vs,dtype=float); n=np.cross(p[1]-p[0],p[2]-p[0]); n/=max(np.linalg.norm(n),1e-12)
    if uv is None:
        axis=np.argmax(abs(n)); ids=([1,2] if axis==0 else [0,2] if axis==1 else [0,1]); uv=p[:,ids]*material[1]
    b=len(g['p']); g['p'].extend(vs);g['n'].extend([n.tolist()]*4);g['uv'].extend(np.asarray(uv).tolist());g['ix'].extend([b,b+1,b+2,b,b+2,b+3])
def box(name,material,c,s):
    x,y,z=c; a,b,h=np.array(s)/2
    if min(s)<=0:return
    v=[(x-a,y-b,z-h),(x+a,y-b,z-h),(x+a,y+b,z-h),(x-a,y+b,z-h),(x-a,y-b,z+h),(x+a,y-b,z+h),(x+a,y+b,z+h),(x-a,y+b,z+h)]
    for f in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:quad(name,material,[v[i] for i in f])
def beam(name,material,a,b,w,h=None):
    a=np.array(a); b=np.array(b); d=b-a; d/=np.linalg.norm(d); ref=np.array([0,0,1.])
    if abs(d[2])>.99:ref=np.array([0,1.,0])
    u=np.cross(d,ref);u/=np.linalg.norm(u);u*=w/2;v=np.cross(d,u);v/=np.linalg.norm(v);v*=(h or w)/2
    pts=[a-u-v,a+u-v,a+u+v,a-u+v,b-u-v,b+u-v,b+u+v,b-u+v]
    for f in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:quad(name,material,[pts[i].tolist() for i in f])
def cylinder(name,material,x,y,z,r,h,n=20):
    # Closed cylinder, explicit normals through face geometry.
    for i in range(n):
        a=i*2*math.pi/n;b=(i+1)*2*math.pi/n
        p=(x+r*math.cos(a),y+r*math.sin(a));q=(x+r*math.cos(b),y+r*math.sin(b))
        quad(name,material,[(p[0],p[1],z),(q[0],q[1],z),(q[0],q[1],z+h),(p[0],p[1],z+h)])
        # Nondegenerate triangles are emitted through a dedicated path.
        tri(name,material,[(x,y,z+h),(p[0],p[1],z+h),(q[0],q[1],z+h)])
        tri(name,material,[(x,y,z),(q[0],q[1],z),(p[0],p[1],z)])
def tri(name,material,vs):
    g=group(name,material);p=np.array(vs);n=np.cross(p[1]-p[0],p[2]-p[0]);n/=max(np.linalg.norm(n),1e-12);b=len(g['p'])
    g['p'].extend(vs);g['n'].extend([n.tolist()]*3);g['uv'].extend([[0,0],[1,0],[.5,1]]);g['ix'].extend([b,b+1,b+2])

def front_window(name,x,y,z,w,h,back=False,panes=3):
    sign=-1 if back else 1 # interior goes +y for front
    box(name+'Reveal',dark,(x,y+sign*.43,z),(w+.12,.9,h+.1))
    # glass stays in front of reveal; floor/strip lights provide parallax behind it
    box(name+'Glass',glass,(x,y-sign*.035,z),(w,.025,h))
    for xx in [x-w/2,x+w/2]+[x-w/2+i*w/panes for i in range(1,panes)]:
        box(name+'Frames',metal,(xx,y-sign*.10,z),(.075,.12,h+.12))
    for zz in [z-h/2,z+h/2,z+h*.10]:box(name+'Frames',metal,(x,y-sign*.10,zz),(w+.08,.12,.07))
    box(name+'Sill',white,(x,y-sign*.15,z-h/2-.045),(w+.17,.36,.09))
    for k in range(panes):
        xx=x-w/2+(k+.5)*w/panes
        box(name+'Lights',light,(xx,y-sign*.052,z+h*.29),(w/panes*.63,.022,.035))
        # bookshelf rows behind panes, genuine geometric detail rather than facade photo.
        for j in range(2):
            box(name+'Shelves',rail,(xx,y-sign*.05,z-h*.28+j*.19),(w/panes*.83,.018,.025))
        box(name+'Curtain',warm,(xx+w/panes*.34,y-sign*.054,z),(.10,.02,h*.88))

def facade_wings():
    # No opaque full box behind the front curtain wall or door lobby.
    for side in [-1,1]:
        xc=side*25.85
        box('WingCore',dark,(xc,12.8,12.15),(20.3,24.8,24.3))
        box('WingBase',rose,(xc,.06,1.8),(20.3,.48,3.6))
        box('WingFrontOrangeTop',brick,(xc,-.18,19.25),(20.3,.75,1.2))
        for i in range(4):
            xx=side*(15.7+i*6.7667)
            box('WingOrangePiers',brick,(xx,-.20,10.4),(1.05,.8,16.4))
            box('WingBasePiers',rose,(xx,-.20,1.6),(1.05,.8,3.2))
        for i in range(3):
            x=side*(15.7+(i+.5)*6.7667)
            for j in range(4):
                z=3.6+(j+.5)*3.73
                front_window('FrontWindows',x,-.52,z,5.55,2.85,panes=4)
            for j in range(5):box('FrontFloorBands',stone if j in (1,2,3) else brick,(x,-.5,3.6+j*3.73),(5.7,.5,.88))
            box('FrontBasePanels',concrete,(x,-.25,1.57),(5.55,.12,3.02))
            for xx in [x-1.85,x,x+1.85]:box('FrontBaseJoints',rail,(xx,-.32,1.57),(.018,.018,2.98))
            for zz in np.arange(.35,3.0,.16):box('FrontBaseLouvers',stone,(x,-.325,zz),(5.5,.018,.016))
        # Continuous upper floor with fine vertical slit windows.
        box('AtticBandTop',stone,(xc,-.39,23.3),(20.3,.72,2.0))
        box('AtticBandBottom',stone,(xc,-.15,19.85),(20.3,.8,.6))
        for i in range(14):
            x=side*(15.7+(i+.5)*20.3/14)
            front_window('AtticWindows',x,-.57,21.3,.83,2.0,panes=1)
        for i in range(15):box('AtticPiers',stone,(side*(15.7+i*20.3/14),-.44,21.65),(.53,.54,3.25))
        box('OuterTerracottaPier',brick,(side*35.35,-.35,12.5),(1.3,1.12,25.0))
        # Side wall, central slit continuous rhythm in five separated openings.
        for yy,ww,ma in [(2.4,4.8,rose),(8.3,7.0,brick),(17.2,7.0,brick),(23.1,4.8,rose)]:
            box('SideCladding',ma,(side*36.04,yy,12.1),(.36,ww,24.2))
        box('SideBase',rose,(side*36.08,12.75,1.15),(.44,25.5,2.3))
        for j in range(5):
            z=3.7+j*4.05
            # A side window is a rotated front-window assembly.
            before={k:len(v['p']) for k,v in GROUPS.items()}
            front_window('SideWindows',12.75,0,z,1.9,2.65,panes=2)
            for k,g in GROUPS.items():
                start=before.get(k,0)
                for i in range(start,len(g['p'])):
                    px,py,pz=g['p'][i];nx,ny,nz=g['n'][i]
                    g['p'][i]=[side*(36.27-py),px,pz];g['n'][i]=[-side*ny,nx,nz]
                if side==-1:
                    # Reflection of coordinates reverses winding.
                    for i in range(0,len(g['ix']),3):
                        if g['ix'][i]>=start:g['ix'][i+1],g['ix'][i+2]=g['ix'][i+2],g['ix'][i+1]
            box('SideSlitSpandrels',brick,(side*36.25,12.75,z+2.025),(.42,1.95,1.4))
        box('SideSlitTopClosure',brick,(side*36.25,12.75,22.9),(.42,1.95,2.8))
    # Rear: nine bays, upper narrow windows, not a copy of the front towers.
    box('RearCore',dark,(0,25.04,12),(71,.8,24))
    box('RearBase',rose,(0,25.56,1.15),(72,.45,2.3))
    for i in range(10):box('RearOrangePiers',brick,(-34+i*68/9,25.72,10.4),(1.22,.65,16.4))
    for i in range(9):
        x=-34+(i+.5)*68/9
        for j in range(4):front_window('RearWindows',x,25.88,4.38+j*4.05,6.25,3.05,True,4)
        for j in range(5):box('RearBands',stone if j in (1,2,3) else brick,(x,25.87,2.35+j*4.05),(6.4,.5,.95))
        box('RearBasePanels',concrete,(x,25.81,1.14),(6.3,.10,2.15))
        for xx in [x-2.1,x,x+2.1]:box('RearBaseJoints',rail,(xx,25.875,1.14),(.018,.025,2.1))
    box('RearOrangeTop',brick,(0,25.67,19.25),(71,.7,1.2))
    box('RearAtticBacking',stone,(0,25.50,21.65),(70,.35,3.2))
    for i in range(9):
        center=-34+(i+.5)*68/9
        for dx in [-2.4,-.8,.8,2.4]:front_window('RearAttic',center+dx,25.83,21.3,1.0,2.0,True,1)
        for dx in [-3.65,-1.6,0,1.6,3.65]:box('RearAtticPiers',stone,(center+dx,25.75,21.65),(.55,.55,3.2))
    for z,h in [(19.8,.65),(23.3,2.0)]:box('RearAtticBands',stone,(0,25.65,z),(72,.65,h))
    for side in [-1,1]:box('RearEnds',brick,(side*35,25.52,12.4),(2,1,24.8))

def tower(x):
    # Towers are hollow faced elements, with deep slit reveals and recesses.
    box('TowerMainUpper',brick,(x,3.5,21.1),(9.8,7,16.6))
    sx=1 if x>0 else -1
    box('TowerMainLower',brick,(sx*11.45,3.5,6.4),(8.5,7,12.8))
    # Real dark slot set ahead of the backing, cut into two cladding cheeks.
    for dx in [-2.72,2.72]:
        box('TowerCheeksUpper',brick,(x+dx,-.36,21.1),(4.35,.73,16.6))
        a=x+dx-2.175;b=x+dx+2.175
        if sx>0:a=max(a,7.2)
        else:b=min(b,-7.2)
        box('TowerCheeksLower',brick,((a+b)/2,-.36,6.4),(b-a,.73,12.8))
    for j in range(6):
        z=2.35+j*4.05
        front_window('TowerSlits',x,-.78,z,1.0,2.6,panes=1)
        box('TowerSlitSpandrels',brick,(x,-.52,z+2.025),(1.02,.55,1.45))
    box('TowerSlotTopClosure',brick,(x,-.52,27.25),(1.10,.55,4.3))
    box('TowerCap',stone,(x,3.5,29.43),(10.0,7.2,.18))
    # Open white crown (four posts front/back) and roofwell beneath.
    for yy in [1.5,5.6]:
        for dx in [-3.2,-1.06,1.06,3.2]:box('CrownPillars',stone,(x+dx,yy,30.66),(.48,.5,2.6))
        box('CrownLintels',stone,(x,yy,32.03),(7.0,.65,.42))
    for dx in [-3.2,3.2]:
        box('CrownSides',stone,(x+dx,3.55,32.03),(.6,4.7,.42))
        for yy in [2.866667,4.233333]:box('CrownPillars',stone,(x+dx,yy,30.66),(.48,.50,2.6))
    box('TowerRoof',roof,(x,3.6,29.57),(8.9,6.4,.12))
    box('TowerDoorCanopy',rail,(x,-1.1,4.3),(2.0,1.4,.13))

def center():
    for x in [-10.8,10.8]:tower(x)
    box('CentralUpperTitle',stone,(0,.15,23.85),(11.8,.8,5.9))
    # Central curtain wall spans from entrance to sign; precise reserved door openings.
    for xx in np.linspace(-5.9,5.9,9):box('AtriumMullions',metal,(float(xx),-.09,13.14),(.075,.15,15.42))
    for xx in [-7.2,-5.9,-4.425,-2.95,0,2.95,4.425,5.9,7.2]:box('AtriumGroundPosts',metal,(xx,-.09,4.305),(.075,.15,2.25))
    for z in [5.43,7.2,9.7,12.2,14.7,17.2,19.7,20.9]:box('AtriumTransoms',metal,(0,-.09,z),(11.8,.17,.08))
    box('AtriumUpperGlass',glass,(0,-.035,16.575),(11.8,.025,8.75))
    # Facade backing is well inside the upper atrium; lobby below stays empty.
    box('AtriumUpperBackdrop',dark,(0,3.2,15),(11.7,.3,14.1))
    for zz in [8.1,12.1,16.15,20.2]:
        box('AtriumUpperFloors',warm,(0,1.7,zz),(11.7,3.0,.16))
        for xx in np.arange(-5,5.1,1.8):box('AtriumLights',light,(xx,.14,zz+.5),(.8,.1,.055))
        for xx in np.arange(-5.6,5.7,.28):box('AtriumBalusters',rail,(xx,.10,zz+.55),(.025,.03,.8))
        box('AtriumRails',rail,(0,.10,zz+.98),(11.5,.06,.05))
    # Static glazing excludes the two functioning door apertures.
    for a,b in [(-7.2,-2.317469),(-.082531,.082531),(2.317469,7.2)]:
        box('GroundStaticGlass',glass,((a+b)/2,-.035,4.305),(b-a,.025,2.25))
    for x in [-1.2,1.2]:
        box('south_library_PhotoVisitGlass',glass,(x,-.14,4.305),(2.234938,.025,2.25))
        for dx in [-1.117469,1.117469]:box('DoorExternalFrames',white,(x+dx,-.15,4.305),(.07,.09,2.32))
        box('DoorExternalFrames',white,(x,-.15,5.465),(2.31,.09,.07))
        # These leaves/handles are a fallback only: runtime hides every PhotoVisitGlass part
        # and creates the existing articulated, collidable door in this same aperture.
        box('south_library_PhotoVisitGlass',white,(x,-.18,4.305),(.055,.07,2.25))
        for dx in [-.15,.15]:box('south_library_PhotoVisitGlass',rail,(x+dx,-.24,4.30),(.035,.08,.62))
    # Portal frames recede upward/outward: three dimensions, panelled soffit.
    for i in range(4):
        half=9.6-i*.62; front=-4.5+i*.92; top=14.9-i*.7
        for sx in [-1,1]:box('PortalFrame',stone,(sx*(half-.28),front+.42,(top+.14)/2),(.56,.88,top-.14))
        box('PortalLintels',stone,(0,front+.42,top-.27),(half*2,.88,.54))
        if i<3:
            for sx in [-1,1]:box('PortalRebates',stone,(sx*(half-.59),front+.88,(top+.14)/2),(.66,.10,top-.14))
            box('PortalSoffitRebates',stone,(0,front+.88,top-.62),(half*2-.56,.10,.7))
    for sx in [-1,1]:box('PortalInnerCheeks',stone,(sx*7.18,-.45,7.65),(.20,1.2,8.95))
    box('AtriumLowerTransomGlass',glass,(0,-.035,8.8),(14.4,.025,6.74))
    box('PortalSoffit',stone,(0,-2.4,12.19),(14.5,4.0,.12))
    for x in [-5.7,-2.85,0,2.85,5.7]:
        for y in [-3.5,-2.1,-.7]:
            box('PortalLightMount',rail,(x,y,12.08),(.22,.38,.07))
            box('PortalLamps',light,(x,y,12.035),(.12,.24,.025))
    # Place real glyph meshes (extruded bitmap silhouette), not a single facade label plate.
    font=ImageFont.truetype('C:/Windows/Fonts/STKAITI.TTF',240)
    for text,x in zip('圖書館',[-3.5,0,3.5]):
        im=Image.new('L',(320,320));dr=ImageDraw.Draw(im);dr.text((160,154),text,font=font,fill=255,anchor='mm')
        mask=np.asarray(im.resize((128,128),Image.Resampling.LANCZOS))>125
        step=3.2/128
        # Greedy horizontal runs reduce geometry while keeping recognisable strokes.
        for yy,row in enumerate(mask):
            start=None
            for xx in range(129):
                yes=xx<128 and row[xx]
                if yes and start is None:start=xx
                if not yes and start is not None:
                    box('GoldCalligraphy',gold,(x+(start+xx-128)*step/2,-.30,24.0+(64-yy)*step),((xx-start)*step,.07,step*1.03));start=None

def entrance():
    # Entrance y values are negative (toward visitor); gameplay collision contract preserved.
    box('EntryLanding',concrete,(0,-2.25,3.08),(19.08,4.5,.20))
    for side in [-1,1]:
        x=side*5.91
        for i in range(18):
            rise=.14+(i+1)*(3.18-.14)/18
            y=-10.67+(i+.5)*6.14/18
            box('EntrySteps',concrete,(x,y,rise/2),(6.82,6.14/18+.009,rise))
            box('StepNosings',white,(x,y-6.14/36+.01,rise+.008),(6.82,.035,.016))
        for xx in [side*2.5,side*9.32]:
            # Wedge parapet with continuous sloped cap.
            y0=-10.77;y1=-4.48;lo=.14;hi=3.18
            v=[(xx-.22,y0,0),(xx+.22,y0,0),(xx+.22,y1,0),(xx-.22,y1,0),(xx-.22,y0,lo+.72),(xx+.22,y0,lo+.72),(xx+.22,y1,hi+.72),(xx-.22,y1,hi+.72)]
            for f in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:quad('StairParapets',stone,[v[i] for i in f])
            beam('ParapetCaps',stone,(xx,y0,lo+.76),(xx,y1,hi+.76),.54,.12)
    # Lower doorway at the central slot, retained as an architectural exterior feature.
    box('LowerPassageFloor',concrete,(0,-6.8,.08),(4.5,7.8,.12))
    front_window('LowerEntry',0,-4.42,1.40,4.45,2.45,False,4)
    for x in [-6.5,-1.2,1.2,6.5]:
        if abs(x)<5:box('south_library_PhotoVisitGlass',blue,(x,-.162,4.2),(1.2,.02,.055))
    # Steps and entrance integrated with the current game floor at 3.18 m.

def railing(a,b,z):
    aa=np.array([a[0],a[1],z]);bb=np.array([b[0],b[1],z]);length=np.linalg.norm(bb-aa)
    for dz in [0,.9]:beam('RoofRail',rail,aa+[0,0,dz],bb+[0,0,dz],.045)
    for t in np.linspace(0,1,max(2,int(length/.28))):
        p=aa+(bb-aa)*t;beam('RoofRail',rail,p,p+[0,0,.92],.026)
def roofbox(x,y,w,d,h):
    z=24.4
    for sx in [-1,1]:box('RoofPenthouses',brick,(x+sx*(w-.3)/2,y,z+h/2),(.3,d,h))
    for sy in [-1,1]:box('RoofPenthouses',brick,(x,y+sy*(d-.3)/2,z+h/2),(w,.3,h))
    box('PenthouseRoof',roof,(x,y,z+h-.85),(w-.6,d-.6,.12))
    for sx in [-1,1]:box('PenthouseCoping',stone,(x+sx*(w-.15)/2,y,z+h+.02),(.25,d+.1,.1))
    for sy in [-1,1]:box('PenthouseCoping',stone,(x,y+sy*(d-.15)/2,z+h+.02),(w+.1,.25,.1))
    front_window('RooftopServiceDoor',x,y-d/2-.03,z+1.1,1.5,2.2,False,2)
def hvac(x,y,w=1.05,d=1.25,h=1.25):
    z=24.5
    box('HVACBody',white,(x,y,z+h/2),(w,d,h))
    box('HVACBase',rail,(x,y,z-.08),(w+.08,d+.08,.16))
    cylinder('HVACFans',fanmat,x,y,z+h+.01,min(w,d)*.36,.025,20)
    cylinder('HVACHubs',white,x,y,z+h+.05,.10,.03,12)
    for yy in np.arange(y-d*.40,y+d*.41,.10):box('HVACGrille',fanmat,(x,y-d/2-.012,z+h/2),(w*.82,.018,.018))
    for zz in np.arange(z+.18,z+h-.08,.09):box('HVACGrille',fanmat,(x,y-d/2-.014,zz),(w*.82,.018,.022))
    for k in range(4):
        a=k*math.pi/2
        beam('FanGuards',rail,(x-.37*math.cos(a),y-.37*math.sin(a),z+h+.05),(x+.37*math.cos(a),y+.37*math.sin(a),z+h+.05),.018)
def rooftops():
    box('RoofDeck',roof,(0,12.75,24.3),(72,25.5,.20))
    for side in [-1,1]:
        box('RoofSideParapet',brick,(side*35.82,12.75,24.7),(.36,25.5,.6))
        railing((side*35.5,1),(side*35.5,24.5),24.9)
    railing((-35,25.25),(35,25.25),24.9)
    for a,b in [(-35,-16),(16,35)]:railing((a,.38),(b,.38),24.7)
    # Three major rooftop blocks at the rear, two front tower crowns.
    for x,y,w,d,h in [(-13.2,22.4,6.5,6,3.9),(-3.6,22.3,6.1,6,4.4),(14.2,22.2,6.1,6,4.0)]:roofbox(x,y,w,d,h)
    for x in [-10.8,10.8]:
        for dx in [-.85,.85]:
            box('RoofServiceCorridorBase',brick,(x+dx,13.2,24.75),(.22,12,.65))
            box('RoofServiceCorridorBeam',brick,(x+dx,13.2,26.55),(.28,12,.4))
            for yy in [7.2,10.2,13.2,16.2,19.2]:box('RoofServiceCorridorPosts',brick,(x+dx,yy,25.65),(.28,.35,1.6))
            box('RoofServiceCorridorGlass',glass,(x+dx,13.2,25.65),(.025,11.7,1.4))
    # Teal service/drainage grid precisely on flat roof, not arbitrary facade stripes.
    for xa,xb in [(-35,-18),(-1,11),(19,35)]:
        for xx in np.arange(xa+3,xb,5):box('RoofDrainGrid',teal,(float(xx),13,24.415),(.27,22,.018))
        for yy in [5.5,15.5,23.9]:box('RoofDrainGrid',teal,((xa+xb)/2,yy,24.415),(xb-xa,.27,.018))
    # Array of condensers on left service terrace, asymmetric as reference.
    for row,yy in enumerate([6.0,7.55,10.0,11.55,14.0,15.55,18.0,19.55]):
        for k in range(5):hvac(-17.8-k*1.18,yy,1.03,1.32,1.12+(row%2)*.16)
    for k in range(5):hvac(-16.7-k*1.3,20.2,1.10,1.15,1.3)
    for k in range(6):hvac(18.1+k*1.2,3.6,.95,1.0,1.9 if k<4 else 1.1)
    for x,y in [(-27,17.8),(-28.5,17.8),(-27,20.2),(-28.5,20.2)]:hvac(x,y,1.3,1.65,2.65)
    for x,y,h in [(-16.0,17.0,3.0),(-11.0,17.0,3.5),(10.5,16.2,2.8)]:
        box('TallAirHandlingCabinet',stone,(x,y,24.5+h/2),(1.8,1.6,h))
        box('TallEquipmentGrille',fanmat,(x,y-.81,25.25),(1.3,.025,1.2))
        for xx in np.arange(x-.6,x+.61,.10):box('TallEquipmentFins',rail,(xx,y-.83,25.25),(.025,.025,1.18))
    for xx in np.arange(-29.4,-16,.25):box('EquipmentPlatformGrate',rail,(xx,13.2,24.46),(.023,19.3,.055))
    for yy in np.arange(3.6,23,.25):box('EquipmentPlatformGrate',rail,(-22.7,yy,24.45),(13.5,.023,.045))
    for k in range(8):hvac(-33+k*2.3,1.4,.70,.55,.7)
    for k in range(6):hvac(20+k*2.2,1.4,.7,.55,.7)
    # Raised metal service paths, central duct network with seams and elbow blocks.
    for x,y,w,d in [(-17,14,1.0,19),(-8.2,16,1.4,15),(9.3,16,1.1,15)]:box('ServiceWalkways',rail,(x,y,24.49),(w,d,.12))
    paths=[((-3,20),(-3,11)),((-3,11),(-6,11)),((-6,11),(-6,5)),((-6,5),(-10,5)),((14,19),(14,12)),((14,12),(11,12)),((11,12),(11,7)),((-13,20),(-13,15)),((-13,15),(-16,15))]
    for (x1,y1),(x2,y2) in paths:
        beam('VentilationDucts',white,(x1,y1,25.35),(x2,y2,25.35),.85,.85)
        length=math.hypot(x2-x1,y2-y1)
        for t in np.arange(.35,length,.65)/max(length,.1):
            x=x1+(x2-x1)*t;y=y1+(y2-y1)*t
            box('DuctSeams',rail,(x,y,25.35),(.87,.035,.87) if x1==x2 else (.035,.87,.87))
    for x,y in [(-8,8),(10,14)]:
        box('AirHandlingUnit',white,(x,y,25.1),(2.0,1.6,1.2))
        for k in range(12):box('AirHandlingGrilles',fanmat,(x-.86+k*.155,y-.81,25.1),(.045,.025,.92))

def export(path):
    blob=bytearray();views=[];acc=[]
    def add(data,component,kind,count,mn=None,mx=None,target=None):
        while len(blob)%4:blob.append(0)
        offset=len(blob);blob.extend(data);v={'buffer':0,'byteOffset':offset,'byteLength':len(data)}
        if target:v['target']=target
        vi=len(views);views.append(v);a={'bufferView':vi,'componentType':component,'count':count,'type':kind}
        if mn is not None:a['min']=mn;a['max']=mx
        ai=len(acc);acc.append(a);return ai
    meshes=[];nodes=[]
    for (name,mi),g in GROUPS.items():
        p=np.asarray(g['p'],dtype='<f4');n=np.asarray(g['n'],dtype='<f4')
        p=p[:,[0,2,1]]*np.array([1,1,-1],dtype='<f4');n=n[:,[0,2,1]]*np.array([1,1,-1],dtype='<f4')
        uv=np.asarray(g['uv'],dtype='<f4');uv[:,1]=1-uv[:,1]
        ip=add(p.tobytes(),5126,'VEC3',len(p),p.min(0).tolist(),p.max(0).tolist(),34962)
        inn=add(n.tobytes(),5126,'VEC3',len(n),target=34962);iu=add(uv.tobytes(),5126,'VEC2',len(uv),target=34962)
        ix=np.asarray(g['ix'],dtype='<u4');ii=add(ix.tobytes(),5125,'SCALAR',len(ix),target=34963)
        meshes.append({'name':name,'primitives':[{'attributes':{'POSITION':ip,'NORMAL':inn,'TEXCOORD_0':iu},'indices':ii,'material':mi}]})
        nodes.append({'name':name,'mesh':len(meshes)-1})
    images=[]
    for im in TEX:
        f=io.BytesIO();im.save(f,format='PNG');data=f.getvalue()
        while len(blob)%4:blob.append(0)
        vi=len(views);views.append({'buffer':0,'byteOffset':len(blob),'byteLength':len(data)});blob.extend(data)
        images.append({'bufferView':vi,'mimeType':'image/png'})
    doc={'asset':{'version':'2.0','generator':'USTC reference reconstruction 20261117'},'scene':0,'scenes':[{'nodes':list(range(len(nodes)))}],'nodes':nodes,'meshes':meshes,'materials':MATS,'buffers':[{'byteLength':len(blob)}],'bufferViews':views,'accessors':acc,'images':images,'samplers':[{'magFilter':9729,'minFilter':9987,'wrapS':10497,'wrapT':10497}],'textures':[{'source':i,'sampler':0} for i in range(len(images))]}
    js=json.dumps(doc,separators=(',',':')).encode();js+=b' '*((-len(js))%4);blob+=b'\0'*((-len(blob))%4)
    path.write_bytes(struct.pack('<III',0x46546c67,2,12+8+len(js)+8+len(blob))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(blob),0x004e4942)+blob)
    allp=np.vstack([np.asarray(g['p']) for g in GROUPS.values()]); extent=(allp.max(0)-allp.min(0)).tolist()
    report={'objects':len(nodes),'triangles':sum(len(g['ix'])//3 for g in GROUPS.values()),'materials':len(MATS),'bytes':path.stat().st_size,'dimensions_estimated_game_xyz_m':[extent[0],extent[2],extent[1]],'door_floor_m':3.18,'game_local_axes':'X right/east, Y up, Z out/south','refs':'6 user uploaded views, 2026-11-17; not surveyed dimensions'}
    path.with_suffix('.json').write_text(json.dumps(report,indent=2),encoding='utf8');print(json.dumps(report))

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,default=OUT/'library_multiview.glb');args=ap.parse_args()
    facade_wings();center();entrance();rooftops();export(args.output)
