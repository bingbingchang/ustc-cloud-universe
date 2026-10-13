"""Complete mapped district roads, entrances and planted spaces in the existing metre frame."""
import json,math,random,sys
import research_road_network as geo
from prepare_library_district import distance
ROOT=geo.ROOT
def read(p):return json.loads((ROOT/p).read_text(encoding='utf-8'))
def write(p,d):(ROOT/p).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def center(p):return [sum(q[i] for q in p)/len(p) for i in [0,1]]
def nearest(p,roads):
    out=[]
    for r in roads:
        for a,b in zip(r['points'],r['points'][1:]):
            dx,dz=b[0]-a[0],b[1]-a[1];dd=dx*dx+dz*dz
            if not dd:continue
            t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dz)/dd))
            out.append([a[0]+t*dx,a[1]+t*dz])
    return sorted(out,key=lambda q:math.dist(p,q))
def rect(x,z,w,l):return [[x-w/2,z-l/2],[x+w/2,z-l/2],[x+w/2,z+l/2],[x-w/2,z+l/2]]
def run():
    refs=read('references/full_campus/mapped_districts.json');net=read('godot/data/campus_road_network.json')
    known={str(r['source']['osm_way']) for r in net['roads']}
    net['roads']=[r for r in net['roads'] if r['id']!='physics_east_walk_connection']
    for d in refs['districts']:
        for r in d['paths']:
            if r['osm_way'] in known:continue
            h=r['highway'];grade=3 if h in ['footway','path','steps','pedestrian'] else 2
            width=2.6 if grade==3 else 4.2;side=0
            if h in ['tertiary','residential','unclassified'] and (r['name']!='校内连接路' or h=='tertiary'):grade=1;width=6.2;side=1.3
            if r.get('width_tag'):
                try:width=float(r['width_tag'])
                except ValueError:pass
            net['roads'].append({'id':'road_'+r['osm_way'],'name':r['name'],'points':r['points'],'width':width,'grade':grade,'sidewalk_width':side,
                'surface':'concrete' if grade==3 else 'asphalt','edge_type':'raised_curb' if side else 'flush_green_or_frontage',
                'osm_highway':h,'priority':d['id'],'source':{'osm_way':r['osm_way'],'url':r['source'],'geometry':'Original mapped centerline'},
                'width_basis':'Satellite pavement proportion cross-checked with JS GIS illustration; approximate width'})
            known.add(r['osm_way'])
    all_buildings=net['buildings']+[b for d in refs['districts'] for b in d['buildings']]
    # All campus footprints also protect unbuilt tiny service sheds from planting.
    _,_,ways,tags,points=geo.osm();boundary=points(ways['262614785'])[:-1]
    footprints=[points(w)[:-1] for w in ways.values() if tags(w).get('building','no')!='no' and points(w)[0]==points(w)[-1]]
    existing_trees=[]
    for p in ['sports_district','south_sports','library_district']:
        for t in read('godot/data/'+p+'.json').get('trees',[]):existing_trees.append([t['position'][0],t['position'][2]])
    planting=read('godot/data/campus_tree_planting.json')
    for t in planting.get('trees',[]):existing_trees.append([t['position'][0],t['position'][2]])
    sports=read('godot/data/sports_district.json');south_sports=read('godot/data/south_sports.json')
    playing_areas=[sports['track']['outer_polygon']]+[c['polygon'] for c in south_sports['courts']]
    lamps=[];random.seed(951012)
    modules=read('godot/data/module_layout.json')
    for d in refs['districts']:
        d['hardscape']=[];d['trees']=[];d['lamps']=[];d['benches']=[];d['walk_routes']=[]
        for b in d['buildings']:
            p=b['outline'];area=sum(a[0]*c[1]-c[0]*a[1] for a,c in zip(p,p[1:]+p[:1]))/2
            if area<0:p=p[::-1];b['outline']=p
            choices=[]
            for i,(a,c) in enumerate(zip(p,p[1:]+p[:1])):
                length=math.dist(a,c)
                if length<4.5:continue
                mx,mz=(a[0]+c[0])/2,(a[1]+c[1])/2;nx,nz=(c[1]-a[1])/length,-(c[0]-a[0])/length
                approach=[mx+nx*4.5,mz+nz*4.5]
                if not geo.contains(d['polygon'],approach) or any(geo.contains(f,approach) for f in footprints):continue
                for q in nearest(approach,net['roads'])[:30]:
                    if min(distance(q,u,v) for u,v in zip(boundary,boundary[1:]+boundary[:1]))<1.2:continue
                    if any(any(geo.contains(f,[approach[0]+(q[0]-approach[0])*k/12,approach[1]+(q[1]-approach[1])*k/12]) for k in range(13)) for f in footprints):continue
                    choices.append((math.dist(q,approach),i,approach,q));break
            if choices:
                _,i,approach,q=min(choices);b['entry_edge']=i;b['front_approach']=[approach[0],.1,approach[1]];b['approach_road']=q
                d['walk_routes'].append({'id':'entry_'+b['osm_way'],'points':[q,approach]})
                d['hardscape'].append({'id':'entry_'+b['osm_way'],'surface':'concrete','polygon':rect(*approach,8,5)})
        for f in d['features']:
            if any(geo.contains(m['polygon'],center(f['polygon'])) for m in modules['modules'] if m['enabled'] and m.get('polygon') and m['id'] not in [s['id'] for s in refs['districts']]):continue
            d['hardscape'].append({'id':f['osm_way'],'surface':'asphalt' if f['kind']=='parking' else 'pavers','polygon':f['polygon'],'kind':f['kind']})
        # Sparse geometric garden paths visible on the aerial lawn east of the main axis.
        if d['id']=='east_living_10':
            for name,ps in [('east_garden_cross',[[96,160],[122,184],[154,207],[182,218]]),('east_garden_loop',[[114,157],[164,157],[179,185],[155,210],[120,190],[114,157]])]:
                net['roads']=[r for r in net['roads'] if r['id']!=name]
                net['roads'].append({'id':name,'name':'东侧绿地步道','points':ps,'width':2,'grade':3,'sidewalk_width':0,'surface':'concrete','edge_type':'flush_green_or_frontage','osm_highway':'footway','priority':d['id'],
                    'source':{'osm_way':name,'url':'https://gis.ustc.edu.cn/','geometry':'Satellite/GIS visible lawn paths, hand registered approximate geometry'},'width_basis':'Visible aerial footway'})
        for r in net['roads']:
            if not r.get('build_enabled',True) or r['grade']>2:continue
            for a,c in zip(r['points'],r['points'][1:]):
                length=math.dist(a,c)
                for k in range(1,int(length/31)+1):
                    t=k/(int(length/31)+1);mx,mz=a[0]+(c[0]-a[0])*t,a[1]+(c[1]-a[1])*t
                    offset=r['width']/2+r['sidewalk_width']+1.0
                    p=[mx+(c[1]-a[1])/length*offset,mz-(c[0]-a[0])/length*offset]
                    if any(geo.contains(f,p) or min(distance(p,u,v) for u,v in zip(f,f[1:]+f[:1]))<1 for f in playing_areas):continue
                    if not geo.contains(d['polygon'],p) or any(geo.contains(f,p) or min(distance(p,u,v) for u,v in zip(f,f[1:]+f[:1]))<1.2 for f in footprints):continue
                    if any(geo.contains(h['polygon'],p) for h in d['hardscape']) or any(math.dist(p,q)<20 for q in lamps):continue
                    if any(min(distance(p,u,v) for u,v in zip(s['points'],s['points'][1:]))<s['width']/2+s['sidewalk_width']+.5 for s in net['roads'] if s is not r):continue
                    lamps.append(p);d['lamps'].append([*p,0])
        x0,z0,x1,z1=d['bounds']
        for z in range(math.ceil(z0),math.floor(z1),17):
            for x in range(math.ceil(x0),math.floor(x1),17):
                p=[x+random.uniform(-3,3),z+random.uniform(-3,3)]
                if any(geo.contains(f,p) for f in playing_areas):continue
                if not geo.contains(d['polygon'],p) or any(geo.contains(f,p) or min(distance(p,u,v) for u,v in zip(f,f[1:]+f[:1]))<3.0 for f in footprints):continue
                # New modules overlap old districts: preserve their established planting.
                if any(geo.contains(m['polygon'],p) for m in modules['modules'] if m['enabled'] and m.get('polygon') and m['id'] not in [s['id'] for s in refs['districts']]):continue
                if any(geo.contains(h['polygon'],p) for h in d['hardscape']):continue
                if any(min(distance(p,u,v) for u,v in zip(r['points'],r['points'][1:]))<r['width']/2+r['sidewalk_width']+2.2 for r in net['roads']):continue
                if any(min(distance(p,u,v) for u,v in zip(r['points'],r['points'][1:]))<3 for r in d['walk_routes']):continue
                if any(math.dist(p,q)<9 for q in existing_trees+lamps):continue
                d['trees'].append({'asset':['tree_plane_a','tree_plane_b','tree_garden','tree_plane_c','tree_conifer'][len(d['trees'])%5],
                    'position':[round(p[0],3),0,round(p[1],3)],'scale':round(random.uniform(.76,1.1),3),'heading':round(random.random()*math.tau,4)})
                existing_trees.append(p)
        for i,t in enumerate(d['trees']):
            if i%16==0:
                x,y,z=t['position'];d['benches'].append([x+1.7,z,1.57])
        spec={k:d[k] for k in ['id','name','bounds','polygon']};spec.update(template='full_mapped_district',enabled=True,ground_y=0,surface_top=.105,ports=[],story_nodes=[],source='references/full_campus/full_osm_overlay.jpg')
        modules['modules']=[m for m in modules['modules'] if m['id']!=d['id']];modules['modules'].append(spec)
        print(d['id'],len(d['buildings']),len(d['trees']),'trees',len(d['lamps']),'lamps',len(d['walk_routes']),'entries')
    known_buildings={b['osm_way'] for b in net['buildings']}
    for d in refs['districts']:
        for b in d['buildings']:
            if b['osm_way'] not in known_buildings:net['buildings'].append(b);known_buildings.add(b['osm_way'])
    # An archway has separate piers; its enclosing survey polygon must not erase the road beneath it.
    net['buildings']=[b for b in net['buildings'] if b['osm_way']!='298813543']
    write('godot/data/full_districts.json',refs);write('godot/data/campus_road_network.json',net);write('godot/data/module_layout.json',modules)
if __name__=='__main__':run()
