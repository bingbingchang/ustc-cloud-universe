"""Apply per-street construction profiles and add the adjacent library district."""
from pathlib import Path
import json,math,random,sys
import research_road_network as geo
ROOT=geo.ROOT
def read(p):return json.loads((ROOT/p).read_text(encoding='utf-8'))
def write(p,d):(ROOT/p).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def distance(p,a,b):
    dx,dz=b[0]-a[0],b[1]-a[1]; t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dz)/(dx*dx+dz*dz))) if dx or dz else 0
    return math.dist(p,[a[0]+t*dx,a[1]+t*dz])

def run():
    network=read('godot/data/campus_road_network.json');refs=read('references/library_district/mapped_features.json')
    network['road_grades']={
        '1':{'name':'车行主路','construction':'沥青车行面，按路段设置抬高人行道、路缘石与交叉口开口'},
        '2':{'name':'校园支路／共享通道','construction':'较窄沥青或块材路，默认无独立人行道，直接连接绿地和建筑前场'},
        '3':{'name':'步行／观景小道','construction':'石板、卵石、砖铺或照片中的窄沥青步道，无车行道和双侧人行道'}}
    main={'265032055':(9.2,2.0),'265032054':(8.0,1.7),'264872431':(7.0,1.5),
          '264872432':(8.0,1.5),'345670547':(8.0,1.5),'478776411':(8.0,1.5),'478776412':(8.0,1.5),
          '265033441':(7.2,1.5),'270792805':(7.5,1.5),'478761391':(7.5,1.5),'478761392':(7.5,1.5)}
    for road in network['roads']:
        wid=road['source']['osm_way']
        if wid in main:
            road['grade']=1;road['width'],road['sidewalk_width']=main[wid];road['surface']='asphalt'
        elif road['osm_highway'] in ['footway','steps']:
            road['grade']=3;road['sidewalk_width']=0;road['surface']='stone';road['width']=min(3.2,road['width'])
        else:
            road['grade']=2;road['sidewalk_width']=0
            if road['osm_highway']=='pedestrian':road['surface']='pavers'
        road['edge_type']='raised_curb' if road['sidewalk_width'] else 'flush_green_or_frontage'
        road['grading_basis']='Game functional hierarchy, individually assigned from satellite and OSM use; not an official civil-engineering road class.'
        if wid=='265032055':
            road['width_basis']='User identifies broad vehicle road west of USTC1958; 2026-10-12 public satellite pavement/vehicle scale estimate.'
            road['estimated_width_range_m']=[8.5,10.0]
    known={r['source']['osm_way'] for r in network['roads']}
    for path in refs['paths']:
        if path['osm_way'] in known:continue
        kind=path['highway'];wid=path['osm_way']
        road={'id':'road_'+wid,'name':'楼间支路' if kind=='service' else '校园步道',
              'points':path['points'],'width':4.2 if kind=='service' else 2.4,'sidewalk_width':0,
              'surface':'asphalt' if kind=='service' else 'stone','grade':2 if kind=='service' else 3,
              'edge_type':'flush_green_or_frontage','osm_highway':kind,'priority':'library_district',
              'source':{'osm_way':wid,'url':path['source'],'geometry':'Original OSM centerline'},
              'width_basis':'Satellite visible path proportions; estimated, not surveyed'}
        if wid=='265033443':road['name']='二教南侧横路';road['width']=5.0
        if wid=='306496886':road['name']='老图书馆前步行轴线';road['width']=3.6;road['surface']='pavers'
        if kind=='steps':road['name']='二教台阶通道';road['surface']='stone';road['structure']='steps'
        if wid=='1135725450':road['build_enabled']=False;road['note']='Mapped lower-level passage; remains closed until under-building access is made.'
        network['roads'].append(road)
    existing={b['osm_way'] for b in network['buildings']}
    for b in refs['buildings']:
        if b['osm_way'] not in existing:network['buildings'].append(b)
    write('godot/data/campus_road_network.json',network)
    modules=read('godot/data/module_layout.json')
    new=[{'id':'guo_west_corridor_06','name':'1958西侧郭沫若路宽路带','template':'mapped_campus_land',
          'polygon':[[-98,232],[-70,232],[-70,453],[-98,453]],'bounds':[-98,232,-70,453]},
         {'id':'library_district_06','name':'老图书馆—新图书馆—第二教学楼','template':'library_district',
          'polygon':[[-98,280],[82,280],[82,293],[198,293],[198,453],[-98,453]],'bounds':[-98,280,198,453]}]
    for m in new:
        m.update(enabled=True,ports=[],story_nodes=[],surface_top=.10,ground_y=0,
                 source='references/library_district/library_osm_overlay.jpg')
        modules['modules']=[s for s in modules['modules'] if s['id']!=m['id']];modules['modules'].append(m)
    write('godot/data/module_layout.json',modules)
    north=read('godot/data/north_axis_layout.json')
    for path in north['paths']:
        if path['width']<3.1:
            path.update(grade=3,sidewalk_width=0,surface='pebble' if path['id'] in ['east_west_shore','west_bank'] else 'stone')
        elif path['id']=='expert_access':path.update(grade=2,sidewalk_width=0,surface='asphalt')
    write('godot/data/north_axis_layout.json',north)
    # Hardscape follows the visible forecourts; the remaining terrain stays lawn.
    district={'buildings':refs['buildings'],'hardscape':[
      {'id':'old_library_front','surface':'pavers','polygon':[[-22,347],[22,347],[22,372],[-22,372]]},
      {'id':'library_south_front','surface':'granite','polygon':[[-28,428],[28,428],[28,438],[-28,438]]},
      {'id':'teaching2_front','surface':'concrete','polygon':[[80,346],[139,346],[139,365],[80,365]]},
      {'id':'teaching2_east_court','surface':'pavers','polygon':[[169,302],[187,302],[187,351],[169,351]]},
      {'id':'canteen_front','surface':'concrete','polygon':[[94,383],[178,383],[178,400],[94,400]]}],
      'walk_routes':[
       {'id':'coffee_west_to_library','points':[[-78.37,258.629],[-77.893,337.209],[-78.506,399.025],[-78.697,440.959],[0,441.74]]},
       {'id':'plaza_to_old_library','points':[[-5.7,280],[-5.7,330],[-.738,336.966],[-.34,361],[-.34,367.0]]},
       {'id':'tianshi_to_teaching2','points':[[75.215,233.425],[74.136,308.231],[73.629,352.75],[91.55,354.42],[123,354.3],[124.03,367.0]]},
       {'id':'library_ring','points':[[73.573,337.749],[73.575,367.063],[73.492,391.421],[73.813,441.856],[0,441.74],[-78.697,440.959],[-77.893,337.209]]}],
      'sources':refs['sources'],'ground_plan_basis':'Satellite forecourts/path edges and OSM footprints; individual paving patterns and plants are art-directed.'}
    # Tree positions follow the canopy masses without placing roots on hardscape.
    doc,nodes,ways,tags,points=geo.osm();buildings=[points(w) for w in ways.values() if 'building' in tags(w)]
    random.seed(1958380);trees=[]
    outline=new[1]['polygon']
    for z in range(290,445,13):
        for x in range(-91,194,13):
            p=[x+random.uniform(-2.4,2.4),z+random.uniform(-2.4,2.4)]
            if not geo.contains(outline,p):continue
            if any(geo.contains(b,p) or min(distance(p,a,c) for a,c in zip(b,b[1:]+b[:1]))<2 for b in buildings):continue
            if any(geo.contains(h['polygon'],p) for h in district['hardscape']):continue
            if any(min(distance(p,a,b) for a,b in zip(r['points'],r['points'][1:]))<r['width']/2+r['sidewalk_width']+1.4 for r in network['roads']):continue
            # Keep the old-library axis and library main entrance visible.
            if abs(p[0])<8 and 330<p[1]<374:continue
            key=['tree_plane_a','tree_garden','tree_plane_b','tree_conifer','tree_plane_c'][len(trees)%5]
            trees.append({'asset':key,'position':[round(p[0],3),0,round(p[1],3)],'scale':round(random.uniform(.86,1.12),3),'heading':round(random.random()*math.tau,4)})
    district['trees']=trees
    write('godot/data/library_district.json',district)
    print('LIBRARY_LAYOUT',len(network['roads']),'roads',len(trees),'new trees',len(refs['buildings']),'buildings')

if __name__=='__main__':run()
