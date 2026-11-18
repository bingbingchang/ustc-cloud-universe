"""Photo-based exteriors for the eastern residences and central campus lanes."""

import math

from mapped_landmark_details import Exterior
from science_exteriors import band_windows
from visit_exteriors import VISITS, door_spans

LIFE_MATERIALS = {
    "RetirementPlaster": ((.48,.425,.289),.85,0),
    "RetirementTrim": ((.62,.579,.48),.84,0),
    "RetirementAwnings": ((.122,.288,.231),.85,0),
    "GardenBrick": ((.43,.258,.171),.88,0),
    "ServiceAwningWood": ((.367,.213,.097),.81,0),
    "ServiceAwningShade": ((.173,.114,.077),.83,0),
    "HistoricYellow": ((.426,.342,.223),.91,0),
    "HistoricStone": ((.414,.398,.355),.82,0),
    "HistoricRed": ((.343,.092,.059),.81,0),
    "HistoricGlass": ((.115,.195,.175),.42,.11),
    "HistoricVine": ((.126,.188,.087),.94,0),
    "HistoricLeaf": ((.193,.270,.115),.88,0),
    "MuseumDoor": ((.24,.058,.078),.73,0),
    "MuseumIvyDeep": ((.052,.122,.047),.90,0),
    "MuseumIvyMid": ((.093,.223,.067),.89,0),
    "MuseumIvyLight": ((.146,.269,.084),.88,0),
    "ApartmentPlaster": ((.548,.409,.327),.89,0),
    "ApartmentGlazing": ((.176,.259,.263),.33,.13),
    "ApartmentAwning": ((.153,.263,.219),.82,0),
}


def retirement(front,sides,outline,height,levels,facade):
    facade(outline,levels,height,"PhotoRetirementPlaster",3.4,detail_edges=(3,))
    w=front.length
    front.member(0,w,.24,height+.18,-.37,.03,"RetirementPlaster")
    front.member(-.03,w+.03,height-.20,height+.17,-.43,.21,"RetirementTrim")
    for a,b,y0,y1,d in ((.55,w-.56,.57,2.93,.040),
                          (2.76,5.65,8.56,10.04,.038),
                          (7.06,9.69,8.56,10.04,.038)):
        front.glazed_opening(a,b,y0,y1,d,7 if b-a>5 else 2,"LabDarkGlass",
                            cross=y1-.48,frame="LabAluminium")
    # The second-floor window band is a bowed bay above the flat entrance.
    start,end=2.82,w-2.79
    points=[front.at(start+(end-start)*i/10,0,.08+math.sin(math.pi*i/10)*.66)[::2]
            for i in range(11)]
    for a,b in zip(points,points[1:]):
        segment=Exterior(front.name,a,b,front.geo,front.slab,front.edgebox,front.inscription,front.collision)
        segment.glazed_opening(0,segment.length,4.67,6.71,0,1,"LobbyGlass",
                               cross=6.15,frame="LabAluminium")
        segment.member(-.015,segment.length+.015,4.53,4.69,-.14,.14,"RetirementTrim")
        segment.member(-.015,segment.length+.015,6.70,6.87,-.14,.14,"RetirementTrim")
    s0,s1=2.55,w-2.29
    front.member(s0,s1,3.12,3.78,-.32,1.31,"RetirementTrim")
    front.member(s0,s1,3.68,3.82,1.18,1.36,"RetirementAwnings")
    front.approach_steps(s0,s1,-.02,1.00,.14,2,.14,.32,"HistoricStone")
    front.glazed_opening(3.22,w-3.22,.42,2.91,.076,4,
                         doors=(w*.5,),cross=2.64,frame="LabAluminium")
    for s in (2.66,w-2.61):
        front.member(s-.18,s+.18,.40,3.14,.95,1.22,"RetirementTrim",f"entrance_pier_{s}")
    front.member(.61,w-.61,.036,.126,1.32,6.33,"PavedForecourt","court")
    front.nameplate("老干部活动中心",w*.5,3.48,1.39,.30,"WhiteLetters")
    for s in (1.2,4.35,8.43,w-1.24):
        for i in range(6):
            y=.28+i*.074
            x=(.14,.20,.23,.23,.20,.14)[i]
            front.member(s-x,s+x,y-.037,y+.036,5.42-x,5.42+x,"HistoricStone")


def vine(side,start,end,top,span):
    for branch in range(max(1,int((end-start)/span))):
        base=start+(end-start)*(branch+.5)/max(1,int((end-start)/span))
        for j in range(7):
            y=.19+(top-.19)*j/7
            s=base+math.sin(j*.91+branch)*.42
            side.sloped_member(s-.025,s+.067,y,y+(top-.19)/7,.15,.026,.079,"HistoricVine")
            for k in range(5):
                g=s+(.22*k-.45)+math.sin(j+k*.51)*.19
                if not start<=g<=end:continue
                t=y+.17+k*.125
                r=.148+.043*math.sin(j*1.73+k*2.04)
                p=[side.at(g-r,t,.053),side.at(g-r*.61,t+r,.083),
                   side.at(g+r*.32,t+r*1.21,.08),side.at(g+r,t+r*.50,.052),
                   side.at(g+r*.48,t-r*.42,.061),side.at(g-r*.28,t-r*.65,.05)]
                side.geo(p,[(0,1,2,3,4,5),(5,4,3,2,1,0)],"PhotoHistoricLeaf" if (j+branch)%3 else "PhotoHistoricVine")


def museum_entry(front,height,levels):
    visit=VISITS[front.name]
    w=front.length
    mid=w*.5
    door_left,door_right,door=next(door_spans(visit,w))
    floor=visit["floor"]
    band_windows(front,3.74,height,levels-1,4.13,"HistoricYellow",
                 window="HistoricGlass",sill="HistoricStone")
    for left,right in ((0,door_left),(door_right,w)):
        front.member(left,right,.25,3.63,-.37,-.146,"HistoricYellow")
        front.member(left,right,.25,.48,-.34,.085,"HistoricStone")
    door_top = floor+door["height"]
    front.member(door_left,door_right,door_top,3.63,-.38,.052,"HistoricYellow")
    d = door["outset"]
    front.member(door_left+.021,door_right-.021,floor+.017,door_top-.025,d-.024,d+.024,"VisitWood")
    for a,b in ((mid-3.08,mid-1.84),(mid+1.84,mid+3.08)):
        front.member(a,b,floor,2.84,-.14,.018,"MuseumDoor")
        for x in (a+.09,b-.09):
            front.member(x-.018,x+.018,.35,2.82,.015,.038,"HistoricRed")
        for y in (.56,1.29,2.63):
            front.member(a+.09,b-.09,y,y+.057,.014,.042,"HistoricRed")
        handle=(a+b)*.5+.24
        front.member(handle-.018,handle+.018,1.01,1.59,.047,.088,"Handrail")
    for s in (mid-3.58,mid-1.54,mid+1.54,mid+3.58):
        front.member(s-.16,s+.16,floor,3.51,.95,1.26,"HistoricStone",f"entry_column_{s:.2f}")
    front.member(mid-3.8,mid+3.8,3.23,3.54,-.25,1.31,"HistoricStone")
    front.member(mid-1.40,mid+1.40,2.98,3.22,-.08,.128,"BlackPlaque")
    front.nameplate("校史馆",mid,3.105,.141,.29)
    front.approach_steps(mid-3.92,mid+3.92,-.12,1.36,.14,2,.089,.31,"HistoricStone")
    front.member(mid-1.37,mid+1.37,.023,.132,1.66,8.95,"PavedForecourt","approach")
    for left,right,low,high,outset in ((.19,mid-3.60,.13,6.34,.15),
          (mid+3.60,w-.12,.13,7.35,.15),(mid-3.6,mid+3.6,3.28,3.72,1.30),
          (mid-3.37,mid+3.36,3.70,4.48,.143)):
        museum_ivy(front,left,right,low,high,outset)


def museum_ivy(front,left,right,low,high,outset):
    height=high-low
    for j in range(math.ceil(height/.17)):
        for i in range(math.ceil((right-left)/.16)):
            wave=math.sin(i*.57+j*.31)+math.sin(i*.17-j*.40)
            if low>3.6 and wave < -.76:
                continue
            x=left+.16*i+.042*math.sin(j*1.67+i)
            y=low+.17*j+.057*math.cos(i*.71+j*.78)
            if x>=right or y>=high:
                continue
            r=.057+.035*(.5+.5*math.sin(i*2.7+j*1.9))
            depth=outset+.085+.055*wave
            pts=[front.at(x-r*.90,y,depth),front.at(x-r*.47,y+r*.64,depth+.026),
                 front.at(x+r*.43,y+r*.67,depth+.024),front.at(x+r*.81,y+.02,depth+.012),
                 front.at(x+r*.20,y-r*.89,depth-.006)]
            mat=("MuseumIvyDeep","MuseumIvyMid","MuseumIvyLight")[(i+j*2)%3]
            front.geo(pts,[(0,1,2),(0,2,3),(0,3,4)],"Photo"+mat)


def historic(front,sides,outline,height,levels,facade):
    museum=front.name.endswith("634")
    facade(outline,levels,height,"PhotoHistoricYellow",3.85,detail_edges=(2 if museum else 16,))
    if museum:
        museum_entry(front,height,levels)
        return
    w=front.length
    band_windows(front,3.61,height,levels-1,4.13,"HistoricYellow",window="HistoricGlass",sill="HistoricStone")
    front.member(0,w,.25,3.61,-.38,-.146,"HistoricYellow")
    front.member(0,w,.25,.70,-.34,.093,"HistoricStone")
    door_width=1.64
    middle=w*.5
    a,b=middle-door_width*.5,middle+door_width*.5
    for s in (a,b):
        front.member(s-.15,s+.15,.27,3.21,-.24,.27,"HistoricStone")
    front.member(a-.15,b+.15,3.00,3.22,-.22,.265,"HistoricStone")
    front.member(a+.057,b-.058,.31,2.96,-.135,-.049,"HistoricRed")
    front.glazed_opening(a+.19,b-.19,1.81,2.66,-.011,2,"HistoricGlass",frame="LabAluminium")
    for y in (.46,1.18,1.71,2.78):
        front.member(a+.09,b-.09,y,y+.048,-.049,.024,"HistoricRed")
    for s in (w*.17,w*.81):
        front.glazed_opening(s-.98,s+.98,.91,2.91,-.10,3,"HistoricGlass",
                             cross=2.08,frame="LabAluminium")
        for x in (s-.99,s-.33,s+.33,s+.99):
            front.member(x-.035,x+.035,.88,2.94,-.119,-.005,"HistoricRed")
    front.approach_steps(a-.46,b+.46,-.01,1.14,.14,2,.089,.31,"HistoricStone")
    front.member(a-.90,b+.90,.03,.128,1.46,6.9,"PavedForecourt","approach")
    front.nameplate("行政楼",middle,3.10,.276,.20)
    for s0,s1 in ((.18,a-.34),(b+.34,w-.18)):
        vine(front,s0,s1,3.36,1.15)
    vine(front,.43,w-.42,height-.34,2.40)


def service_building(front,sides,outline,height,levels,facade):
    facade(outline,levels,height,"PhotoLabWhite",3.75,detail_edges=(3,))
    w=front.length
    band_windows(front,4.08,height,levels-1,4.3,"LabWhite",air_units=True)
    front.member(.05,w-.05,3.28,4.08,-.31,.59,"GardenBrick")
    front.member(.06,w-.06,3.38,3.95,.59,.72,"ServiceAwningShade")
    for row in range(4):
        bottom=3.39+row*.148
        front.member(.05,w-.05,bottom,bottom+.084,.70,.91,"ServiceAwningWood")
    for s in range(1,int(w),3):
        front.member(s-.024,s+.024,3.33,4.04,.725,.895,"ServiceAwningShade")
    front.glazed_opening(.23,w-.22,.27,3.30,-.12,17,"LabDarkGlass",cross=2.61,frame="LabAluminium")
    for s in range(0,int(w),5):
        front.member(s,s+.32,.22,3.33,-.30,.41,"GardenBrick")
    front.approach_steps(w*.46,w*.58,-.06,1.38,.14,2,.096,.31,"HistoricStone")
    front.nameplate("服务楼",w*.52,3.89,.916,.25,"WhiteLetters")


def apartment(front,sides,outline,height,levels,facade):
    facade(outline,levels,height,"PhotoApartmentPlaster",4.0,detail_edges=(0,2))
    for side in (sides[0],sides[2]):
        w=side.length
        step=(height-.43)/levels
        n=max(1,round(w/4.95))
        for floor in range(levels):
            y=.24+floor*step
            side.member(.03,w-.03,y+.14,y+step-.06,-.36,.008,"ApartmentPlaster")
            for i in range(n):
                s=(i+.5)*w/n
                if floor==0 or (i%3==1):
                    side.glazed_opening(s-.61,s+.61,y+.76,y+2.25,.029,2,"HistoricGlass",cross=y+1.8)
                    continue
                side.member(s-1.48,s+1.48,y+.17,y+.47,.027,1.02,"ApartmentPlaster")
                side.member(s-1.45,s+1.46,y+.47,y+1.14,.97,1.015,"ApartmentPlaster")
                side.glazed_opening(s-1.41,s+1.42,y+1.14,y+step-.21,1.006,
                                    4,"ApartmentGlazing",cross=y+step-.56)
                for x in (s-1.44,s+1.42):
                    side.member(x-.047,x+.047,y+.45,y+step-.15,.02,1.017,"ApartmentPlaster")
                if i%3==0:
                    side.member(s-1.39,s+1.39,y+step-.19,y+step-.103,.39,1.19,"ApartmentAwning")
        side.member(0,w,height-.27,height+.30,-.37,.11,"ApartmentPlaster")
    front.member(.2,front.length-.2,.05,.133,.13,3.0,"PavedForecourt","front_footpath")
    middle=front.length*.52
    front.member(middle-1.04,middle+1.04,.31,2.76,.019,.085,"HistoricGlass")
    front.member(middle-1.23,middle+1.23,2.63,2.82,.029,1.03,"ApartmentAwning")


EXTERIORS={
    "1135360046": (retirement,3),
    "271365631": (historic,16),
    "271365634": (historic,2),
    "271365637": (service_building,3),
    "1135360047": (apartment,2),
}


def build_life_exterior(asset,building,geo,slab,edgebox,inscription,solids,facade):
    outline=building["outline"]
    sides=[Exterior(asset,a,b,geo,slab,edgebox,inscription,solids)
           for a,b in zip(outline,outline[1:]+outline[:1])]
    model,edge=EXTERIORS[building["osm_way"]]
    model(sides[edge],sides,outline,building["height"],building["levels"],facade)
