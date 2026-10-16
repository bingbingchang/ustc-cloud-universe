"""Build fifteen differentiated campus NPCs on the existing articulated human contract."""
from pathlib import Path
import json
import math
import bpy
from mathutils import Vector

SCRIPT = Path(__file__).resolve()
ROOT = SCRIPT.parents[2]
exec(SCRIPT.with_name('build_population.py').read_text(encoding='utf-8').split('report={}')[0], globals())
APPEARANCE = json.loads((ROOT/'godot/data/npc_appearance.json').read_text(encoding='utf-8'))
COLORS = {'solar':'dc9b3c','finance':'397f80','library':'5675ad','history':'aa6159','ai':'7d69a7',
          'dining':'ede8db','physics':'836748','student':'447f9e','dorm':'985b60','network':'d28c37',
          'lab':'e3e8e5','sports':'346b82','career':'485968','international':'b16e46','botany':'6d8558'}


def color(hex_color):
    return tuple(int(hex_color[i:i+2],16)/255 for i in (0,2,4))


def find(root, name):
    return next(o for o in root.children_recursive if o.name == name)


def hairstyle(head, style):
    # Remove the former identical shoulder-length hair before designing each silhouette.
    for obj in list(head.children_recursive):
        if obj.type == 'MESH' and any(m == M['Hair'] for m in obj.data.materials):
            bpy.data.objects.remove(obj, do_unlink=True)
    verts=[]; faces=[]; segments=32; rows=15
    profile=[(0,.036,.043,-.013),(.025,.054,.059,-.008),(.065,.072,.065,0),(.115,.083,.073,.003),(.17,.086,.075,.003),(.225,.084,.072,.004),(.27,.068,.060,.005),(.29,.033,.035,.004),(.312,.001,.002,0)]
    for j in range(rows):
        for i in range(segments):
            a=i*math.tau/segments; front=max(0,math.cos(a))
            low=(.055 if style in ['bob','wavy'] else .125)+front*(.17 if style in ['bob','wavy'] else .105)
            y=low+(.312-low)*j/(rows-1)
            for p,q in zip(profile[:-1],profile[1:]):
                if y<=q[0]:
                    t=(y-p[0])/(q[0]-p[0]); w=p[1]+(q[1]-p[1])*t; d=p[2]+(q[2]-p[2])*t; z=p[3]+(q[3]-p[3])*t; break
            c=math.cos(a)
            verts.append(pt(((w+.008)*math.sin(a),y,z-(d+.008)*math.copysign(abs(c)**.72,c))))
    for j in range(rows-1):
        for i in range(segments):faces.append((j*segments+i,j*segments+(i+1)%segments,(j+1)*segments+(i+1)%segments,(j+1)*segments+i))
    mesh=bpy.data.meshes.new('HairSilhouette');mesh.from_pydata(verts,[],faces);mesh.materials.append(M['Hair'])
    obj=bpy.data.objects.new('HairSilhouette',mesh);bpy.context.collection.objects.link(obj);obj.parent=head
    for p in mesh.polygons:p.use_smooth=True
    if style=='bun':ball('TiedHairBun',head,(0,.22,.11),(.055,.055,.042),'Hair')
    elif style=='ponytail':
        ball('PonytailTie',head,(0,.17,.09),(.027,.025,.028),'Trim')
        ball('Ponytail',head,(0,.075,.13),(.035,.105,.032),'Hair')
    elif style in ['curly','messy','wavy']:
        for i in range(7):
            a=(i-3)*.40
            ball('TexturedHair',head,(math.sin(a)*.065,.28+(i%2)*.014,-.025+math.cos(a)*.015),(.034,.037,.036),'Hair')
    if style in ['bob','wavy']:
        for side in [-1,1]:ball('BobSide',head,(side*.085,.08,.035),(.025,.1,.042),'Hair')
    for s in [-1,1]:rod('Eyebrow',head,(s*.039-.019,.195,-.075),(s*.039+.018,.198,-.075),.0018,'Hair')


def glasses(head, safety=False):
    for side in [-1,1]:
        x=side*.039
        for a,b in [((x-.026,.148,-.086),(x+.026,.148,-.086)),((x-.026,.184,-.086),(x+.026,.184,-.086)),((x-.026,.148,-.086),(x-.026,.184,-.086)),((x+.026,.148,-.086),(x+.026,.184,-.086))]:
            rod('GlassesFrame',head,a,b,.0028 if safety else .0019,'Trim' if safety else 'Metal')
        rod('GlassesTemple',head,(side*.068,.173,-.082),(side*.09,.17,.025),.002,'Metal')
    rod('GlassesBridge',head,(-.013,.169,-.087),(.013,.169,-.087),.002,'Metal')


def garment(human, head, profile, ident):
    torso=find(human,'Ambient_Torso'); outfit=profile['outfit']
    if 'coat' in outfit or outfit=='lab_jacket':
        white=outfit in ['lab_coat','lab_jacket']
        loft('OpenCoat',torso,[(-.18,.15,.085,0),(.03,.145,.085,0),(.25,.15,.080,0),(.37,.153,.073,0)],'Cream' if white else 'Cloth',24)
        cube('InnerShirt',torso,(0,.25,-.085),(.13,.30,.013),'Accent',.005)
        for side in [-1,1]:
            triangle('CoatLapel',torso,[(side*.025,.42,-.062),(side*.11,.33,-.085),(side*.04,.20,-.09)],'Cream' if white else 'Trim')
            cube('CoatPocket',torso,(side*.10,.04,-.092),(.064,.07,.008),'ClothDark',.003)
    if outfit in ['blazer','blazer_scarf']:
        for side in [-1,1]:triangle('JacketLapel',torso,[(side*.025,.42,-.058),(side*.105,.32,-.08),(side*.036,.20,-.086)],'Trim')
        cube('BusinessShirt',torso,(0,.31,-.076),(.07,.19,.008),'Cream',.002)
        if outfit=='blazer':triangle('Tie',torso,[(-.014,.37,-.085),(.014,.37,-.085),(0,.22,-.09)],'Accent')
    if outfit=='chef':
        cube('ApronBib',torso,(0,.20,-.086),(.23,.35,.018),'Accent',.012)
        cube('ApronSkirt',torso,(0,-.08,-.09),(.28,.23,.02),'Accent',.01)
        for side in [-1,1]:rod('ApronNeckStrap',torso,(side*.07,.38,-.059),(side*.09,.29,-.091),.008,'Accent')
        cube('ApronPocket',torso,(0,.10,-.104),(.15,.09,.014),'Cloth',.006)
        loft('ChefHatBand',head,[(.27,.094,.075,0),(.34,.096,.078,0)],'Cream',24)
        for i in range(5):ball('ChefHatPuff',head,((i-2)*.034,.37,.004),(.048,.055,.075),'Cream')
        for side in [-1,1]:
            for j in range(3):ball('ChefButton',torso,(side*.055,.32-j*.075,-.105),(.004,.004,.003),'Cream')
    if outfit in ['quilt_vest','field_vest','utility','scarf_vest']:
        loft('Vest',torso,[(.02,.134,.084,0),(.28,.147,.082,0),(.39,.115,.06,0)],'Accent',24)
        for side in [-1,1]:
            cube('UtilityPocket',torso,(side*.083,.15,-.087),(.076,.095,.02),'Trim',.004)
            if outfit=='utility':cube('ReflectiveStrip',torso,(side*.11,.26,-.091),(.019,.19,.004),'Cream',.001)
        if outfit=='quilt_vest':
            for y in [.09,.18,.27]:rod('QuiltSeam',torso,(-.11,y,-.09),(.11,y,-.09),.0018,'ClothDark')
    if outfit in ['scarf','scarf_vest','blazer_scarf']:
        loft('ScarfCollar',torso,[(.40,.051,.045,0),(.45,.049,.045,0)],'Accent',24)
        cube('ScarfTail',torso,(.035,.29,-.087),(.04,.23,.012),'Accent',.008)
    if outfit=='hoodie':
        ball('FoldedHood',torso,(0,.37,.068),(.09,.075,.05),'ClothDark')
        for side in [-1,1]:rod('HoodDrawstring',torso,(side*.035,.39,-.063),(side*.045,.28,-.09),.0028,'Cream')
        cube('HoodiePocket',torso,(0,.13,-.083),(.18,.085,.015),'ClothDark',.018)
    if outfit in ['tracksuit','varsity']:
        for side in [-1,1]:
            cube('SportSideStripe',torso,(side*.132,.23,-.03),(.013,.29,.09),'Cream',.003)
            arm=find(human,'Ambient_Arm'+('L' if side<0 else 'R'))
            rod('SleeveStripe',arm,(side*.047,-.02,-.025),(side*.035,-.24,-.025),.006,'Cream')
        if outfit=='tracksuit':
            loft('Headband',head,[(.22,.088,.075,0),(.247,.083,.073,0)],'Cream',32)
            rod('WhistleCord',torso,(-.026,.43,-.043),(0,.29,-.09),.002,'Ink')
            rod('WhistleCord',torso,(.026,.43,-.043),(0,.29,-.09),.002,'Ink')
            cube('Whistle',torso,(0,.28,-.093),(.022,.017,.038),'Metal',.004)
    if outfit=='field_vest':
        loft('SunHatBrim',head,[(.279,.153,.125,0),(.291,.153,.125,0)],'Cream',40)
        loft('SunHatCrown',head,[(.284,.092,.076,0),(.35,.074,.063,0),(.368,.04,.036,0)],'Cream',32)
    if profile.get('backpack'):
        cube('Backpack',torso,(0,.23,.128),(.25,.33,.12),'Trim',.05)
        cube('BackpackFrontPocket',torso,(0,.16,.20),(.18,.13,.035),'Accent',.018)
        for side in [-1,1]:rod('BackpackStrap',torso,(side*.11,.38,-.025),(side*.115,.05,-.084),.010,'Trim')
    # A small identity card keeps service professions readable from normal distance.
    if ident not in ['dining','sports','botany']:
        rod('Lanyard',torso,(-.025,.44,-.045),(0,.28,-.09),.002,'Accent')
        rod('Lanyard',torso,(.025,.44,-.045),(0,.28,-.09),.002,'Accent')
        cube('IDCard',torso,(0,.255,-.095),(.044,.060,.006),'Cream',.003)
        cube('IDPhoto',torso,(-.009,.264,-.099),(.014,.018,.001),'Accent',.001)


def hand_props(human, ident):
    left=find(human,'Ambient_HandL'); right=find(human,'Ambient_HandR')
    book=find(human,'Ambient_Book')
    for child in list(book.children_recursive):bpy.data.objects.remove(child,do_unlink=True)
    node('Ambient_Page',book)
    def board(parent,title=False):
        cube('Clipboard',parent,(0,.095,-.014),(.18,.24,.018),'Trim',.006)
        cube('Paper',parent,(0,.10,-.026),(.154,.21,.003),'Page',.002)
        for j in range(4):cube('PaperLine',parent,(0,.16-j*.035,-.029),(.10,.003,.001),'Accent',.0005)
    def notebook(parent):
        cube('BookCover',parent,(0,.09,-.014),(.16,.23,.035),'Accent',.006)
        cube('BookSpine',parent,(-.075,.09,-.014),(.014,.23,.038),'Trim',.004)
        cube('BookTitle',parent,(0,.14,-.034),(.10,.012,.002),'Cream',.002)
    if ident=='solar':
        ball('SolarModel',left,(0,.08,0),(.075,.075,.075),'Accent')
        for i in range(8):
            a=i*math.tau/8
            rod('CoronaRay',left,(math.cos(a)*.085,.08+math.sin(a)*.085,0),(math.cos(a)*.102,.08+math.sin(a)*.102,0),.003,'Cream')
    elif ident=='finance':
        cube('Calculator',left,(0,.07,0),(.105,.16,.025),'Trim',.008)
        cube('CalculatorScreen',left,(0,.12,-.015),(.082,.035,.004),'Screen',.002)
        for x in range(3):
            for y in range(3):cube('CalculatorKey',left,((x-1)*.027,.025+y*.025,-.016),(.018,.015,.004),'Cream',.002)
    elif ident=='dining':
        cube('Tray',left,(.025,.01,-.015),(.25,.017,.17),'Metal',.012)
        for x in [-.045,.055]:ball('RiceBowl',left,(x,.035,-.025),(.045,.025,.045),'Cream')
        rod('LadleHandle',right,(0,-.02,0),(0,.19,0),.007,'Trim')
        ball('LadleBowl',right,(0,.22,-.008),(.038,.018,.05),'Metal')
    elif ident=='sports':
        ball('Basketball',left,(0,.05,0),(.105,.105,.105),'Accent')
        for a in [0,math.pi/2]:
            for j in range(24):
                u=j*math.tau/24;v=(j+1)*math.tau/24
                rod('BallSeam',left,(.107*math.cos(u)*math.cos(a),.05+.107*math.sin(u),.107*math.cos(u)*math.sin(a)),(.107*math.cos(v)*math.cos(a),.05+.107*math.sin(v),.107*math.cos(v)*math.sin(a)),.0015,'Trim')
        cube('Stopwatch',right,(0,.025,-.006),(.04,.052,.015),'Metal',.01)
    elif ident=='dorm':
        board(left)
        ring('KeyRing',right,(0,-.025,0),.023,'Metal')
        for j in range(3):
            rod('Key',right,((j-1)*.014,-.04,0),((j-1)*.014,-.105,0),.004,'Metal')
            cube('KeyTooth',right,((j-1)*.014+.005,-.095,0),(.012,.014,.008),'Metal',.001)
    elif ident in ['network','ai']:
        cube('Tester' if ident=='network' else 'Tablet',left,(0,.08,-.012),(.11 if ident=='network' else .18,.17 if ident=='network' else .24,.026),'Trim',.009)
        cube('DeviceScreen',left,(0,.09,-.028),(.085 if ident=='network' else .15,.10 if ident=='network' else .20,.003),'Screen',.002)
        if ident=='network':
            for j in range(12):
                a=j*math.tau/12;b=(j+1)*math.tau/12
                rod('CoiledCable',left,(.055*math.cos(a),.2+.055*math.sin(a),0),(.055*math.cos(b),.2+.055*math.sin(b),0),.003,'Accent')
    elif ident=='lab':
        board(left)
        rod('TestTube',right,(0,-.02,0),(0,.095,0),.009,'Cream')
        rod('SampleLiquid',right,(0,-.014,-.002),(0,.04,-.002),.008,'Accent')
        cube('TubeCap',right,(0,.10,0),(.024,.016,.024),'Trim',.003)
    elif ident=='botany':
        loft('PlantPot',left,[(0,.030,.030,0),(.065,.045,.045,0)],'Accent',20)
        rod('PlantStem',left,(0,.06,0),(0,.23,0),.003,'Trim')
        for s,y in [(-1,.12),(1,.16),(-1,.20)]:
            leaf=ball('Leaf',left,(s*.028,y,0),(.038,.014,.02),'Leaf');leaf.rotation_euler.y=s*.4
        ring('MagnifyingGlass',right,(0,.10,0),.042,'Metal')
        rod('MagnifierHandle',right,(0,-.035,0),(0,.06,0),.006,'Trim')
    elif ident in ['student','international']:
        for j in range(3):
            cube('FoldedMap',left,((j-1)*.06,.09,-.01),(.061,.20,.006),'Page',.001)
            cube('MapRoute',left,((j-1)*.06,.10,-.014),(.015,.13,.002),'Accent',.001)
    elif ident=='career':
        board(left)
        rod('Pen',right,(0,-.04,0),(0,.09,0),.0035,'Accent')
    else:
        notebook(left)
        if ident=='physics':rod('Chalk',right,(0,-.012,0),(0,.037,0),.004,'Cream')


report={}
for ident,profile in APPEARANCE.items():
    exec(HELPERS,globals())
    palette={'Skin':color(profile['skin']),'Hair':color(profile['hair_color']),'Cream':(.87,.86,.79),'Ink':(.035,.045,.048),
             'Trouser':(.12,.16,.19),'Shoe':(.09,.12,.14),'Sole':(.52,.56,.55),'Page':(.88,.87,.79),'Cover':color(COLORS[ident]),'Metal':(.38,.43,.44)}
    for key,value in palette.items():
        M[key].diffuse_color=(*value,1);M[key].node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*value,1)
    accent=color(COLORS[ident])
    for key,value in {'Cloth':accent,'ClothDark':tuple(v*.70 for v in accent),'Trim':(.17,.22,.25),'Accent':(.63,.33,.14) if ident=='sports' else tuple(min(1,v*1.1+.05) for v in accent),'Screen':(.25,.51,.53),'Lip':(.34,.22,.18),'Leaf':(.24,.43,.18)}.items():material(key,key,value)
    if ident=='dining':
        M['Accent'].diffuse_color=(.40,.22,.12,1);M['Accent'].node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.40,.22,.12,1)
    if ident=='sports':
        M['Shoe'].diffuse_color=(.78,.81,.78,1);M['Shoe'].node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.78,.81,.78,1)
    for key,m in M.items():m.name='Hero_'+ident+'_'+key
    root=node('Hero_'+ident);human=human_asset(root,'study_walk');head=find(root,'Ambient_Head')
    if ident in ['dining','sports']:
        for side in ['L','R']:
            arm=find(root,'Ambient_Arm'+side);fore=find(root,'Ambient_Fore'+side)
            for obj in list(arm.children):
                if obj.type=='MESH' and obj.name.startswith('Sleeve'):bpy.data.objects.remove(obj,do_unlink=True)
            loft('ShortSleeve',arm,[(.02,.042,.042,0),(-.03,.055,.052,0),(-.14,.047,.045,0)],'Cloth',24)
            loft('ExposedUpperArm',arm,[(-.14,.035,.034,0),(-.28,.033,.033,0)],'Skin',24)
            for obj in fore.children:
                if obj.type=='MESH':obj.data.materials.clear();obj.data.materials.append(M['Skin'])
            if ident=='sports':
                leg=find(root,'Ambient_Leg'+side);knee=find(root,'Ambient_Knee'+side)
                for obj in list(leg.children):
                    if obj.type=='MESH' and obj.name.startswith('TrouserThigh'):bpy.data.objects.remove(obj,do_unlink=True)
                loft('SportShorts',leg,[(.02,.073,.067,0),(-.20,.06,.06,0)],'ClothDark',24)
                loft('ExposedThigh',leg,[(-.18,.049,.048,0),(-.36,.04,.041,0)],'Skin',24)
                for obj in knee.children:
                    if obj.type=='MESH':obj.data.materials.clear();obj.data.materials.append(M['Skin'])
                loft('SportSock',knee,[(-.25,.041,.042,0),(-.34,.04,.041,0)],'Cream',24)
    hairstyle(head,profile['hair'])
    head.scale=(1.07 if profile.get('beard') else 1.0,1.0,.98 if ident in ['finance','dorm'] else 1.0)
    if profile.get('glasses'):glasses(head,ident=='lab')
    if profile.get('beard'):
        for x in [-.034,-.017,0,.017,.034]:rod('Stubble',head,(x,.035,-.06),(x,.053,-.067),.002,'Hair')
    torso=find(root,'Ambient_Torso');torso.scale.x=profile['width']
    garment(human,head,profile,ident);hand_props(human,ident)
    for obj in root.children_recursive:
        if obj.type=='MESH':
            for modifier in obj.modifiers:
                if modifier.type=='BEVEL':modifier.segments=2
    # The design palette is sRGB; glTF baseColorFactor stores linear RGB.
    for m in M.values():
        rgba=m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value
        linear=tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgba[:3])
        m.diffuse_color=(*linear,1)
        m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*linear,1)
    export(root,'npc_'+ident+'.glb')
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/source'/('npc_'+ident+'.blend')))
    report[ident]={'asset':'npc_'+ident+'.glb','outfit':profile['outfit'],'hair':profile['hair'],'height_m':profile['height'],'rig':'Ambient_* articulated node contract'}
    print('NPC_ASSET_READY',ident,flush=True)
(ROOT/'godot/assets/npc_cast_manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('NPC_CAST_COMPLETE',len(report),flush=True)
