"""Photo-matched exterior replacements within the campus metre frame."""

import math
from visit_exteriors import VISITS, walkable_glazing


MATERIALS = {
    "AuditStone": ((.59, .505, .442), .83, 0),
    "AuditSoffit": ((.54, .535, .495), .81, 0),
    "AuditBase": ((.35, .205, .14), .75, 0),
    "AuditSteps": ((.46, .41, .34), .83, 0),
    "RoofMembrane": ((.205, .22, .21), .94, 0),
    "PavedForecourt": ((.37, .36, .32), .94, 0),
    "ParkingPaint": ((.82, .81, .735), .90, 0),
    "WindowFrame": ((.43, .445, .424), .42, .28),
    "LobbyGlass": ((.24, .36, .357), .2, .12),
    "DoorGlass": ((.45, .56, .55), .18, .08),
    "ClearCanopy": ((.38, .48, .50), .24, .16),
    "CurtainBlue": ((.32, .46, .46), .87, 0),
    "CurtainShade": ((.228, .360, .369), .89, 0),
    "DarkReveal": ((.102, .124, .11), .87, 0),
    "DoorStripe": ((.033, .19, .52), .51, 0),
    "DoorPull": ((.47, .064, .044), .42, .21),
    "ActivityBrick": ((.59, .535, .472), .88, 0),
    "ActivityStone": ((.53, .44, .39), .82, 0),
    "ActivityRedBase": ((.278, .139, .111), .68, 0),
    "ActivityPaving": ((.265, .274, .253), .88, 0),
    "ActivityInlay": ((.356, .35, .323), .88, 0),
    "CeilingSlot": ((.17, .19, .19), .76, 0),
    "ArchivePlaster": ((.49, .478, .401), .91, 0),
    "ArchiveInset": ((.29, .283, .254), .91, 0),
    "ArchiveBrick": ((.50, .407, .298), .91, 0),
    "ArchiveDoor": ((.34, .37, .362), .77, .1),
    "WeatheredConcrete": ((.41, .42, .40), .87, 0),
    "Ironwork": ((.095, .104, .097), .55, .25),
    "Handrail": ((.48, .501, .49), .38, .5),
    "BlackPlaque": ((.07, .08, .075), .72, .12),
    "GoldLetters": ((.67, .47, .155), .4, .5),
    "WhiteLetters": ((.74, .743, .70), .7, .06),
}
TRANSLUCENT = {"LobbyGlass": .43, "ClearCanopy": .32, "VisitGlass": .26, "DoorGlass": .19}

def install_photo_materials(material, materials, palette):
    for name, (color, roughness, metallic) in palette.items():
        key = "Photo" + name
        material(key,color,roughness,metallic)
        if name in TRANSLUCENT:
            mat = materials[key]
            alpha = TRANSLUCENT[name]
            mat.diffuse_color[3] = alpha
            shader = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
            shader.inputs['Alpha'].default_value = alpha
            mat.surface_render_method = 'BLENDED'


class Exterior:
    """Draw details in a facade's tangent/up/outward axes and emit matching solids."""

    def __init__(self, name, a, b, geo, slab, edgebox, inscription, collision):
        self.name = name
        self.origin = a
        self.end = b
        self.length = math.dist(a, b)
        self.tangent = ((b[0] - a[0]) / self.length, (b[1] - a[1]) / self.length)
        self.normal = (self.tangent[1], -self.tangent[0])
        self.geo = geo
        self.slab = slab
        self.edgebox = edgebox
        self.inscription = inscription
        self.collision = collision

    def at(self, s, y, d):
        a, t, n = self.origin, self.tangent, self.normal
        return (a[0] + s*t[0] + d*n[0], y, a[1] + s*t[1] + d*n[1])

    def polygon(self, s0, s1, d0, d1):
        return [[x, z] for x, _, z in (self.at(s, 0, d) for s, d in
                ((s0, d0), (s1, d0), (s1, d1), (s0, d1)))]

    def member(self, s0, s1, y0, y1, d0, d1, finish, solid=None):
        self.edgebox(self.origin,self.end,s0,s1,y0,y1,d0,d1,"Photo" + finish)
        if solid:
            self.block(solid, self.polygon(s0, s1, d0, d1), y0, y1)

    def block(self, name, polygon, bottom, top):
        self.collision.append({"name": f"{self.name}_{name}", "type": "polygon_prism",
                               "polygon": polygon, "bottom": bottom, "top": top})

    def nameplate(self, caption, s, y, d, height, finish="GoldLetters"):
        self.inscription(caption, self.at(s, y, d), height, "Photo" + finish,
                         heading=math.atan2(*self.normal))

    def sloped_member(self, s0, s1, y0, y1, height, d0, d1, finish):
        vertices = [self.at(s, y+dy, d) for d in (d0, d1) for s,y,dy in
                    ((s0,y0,0), (s1,y1,0), (s1,y1,height), (s0,y0,height))]
        self.geo(vertices, [(0,3,2,1), (4,5,6,7), (0,1,5,4), (3,7,6,2),
                            (0,4,7,3), (1,2,6,5)], "Photo" + finish)

    def rail(self, s0, s1, t0, t1, d, finish="Handrail", spacing=.22):
        self.sloped_member(s0, s1, t0+.99, t1+.99, .046, d-.028, d+.028, finish)
        self.sloped_member(s0, s1, t0+.11, t1+.11, .032, d-.018, d+.018, finish)
        count = max(1, math.ceil((s1-s0)/spacing))
        for i in range(count+1):
            s, y = s0+(s1-s0)*i/count, t0+(t1-t0)*i/count
            p = .022 if i in (0, count) else .009
            self.member(s-p, s+p, y+.10, y+1, d-p, d+p, finish)

    def member_with_gaps(self, start, end, bottom, top, d0, d1, finish, gaps):
        cursor = start
        for low, high in sorted(gaps):
            if low > cursor:
                self.member(cursor, min(low,end), bottom, top, d0, d1, finish)
            cursor = max(cursor,high)
            if cursor >= end:
                return
        if cursor < end:
            self.member(cursor,end,bottom,top,d0,d1,finish)

    def glazed_opening(self, start, end, bottom, top, depth, panes,
                       finish="LobbyGlass", doors=(), cross=None, frame="WindowFrame"):
        width = min(2.42, (end-start)/panes*1.35)
        if doors:
            spans = [(s-width/2,s+width/2) for s in doors]
            head = min(top,bottom+2.27)
            self.member_with_gaps(start,end,bottom,head,depth-.015,depth+.015,finish,spans)
            for low,high in spans:
                self.member(low,high,bottom,head,depth-.015,depth+.015,"DoorGlass")
            if head < top:
                self.member(start,end,head,top,depth-.015,depth+.015,finish)
        else:
            self.member(start,end,bottom,top,depth-.015,depth+.015,finish)
        for i in range(panes+1):
            s = start+(end-start)*i/panes
            self.member(s-.028, s+.028, bottom, top, depth+.012, depth+.075, frame)
        for y in (bottom, top, *(() if cross is None else (cross,))):
            self.member(start, end, y-.033, y+.033, depth+.012, depth+.078, frame)
        for s in doors:
            for x in (s-width/2, s, s+width/2):
                self.member(x-.018, x+.018, bottom+.02, bottom+2.27, depth+.025, depth+.065, frame)
            self.member(s-width/2,s+width/2,bottom+2.24,bottom+2.28,depth+.025,depth+.065,frame)
            self.member(s-width/2,s+width/2,bottom+.91,bottom+.965,depth+.076,depth+.086,"DoorStripe")
            for x in (s-.13, s+.13):
                self.member(x-.018,x+.018,bottom+.82,bottom+1.30,depth+.095,depth+.17,"DoorPull")

    def approach_steps(self, start, end, back, landing_end, base_y, count, rise, depth, finish):
        for i in range(count):
            top = base_y+(count-i)*rise
            end_of_tread = landing_end+i*depth
            self.member(start,end,base_y-.01,top,back,end_of_tread,finish,f"step_{i}")

    def stair_flight(self, name, start, end, d0, d1, low, high, rising, finish):
        count = math.ceil((high-low)/.174)
        tread = (end-start)/count
        self.sloped_member(start,end,(low if rising else high)-.24,
                           (high if rising else low)-.24,.24,d0,d1,finish)
        for i in range(count):
            s = start+i*tread
            y = low+(high-low)*(i+1 if rising else count-i)/count
            self.member(s,s+tread,y-.27,y,d0,d1,finish,f"{name}_tread_{i}")

    def stair_guard(self, name, s0, s1, y0, y1, d0, d1):
        count = math.ceil((s1-s0)/.65)
        for i in range(count):
            a, b = i/count, (i+1)/count
            self.block(f"{name}_{i}",self.polygon(s0+(s1-s0)*a,s0+(s1-s0)*b,d0,d1),
                       min(y0+(y1-y0)*a,y0+(y1-y0)*b)-.16,
                       max(y0+(y1-y0)*a,y0+(y1-y0)*b)+1.0)

    def depth_frame(self, s):
        a, b = self.at(s,0,0), self.at(s,0,1)
        return Exterior(self.name,a[::2],b[::2],self.geo,self.slab,self.edgebox,self.inscription,self.collision)


def auditorium(front, outline, height, sides):
    length = front.length
    base = .95
    lower_head, upper_head = 4.31, 6.20
    first, last = length*.164, length*.842
    partition = .97
    zone = last-first-2*partition
    front.slab(outline, .07, base, "PhotoAuditBase")
    front.slab(outline, height-.04, height+.23, "PhotoRoofMembrane")
    front.block("hall", outline, .07, height+.23)
    for side in sides:
        span = side.length
        side.member(-.14,span+.14,height-.39,height+.19,-.26,.55,"AuditSoffit")
        side.member(-.15,span+.15,height+.14,height+.61,-.28,.59,"AuditStone")
        if side is not front:
            side.member(0,span,base,height-.12,-.29,.015,"AuditStone")
            continue
        side.member(-1.08,span+1.08,height-.46,height+.19,-.34,1.25,"AuditSoffit")
        side.member(-1.12,span+1.12,height+.12,height+.68,-.36,1.29,"AuditStone")
        for s in (0,span):
            side.member(s-.08,s+.08,base,height-.34,-.28,.018,"AuditStone")
    front.member(0,first,base,height-.38,-.29,.02,"AuditStone")
    front.member(last,length,base,height-.38,-.29,.02,"AuditStone")
    for a,b in ((0,first),(last,length)):
        front.member(a,b,base,base+.83,.015,.088,"AuditBase")
    front.member(first,last,upper_head,height-.38,-.29,.02,"AuditStone")
    front.member(first,last,lower_head,lower_head+.57,-.29,.018,"AuditStone")
    start = first
    for i, proportion in enumerate((.278,.445,.277)):
        end = start+zone*proportion
        step=(end-start)/(5 if i==1 else 4)
        walkable_glazing(front,start+.045,end-.045,lower_head,-.14,step,"LobbyGlass","WindowFrame")
        for k in range(1,round((end-start)/step)):
            s=start+k*step
            for y in (base+2.53,lower_head-.17):
                front.member(s-.062,s+.062,y-.055,y+.055,-.128,-.099,"Handrail")
        front.member(start,end,lower_head+.58,upper_head,-.16,-.085,"CurtainBlue")
        part_count=max(1,int((end-start)/.16))
        width=(end-start)/part_count
        for k in range(1,part_count):
            s = start+k*width
            front.member(s,s+width*.32,lower_head+.59,upper_head-.012,-.081,-.060,"CurtainShade")
        if i < 2:
            front.member(end,end+partition,base,upper_head,-.31,.035,"AuditStone")
            front.member(end+.35,end+.62,base,upper_head-.07,.036,.082,"AuditBase")
            front.member(end-.04,end+partition+.04,upper_head-.11,upper_head+.07,.03,.135,"AuditStone")
        start = end+partition
    back=-VISITS[front.name]["depth"]
    front.member(first,last,base,height-.54,back-.14,back-.06,"DarkReveal")
    front.member(first,last,base-.012,base+.018,-3.34,.02,"AuditSteps")
    for s in (first,(first+last)/2,last):
        front.member(s-.14,s+.14,base,lower_head,back-.01,back+.20,"AuditSoffit")
    front.approach_steps(.35,length-.35,-.02,1.05,.14,5,.162,.34,"AuditSteps")
    front.member(-1,length+1,.06,.12,2.41,13.4,"PavedForecourt","forecourt")
    for s in range(3,int(length-2),3):
        front.member(s-.04,s+.04,.122,.126,2.62,7.1,"ParkingPaint")
        front.member(s-.52,s+.52,.124,.128,7.045,7.12,"ParkingPaint")
    front.member(.2,.69,1.88,2.13,.017,.055,"BlackPlaque")
    front.nameplate("大礼堂",.445,2.005,.061,.125)


def circular_stair_screen(front, station, height, depth):
    """Square masonry panel, with a genuinely recessed circular center."""
    divisions = 24
    points = []
    for i in range(divisions):
        a = 2*math.pi*i/divisions
        x,y = math.cos(a),math.sin(a)
        q = .78/max(abs(x),abs(y))
        points.extend((front.at(station+x*q,height+y*q,depth),
                       front.at(station+x*.44,height+y*.44,depth),
                       front.at(station+x*.39,height+y*.39,depth-.12)))
    outer, inner = [], []
    for i in range(divisions):
        a,b = i*3, (i+1)%divisions*3
        outer.append((a,b,b+1,a+1))
        inner.append((a+1,b+1,b+2,a+2))
    front.geo(points,outer,"PhotoActivityBrick")
    front.geo(points,inner,"PhotoActivityStone")
    front.geo(points,[tuple(i*3+2 for i in range(divisions))],"PhotoDarkReveal")


def activity_center(front, outline, height, sides):
    width = front.length
    roof_level = 10.45
    side_panels = ((0,width*.29,0,17.15),
                   (width*.29,width*.68,6.54,height),
                   (width*.68,width,0,17.45))
    inset = -10.7
    court = front.polygon(0,width,inset,0)
    columns = [(width*.031,-.65), (width*.29,5.87),
               (width*.68,5.87), (width*.965,-.65),
               (width*.031,-6.16),(width*.965,-6.16)]
    front.member(-.7,width+.7,.04,.153,inset,14.4,"ActivityPaving","courtfloor")
    for s in range(0,int(width),3):
        front.member(s-.025,s+.025,.153,.158,-10.5,14.39,"ActivityInlay")
    for d in range(-9,15,3):
        front.member(-.69,width+.69,.153,.158,d-.025,d+.025,"ActivityInlay")
    lower = [court[0],outline[6],outline[5],court[1]]
    front.slab(lower,roof_level,roof_level+.24,"PhotoAuditSoffit")
    front.slab(lower,17.04,17.24,"PhotoRoofMembrane")
    front.block("upper_volume",lower,roof_level,17.24)
    front.slab(lower,.08,.18,"PhotoWeatheredConcrete")
    front.block("closed_core",lower,.08,roof_level)
    for side in sides:
        if side is front or side.length < 1:
            continue
        side.member(0,side.length,roof_level+.23,17.09,-.28,.015,"ActivityBrick")
        side.member(0,side.length,17.04,17.24,-.31,.105,"AuditSoffit")
    # The two long return walls begin behind the column line.
    for a,b in ((court[0],outline[6]),(outline[5],court[1]),(outline[6],outline[5])):
        front.edgebox(a,b,0,math.dist(a,b),.18,roof_level,-.3,.025,"PhotoActivityBrick")
    for i,(start,end,d,top) in enumerate(side_panels):
        front.member(start,end,roof_level,top,d-.27,d+.085,"ActivityBrick")
        front.member(start-.14,end+.14,roof_level-.14,roof_level+.245,inset,d+.35,"AuditSoffit")
        front.member(start,end,top-.22,top+.04,inset,d+.17,"RoofMembrane")
        for s in (start,end):
            front.member(s-.135,s+.135,roof_level,top,inset,d+.02,"ActivityBrick")
        front.block(f"canopy_{i}",front.polygon(start,end,inset,d),roof_level,top)
        front.member(start+.7,end-.7,top+.64,top+.98,d-.74,d-.35,"AuditSoffit")
        for s in (start+.7,end-.7):
            front.member(s-.11,s+.11,top+.03,top+.65,d-.73,d-.36,"AuditSoffit")
    for i, (s,d) in enumerate(columns):
        front.member(s-.74,s+.74,.153,.35,d-.74,d+.74,"ActivityRedBase",f"columnfoot_{i}")
        front.member(s-.66,s+.66,.35,1.02,d-.66,d+.66,"ActivityRedBase",f"columnbase_{i}")
        front.member(s-.70,s+.70,1.02,1.17,d-.70,d+.70,"ActivityRedBase")
        front.member(s-.56,s+.56,1.17,10.30,d-.56,d+.56,"ActivityStone",f"column_{i}")
        front.member(s-.68,s+.68,10.15,10.49,d-.68,d+.68,"ActivityStone")
    for s in range(4,int(width)-3,3):
        for d in (-9,-7,-5,-3,-1):
            front.member(s-.68,s+.68,10.294,10.309,d-.055,d+.055,"CeilingSlot")
        if width*.31<=s<=width*.66:
            for d in (1,3,5):
                front.member(s-.68,s+.68,10.294,10.309,d-.055,d+.055,"CeilingSlot")
    front.member(0,width,3.32,3.71,inset-.04,inset+.08,"ActivityBrick")
    front.member(0,width,5.0,6.45,inset-.04,inset+.08,"ActivityBrick")
    front.member(0,width,7.35,8.89,inset-.04,inset+.08,"ActivityBrick")
    front.member(0,width,9.77,roof_level,inset-.04,inset+.08,"ActivityBrick")
    for a,b in ((.15,width*.11),(width*.88,width-.15)):
        front.member(a,b,.155,9.78,inset-.08,inset+.12,"ActivityBrick")
    room=VISITS[front.name]
    a,b=(front.at(s,0,inset) for s in (0,width))
    entry=Exterior(front.name,(a[0],a[2]),(b[0],b[2]),front.geo,front.slab,front.edgebox,
                   front.inscription,front.collision)
    front.member(0,width,.16,roof_level-.09,inset-room["depth"]-.19,inset-room["depth"]-.12,"DarkReveal")
    walkable_glazing(entry,width*.11,width*.88,3.30,.015,2.0,"LobbyGlass","WindowFrame")
    s0,s1=width*.395,width*.595
    front.approach_steps(s0,s1,inset-.10,inset+.38,.15,2,.09,.32,"ActivityStone")
    for fraction in (.22,.46,.76):
        st=width*fraction
        front.member(st-.70,st+.70,2.93,3.21,inset+.018,inset+.07,"BlackPlaque")
    for floor in (3.7,6.44,8.88):
        front.glazed_opening(width*.11,width*.88,floor,floor+1.08,inset+.01,17,finish="CurtainBlue")
    front.member(width*.20,width*.80,3.43,3.73,inset-.08,inset+2.8,"ActivityBrick","gallery")
    front.member(width*.20,width*.80,3.72,4.60,inset+2.60,inset+2.79,"ActivityBrick","gallery_guard")
    front.rail(width*.22,width*.78,3.73,3.73,inset+2.68,spacing=1.15)
    for mirrored in (False, True):
        # Both stairs face the open plaza; flights and protective walls mirror across its centerline.
        lo, hi = (3.7,10.55) if not mirrored else (width-10.55,width-3.7)
        s = lo + 1.62 if not mirrored else hi - 1.62
        for y in (2.23,5.66,8.85):
            circular_stair_screen(front,s,y,-9.12)
        for level, bottom in enumerate((.153,3.73)):
            middle, top = bottom+1.79,bottom+3.58
            prefix = f"stair_{int(mirrored)}_{level}"
            front.stair_flight(prefix+"a",lo,hi,-6.87,-4.93,bottom,middle,mirrored,"ActivityBrick")
            front.stair_flight(prefix+"b",lo,hi,-9.04,-7.11,middle,top,not mirrored,"ActivityBrick")
            landing_lo = hi if mirrored else lo-1.91
            landing_hi = hi+1.91 if mirrored else lo
            front.member(landing_lo,landing_hi,middle-.23,middle,-9.08,-4.91,"ActivityBrick",prefix+"landing")
            front.member(landing_lo,landing_hi,middle-.21,middle+.77,-5.00,-4.82,"ActivityBrick",prefix+"landing_guard")
            front.rail(landing_lo,landing_hi,middle,middle,-4.89,spacing=.85)
            # Keep the return bridge to the gallery inside the covered facade.
            mid_lo, mid_hi = (lo-1.8,lo+.02) if mirrored else (hi-.02,hi+1.8)
            front.member(mid_lo,mid_hi,top-.26,top,inset+.07,-6.82,"ActivityBrick",prefix+"upper_landing")
            front.member(lo,hi,middle-.12,middle+.18,-7.09,-6.89,"ActivityBrick")
            l_y, r_y = (bottom,middle) if mirrored else (middle,bottom)
            front.sloped_member(lo,hi,l_y-.17,r_y-.17,.92,-4.99,-4.8,"ActivityBrick")
            front.rail(lo,hi,l_y,r_y,-4.88,spacing=.9)
            front.stair_guard(prefix+"a_guard",lo,hi,l_y,r_y,-5.00,-4.82)
            l_y, r_y = (top,middle) if mirrored else (middle,top)
            front.sloped_member(lo,hi,l_y-.17,r_y-.17,.85,-7.20,-7.03,"ActivityBrick")
            front.rail(lo,hi,l_y,r_y,-7.13,spacing=.9)
            front.stair_guard(prefix+"b_guard",lo,hi,l_y,r_y,-7.19,-7.06)
    front.nameplate("师生活动中心",width/2,3.58,inset+.095,.35)


def archives(front, outline, height, sides):
    front.slab(outline,.08,.24,"PhotoWeatheredConcrete")
    front.slab(outline,height-.17,height+.10,"PhotoRoofMembrane")
    front.block("archives",outline,.08,height+.10)
    for i, side in enumerate(sides):
        span = side.length
        side.member(0,span,height-.21,height+.13,-.31,.37,"AuditSoffit")
        side.member(0,span,height+.08,height+.17,-.35,.40,"WeatheredConcrete")
        if i not in (0,2):
            side.member(0,span,.24,height-.15,-.31,.012,"ArchivePlaster")
            continue
        side.member(0,span,.24,1.45,-.30,.018,"ArchivePlaster")
        side.member(0,span,2.93,4.96,-.30,.017,"ArchivePlaster")
        side.member(0,span,6.24,height-.17,-.30,.019,"ArchivePlaster")
        n = int(span/11)
        for k in range(n):
            a,b = (k+.11)*span/n,(k+.89)*span/n
            edge = (k+1)*span/n if k < n-1 else span
            for base,top in ((1.45,2.93),(4.96,6.24)):
                side.member(k*span/n,a,base,top,-.3,.02,"ArchivePlaster")
                side.member(b,edge,base,top,-.3,.02,"ArchivePlaster")
                side.member(a,b,base,top,-.25,-.18,"ArchiveInset")
                for s in (a+.88,(a+b)/2,b-.88):
                    side.glazed_opening(s-.30,s+.30,base+.13,top-.11,-.158,1,finish="CurtainBlue",
                                        cross=top-.43,frame="Ironwork")
                side.member(a,b,base-.048,base+.016,-.24,.115,"WeatheredConcrete")
    # The signed iron gate is offset from the blank gable, at the side-lane mouth.
    for i,s in enumerate((-4.92,-.63)):
        front.member(s-.32,s+.32,.10,2.72,-.39,.34,"ArchiveBrick",f"gatepier_{i}")
        front.member(s-.37,s+.37,2.70,2.82,-.43,.41,"ArchiveBrick")
    front.member(-4.60,-.96,.33,.38,-.055,.055,"Ironwork")
    front.member(-4.60,-.96,2.17,2.24,-.055,.055,"Ironwork")
    for i in range(25):
        s=-4.59+i*.15
        front.member(s-.012,s+.012,.36,2.38,-.02,.03,"Ironwork")
    front.block("closed_gate",front.polygon(-4.62,-.93,-.065,.065),.136,2.36)
    front.member(-7.65,-5.22,.1,.73,-.22,.24,"ArchiveBrick","fence_base")
    front.member(-7.65,-5.22,.74,.80,-.24,.25,"ArchiveBrick")
    for i in range(15):
        s=-7.6+i*.17
        front.member(s-.013,s+.013,.76,2.25,-.022,.022,"Ironwork")
    for y in (.86,1.96):
        front.member(-7.65,-5.24,y,y+.035,-.03,.03,"Ironwork")
    front.block("fence",front.polygon(-7.64,-5.23,-.04,.04),.74,2.26)
    front.member(-5.11,-4.73,1.17,2.25,.338,.375,"BlackPlaque")
    for k,ch in enumerate("档案馆"):
        front.nameplate(ch,-4.92,2.01-k*.294,.38,.258)
    front.member(-7.7,.05,.04,.124,-4.0,4.4,"PavedForecourt","side_approach")
    side = sides[2]
    side.member(0,side.length,.075,.126,.05,3.60,"PavedForecourt","side_lane")
    # The flight along the blank west wall leaves a clear lane between the stair and the road.
    west = front
    west.member(.03,west.length,.075,.129,.04,3.72,"PavedForecourt","stair_approach")
    west.stair_flight("archive_short",2.7,4.62,.10,1.60,.129,1.16,True,"WeatheredConcrete")
    west.member(4.62,6.08,.11,1.16,.08,1.61,"ArchivePlaster","archive_low_landing")
    west.stair_flight("archive_inner",6.08,11.78,.10,1.64,1.16,3.15,True,"WeatheredConcrete")
    west.member(11.78,13.37,2.89,3.15,.08,3.20,"WeatheredConcrete","archive_mid_landing")
    west.stair_flight("archive_return",6.08,11.78,1.67,3.21,3.15,5.15,False,"WeatheredConcrete")
    west.member(4.45,6.08,4.90,5.15,.09,3.21,"WeatheredConcrete","archive_high_landing")
    for s,y in ((5.40,1.16),(5.30,5.15)):
        west.member(s-.46,s+.46,y,y+2.06,-.018,.064,"ArchiveDoor")
        west.member(s-.52,s-.46,y,y+2.12,.01,.09,"WeatheredConcrete")
        west.member(s+.46,s+.52,y,y+2.12,.01,.09,"WeatheredConcrete")
        west.member(s-.52,s+.52,y+2.04,y+2.12,.01,.09,"WeatheredConcrete")
    west.member(4.60,6.02,7.24,7.40,.05,1.14,"AuditSoffit")
    for s,y in ((5.75,4.90),(12.48,2.89)):
        west.member(s-.16,s+.16,.129,y,2.58,2.91,"ArchivePlaster",f"archive_pier_{s}")
    rails = ((2.7,4.62,.129,1.16,1.61),(4.62,6.08,1.16,1.16,1.62),
             (6.08,11.78,1.16,3.15,1.65),(11.78,13.37,3.15,3.15,3.20),
             (6.08,11.78,5.15,3.15,3.21),(4.45,6.08,5.15,5.15,3.23))
    for i, (a,b,y0,y1,d) in enumerate(rails):
        west.rail(a,b,y0,y1,d)
        west.stair_guard(f"archive_rail_{i}",a,b,y0,y1,d-.03,d+.03)


DETAILS = {
    "271958271": auditorium,
    "267624861": activity_center,
    "271958263": archives,
}


def build_detail(asset, building, geo, slab, edgebox, inscription, solids):
    outline = building["outline"]
    sides = [Exterior(asset,a,b,geo,slab,edgebox,inscription,solids)
             for a,b in zip(outline,outline[1:]+outline[:1])]
    wid = building["osm_way"]
    front = sides[4 if wid == "271958271" else 5]
    if wid == "267624861":
        front = Exterior(asset,outline[7],outline[4],geo,slab,edgebox,inscription,solids)
        sides = [sides[4],sides[5],sides[6]]
    DETAILS[wid](front, outline, 7.65 if wid == "271958263" else building["height"], sides)
