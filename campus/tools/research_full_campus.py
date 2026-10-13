"""Mapped assets for the remaining districts, cross-checked with retained GIS/plan imagery."""
import json,math,urllib.request,io
from concurrent.futures import ThreadPoolExecutor
from PIL import Image,ImageDraw
import research_road_network as geo
ROOT=geo.ROOT;OUT=ROOT/'references/full_campus'
DISTRICTS=[('west_connection_09','西侧连接区',[-396,110,-70,675]),
           ('east_living_10','东侧住宅与生活区',[80,50,379,680]),
           ('central_life_11','行政楼—校史馆—中部生活区',[-95,448,195,680]),
           ('south_research_12','南部科研楼群—礼堂—南门',[-397,670,379,947])]
def run():
    OUT.mkdir(exist_ok=True);_,_,ways,tags,points=geo.osm();boundary=points(ways['262614785'])[:-1]
    network=json.loads((ROOT/'godot/data/campus_road_network.json').read_text(encoding='utf-8'))
    preserved={str(b['osm_way']) for b in network['buildings']}
    previous=ROOT/'godot/data/full_districts.json'
    if previous.exists():
        own={b['osm_way'] for d in json.loads(previous.read_text(encoding='utf-8'))['districts'] for b in d['buildings']}
        preserved.difference_update(own)
    preserved.update(str(b['osm_way']) for b in json.loads((ROOT/'godot/data/north_axis_layout.json').read_text(encoding='utf-8'))['buildings'])
    preserved.update(['265575540','268207470','267646978','270335375','306371643'])
    hall=json.loads((ROOT/'godot/assets/site.json').read_text(encoding='utf-8'))['hall_outline']
    districts=[{'id':id,'name':name,'bounds':bounds,'polygon':geo.clip_rectangle(boundary,bounds),'buildings':[],'paths':[],'features':[]} for id,name,bounds in DISTRICTS]
    def signed_area(p):return abs(sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(p,p[1:]+p[:1]))*.5)
    def assign(p):
        center=[sum(q[0] for q in p)/len(p),sum(q[1] for q in p)/len(p)]
        if not geo.contains(boundary,center):return None
        # Prioritize south/central where their buildings straddle a district interface.
        for d in districts[::-1]:
            if geo.contains(d['polygon'],center):return d
    for wid,w in ways.items():
        t=tags(w);p=points(w)
        if 'building' in t and t['building']!='no' and wid not in preserved:
            if p[0]!=p[-1] or signed_area(p[:-1])<15:continue
            p=p[:-1];d=assign(p)
            if not d or geo.contains(hall,[sum(q[0] for q in p)/len(p),sum(q[1] for q in p)/len(p)]):continue
            name=t.get('name',t.get('ref','校内附属建筑'));kind=t['building']
            explicit=t.get('building:levels');levels=int(float(explicit)) if explicit else (6 if kind in ['dormitory','apartments'] else 5 if kind=='residential' else 4)
            style='residential' if kind in ['dormitory','apartments','residential'] or name.endswith('#') else 'academic'
            if '档案' in name or '校史' in name or '行政楼' in name or '数学' in name:style='heritage';levels=4 if not explicit else levels
            if name in ['礼堂','水上报告厅']:style='auditorium';levels=2
            if kind=='hospital':style='hospital';levels=4 if name=='门诊部' else 2
            if kind in ['garages'] or '仓库' in name or '门岗' in name or signed_area(p)<130:style='service';levels=1
            if '物质科学教研' in name:style='research_tower'
            if '前沿研究中心' in name:style='research_glass';levels=8
            if '幼儿园' in name or kind=='school':style='kindergarten';levels=3
            if name=='东区学生活动中心':style='student_activity';levels=6
            if name=='中科大东区正门':style='west_gate';levels=1
            d['buildings'].append({'osm_way':wid,'name':name,'outline':p,'levels':levels,'height':round(levels*3.4+.6,2),
                'style':style,'source':f'https://www.openstreetmap.org/way/{wid}',
                'confidence':'Mapped footprint, GIS and official-map identity/massing; '+('OSM storeys' if explicit else 'estimated storeys and unseen facade bays')})
        elif 'highway' in t and t.get('area')!='yes' and t['highway'] not in ['primary','secondary','trunk','trunk_link','motorway']:
            clipped=geo.line_boundary_clip(p,boundary)
            if len(clipped)<2:continue
            for d in districts:
                if any(geo.contains(d['polygon'],q) for q in clipped):
                    d['paths'].append({'osm_way':wid,'name':t.get('name','校内连接路'),'highway':t['highway'],'points':clipped,'width_tag':t.get('width'),
                        'source':f'https://www.openstreetmap.org/way/{wid}'});break
        elif p[0]==p[-1] and (t.get('amenity')=='parking' or t.get('leisure')=='pitch'):
            d=assign(p[:-1])
            if d:d['features'].append({'osm_way':wid,'name':t.get('name','停车区' if t.get('amenity')=='parking' else '活动场'),
                     'kind':'parking' if t.get('amenity')=='parking' else 'recreation','polygon':p[:-1]})
    sources=[{'url':'https://gis.ustc.edu.cn/','local':'references/south_sports/gis_east_tiles.jpg','use':'Retained JS tile image: building colors, height tiers, courtyards, hierarchy and adjacency'},
             {'local':'references/maps/east_campus.png','use':'Official building identity and road naming'},
             {'url':'https://www.openstreetmap.org/way/262614785','local':'renders/coverage/osm_east_full.xml','use':'Boundary, original outlines and street centerlines'},
             {'url':'https://aga.ustc.edu.cn/info/1400/36242.htm','use':'Auditorium red masonry and grey pitched roof'},
             {'url':'https://news.ustc.edu.cn/info/1055/88962.htm','use':'Earth/space frontier research center identity and exterior'}]
    (OUT/'mapped_districts.json').write_text(json.dumps({'districts':districts,'sources':sources,'preserved_building_ids':sorted(preserved)},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    zoom=18
    def tile(lon,lat):return ((lon+180)/360*2**zoom,(1-math.asinh(math.tan(math.radians(lat)))/math.pi)/2*2**zoom)
    corners=[tile(*geo.geographic(p)) for p in [[-420,-110],[405,-110],[405,972],[-420,972]]]
    x0,y0=map(math.floor,[min(p[0] for p in corners),min(p[1] for p in corners)]);x1,y1=map(math.floor,[max(p[0] for p in corners),max(p[1] for p in corners)])
    base='https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer';cache=OUT/'satellite_tiles';cache.mkdir(exist_ok=True)
    def fetch(p):
        x,y=p;path=cache/f'{zoom}_{x}_{y}.jpg'
        if not path.exists():
            with urllib.request.urlopen(f'{base}/tile/{zoom}/{y}/{x}',timeout=40) as r:path.write_bytes(r.read())
        return x,y,Image.open(path).convert('RGB')
    im=Image.new('RGB',((x1-x0+1)*256,(y1-y0+1)*256))
    with ThreadPoolExecutor(max_workers=6) as pool:
        for x,y,t in pool.map(fetch,[(x,y) for y in range(y0,y1+1) for x in range(x0,x1+1)]):im.paste(t,((x-x0)*256,(y-y0)*256))
    im.save(OUT/'east_full_satellite.jpg',quality=96)
    meta={'source_url':base,'zoom':zoom,'tile_origin':[x0,y0],'size':list(im.size),'retrieved_date':'2026-10-12','capture_date':'unknown','attribution':'Esri, Vantor, Earthstar Geographics, GIS User Community'}
    (OUT/'satellite_metadata.json').write_text(json.dumps(meta,indent=2)+'\n',encoding='utf-8')
    def px(p):
        x,y=tile(*geo.geographic(p));return ((x-x0)*256,(y-y0)*256)
    draw=ImageDraw.Draw(im)
    for d in districts:
        p=d['polygon'];draw.line([px(q) for q in p+[p[0]]],fill='#ffff00',width=2)
        for b in d['buildings']:
            p=b['outline'];draw.line([px(q) for q in p+[p[0]]],fill='#00ffff',width=2)
        for r in d['paths']:draw.line([px(q) for q in r['points']],fill='#ffffff',width=1)
    im.save(OUT/'full_osm_overlay.jpg',quality=96)
    print('FULL_REFERENCES',[(d['id'],len(d['buildings']),len(d['paths'])) for d in districts],meta['size'])
if __name__=='__main__':run()
