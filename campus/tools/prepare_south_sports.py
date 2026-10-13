"""Extend the southern sports district, keeping mapped courts and buildings distinct."""
import json,math,random,sys
import research_road_network as geo
from prepare_library_district import distance
ROOT=geo.ROOT
def read(p):return json.loads((ROOT/p).read_text(encoding='utf-8'))
def write(p,d):(ROOT/p).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def rect(x,z,w,l,heading=0):
    return [[round(x+dx*math.cos(heading)+dz*math.sin(heading),4),round(z-dx*math.sin(heading)+dz*math.cos(heading),4)]
            for dx,dz in [(-w/2,-l/2),(w/2,-l/2),(w/2,l/2),(-w/2,l/2)]]

def run():
    refs=read('references/south_sports/mapped_features.json');net=read('godot/data/campus_road_network.json')
    profiles={'265033437':('球场西侧南北连接路',4.8,2,0),
              '265032060':('物理楼路·南侧横路',7.0,1,1.5),
              '298766877':('球场东侧服务路',3.5,2,0),
              '265033438':('西侧公寓连接路',4.0,2,0)}
    known={r['source']['osm_way']:r for r in net['roads']}
    for r in refs['paths']:
        wid=r['osm_way'];name,width,grade,side=profiles[wid]
        data={'name':name,'width':width,'grade':grade,'sidewalk_width':side,'surface':'asphalt',
              'edge_type':'raised_curb' if side else 'flush_green_or_frontage',
              'width_basis':'Satellite pavement/curb proportions cross-checked with official GIS image; visual estimate.'}
        if wid in known:known[wid].update(data)
        else:net['roads'].append({'id':'road_'+wid,'points':r['points'],'osm_highway':r['highway'],
               'priority':'south_sports','source':{'osm_way':wid,'url':r['source'],'geometry':'Original mapped centerline'},**data})
    # Narrow lanes visible between court groups and in the open dormitory courtyard.
    paths=[('courts_north_cross',[[-271.19,550.03],[-226,550.0],[-178,550.0],[-82,542.0]],3.0),
           ('courts_middle_cross',[[-271.1,589.0],[-233,589.0],[-180,589.0],[-179,614.4],[-137.8,614.4]],2.4),
           ('courts_south_link',[[-271.1,631],[-229.5,631],[-229.5,660],[-137.2,660]],2.4),
           ('dorm_courtyard',[[-271.1,625],[-285,625],[-307,625],[-326.5,625]],3.0),
           ('west_gym_approach',[[-271.1,570],[-295,570],[-318,570]],2.4)]
    for id,p,w in paths:
        rid='south_'+id
        if any(r['id']==rid for r in net['roads']):continue
        net['roads'].append({'id':rid,'name':'南侧球场与公寓步道','points':p,'width':w,'grade':3,'sidewalk_width':0,
           'surface':'concrete','edge_type':'flush_green_or_frontage','osm_highway':'footway','priority':'south_sports',
           'source':{'osm_way':'satellite_'+id,'url':refs['sources'][0]['url'],'geometry':'Visible satellite/GIS path, approximate hand registration in existing metre frame'},
           'width_basis':'Aerial visible lane, approximate'})
    old={b['osm_way'] for b in net['buildings']}
    for b in refs['buildings']:
        if b['osm_way'] not in old:net['buildings'].append(b)
    write('godot/data/campus_road_network.json',net)
    modules=read('godot/data/module_layout.json')
    spec={'id':'south_sports_08','name':'运动场南侧球场—364／365公寓','template':'south_sports','enabled':True,
          'bounds':refs['bounds'],'polygon':refs['polygon'],'surface_top':.105,'ground_y':0,'ports':[],'story_nodes':[],
          'source':'references/south_sports/south_osm_overlay.jpg'}
    modules['modules']=[m for m in modules['modules'] if m['id']!=spec['id']];modules['modules'].append(spec);write('godot/data/module_layout.json',modules)
    courts=[]
    for i,(x,z,w,l) in enumerate([(-254.5,567.5,14.2,26.0),(-238.4,567.5,14.2,26.0),
                               (-224,610.0,14.4,27.0),(-208.5,610.0,14.4,27.0),(-193,610.0,14.4,27.0)]):
        courts.append({'id':'basketball_'+str(i+1),'sport':'basketball','center':[x,z],'width':w,'length':l,'heading':0,
              'polygon':rect(x,z,w+1.5,l+2.8),'court_polygon':rect(x,z,w,l),
              'basis':'5 separate markings visible in satellite/GIS; fitted to actual grouped footprints, dimensions approximate.'})
    for i,(x,z,a) in enumerate([(-166.4,594.8,0),(-149.2,594.8,0),(-166.4,634.0,0),(-149.2,634.0,0),(-204.0,642.5,math.pi/2)]):
        courts.append({'id':'tennis_'+str(i+1),'sport':'tennis','center':[x,z],'width':10.97,'length':23.77,'heading':a,
              'polygon':rect(x,z,16.5,34.2,a),'court_polygon':rect(x,z,10.97,23.77,a),
              'basis':'Four north/south courts plus one west transverse court in aerial image; colors/fence cross-checked against 2026 official photo.'})
    d={'buildings':refs['buildings'],'courts':courts,'sources':refs['sources'],
       'hardscape':[{'id':'dorm_courtyard','surface':'pavers','polygon':[[-329,615],[-276,615],[-276,637],[-329,637]]},
                    {'id':'service_front','surface':'concrete','polygon':[[-134,647],[-90,647],[-90,658],[-134,658]]}],
       'benches':[[-285,618,1.57],[-318,633,0],[-230,588,0],[-180,626,1.57],[-130,657,0]],
       'lamps':[[-273.8,556,0],[-273.8,589,0],[-273.8,631,0],[-285,622,0],[-318,631,0],[-88,578,0],[-88,622,0],[-131,657,0]],
       'walk_routes':[
          {'id':'track_to_south_courts','points':[[-176.76,530],[-176.76,544.88],[-177,550],[-226,550],[-271.19,550.03],[-271.1,589],[-271.1,625]]},
          {'id':'guo_road_to_south_cross','points':[[-78.7,441],[-80.7,517.5],[-82,598.7],[-83.94,667.58],[-175.1,666.77],[-271.08,664.38]]},
          {'id':'dorm364_365_courtyard','points':[[-271.1,625],[-285,625],[-305,625],[-326.5,625]]},
          {'id':'courts_to_tennis_gates','points':[[-271.1,589],[-233,589],[-180,589],[-179,614.4],[-137.8,614.4]]},
          {'id':'south_walk_and_exit','points':[[-271.1,631],[-229.5,631],[-229.5,660],[-180,660],[-137.2,660],[-137.09,666.8]]}]}
    for court in courts:
        x,z=court['center'];d['walk_routes'].append({'id':court['id']+'_surface','points':[[x,z-court['length']*.28],[x,z],[x,z+court['length']*.28]]} if court['heading']==0 else {'id':court['id']+'_surface','points':[[x-7,z],[x,z],[x+7,z]]})
    # Canopies stay out of the painted courts, court runoff and real building footprints.
    _,_,ways,tags,points=geo.osm();footprints=[points(w) for w in ways.values() if 'building' in tags(w)]
    occupied=read('godot/data/sports_district.json')['trees'];random.seed(364365);trees=[]
    for z in range(538,670,11):
        for x in range(-374,-88,11):
            p=[x+random.uniform(-1.8,1.8),z+random.uniform(-1.8,1.8)]
            if not geo.contains(spec['polygon'],p):continue
            if any(geo.contains(b,p) or min(distance(p,a,c) for a,c in zip(b,b[1:]+b[:1]))<2.5 for b in footprints):continue
            if any(geo.contains(c['polygon'],p) or min(distance(p,a,b) for a,b in zip(c['polygon'],c['polygon'][1:]+c['polygon'][:1]))<2.0 for c in courts):continue
            if any(geo.contains(h['polygon'],p) for h in d['hardscape']):continue
            if any(min(distance(p,a,b) for a,b in zip(r['points'],r['points'][1:]))<r['width']/2+r['sidewalk_width']+1.5 for r in net['roads']):continue
            if any(math.dist(p,[t['position'][0],t['position'][2]])<8 for t in occupied):continue
            trees.append({'asset':['tree_plane_a','tree_garden','tree_plane_b','tree_conifer','tree_plane_c'][len(trees)%5],
                'position':[round(p[0],3),0,round(p[1],3)],'scale':round(random.uniform(.80,1.05),3),'heading':round(random.random()*math.tau,4)})
    d['trees']=trees;write('godot/data/south_sports.json',d);print('SOUTH_LAYOUT',len(courts),'courts',len(trees),'trees',len(net['roads']),'roads')

def finish_entrances():
    d=read('godot/data/south_sports.json');manifest=read('godot/assets/south_sports_manifest.json');net=read('godot/data/campus_road_network.json')
    d['hardscape']=[h for h in d['hardscape'] if not h['id'].startswith('entry_')];approaches=[]
    for b in manifest['buildings']:
        p=[b['front_approach'][0],b['front_approach'][2]];choices=[]
        for r in net['roads']:
            for a,c in zip(r['points'],r['points'][1:]):
                dx,dz=c[0]-a[0],c[1]-a[1];t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dz)/(dx*dx+dz*dz))) if dx or dz else 0
                choices.append([a[0]+t*dx,a[1]+t*dz])
        q=min(choices,key=lambda q:math.dist(q,p));approaches.append((p,q))
        d['hardscape'].append({'id':'entry_'+b['osm_way'],'surface':'concrete','polygon':rect(p[0],p[1],9,4.6)})
        d['walk_routes']=[r for r in d['walk_routes'] if r['id']!='entry_'+b['osm_way']]
        d['walk_routes'].append({'id':'entry_'+b['osm_way'],'points':[q,p]})
    d['trees']=[t for t in d['trees'] if all(distance([t['position'][0],t['position'][2]],p,q)>3 for p,q in approaches)
                and not any(geo.contains(h['polygon'],[t['position'][0],t['position'][2]]) for h in d['hardscape'])]
    write('godot/data/south_sports.json',d);print('SOUTH_ENTRANCES',len(approaches),'trees',len(d['trees']))
if __name__=='__main__':finish_entrances() if '--finish-entrances' in sys.argv else run()
