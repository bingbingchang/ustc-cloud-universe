"""Photographed facades on the south sports and social sciences lanes."""

from mapped_landmark_details import Exterior
from science_exteriors import band_windows, entrance


SPORTS_MATERIALS = {
    "GymBrick": ((.388,.163,.103),.89,0),
    "GymCream": ((.635,.600,.531),.84,0),
    "GymBlue": ((.10,.276,.377),.26,.32),
    "CollegeRed": ((.43,.139,.102),.82,0),
    "CollegeGlass": ((.048,.205,.362),.19,.31),
    "CollegeGlassDeep": ((.037,.113,.235),.23,.27),
    "CollegeGrey": ((.28,.295,.286),.74,.12),
    "ServiceStone": ((.61,.589,.549),.81,0),
    "D364Red": ((.403,.177,.133),.86,0),
    "D364Concrete": ((.429,.436,.408),.85,0),
}


def front_yard(front,start,end,near,far):
    front.member(start,end,.06,.131,near,far,"PavedForecourt","front_yard")


def gym(front,sides,outline,height,_levels,_facade):
    front.block("gym",outline,.08,height+.31)
    front.slab(outline,.08,.31,"PhotoGymCream")
    front.slab(outline,height-.17,height+.18,"PhotoLabSill")
    for side in sides:
        w=side.length
        side.member(0,w,.24,height-.14,-.39,-.10,"GymBrick")
        side.member(0,w,height-.31,height+.25,-.35,.45,"GymCream")
        side.member(0,w,.24,.77,-.32,.048,"GymCream")
    w=front.length
    mid=w*.50
    half=.5*(w-.8)
    front.geo([front.at(s,y,d) for d in (-.34,.075) for s,y in
               ((mid-half,7.07),(mid+half,7.07),(mid,10.29))],
              [(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)],"PhotoGymBrick")
    front.glazed_opening(w*.145,w*.855,4.62,6.98,.03,8,"GymBlue",cross=6.05,frame="LabAluminium")
    front.sloped_member(.40,mid,7.07,10.25,.28,-.18,.12,"GymBrick")
    front.sloped_member(mid,w-.40,10.25,7.07,.28,-.18,.12,"GymBrick")
    front.sloped_member(.30,mid,7.22,10.40,.15,-.25,.18,"GymCream")
    front.sloped_member(mid,w-.30,10.40,7.22,.15,-.25,.18,"GymCream")
    for i,l in enumerate((mid-3.81,mid+3.66)):
        front.member(l-.29,l+.29,.40,7.21,-.20,.21,"GymBrick")
    entrance(front,mid-4.18,mid+4.18,top=4.03,eave=1.82,stone="GymCream",
             floor="LabSill",label="东区羽毛球馆",steps=2,rise=.136)
    front_yard(front,.65,w-.65,2.17,6.82)
    return front.at(mid,.14,5.1)


def international(front,sides,outline,height,levels,facade):
    facade(outline,levels,height,"PhotoCollegeRed",3.8,detail_edges=(0,1))
    for side in (front,sides[1]):
        w=side.length
        side.member(0,w,.21,3.89,-.43,-.23,"CollegeRed")
        side.member(0,w,3.90,4.40,-.46,.34,"CollegeGrey")
        start,end=.50,w-.50
        bands = [4.40,6.72,8.90,11.56,height-.31]
        for i,(low,high) in enumerate(zip(bands,bands[1:])):
            side.glazed_opening(start,end,low,high,-.067,max(7,round(w/1.53)),
                                "CollegeGlassDeep" if i==0 else "CollegeGlass",frame="LabAluminium")
        for k in (0,w):
            side.member(k-.33,k+.33,.31,height,-.22,.09,"CollegeRed")
        side.member(-.10,w+.10,height-.27,height+.22,-.40,.27,"CollegeGrey")
    mid=front.length*.37
    entrance(front,mid-5.7,mid+5.7,top=3.90,eave=1.79,stone="CollegeGrey",
             floor="ServiceStone",label="",steps=4,rise=.147)
    for s in (mid-5.5,mid+5.56):
        front.member(s-.18,s+.18,.72,3.43,.20,1.05,"ServiceStone")
    front.member(mid+6.15,front.length-.41,.28,3.84,-.32,.04,"CollegeRed")
    front.nameplate("国际学院",mid+10.2,2.72,.054,.43,"WhiteLetters")
    front_yard(front,2.7,front.length-1.5,3.2,6.7)
    return front.at(mid,.14,5.6)


def student_services(front,sides,outline,height,levels,facade):
    facade(outline,levels,height,"PhotoServiceStone",3.85,detail_edges=(0,1))
    w=front.length
    band_windows(front,4.42,height,levels-1,4.3,"ServiceStone")
    front.glazed_opening(.35,w-.38,.34,4.38,-.22,13,"LabDarkGlass",cross=3.66)
    front.member(-.02,w+.02,4.22,4.52,-.35,.36,"ServiceStone")
    a,b=w*.28,w*.64
    entrance(front,a,b,top=4.26,eave=3.37,stone="ServiceStone",
             floor="LabSill",label="",steps=4,rise=.145)
    front.nameplate("学生服务中心",(a+b)*.5,4.05,3.432,.41,"WhiteLetters")
    side=sides[1]
    band_windows(side,.24,height,levels,4.15,"ServiceStone")
    front_yard(front,a-2.1,b+3.1,4.87,7.15)
    return front.at((a+b)*.5,.14,6.5)


def graduate_housing(front,sides,outline,height,levels,facade):
    facade(outline,levels,height,"PhotoD364Red",3.60,detail_edges=(0,1,19))
    w=front.length
    band_windows(front,.24,height,levels,4.0,"D364Red",air_units=True)
    for side in (sides[1],sides[19]):
        z=side.length
        band_windows(side,.23,height,levels,4.7,"D364Concrete",sill="D364Concrete",air_units=True)
        for i in range(1,levels):
            y=.26+i*(height-.49)/levels
            side.member(.13,z-.12,y-.09,y+.16,-.13,1.09,"D364Concrete")
            side.member(.13,z-.12,y+.87,y+.95,.96,1.08,"LabAluminium")
            for s in range(1,int(z)-1,2):
                side.member(s,s+.10,y+.135,y+.953,.97,1.085,"D364Concrete")
    entrance(front,w*.38,w*.61,top=3.83,eave=1.72,stone="D364Concrete",
             floor="ServiceStone",label="364／365",steps=2,rise=.13)
    front_yard(front,.55,w-.60,2.15,35.0)
    for s in (2.8,w-3.1):
        for k in range(11):
            d=3.35+k*2.50
            front.member(s-2.2,s+1.9,.132,.144,d,d+.062,"ParkingPaint")
        for d in (7.6,16.75,25.9):
            front.member(s-.065,s+.065,.56,.63,d,d+3.28,"Ironwork",f"rack_{s}_{d}")
            for i in range(5):
                other=d+.22+i*.69
                front.member(s-.066,s+.066,.14,.61,other-.04,other+.04,"Ironwork")
    return front.at(w*.495,.14,5.6)


SOUTH_PHOTO = {"271959067":(gym,2),"270334649":(international,0),
               "270334648":(student_services,0),"271959068":(graduate_housing,0)}


def add_exterior(asset,building,geo,slab,edgebox,inscription,solids,facade):
    outline=building["outline"]
    sides=[Exterior(asset,a,b,geo,slab,edgebox,inscription,solids)
           for a,b in zip(outline,outline[1:]+outline[:1])]
    model,e=SOUTH_PHOTO[building["osm_way"]]
    return model(sides[e],sides,outline,building["height"],building["levels"],facade)


def add_teaching_office(asset,building,geo,slab,edgebox,inscription,solids,facade):
    outline=building["outline"]
    height,levels=building["height"],building["levels"]
    facade(outline,levels,height,"PhotoGymCream",3.60,detail_edges=(6,))
    front=Exterior(asset,outline[6],outline[7],geo,slab,edgebox,inscription,solids)
    w=front.length
    band_windows(front,4.24,height,levels-1,4.20,"GymCream")
    a,b=w*.33,w*.66
    for x0,x1 in ((0,a),(b,w)):
        front.member(x0,x1,.22,4.25,-.34,.025,"GymCream")
    front.glazed_opening(a,b,.60,4.20,-.13,7,"GymBlue",cross=3.57)
    entrance(front,a,b,top=4.19,eave=1.37,stone="GymCream",
             floor="LabSill",label="体育教学部",steps=3,rise=.152)
    front_yard(front,a-2.16,b+2.21,2.18,5.42)
    return front.at((a+b)*.5,.14,4.2)
