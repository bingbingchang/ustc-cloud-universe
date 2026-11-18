"""Individual facades from the USTC GIS albums; coordinates are Godot metres."""

import math

from mapped_landmark_details import Exterior
from visit_exteriors import VISITS, walkable_glazing


SCIENCE_MATERIALS = {
    "ReportCladding": ((.238,.069,.028),.87,0),
    "ReportStone": ((.66,.66,.62),.78,0),
    "ReportRecess": ((.10,.145,.143),.73,.02),
    "ReportGlass": ((.087,.161,.19),.23,.26),
    "LabTile": ((.59,.557,.473),.86,0),
    "LabWhite": ((.62,.635,.61),.86,0),
    "LabGoldPanel": ((.49,.397,.247),.84,0),
    "LabSill": ((.43,.435,.406),.66,0),
    "LabCanopy": ((.52,.455,.394),.79,0),
    "LabGranite": ((.355,.195,.15),.53,0),
    "LabBlueGlass": ((.102,.287,.412),.20,.29),
    "LabDarkGlass": ((.109,.19,.218),.27,.20),
    "LabGlare": ((.185,.277,.30),.30,.17),
    "LabAluminium": ((.235,.265,.27),.39,.47),
    "LabShadow": ((.093,.107,.102),.79,0),
    "ResourcesGrey": ((.325,.344,.345),.86,0),
    "ResourcesTrim": ((.444,.452,.45),.79,0),
    "ResourcesLouver": ((.313,.214,.139),.82,0),
    "MatterGrey": ((.345,.365,.373),.82,0),
    "MatterPier": ((.289,.304,.315),.86,0),
    "MatterFin": ((.403,.423,.427),.70,.04),
    "MatterScreen": ((.68,.69,.66),.67,.17),
    "MatterRedPanel": ((.44,.115,.077),.65,.13),
    "NoParkingPaint": ((.80,.65,.28),.86,0),
}


def report_hall(front, sides, outline, height, _levels, _facade):
    front.block("hall", outline, -.24, height+.21)
    front.slab(outline,height-.27,height+.14,"PhotoRoofMembrane")
    front.slab(outline,.09,.34,"PhotoReportStone")
    lake = sides[2]
    for side in sides:
        length = side.length
        if side is lake or side is front:
            continue
        finish = "ReportStone" if side in (sides[0],sides[1],sides[3],sides[4],sides[10]) else "ReportCladding"
        side.member(0,length,-.37,2.5,-.34,.018,"ReportStone")
        side.member(0,length,2.5,height-.10,-.35,.10,finish)
        side.member(0,length,height-.10,height+.20,-.32,.15,"ReportStone")
    n = lake.length
    lake.member(-.25,n+.25,-.42,.18,-.38,.95,"ReportRecess")
    lake.member(-.52,n+.52,.10,.34,-.78,1.62,"ReportStone","promenade")
    lake.member(-.52,n+.52,.34,1.05,1.46,1.63,"ReportStone","parapet")
    for s in (-.52,n+.36):
        lake.member(s,s+.16,.34,1.04,-.78,1.60,"ReportStone",f"return_{s}")
    for s in (1.3,n*.37,n*.68,n-1.25):
        lake.member(s-.26,s+.26,-.85,.11,-.20,.52,"ReportRecess")
    lake.glazed_opening(.49,n-.49,.36,2.72,-.32,15,"ReportGlass",cross=2.01,frame="LabAluminium")
    lake.member(-.20,n+.20,2.65,2.81,-.46,.95,"LabAluminium")
    lake.member(-.18,n+.18,2.805,2.86,-.38,.91,"ClearCanopy")
    for i in range(15):
        s=.50+i*(n-1)/14
        lake.member(s-.021,s+.021,2.78,2.855,-.47,.93,"LabAluminium")
    lake.member(-.45,n+.45,2.87,3.19,-.36,.25,"ReportStone")
    lake.glazed_opening(.51,n-.52,3.19,6.48,-.065,13,"ReportGlass",cross=5.75,frame="LabAluminium")
    for s in (.0,n-.54):
        lake.member(s,s+.55,3.10,6.56,-.35,.20,"ReportStone")
    lake.member(-.46,n+.46,6.48,height+.21,-.41,.21,"ReportStone")
    lake.member(-.49,n+.49,height+.13,height+.21,-.44,.25,"ReportStone")
    for k in (2,3,6,9,10):
        s = .51+(n-1.03)*k/13
        w = (n-1.03)/13-.095
        vertices = [lake.at(s+x,y,d) for x,y,d in
                    ((.03,4.01,.25),(w,4.01,.25),(w,4.63,.032),(.03,4.63,.032))]
        lake.geo(vertices,[(0,1,2,3)],"PhotoReportGlass")
        lake.member(s+.02,s+w+.02,3.994,4.032,.235,.263,"LabAluminium")
    width = front.length
    front.member(-.14,width+.14,2.58,height-.06,-.37,.23,"ReportCladding")
    front.member(-.14,width+.14,height-.06,height+.13,-.40,.26,"LabSill")
    front.member(.0,width,.28,2.66,-.38,-.23,"ReportStone")
    for s in (.35,width*.36,width*.68,width-.35):
        front.member(s-.23,s+.23,.22,2.65,-.29,.035,"LabSill")
    # GIS album 10632 shows the side service leaf at the left edge when
    # viewed from the road. Its destination has no corresponding interior.
    door = width-2.0
    front.member(door-.73,door+.73,.30,2.47,-.221,-.16,"ReportRecess")
    front.member(door-.60,door+.60,.34,2.34,-.156,-.11,"LabGranite")
    front.member(door+.31,door+.35,1.19,1.40,-.10,-.04,"Handrail")
    front.approach_steps(door-.93,door+.92,-.02,.48,.13,2,.105,.31,"ReportStone")
    front.member(.32,width-.20,.045,.130,.03,3.50,"PavedForecourt","paved_entry")
    for i in range(7):
        d = .087+i*.49
        front.member(.34,width-.22,.131,.138,d,d+.053,"LabGranite")


def band_windows(side, low, high, levels, pitch, wall, *,
                 window="LabDarkGlass", sill="LabSill", air_units=False):
    n = max(1,round(side.length/pitch))
    bay = side.length/n
    step = (high-low)/levels
    for row in range(levels):
        y = low+row*step
        sill_y = y+step*.285
        lintel_y = y+step*.825
        side.member(0,side.length,y,sill_y,-.41,.012,wall)
        side.member(0,side.length,lintel_y,y+step,-.41,.012,wall)
        for k in range(n):
            a,b = k*bay,(k+1)*bay
            margin = min(.43,bay*.23)
            left,right = a+margin,b-margin
            side.member(a,left,sill_y,lintel_y,-.40,.013,wall)
            side.member(right,b,sill_y,lintel_y,-.40,.013,wall)
            side.glazed_opening(left,right,sill_y+.04,lintel_y-.035,-.215,3,
                                window if (k+row)%7 else "LabGlare",
                                cross=lintel_y-step*.15,frame="LabAluminium")
            side.member(left-.025,right+.025,sill_y-.054,sill_y+.025,-.30,.13,sill)
            if air_units and (k+3*row)%4==1:
                s=right-.37
                side.member(s-.26,s+.26,sill_y-.44,sill_y-.048,.018,.30,"LabWhite")
                side.member(s-.20,s+.20,sill_y-.375,sill_y-.089,.303,.318,"LabSill")


def entrance(front, start, end, *, top=3.76, eave=1.7, inset=-.11,
             stone="LabCanopy", floor="LabGranite", label="", steps=3, rise=.15):
    y = .14 + steps*rise
    front.member(start,end,top-.46,top,inset-.35,eave,stone)
    front.member(start,end,top-.08,top+.035,-.34,eave+.054,"LabSill")
    for i,s in enumerate((start+.25,end-.25)):
        front.member(s-.24,s+.24,y,top-.42,eave-.79,eave-.26,stone,f"entry_pier_{i}")
    front.member(start+.32,end-.32,y,top-.46,inset-1.9,inset-1.80,"LabShadow")
    front.member(start+.32,end-.32,y-.08,y,inset-1.80,inset,"LabCanopy")
    mid = (start+end)*.5
    front.glazed_opening(start+.46,end-.46,y,top-.50,inset,5,
                         doors=(mid,),cross=min(y+2.42,top-.55),frame="LabAluminium")
    front.approach_steps(start-.20,end+.20,-.10,eave+.03,.14,steps,rise,.34,floor)
    if label:
        front.nameplate(label,mid,top-.236,eave+.036,.30)
    return y


def glazed_turret(front, center, radius, height, floors):
    segments = 12
    rise = (height-.32)/floors
    for k in range(segments):
        a = front.at(center+radius*math.cos(k*math.pi/segments),0,
                     -.21+radius*math.sin(k*math.pi/segments))[::2]
        b = front.at(center+radius*math.cos((k+1)*math.pi/segments),0,
                     -.21+radius*math.sin((k+1)*math.pi/segments))[::2]
        facet = Exterior(front.name,b,a,front.geo,front.slab,front.edgebox,front.inscription,front.collision)
        facet.member(0,facet.length,.25,height-.11,-.045,.024,"LabBlueGlass")
        for i in range(floors+1):
            y = .30+rise*i
            facet.member(-.018,facet.length+.018,y-.105,y+.105,-.075,.068,"LabAluminium")
        if k%2==0:
            facet.member(.0,.034,.24,height-.10,-.02,.045,"LabAluminium")
    footprint = [front.at(center+radius*math.cos(k*math.pi/segments),0,
                          -.21+radius*math.sin(k*math.pi/segments))[::2] for k in range(segments+1)]
    front.slab(footprint,height-.16,height+.12,"PhotoLabSill")
    front.block("stair_turret",footprint,.05,height+.12)


def modern_physics(front, sides, outline, height, levels, facade):
    facade(outline,levels,height,"PhotoLabTile",3.6,detail_edges=(3,))
    width = front.length
    band_windows(front,3.83,height,levels-1,3.82,"LabTile")
    mid = width*.53
    for a,b in ((.26,mid-1.34),(mid+1.34,width-.28)):
        front.glazed_opening(a,b,.30,3.84,-.29,max(2,round((b-a)/2.2)),
                             "LabDarkGlass",cross=2.91,frame="LabAluminium")
    front.glazed_opening(mid-1.34,mid+1.34,3.53,3.84,-.29,2,"LabDarkGlass",frame="LabAluminium")
    for s in range(2,int(width),4):
        if abs(s-mid)>1.55:
            front.member(s-.20,s+.20,.25,3.85,-.29,.13,"LabTile")
    glazed_turret(front,width-3.88,2.67,height+.10,levels)
    front.member(.48,3.87,.27,height+.08,-.14,.57,"LabBlueGlass")
    for floor in range(1,levels*2):
        y=height*floor/(levels*2)
        front.member(.36,4.02,y-.076,y+.082,-.18,.88,"LabSill")
    for s in (1.51,2.75):
        front.member(s-.014,s+.014,.25,height,.56,.604,"LabAluminium")
    front.member(mid-5.2,mid+5.2,.07,.13,2.59,8.0,"PavedForecourt","court")
    entrance(front,mid-4.95,mid+4.95,top=3.99,eave=2.48,
             stone="LabCanopy",floor="LabSill",label="近代物理系",steps=2)
    for s in range(1,int(width),4):
        front.member(s-.20,s+.20,height,height+1.42,-3.37,.02,"LabTile")
    front.member(.06,width-.1,height+1.22,height+1.58,-3.39,.028,"LabTile")


def molecule(front, sides, outline, height, levels, facade):
    facade(outline,levels,height,"PhotoLabTile",4.2,detail_edges=(1,))
    w = front.length
    band_windows(front,4.87,height,levels-1,4.45,"LabTile")
    mid = w*.485
    front.member_with_gaps(.05,w-.05,.30,3.25,-.36,-.19,"LabTile",[(mid-1.32,mid+1.32)])
    front.member(.05,w-.05,3.25,4.87,-.36,-.19,"LabTile")
    front.member(.15,w-.15,.07,.133,2.45,5.9,"PavedForecourt","paved_entry")
    entrance(front,w*.21,w*.76,top=3.71,eave=2.17,
             stone="LabCanopy",label="",steps=2)
    front.member(w*.16,w*.81,3.70,4.89,-.23,2.21,"LabCanopy")
    front.member(w*.16,w*.81,4.88,5.03,-.34,2.28,"LabSill")
    for s in (w*.22,w*.38,w*.54,w*.70):
        front.member(s-.025,s+.025,3.74,4.89,2.210,2.222,"LabSill")
    front.member(w*.763,w*.806,.15,3.71,.32,2.09,"LabCanopy","side_cheek")
    front.member(w*.224,w*.34,2.23,2.65,-.166,-.137,"BlackPlaque")
    front.nameplate("单分子科学楼",w*.28,2.45,-.124,.28,"WhiteLetters")


def resources(front, sides, outline, height, levels, facade):
    w = front.length
    facade(outline,levels,height,"PhotoResourcesGrey",4.7,detail_edges=(14,23,24))
    for side in (sides[14],sides[24]):
        band_windows(side,5.47,height,levels-1,4.62,"ResourcesGrey",sill="ResourcesTrim")
        n = max(3,round(side.length/4.2))
        for k in range(n):
            s=(k+.5)*side.length/n
            side.glazed_opening(s-.60,s+1.27,1.09,5.40,-.20,2,"LabDarkGlass",frame="LabAluminium")
            side.member(s-1.28,s-.64,.33,5.5,-.33,.13,"ResourcesGrey")
            for i in range(15):
                y=.81+i*.285
                side.member(s-.62,s-.28,y,y+.048,-.20,.011,"ResourcesLouver")
            side.member(s+1.28,s+1.63,.33,5.52,-.34,.19,"ResourcesGrey")
        side.member(0,side.length,5.43,5.91,-.30,.30,"ResourcesTrim")
    band_windows(front,5.91,height,levels-1,4.87,"ResourcesGrey",sill="ResourcesTrim")
    front.member(-.09,w+.09,5.43,5.92,-.57,.76,"ResourcesTrim")
    a,b=w*.39,w*.68
    front.member(0,a,.28,5.43,-.45,-.30,"ResourcesGrey")
    front.member(b,w,.28,5.43,-.45,-.30,"ResourcesGrey")
    front.member(a,b,1.02,5.39,-2.52,-2.42,"LabShadow")
    front.member(a,b,.93,1.02,-2.42,-.19,"ResourcesTrim")
    front.glazed_opening(a,b,3.17,5.39,-.27,9,"LabDarkGlass",cross=3.21,frame="LabAluminium")
    front.glazed_opening(a,b,1.02,3.17,-.19,9,"LobbyGlass",doors=((a+b)/2,),cross=2.78)
    front.member(a-3.24,b+2.2,5.26,5.43,-.43,3.20,"LabShadow")
    for i in range(65):
        s=a-3.21+i*(b-a+5.35)/65
        front.member(s,s+.044,5.245,5.29,-.42,3.19,"LabAluminium")
    for i,s in enumerate((a-1.5,a+3.26,b+1.10)):
        front.member(s-.37,s+.37,.140,5.34,1.43,2.12,"ResourcesGrey",f"portico_{i}")
    for s in (a+1.20,(a+b)/2,b-1.08):
        front.member(s-.32,s+.32,5.194,5.246,2.18,2.69,"WhiteLetters")
    front.approach_steps(a-2.14,b+1.68,-.02,2.18,.14,6,.148,.33,"LabCanopy")
    front.member(a-2.2,b+2.31,.060,.135,3.88,8.80,"PavedForecourt","forecourt")
    front.nameplate("化学与材料科学学院",(a+b)/2,5.67,.771,.36,"WhiteLetters")
    for k in range(11):
        s=a-2.12+k*(b-a+3.78)/10
        front.member(s-.031,s+.031,.136,.144,5.20,8.1,"NoParkingPaint")


def hex_screen(side, start, end, bottom, top):
    """Extrude each shared edge once so the screen stays a single surface."""
    radius = .88
    dx,dy = math.sqrt(3)*radius, 1.5*radius
    edges = set()
    for row in range(int((top-bottom-2*radius)/dy)+1):
        y = bottom+radius+row*dy
        for col in range(int((end-start)/dx)):
            s = start+dx*(col+.5+(row%2)*.5)
            if s+dx*.5 > end+.001:
                continue
            corners = [(s+radius*math.cos(math.radians(30+i*60)),
                        y+radius*math.sin(math.radians(30+i*60))) for i in range(6)]
            for a,b in zip(corners,corners[1:]+corners[:1]):
                edges.add(tuple(sorted((tuple(round(v,4) for v in a),tuple(round(v,4) for v in b)))))
    faces = [(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)]
    for (s0,y0),(s1,y1) in sorted(edges):
        length=math.hypot(s1-s0,y1-y0)
        ds,dy=-(y1-y0)*.049/length,(s1-s0)*.049/length
        side.geo([side.at(s+sign*ds,y+sign*dy,d) for d in (.10,.28)
                  for s,y,sign in ((s0,y0,-1),(s1,y1,-1),(s1,y1,1),(s0,y0,1))],
                 faces,"PhotoMatterScreen")


def materials_tower(front, sides, outline, height, levels, _facade):
    code = front.name.split("_")[-1]
    screens = {"686068242": (1,), "686068854": (2,5), "686069052": (3,4)}[code]
    base = 5.15
    front.block("tower",outline,.08,height+.25)
    front.slab(outline,.08,.30,"PhotoMatterPier")
    front.slab(outline,height-.24,height+.14,"PhotoRoofMembrane")
    for i,side in enumerate(sides):
        w = side.length
        if w < 9.0:
            side.member(0,w,.3,height,-.32,.018,"MatterPier")
            continue
        side.member(0,w,height-.24,height+.67,-.41,.40,"MatterGrey")
        for s in (0,w):
            side.member(s-.32,s+.32,.25,height+.44,-.31,.24,"MatterPier")
        if w>35 and i in (0,1,2,3):
            n=max(5,round((w-6.4)/1.40))
            first,last=3.2,w-3.2
            side.member(.32,w-.32,base,height-1.58,-.30,-.23,"LabDarkGlass")
            for j in range(n+1):
                s=first+j*(last-first)/n
                side.member(s-.19,s+.19,base,height-1.78,-.26,.13,"MatterFin")
            for j in range(1,levels):
                y=base+(height-base-1.67)*j/levels
                side.member(first,last,y-.069,y+.069,-.28,-.08,"MatterGrey")
            for y in (height*.48,height*.765):
                side.member(first,last,y-.24,y+.24,-.27,.105,"MatterGrey")
            for a,b in ((.32,first-.21),(last+.21,w-.32)):
                side.member(a,b,base,height-1.59,-.29,.091,"MatterPier")
            for s in range(4,int(w-3),6):
                side.member(s-.17,s+.17,height-1.90,height-.15,-.45,.16,"MatterGrey")
        else:
            side.glazed_opening(w*.22,w*.75,base,height-1.55,-.21,max(2,round(w*.38)),"LabDarkGlass",frame="LabAluminium")
            for a,b in ((.33,w*.218),(w*.752,w-.32)):
                side.member(a,b,base,height-.9,-.28,.092,"MatterPier")
            for j in range(1,levels):
                y=base+(height-base-1.55)*j/levels
                side.member(w*.20,w*.76,y-.067,y+.065,-.225,-.09,"MatterGrey")
        mid = w*.49
        gaps = [(mid-1.32,mid+1.32)] if side is front else []
        side.member_with_gaps(.16,w-.16,.29,base,-.32,-.17,"LabShadow",gaps)
        frontages = [(.51,mid-1.32),(mid+1.32,w-.54)] if gaps else [(.51,w-.54)]
        for lo,hi in frontages:
            side.glazed_opening(lo,hi,.34,base-.18,-.135,max(2,round((hi-lo)/2.7)),
                                "LabDarkGlass",cross=2.72,frame="LabAluminium")
        for s in range(2,int(w),5):
            if not gaps or abs(s-mid)>1.52:
                side.member(s-.18,s+.18,.30,base+.09,-.32,.084,"MatterGrey")
        if gaps:
            side.member(mid-1.32,mid+1.32,3.45,base,-.32,-.17,"LabShadow")
        if i in screens:
            lo = max(.55,w-13.7) if code == "686068242" else .70
            hi = min(w-.48,lo+9.2)
            side.member(lo-.21,hi+.14,4.4,height-1.08,-.095,-.022,"LabDarkGlass")
            hex_screen(side,lo,hi,4.53,height-1.24)
    mid = front.length*.49
    width=min(5.1,front.length*.35)
    entrance(front,mid-width,mid+width,top=3.89,eave=1.72,
             stone="MatterGrey",floor="LabSill",label="",steps=2)
    front.nameplate("物质科学教研"+"ABC"[("686068242","686068854","686069052").index(code)]+"楼",
                    mid,3.67,1.776,.33,"WhiteLetters")


def matter_connector(front, sides, outline, height, levels, facade):
    facade(outline,levels,height,"PhotoMatterGrey",3.0,detail_edges=(2,))
    w=front.length
    first,last=w*.19,w*.84
    low,top=3.18,height-.95
    front.glazed_opening(.61,w-.53,.26,height-.14,-.24,25,"LabDarkGlass",cross=9.82,frame="LabAluminium")
    for y in (3.01,6.50,9.83,13.07):
        front.member(.16,w-.16,y-.17,y+.17,-.29,.065,"MatterPier")
    for s in (1.04,w-1.10):
        front.member(s-.74,s+.74,.25,height-.14,-.44,.12,"MatterPier")
    front.member(.02,w-.02,height-.34,height+.30,-.35,.31,"MatterGrey")
    for s in (first,last):
        front.member(s-.36,s+.36,low-.38,top+.42,-.32,1.76,"MatterRedPanel")
    for y in (low,top):
        front.member(first-.38,last+.38,y-.39,y+.42,-.33,1.76,"MatterRedPanel")
    front.glazed_opening(first+.35,last-.36,low+.41,top-.40,1.24,16,"LabDarkGlass",
                        cross=8.61,frame="LabAluminium")
    for y in (5.24,7.12,10.5,11.83):
        front.member(first+.34,last-.34,y-.026,y+.026,1.254,1.323,"LabAluminium")
    for i,s in enumerate((first,last)):
        front.member(s-.27,s+.27,.14,low-.40,1.08,1.63,"MatterPier",f"frame_column_{i}")


def computing(front, sides, outline, height, levels, facade):
    facade(outline,levels,height,"PhotoLabTile",4.06,detail_edges=(3,4))
    band_windows(front,3.89,height,levels-1,4.02,"LabTile",air_units=True)
    w=front.length
    front.member(0,w,3.29,3.95,-.35,.84,"LabWhite")
    room = VISITS[front.name]
    center = w*(.5+room["offset"])
    left,right = center-room["width"]/2,center+room["width"]/2
    for start,end in ((.18,left),(right,w-.20)):
        front.glazed_opening(start,end,.46,3.32,-.21,max(1,round((end-start)/2.8)),
                             "LabDarkGlass",cross=2.79)
    for s in (3,18,24,29,36,44):
        front.member(s-.22,s+.22,.14,3.45,-.28,.27,"LabTile")
    a,b=4.6,15.2
    front.member(a,b,3.30,3.73,-.37,1.36,"LabTile")
    for s in (a+.25,b-.25):
        front.member(s-.22,s+.22,.50,3.31,.48,.85,"LabTile",f"entry_pier_{s}")
    front.approach_steps(a-.2,b+.2,-.15,1.39,.14,3,.12,.34,"LabGranite")
    front.member(left,right,.50,3.55,-room["depth"]-.09,-room["depth"]-.05,"LabShadow")
    walkable_glazing(front,left,right,3.32,-.14,1.53,"LobbyGlass","LabAluminium")
    corner=sides[3]
    band_windows(corner,3.89,height,levels-1,4.3,"LabTile")
    corner.glazed_opening(.20,corner.length-.20,.50,3.35,-.16,4,"LabDarkGlass",cross=2.73)
    corner.member(.0,corner.length,3.31,3.94,-.32,.84,"LabWhite")
    front.member(a-1.2,b+2.2,.064,.132,2.11,4.25,"PavedForecourt","frontage")


def chemistry_school(front, sides, outline, height, levels, facade):
    facade(outline,levels,height,"PhotoLabWhite",3.64,detail_edges=(5,))
    band_windows(front,3.94,height,levels-1,3.60,"LabWhite",air_units=True)
    w=front.length
    for a,b in ((.20,w*.25+.46),(w*.74-.46,w-.20)):
        front.glazed_opening(a,b,.27,3.85,-.19,3,"LabDarkGlass",cross=2.79)
    front.glazed_opening(w*.25+.46,w*.74-.46,3.12,3.85,-.19,4,"LabDarkGlass")
    entrance(front,w*.25,w*.74,top=3.62,eave=2.18,stone="LabTile",floor="LabSill",
             label="",steps=3,rise=.127)
    front.nameplate("化学与材料科学学院",w*.495,3.41,2.238,.35)


def chemistry_lab(front,sides,outline,height,levels,facade):
    facade(outline,levels,height,"PhotoLabGoldPanel",3.75,detail_edges=(2,))
    w=front.length
    a,b=w*.24,w*.68
    for k in range(1,levels):
        y=height*k/levels
        front.member(0,w,y-.018,y+.025,-.32,.050,"LabSill")
    front.member(.01,w-.01,3.72,height+.03,-.31,.02,"LabGoldPanel")
    front.member(.01,a,.23,3.72,-.31,.02,"LabGoldPanel")
    front.member(b,w-.01,.23,3.72,-.31,.02,"LabGoldPanel")
    # The approach photo shows one exposed column and a full-height return
    # against the cladding on the other side of the glass.
    front.member(a,b,3.22,3.72,-.29,2.28,"LabWhite")
    front.member(a,b,3.63,3.72,.11,2.31,"LabSill")
    front.member(a+.15,a+.47,.55,3.22,.97,1.35,"LabWhite","entrance_column")
    front.member(b-.53,b,.545,3.23,-.27,1.69,"LabGoldPanel","entrance_return")
    front.member(a+.54,b-.56,.55,3.22,-2.25,-2.16,"LabShadow")
    front.member(a+.54,b-.56,.46,.55,-2.16,-.12,"LabCanopy")
    front.glazed_opening(a+.56,b-.59,.55,3.16,-.119,5,"LabDarkGlass",
                         doors=((a+b)/2,),cross=2.69,frame="LabAluminium")
    front.approach_steps(a-.21,b+.22,-.15,2.31,.14,3,.136,.34,"LabSill")
    front.nameplate("化学实验楼",(a+b)/2,3.49,2.338,.35)
    back=sides[3]
    back.member(1.13,8.78,.084,.139,.03,2.90,"PavedForecourt","side_path")
    back.stair_flight("external_stair",2.3,8.4,.25,1.85,.143,2.83,True,"LabGoldPanel")
    back.member(8.35,10.10,2.60,2.83,.26,1.87,"LabGoldPanel","external_landing")
    back.rail(2.3,8.4,.143,2.83,1.89,spacing=.69)
    back.stair_guard("external_guard",2.3,8.4,.143,2.83,1.84,1.95)


def mathematics(front,sides,outline,height,levels,facade):
    facade(outline,levels,height,"PhotoLabWhite",3.75,detail_edges=(0,3,5,7,8,10,12,14,16))
    for i in (0,5,7,8,10,12,14,16):
        side=sides[i]
        if side.length>1.0:
            band_windows(side,.26,height,levels,3.96,"LabWhite",air_units=True)
    w=front.length
    band_windows(front,3.99,height,levels-1,3.82,"LabWhite",air_units=True)
    for a,b in ((.18,w*.21+.46),(w*.79-.46,w-.18)):
        front.glazed_opening(a,b,.29,3.94,-.196,3,"LabDarkGlass",cross=2.84)
    front.glazed_opening(w*.21+.46,w*.79-.46,3.45,3.94,-.196,4,"LabDarkGlass")
    entrance(front,w*.21,w*.79,top=3.95,eave=2.55,stone="LabWhite",
             floor="LabSill",steps=4,rise=.142)
    front.nameplate("物 理 系",w*.5,3.72,2.61,.59)
    for side in (sides[8],sides[16]):
        side.member(.11,side.length-.13,height-.20,height+.20,-.36,.16,"LabSill")
    front.member(w*.19,w*.81,.046,.132,3.71,11.6,"PavedForecourt","court")
    for s in (w*.22,w*.78):
        front.member(s-.042,s+.042,.133,.144,4.0,11.1,"NoParkingPaint")
    for d in (4.03,7.38,11.03):
        front.member(w*.22,w*.78,.135,.145,d,d+.075,"NoParkingPaint")
    for s in range(9,int(w)-8,4):
        for sign in (-1,1):
            p0=front.at(s+sign*1.8,.138,4.1)[::2]
            p1=front.at(s-sign*1.8,.138,11.02)[::2]
            front.edgebox(p0,p1,0,math.dist(p0,p1),.138,.143,-.028,.028,"PhotoNoParkingPaint")


def teaching_laboratory(front,sides,outline,height,levels,facade):
    podium=9.3
    facade(outline,2,podium,"PhotoLabWhite",4.4,detail_edges=(0,))
    w=front.length
    a,b=w*.55,w*.69
    for s0,s1 in ((0,a),(b,w)):
        edge=Exterior(front.name,front.at(s0,0,0)[::2],front.at(s1,0,0)[::2],
                      front.geo,front.slab,front.edgebox,front.inscription,front.collision)
        band_windows(edge,.26,podium,2,4.9,"LabWhite")
    for j,(tower_left,tower_right) in enumerate(((5.8,32.9),(53.2,78.1))):
        polygon=front.polygon(tower_left,tower_right,-31.2,-6.75)
        front.block(f"lab_tower_{j}",polygon,podium-.10,height+.50)
        front.slab(polygon,height-.15,height+.14,"PhotoLabSill")
        polygon.reverse()
        for k,(p,q) in enumerate(zip(polygon,polygon[1:]+polygon[:1])):
            side=Exterior(front.name,p,q,front.geo,front.slab,front.edgebox,front.inscription,front.collision)
            if k in (0,1,2):
                band_windows(side,podium,height,levels-2,3.87,"LabWhite",window="LabDarkGlass")
            else:
                span=side.length
                a0,b0=span*.36,span*.69
                side.member(0,a0,podium,height,-.37,.020,"LabWhite")
                side.member(b0,span,podium,height,-.37,.020,"LabWhite")
                side.glazed_opening(a0,b0,podium,height-.34,-.24,5,"LabBlueGlass",frame="LabAluminium")
                for floor in range(1,levels-1):
                    y=podium+(height-podium)*floor/(levels-2)
                    side.member(a0,b0,y-.064,y+.064,-.26,-.15,"LabAluminium")
                    for s in (span*.17,span*.84):
                        side.glazed_opening(s-.45,s+.45,y-.70,y+.68,.034,1,"LabDarkGlass",frame="LabAluminium")
            side.member(-.10,side.length+.10,height-.15,height+.50,-.31,.24,"LabWhite")
    for edge in (a,b):
        front.member(edge-.19,edge+.19,.16,8.96,-.33,.22,"LabWhite")
    front.member(a,b,.16,1.162,-.202,.101,"LabShadow")
    front.member(a,b,4.04,8.42,-.202,.101,"LabShadow")
    front.member(a,b,1.162,4.04,-2.05,-1.98,"LabShadow")
    front.member(a,b,1.06,1.162,-1.98,.11,"LabSill")
    front.glazed_opening(a+.26,b-.26,4.49,8.40,.162,8,"LabBlueGlass",cross=6.75,frame="LabAluminium")
    center=(a+b)*.5
    front.approach_steps(a+.12,center-.43,-.02,1.34,.14,7,.146,.31,"LabSill")
    front.approach_steps(center+.43,b-.08,-.02,1.34,.14,7,.146,.31,"LabSill")
    front.member(a+.12,b-.08,.08,1.162,-.14,1.34,"LabSill","entry_landing")
    ramp = front.depth_frame(center)
    ramp.sloped_member(1.31,3.55,1.123,.10,.039,-.43,.43,"LabGranite")
    front.collision.append({
        "name":front.name+"_entry_ramp","type":"sloped_prism",
        "polygon":front.polygon(center-.43,center+.43,1.31,3.55),
        "top_heights":[1.162,1.162,.139,.139],"bottom":.075,"top":1.162,
    })
    front.member(a+.12,b-.08,4.04,4.50,-.31,1.44,"LabWhite")
    front.glazed_opening(a+.44,b-.44,1.162,4.04,.17,7,
                         doors=(center,),cross=3.49,frame="LabAluminium")
    front.nameplate("基础科学教学实验中心",(a+b)/2,4.27,1.50,.30,"WhiteLetters")
    for s in (a+.12,b-.08):
        front.member(s-.12,s+.12,.14,1.31,1.31,3.55,"LabSill",f"retaining_{s}")
    start,end=a-2.1,a-.19
    # Set the foldback stairs beside the facade, clear of the mapped road.
    outside_near, outside_far = 1.51, 2.35
    front.stair_flight("lab_external_base",a-16.5,a-12.6,outside_near,outside_far,.14,1.17,True,"LabWhite")
    front.member(a-13.42,a-11.27,.93,1.17,.52,outside_far,"LabWhite","lab_base_deck")
    for level in range(3):
        y=1.17+level*2.72
        outside=-.02-level*.01
        front.stair_flight(f"lab_external_{level}",a-12.6,start,outside+.56,outside+1.47,y,y+1.36,True,"LabWhite")
        front.stair_guard(f"lab_external_guard_{level}",a-12.6,start,y,y+1.36,1.43,1.50)
        front.rail(a-12.6,start,y,y+1.36,1.48,spacing=1.25)
        front.member(start,end,y+1.16,y+1.36,.52,1.52,"LabWhite",f"external_deck_{level}")
        front.stair_flight(f"lab_return_{level}",a-12.6,start,outside_near,outside_far,y+1.36,y+2.72,False,"LabWhite")
        front.rail(a-12.6,start,y+2.72,y+1.36,2.36,spacing=1.25)
        front.stair_guard(f"lab_return_guard_{level}",a-12.6,start,y+2.72,y+1.36,2.32,2.39)
        front.member(a-13.65,a-12.58,y+2.52,y+2.72,.52,outside_far,"LabWhite",f"lab_return_deck_{level}")


SCIENCE = {
    "267646980": (report_hall,7),
    "298766431": (modern_physics,3),
    "1135310347": (molecule,1),
    "298742273": (resources,23),
    "686068242": (materials_tower,1),
    "686068854": (materials_tower,1),
    "686069052": (materials_tower,4),
    "1135360053": (matter_connector,2),
    "290098001": (computing,4),
    "290097999": (chemistry_school,5),
    "1135310348": (chemistry_lab,2),
    "298766164": (mathematics,3),
    "1135310341": (teaching_laboratory,0),
}


def build_science_exterior(asset, building, geo, slab, edgebox, inscription, solids, facade):
    outline=building["outline"]
    sides=[Exterior(asset,a,b,geo,slab,edgebox,inscription,solids)
           for a,b in zip(outline,outline[1:]+outline[:1])]
    build, edge = SCIENCE[building["osm_way"]]
    build(sides[edge],sides,outline,building["height"],building["levels"],facade)
