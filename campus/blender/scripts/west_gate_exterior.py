"""East Campus main gate (GIS panoramas 6 and 7)."""

from mapped_landmark_details import Exterior


GATE_MATERIALS = {
    "GateMasonry": ((.305,.321,.31),.82,0),
    "GateInset": ((.168,.078,.049),.63,.15),
    "GateTrim": ((.389,.365,.32),.73,.07),
    "GateLane": ((.139,.151,.144),.91,0),
    "GateLine": ((.66,.585,.37),.83,0),
    "GateWhitePaint": ((.78,.78,.705),.85,0),
    "GateRail": ((.34,.38,.37),.55,.40),
    "GateGlass": ((.11,.19,.188),.24,.24),
    "GateAwning": ((.29,.132,.264),.92,0),
    "GateFlag": ((.52,.029,.029),.82,0),
}


def main_gate(asset, building, geo, slab, edgebox, inscription, solids):
    p=building["outline"]
    face=Exterior(asset,p[3],p[0],geo,slab,edgebox,inscription,solids)
    w=face.length
    jamb=3.72
    depth=4.22
    for i,(a,b) in enumerate(((0,jamb),(w-jamb,w))):
        face.member(a,b,.14,5.62,-depth,.04,"GateMasonry",f"main_pier_{i}")
        face.member(a-.15,b+.16,.14,.43,-depth-.13,.20,"GateTrim")
    face.member(0,w,4.89,7.28,-depth,.04,"GateMasonry","top_beam")
    face.member(-.06,w+.06,7.23,7.43,-depth-.08,.12,"GateTrim")
    face.member(jamb-.20,w-jamb+.20,4.89,5.45,-depth-.09,.165,"GateInset")
    for i,s in enumerate((jamb,w-jamb)):
        face.member(s-.42,s+.42,.14,4.90,-depth-.09,.164,"GateInset",f"portal_jamb_{i}")
        face.member(s-.48,s+.48,4.87,5.52,-depth-.07,.192,"GateTrim")
    for row in range(11):
        y=.30+row*.63
        for a,b in ((.04,jamb-.39),(w-jamb+.39,w-.04)):
            face.member(a,b,y,y+.018,.041,.057,"GateTrim")
        if y>=5.48:
            face.member(jamb-.38,w-jamb+.38,y,y+.018,.041,.055,"GateTrim")
    face.nameplate("中 国 科 学 技 术 大 学",w*.50,6.37,.067,.74)
    return_face=Exterior(asset,p[1],p[2],geo,slab,edgebox,inscription,solids)
    return_face.nameplate("中 国 科 学 技 术 大 学",return_face.length*.50,6.37,.071,.70)
    # Road surface runs continuously beneath the portal and both island bypasses.
    face.member(jamb-.4,w-jamb+.40,.056,.138,-depth-10.9,6.5,"GateLane","portal_ground")
    face.member(-.21,w+.21,.049,.138,6.5,28.1,"GateLane")
    face.member(.015,jamb-.405,.052,.138,.04,6.5,"GateLane")
    face.member(w-jamb+.405,w-.015,.052,.138,.04,6.5,"GateLane")
    for s in (w*.24,w*.76):
        face.member(s-.064,s+.064,.138,.147,5.18,26.1,"GateWhitePaint")
    for row in range(6):
        d = 11.0+row*2.38
        face.member(w*.50-.059,w*.50+.059,.138,.147,d,d+1.05,"GateWhitePaint")
    for a,b in ((w*.07,w*.245),(w*.755,w*.92)):
        for d in (2.29,4.27):
            face.member(a,b,.138,.149,d-.051,d+.051,"GateWhitePaint")
        for rail_y in (.52,.93):
            face.member(a,b,rail_y-.037,rail_y+.037,4.12,4.17,"GateRail")
        for i in range(9):
            s = a+(b-a)*i/8
            face.member(s-.019,s+.019,.139,1.005,4.12,4.17,"GateRail")
        face.block(f"apron_rail_{a}",face.polygon(a,b,4.1,4.19),.138,1.005)
    island=face.polygon(w*.66,w*.66+1.25,-depth-10.5,-depth-3.0)
    face.slab(island,.136,.278,"PhotoGateTrim")
    face.block("island",island,.136,.278)
    center=w*.66+.625
    face.member(center-.09,center+.09,.278,2.59,-depth-8.0,-depth-7.83,"GateTrim","island_post")
    face.member(center-1.14,center+1.14,2.53,2.84,-depth-9.15,-depth-6.69,"GateAwning")
    for direction in (-1,1):
        s=center+direction*.95
        face.member(s-.048,s+.048,.14,.155,-depth-11.3,-depth-4.6,"GateLine")
    face.member(w*.49,w*.49+.053,7.41,9.36,-2.15,-2.09,"GateTrim")
    face.member(w*.49+.025,w*.49+1.50,8.62,9.29,-2.145,-2.107,"GateFlag")
    # Pavilion at the side of the entry, leaving the pedestrian opening clear.
    a,b=1.09,jamb-.28
    face.member(a,b,.14,1.01,-depth-2.41,-depth-.08,"GateTrim","gatehouse")
    face.member(a,b,1.01,2.57,-depth-2.4,-depth-.08,"GateGlass","gatehouse_glazing")
    face.member(a-.20,b+.20,2.55,2.81,-depth-2.64,-depth+.14,"GateTrim")
