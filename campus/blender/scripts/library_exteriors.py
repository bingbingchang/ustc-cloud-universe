"""GIS evidence for the five public buildings along the library district."""

import math

from mapped_landmark_details import Exterior
from visit_exteriors import VISITS, walkable_glazing


LIBRARY_MATERIALS = {
    "LibraryOrangeBrick": ((.57,.244,.108),.83,0),
    "LibraryStone": ((.44,.436,.406),.79,.04),
    "LibraryGlassDark": ((.115,.185,.196),.25,.20),
    "LibraryWhitePanel": ((.57,.574,.545),.76,.08),
    "LibraryDarkMetal": ((.111,.13,.12),.51,.27),
    "OldLibraryBrick": ((.465,.237,.151),.86,0),
    "OldLibraryScreen": ((.29,.135,.085),.86,0),
    "TeachingOrange": ((.465,.240,.138),.79,0),
    "CampusBlue": ((.033,.115,.31),.55,0),
    "CanteenRed": ((.355,.138,.126),.84,0),
    "CanteenPanel": ((.415,.415,.386),.85,0),
    "PavingJoint": ((.31,.16,.115),.87,0),
    "ShrubLow": ((.12,.202,.078),.92,0),
}

# OSM edge indices refer to positively wound outlines from library_district.json.
FRONTS = {
    "284161541": (16, "10662"),
    "284161540": (2, "10628"),
    "271958257": (27, "10630"),
    "1135310337": (0, "10631"),
    "284161542": (7, "10633"),
}


def floor_stairs(front, name, left, right, level, start, landing, rise=.165, tread=.34, parapets=False):
    """Walkable external stair, with visible stringers and continuous handrails."""
    count = max(1, round((level-.135)/rise))
    start_y = .135
    y_step = (level-start_y)/count
    end = landing + (count-1)*tread
    front.member(left,right,.06,start_y,end,end+.70,"LibraryStone",name+"_foot")
    for i in range(count):
        front.member(left,right,.079,level-i*y_step,start,landing+i*tread,
                     "LibraryStone",f"{name}_step_{i}")
        front.member(left+.025,right-.025,level-i*y_step-.024,level-i*y_step-.012,
                     landing+i*tread-.014,landing+i*tread+.003,"LibraryDarkMetal")
    for s, side in ((left-.045,"l"),(right+.045,"r")):
        edge = front.depth_frame(s)
        if parapets:
            edge.sloped_member(landing,end,level-.14,start_y-.14,.90,-.14,.14,"LibraryStone")
            edge.sloped_member(landing,end,level+.72,start_y+.72,.088,-.16,.16,"LibraryWhitePanel")
            edge.sloped_member(landing,end,level+.86,start_y+.78,.035,-.05,.05,"Handrail")
            edge.stair_guard(name+"_side_"+side,landing,end,level-.19,start_y-.16,-.14,.14)
            front.member(s-.14,s+.14,level-.13,level+.82,max(start,landing-1.08),landing,
                         "LibraryStone",name+"_parapet_landing_"+side)
        else:
            edge.sloped_member(landing,end,level-.12,start_y+.02,.24,-.18,.18,"LibraryStone")
            edge.rail(landing,end,level,start_y,0,spacing=.70)
            edge.rail(start,landing,level,level,0,spacing=.65)
            edge.stair_guard(name+"_rail_"+side,landing,end,level,start_y,-.045,.045)
            front.block(name+"_landing_rail_"+side,front.polygon(s-.043,s+.043,start,landing),level,level+1.03)
    return end


def new_library(front):
    mid = front.length/2
    level = 3.18
    portal_end = 5.05
    for side,s in (("left",mid-8.54),("right",mid+7.94)):
        front.member(s,s+.63,.13,21.65,.0,2.65,"LibraryOrangeBrick",side+"_pier")
        front.member(s-.83,s+.63,11.62,21.65,.0,2.60,"LibraryOrangeBrick")
        front.member(s-.94,s+.75,21.54,21.78,.0,2.73,"LibraryWhitePanel")
    for i,(half,y1,d) in enumerate(((10.48,13.43,portal_end),(9.63,12.65,4.37),(8.92,11.88,3.68))):
        for s in (mid-half,mid+half-.57):
            front.member(s,s+.57,.13,y1,d-.88,d,"LibraryStone",f"portal_{i}_{s:.2f}")
        front.member(mid-half,mid+half,y1-.58,y1,d-.92,d,"LibraryStone")
        front.member(mid-half+.56,mid+half-.56,y1-.767,y1-.54,.055,d-.14,"AuditSoffit")
    for s in (mid-8.35,mid+7.97):
        front.member(s,s+.39,.12,11.30,.01,3.74,"LibraryWhitePanel")
    front.member(mid-6.91,mid+6.91,17.1,21.13,.02,.63,"LibraryWhitePanel")
    front.nameplate("图 书 馆",mid,19.44,.651,1.04)
    front.glazed_opening(mid-6.85,mid+6.85,13.42,17.10,.17,10,
                         finish="LibraryGlassDark",cross=15.76,frame="LibraryDarkMetal")
    front.member(mid-6.85,mid+6.85,11.29,13.44,.01,.19,"LibraryStone")
    front.member(mid-6.78,mid+6.78,level-.13,level,.025,4.52,"LibraryStone","main_landing")
    # The two external flights leave the lower entrance and the approach between them open.
    floor_stairs(front,"library_left",mid-7.72,mid-2.50,level,.025,4.53,tread=.32,parapets=True)
    floor_stairs(front,"library_right",mid+2.50,mid+7.72,level,.025,4.53,tread=.32,parapets=True)
    front.member(mid-2.50,mid+2.50,level-.78,level-.13,.04,4.50,"LibraryStone")
    front.member(mid-2.50,mid+2.50,.064,.139,.03,11.3,"LibraryStone","lower_approach")
    front.glazed_opening(mid-2.48,mid+2.48,.139,2.38,.115,4,
                         finish="LibraryGlassDark",doors=(mid,),frame="LibraryDarkMetal")
    front.member(mid-1.75,mid+1.75,.079,.139,-2.55,.10,"LibraryStone")
    front.member(mid-1.75,mid+1.75,.139,2.47,-2.62,-2.55,"AuditSoffit")
    walkable_glazing(front,mid-6.75,mid+6.75,11.28,.14,1.30,"LobbyGlass","LibraryDarkMetal")
    front.member(mid-6.78,mid+6.78,level+.025,11.27,-8.56,-8.48,"DarkReveal")
    for s in (mid-4.1,mid,mid+4.1):
        front.member(s-.11,s+.11,5.46,11.20,-.44,-.20,"LibraryWhitePanel")
    for s in (mid-4.1,mid,mid+4.1):
        front.glazed_opening(s-.87,s+.87,15.57,16.40,.208,3,"LibraryGlassDark",frame="LibraryDarkMetal")
    return front.at(mid,.14,11.15)


def new_library_wings(outline, name, geo, slab, edgebox, inscription, solids):
    for edge in (14,15,17,18,19):
        wall = Exterior(name,outline[edge],outline[(edge+1)%len(outline)],geo,slab,edgebox,inscription,solids)
        span = wall.length
        if edge not in (15,18):
            wall.member(0,span,.15,22.2,-.32,.09,"LibraryOrangeBrick")
            continue
        center=span*(.45 if edge==15 else .56)
        wall.member(0,center-.58,.15,22.2,-.32,.09,"LibraryOrangeBrick")
        wall.member(center+.58,span,.15,22.2,-.32,.09,"LibraryOrangeBrick")
        bottom=.15
        for low,high in ((3.16,5.55),(6.21,9.52),(10.38,13.74),(14.50,17.56),(18.32,20.16)):
            wall.member(center-.58,center+.58,bottom,low,-.32,.09,"LibraryOrangeBrick")
            wall.member(center-.58,center+.58,low,high,-.31,-.025,"DarkReveal")
            wall.glazed_opening(center-.45,center+.45,low+.10,high-.07,.012,2,
                                "LibraryGlassDark",frame="LibraryDarkMetal")
            bottom=high
        wall.member(center-.58,center+.58,bottom,22.2,-.32,.09,"LibraryOrangeBrick")
        wall.member(.7,span-.7,22.15,22.41,-1.05,-.19,"LibraryWhitePanel")
        for s in (.72,span*.33,span*.65,span-.72):
            wall.member(s-.13,s+.13,22.40,23.51,-1.10,-.37,"LibraryWhitePanel")
        wall.member(.7,span-.7,23.51,23.75,-1.20,-.29,"LibraryWhitePanel")


def arch_window(front,s,w,bottom,spring,top,depth):
    r = w/2
    points = [(s-r,bottom),(s+r,bottom)]
    points.extend((s+r*math.cos(i*math.pi/10),spring+(top-spring)*math.sin(i*math.pi/10)) for i in range(11))
    count = len(points)
    verts = [front.at(x,y,d) for d in (depth,depth+.052) for x,y in points]
    faces = [tuple(reversed(range(count))),tuple(range(count,2*count))]
    faces.extend((i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count))
    front.geo(verts,faces,"PhotoLibraryGlassDark")
    front.member(s-.03,s+.03,bottom,top-.018,depth+.045,depth+.084,"LibraryDarkMetal")
    front.member(s-r,s+r,spring-.04,spring+.012,depth+.038,depth+.079,"LibraryDarkMetal")


def old_library(front):
    w = front.length
    mid = w/2
    level = 1.42
    door_spans = [(mid-2.79,mid-.61),(mid+.61,mid+2.79)]
    front.member(0,w,.15,level,-.21,-.12,"DarkReveal")
    front.member_with_gaps(0,w,level,level+2.27,-.21,-.12,"DarkReveal",door_spans)
    front.member(0,w,level+2.27,4.43,-.21,-.12,"DarkReveal")
    front.member(mid-4.7,mid+4.7,level-.12,level,-2.43,.10,"LibraryStone")
    front.member(mid-4.7,mid+4.7,level,4.43,-2.51,-2.43,"AuditSoffit")
    front.member(0,w,4.43,14.2,-.21,.025,"OldLibraryBrick")
    front.member(0,w,13.91,14.37,.035,.32,"LibraryWhitePanel")
    front.member(-.58,w+.58,4.42,5.12,.04,2.04,"LibraryWhitePanel")
    front.member(0,w,.11,.99,.03,.15,"LibraryStone")
    for k in range(11):
        s = (k+.5)*w/11
        front.member(k*w/11-.09,k*w/11+.09,5.05,14.12,.03,.225,"OldLibraryBrick")
        for bottom,top in ((5.1,7.71),(8.38,10.83)):
            front.glazed_opening(s-.78,s+.78,bottom,top,.087,2,
                                 finish="LibraryGlassDark",cross=top-.56,frame="LibraryDarkMetal")
        arch_window(front,s,1.52,11.64,12.94,13.67,.105)
        for y in (7.37,10.62):
            front.member(s-.82,s+.82,y-.09,y+.49,.135,.394,"OldLibraryScreen")
            for j in range(5):
                front.member(s-.805,s+.805,y-.03+j*.109,y+j*.109,.392,.43,"OldLibraryBrick")
    for s in (mid-6.24,mid+6.24):
        front.member(s-.27,s+.27,.16,4.44,.06,1.47,"LibraryStone","porch_post_"+str(s))
    for a,b in ((.25,mid-5.42),(mid+5.42,w-.25)):
        front.glazed_opening(a,b,1.43,4.42,.12,max(2,int((b-a)/1.40)),
                             finish="LibraryGlassDark",cross=3.77,frame="LibraryDarkMetal")
    front.member(mid-5.48,mid+5.48,.082,level,.04,1.52,"LibraryStone","door_landing")
    floor_stairs(front,"old_library",mid-5.24,mid+5.24,level,.045,1.52,tread=.34)
    front.glazed_opening(mid-4.7,mid+4.7,level,4.43,.133,6,
                         doors=(mid-1.7,mid+1.7),cross=3.87,frame="LibraryDarkMetal")
    front.member(mid-11,mid+11,.075,.136,4.9,12.7,"ActivityPaving","plaza_link")
    for s in (mid-8.24,mid-5.6,mid+5.6,mid+8.24):
        front.member(s-.045,s+.045,.137,.144,4.91,12.69,"PavingJoint")
    for d in (6.2,9.8,12.0):
        front.member(mid-10.99,mid+10.99,.137,.144,d-.045,d+.045,"PavingJoint")
    return front.at(mid,.14,7.9)


def teaching_two(front):
    mid = front.length/2
    room = VISITS[front.name]
    half = room["width"]/2
    for a,b in ((0,mid-half),(mid+half,front.length)):
        front.member(a,b,.125,4.74,-.09,.025,"DarkReveal")
    front.member(mid-half,mid+half,.146,3.49,-room["depth"]-.11,-room["depth"]-.05,"DarkReveal")
    front.member(.0,front.length,4.74,5.7,.052,3.06,"TeachingOrange")
    front.member(0,front.length,5.69,28.50,-.28,.01,"LibraryStone")
    for floor in range(2,8):
        bottom = floor*3.48+.66
        for i in range(7):
            s = (i+.5)*front.length/7
            front.glazed_opening(s-1.02,s+1.02,bottom,bottom+1.55,.071,2,
                                 finish="LibraryGlassDark",cross=bottom+1.16,frame="LibraryDarkMetal")
    for i in range(8):
        s = i*front.length/7
        front.member(s-.13,s+.13,5.70,28.47,.012,.26,"LibraryWhitePanel")
    for a,b in ((0,mid-7.75),(mid+7.75,front.length)):
        front.member(a,b,.14,4.78,.05,2.97,"TeachingOrange",f"portal_wall_{a}")
    front.member(mid-7.86,mid+7.86,3.64,3.79,.12,3.21,"LibraryWhitePanel")
    front.member(mid-7.77,mid+7.77,3.77,4.81,2.66,3.012,"TeachingOrange")
    for a in (mid-7.68,mid+3.9):
        for i in range(9):
            s = a+i*.405
            front.member(s,s+.118,.15,3.69,2.38,3.02,"TeachingOrange")
        front.block(f"side_screen_{a}",front.polygon(a,a+3.36,2.37,3.04),.14,3.71)
    front.member(mid-1,mid+1,4.02,4.66,3.013,3.04,"CampusBlue")
    front.nameplate("第二教学楼",mid,4.365,3.054,.28,"WhiteLetters")
    front.member(mid-8.2,mid+8.2,.08,.147,.013,5.7,"ActivityPaving","approach")
    walkable_glazing(front,mid-3.22,mid+3.22,3.35,-.21,1.26,"LobbyGlass","LibraryDarkMetal")
    for a,b in ((0,mid-7.75),(mid+7.75,front.length)):
        for s in range(1,5):
            x = a+(b-a)*s/5
            front.member(x-.012,x+.012,.25,4.66,2.969,2.974,"LibraryDarkMetal")
    front.member(mid-4.15,mid-3.222,.15,3.43,-.19,.085,"LibraryStone")
    front.member(mid+3.222,mid+4.15,.15,3.43,-.19,.085,"LibraryStone")
    for s in (mid-3.59,mid+3.57):
        front.member(s-.21,s+.21,1.46,1.76,.085,.102,"CampusBlue")
    for s in (mid-5.38,mid+5.38):
        front.member(s-.29,s+.29,.147,3.64,.12,1.07,"LibraryStone",f"vestibule_column_{s}")
    return front.at(mid,.15,5.5)


def gifted_young(front):
    mid = front.length/2
    level = 2.24
    front.member(0,front.length,12.10,14.64,.045,1.25,"LibraryWhitePanel")
    front.member(0,front.length,.11,level,.05,.33,"LibraryStone")
    front.member(.46,front.length-.46,5.3,6.42,.07,1.5,"LibraryWhitePanel")
    front.nameplate("少年班",mid-1.17,5.91,1.522,.48,"DoorPull")
    front.nameplate("School of the Gifted Young",mid+1.58,5.92,1.524,.212,"CampusBlue")
    front.member(.04,front.length-.04,12.26,14.52,.022,.25,"TeachingOrange")
    for a,b in ((.03,1.56),(front.length-1.55,front.length-.03)):
        front.member(a,b,6.24,12.28,.015,.25,"TeachingOrange")
    front.glazed_opening(1.59,front.length-1.59,6.41,12.18,.16,6,
                         finish="LibraryGlassDark",cross=9.7,frame="LibraryDarkMetal")
    for i in range(4):
        s = 1.57+i*(front.length-3.14)/3
        front.member(s-.149,s+.149,6.44,12.19,.14,.94,"LibraryWhitePanel")
    front.glazed_opening(1.24,front.length-1.22,level,5.28,.18,6,doors=(mid,),cross=4.57)
    for s in (.38,front.length-.38):
        front.member(s-.22,s+.22,level,5.33,.09,.91,"LibraryWhitePanel")
    floor_depth = floor_stairs(front,"gifted",mid-3.09,mid+3.09,level,.07,2.04,tread=.35)
    return front.at(mid,.14,floor_depth+.9)


def canteen(front):
    mid = front.length/2
    span = front.length
    level = 2.96
    center_left,center_right = mid-6.04,mid+6.04
    for i,(a,b) in enumerate(((0,mid-7.45),(mid+7.45,span))):
        front.member(a,b,9.34,12.25,.035,4.98,"CanteenRed")
        front.member(a,b,5.26,6.83,.045,4.86,"CanteenRed")
        front.member(a,b,.68,1.22,.045,4.75,"CanteenRed")
        for s in (a,b-.31):
            front.member(s,s+.31,.67,9.37,.04,4.81,"CanteenRed",f"wing_edge_{i}_{s}")
        front.glazed_opening(a+.29,b-.29,1.19,5.31,4.62,7,
                             finish="LibraryGlassDark",cross=3.77,frame="LibraryDarkMetal")
        front.glazed_opening(a+.28,b-.28,6.81,9.36,4.63,9,
                             finish="LibraryGlassDark",cross=8.06,frame="LibraryDarkMetal")
        front.member(a,b,.079,.69,.02,5.0,"LibraryStone",f"wing_ground_{i}")
        front.block(f"closed_wing_{i}",front.polygon(a,b,.05,4.62),.67,9.40)
    front.member(center_left,center_right,9.36,13.09,.06,2.63,"CanteenRed")
    front.member(center_left,center_right,5.51,9.46,.055,.79,"CanteenPanel")
    for portion in (-.28,0,.28):
        s = mid+(center_right-center_left)*portion
        front.member(s-.24,s+.24,7.009,7.40,.78,.81,"DarkReveal")
    for s in (center_left,center_right-.57):
        front.member(s,s+.57,6.22,9.44,.045,2.38,"CanteenRed")
    for s in (-3.29,0,3.29):
        front.glazed_opening(mid+s-.98,mid+s+.98,7.77,9.11,.82,2,
                             finish="LibraryGlassDark",frame="LibraryDarkMetal")
    front.member(mid-8.05,mid+8.05,4.06,5.90,1.08,4.22,"CanteenPanel")
    front.member(mid-8.03,mid+8.03,3.91,4.12,.03,4.1,"AuditSoffit")
    for s in (mid-5.66,mid+5.66):
        front.member(s-.32,s+.32,.39,4.0,2.72,3.9,"LibraryStone",f"entry_column_{s}")
    front.glazed_opening(mid-5.43,mid+5.43,.45,3.86,.154,8,doors=(mid-1.6,mid+1.6),
                         cross=2.63,frame="LibraryDarkMetal")
    front.member(mid-8.09,mid+8.09,.08,.445,.025,5.0,"LibraryStone","entry_platform")
    front.approach_steps(mid-8.10,mid+8.10,4.99,5.56,.13,2,.1575,.34,"LibraryStone")
    floor_stairs(front,"north_canteen_left",mid-7.27,mid-5.61,level,.08,1.38,tread=.30)
    floor_stairs(front,"north_canteen_right",mid+5.61,mid+7.27,level,.08,1.38,tread=.30)
    front.member(mid-20.24,mid+20.24,.055,.136,5.92,8.95,"PavedForecourt","parking")
    for s in range(-18,20,3):
        front.member(mid+s-.026,mid+s+.026,.137,.143,6.03,8.93,"ParkingPaint")
    return front.at(mid,.14,8.35)


def build_library_front(wid, asset, outline, geo, slab, edgebox, inscription, solids):
    edge,_ = FRONTS[wid]
    front = Exterior(asset,outline[edge],outline[(edge+1)%len(outline)],geo,slab,edgebox,inscription,solids)
    if wid == "284161541":
        new_library_wings(outline,asset,geo,slab,edgebox,inscription,solids)
    return {"284161541":new_library,"284161540":old_library,"271958257":teaching_two,
            "1135310337":gifted_young,"284161542":canteen}[wid](front)
