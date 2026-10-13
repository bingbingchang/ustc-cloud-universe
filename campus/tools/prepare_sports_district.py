"""Add the adjacent athletic/dormitory module in the existing campus frame."""
import json,math,random,sys
import research_road_network as geo
from prepare_library_district import distance
ROOT=geo.ROOT
def read(p):return json.loads((ROOT/p).read_text(encoding='utf-8'))
def write(p,d):(ROOT/p).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def run():
    refs=read('references/sports_district/mapped_features.json')
    network=read('godot/data/campus_road_network.json')
    names={'265575541':'运动场北侧连接路','308701271':'运动场东侧步道',
           '302181056':'320与321楼间支路','1135310345':'321与322楼间支路',
           '551220504':'322与323楼间步道','265032058':'树路·运动场南侧横路',
           '265575538':'体育教学部东侧支路'}
    known={r['source']['osm_way']:r for r in network['roads']}
    for path in refs['paths']:
        wid=path['osm_way'];foot=path['highway']=='footway'
        profile={'name':names[wid],'width':2.6 if foot else (5.5 if wid=='265032058' else 4.4),
                 'sidewalk_width':0,'grade':3 if foot else 2,'surface':'concrete' if foot else 'asphalt',
                 'edge_type':'flush_green_or_frontage',
                 'width_basis':'Satellite pavement proportions; estimated widths, no independent sidewalks on narrow dormitory lanes.'}
        if wid in known:known[wid].update(profile)
        else:
            network['roads'].append({'id':'road_'+wid,'points':path['points'],'osm_highway':path['highway'],
              'priority':'sports_district','source':{'osm_way':wid,'url':path['source'],'geometry':'Original OSM centerline'},**profile})
    existing={b['osm_way'] for b in network['buildings']}
    for b in refs['buildings']:
        if b['osm_way'] not in existing:network['buildings'].append(b)
    write('godot/data/campus_road_network.json',network)
    modules=read('godot/data/module_layout.json')
    spec={'id':'sports_district_07','name':'东区田径场与320—323学生公寓','template':'sports_district',
          'enabled':True,'bounds':refs['bounds'],'polygon':refs['polygon'],'surface_top':.10,'ground_y':0,
          'ports':[],'story_nodes':[],'source':'references/sports_district/sports_osm_overlay.jpg'}
    modules['modules']=[s for s in modules['modules'] if s['id']!=spec['id']];modules['modules'].append(spec)
    write('godot/data/module_layout.json',modules)
    center=[-225.45,456.16];radius=46.8;half=39.5
    outer=[]
    for k in range(65):
        a=math.pi*k/64;outer.append([round(center[0]+radius*math.cos(a),4),round(center[1]+half+radius*math.sin(a),4)])
    for k in range(65):
        a=math.pi+math.pi*k/64;outer.append([round(center[0]+radius*math.cos(a),4),round(center[1]-half+radius*math.sin(a),4)])
    hardscape=[{'id':'field_north_entry','surface':'concrete','polygon':[[-190,379],[-170,379],[-170,398],[-190,398]]},
               {'id':'dorm_courts','surface':'pavers','polygon':[[-173,430],[-97,430],[-97,448],[-173,448]]}]
    for b in refs['buildings']:
        if not b['osm_way'].startswith('267'):continue
        p=b['outline'];z=max(q[1] for q in p)
        hardscape.append({'id':'entry_'+b['osm_way'],'surface':'concrete','polygon':[[-144,z],[-119,z],[-119,z+5.0],[-144,z+5.0]]})
    d={'buildings':refs['buildings'],'hardscape':hardscape,
       'track':{'center':center,'outer_radius':radius,'straight_half_length':half,'lanes':8,'lane_width':1.22,'outer_polygon':outer,
                'basis':'Eight red lanes visible in official photographs; oval fit to satellite edges, not a surveyed athletics specification.'},
       'soccer_outline':refs['soccer_outline'],'grandstand_outline':refs['grandstand_outline'],
       'sources':refs['sources'],
       'benches':[[-165,436,0],[-106,436,0],[-165,477,0],[-107,477,0],[-165,511,0],[-107,511,0]],
       'lamps':[[-88,403,0],[-88,439,0],[-88,475,0],[-88,513,0],[-183,390,0],[-174.6,438,0],[-174.6,482,0],[-184,528,0]],
       'walk_routes':[
        {'id':'coffee_to_sports_entry','points':[[-78.37,258.63],[-77.893,337.21],[-78.506,399.025],[-144.659,397.992],[-151.651,389.465],[-162.632,382.702],[-178.031,376.87],[-192,390],[-186,417]]},
        {'id':'library_to_dorms','points':[[20,441.74],[-78.697,440.959],[-117,440.7],[-160,440.5],[-177.55,440.5]]},
        {'id':'dorm_east_to_south','points':[[-78.7,440.96],[-79.5,469.7],[-80.7,517.5],[-81.2,541.7],[-132,542.5],[-177,544.88]]},
        {'id':'dorm_west_walkway','points':[[-178.031,376.87],[-177.55,440.5],[-177.36,469.6],[-177.0,517],[-176.759,544.879]]},
        {'id':'track_full_lap','points':[]},
        {'id':'football_cross_field','points':[[-225.45,405],[-225.45,432],[-225.45,480],[-225.45,508]]}]}
    lap=[];r=42.0
    for k in range(13):
        a=math.pi*k/12;lap.append([center[0]+r*math.cos(a),center[1]+half+r*math.sin(a)])
    for k in range(13):
        a=math.pi+math.pi*k/12;lap.append([center[0]+r*math.cos(a),center[1]-half+r*math.sin(a)])
    lap.append(lap[0]);d['walk_routes'][4]['points']=lap
    for b in refs['buildings']:
        if not b['osm_way'].startswith('267'):continue
        z=max(q[1] for q in b['outline'])+2.4
        d['walk_routes'].append({'id':'entry_'+b['osm_way'],'points':[[-87,z],[-112,z],[-131,z]]})
    _,_,ways,tags,points=geo.osm();footprints=[points(w) for w in ways.values() if 'building' in tags(w)]
    occupied=[t['position'] for t in read('godot/data/library_district.json')['trees']]
    random.seed(320323);trees=[]
    for z in range(361,548,12):
        for x in range(-326,-88,12):
            p=[x+random.uniform(-2,2),z+random.uniform(-2,2)]
            if not geo.contains(spec['polygon'],p) or geo.contains(outer,p):continue
            if any(geo.contains(b,p) or min(distance(p,a,c) for a,c in zip(b,b[1:]+b[:1]))<2.3 for b in footprints):continue
            if any(geo.contains(h['polygon'],p) for h in hardscape):continue
            if any(min(distance(p,a,b) for a,b in zip(r['points'],r['points'][1:]))<r['width']/2+r['sidewalk_width']+1.3 for r in network['roads']):continue
            if any(math.dist(p,[t[0],t[2]])<8 for t in occupied):continue
            key=['tree_plane_a','tree_plane_b','tree_garden','tree_plane_c','tree_conifer'][len(trees)%5]
            trees.append({'asset':key,'position':[round(p[0],3),0,round(p[1],3)],'scale':round(random.uniform(.80,1.12),3),'heading':round(random.random()*math.tau,4)})
    d['trees']=trees;write('godot/data/sports_district.json',d)
    print('SPORTS_LAYOUT',len(trees),'trees',len(network['roads']),'roads',len(d['walk_routes']),'routes')
def finish_entrances():
    # Ground and planting follow the generated door approach, not an assumed building centre.
    d=read('godot/data/sports_district.json');manifest=read('godot/assets/sports_district_manifest.json')
    network=read('godot/data/campus_road_network.json')
    d['hardscape']=[h for h in d['hardscape'] if not h['id'].startswith('entry_')]
    d['walk_routes']=[r for r in d['walk_routes'] if not r['id'].startswith('entry_')]
    approaches=[]
    for b in manifest['buildings']:
        p=[b['front_approach'][0],b['front_approach'][2]]
        segments=[(a,c) for road in network['roads'] for a,c in zip(road['points'],road['points'][1:])]
        def closest(a,c):
            dx,dz=c[0]-a[0],c[1]-a[1];t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dz)/(dx*dx+dz*dz))) if dx or dz else 0
            return [a[0]+t*dx,a[1]+t*dz]
        q=min((closest(a,c) for a,c in segments),key=lambda q:math.dist(p,q));approaches.append((p,q))
        d['hardscape'].append({'id':'entry_'+b['osm_way'],'surface':'concrete',
            'polygon':[[p[0]-5,p[1]-2.5],[p[0]+5,p[1]-2.5],[p[0]+5,p[1]+2.3],[p[0]-5,p[1]+2.3]]})
        if b['osm_way'].startswith('267'):
            d['walk_routes'].append({'id':'entry_'+b['osm_way'],'points':[q,p]})
    before=len(d['trees'])
    d['trees']=[t for t in d['trees'] if all(distance([t['position'][0],t['position'][2]],p,q)>3 for p,q in approaches)
                and not any(geo.contains(h['polygon'],[t['position'][0],t['position'][2]]) for h in d['hardscape'])]
    write('godot/data/sports_district.json',d);print('SPORTS_ENTRANCES',len(approaches),'trees',before,'->',len(d['trees']))

if __name__=='__main__':
    finish_entrances() if '--finish-entrances' in sys.argv else run()
