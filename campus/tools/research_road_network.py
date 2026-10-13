"""Extract road/footprint reference geometry in site.json's existing meter frame."""
from pathlib import Path
import json, math, urllib.parse, urllib.request, xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
from PIL import Image
import io

def osm():
    doc=ET.parse(ROOT/'renders/coverage/osm_east_full.xml').getroot()
    nodes={n.attrib['id']:n for n in doc.findall('node')}
    ways={w.attrib['id']:w for w in doc.findall('way')}
    def tags(obj):
        return {t.attrib['k']:t.attrib['v'] for t in obj.findall('tag')}
    def points(way):
        return [local([float(nodes[n.attrib['ref']].attrib['lon']),
                       float(nodes[n.attrib['ref']].attrib['lat'])]) for n in way.findall('nd')]
    return doc,nodes,ways,tags,points

def overlay():
    from PIL import ImageDraw
    doc,nodes,ways,tags,points=osm()
    meta=json.loads((ROOT/'references/road_network/satellite_metadata.json').read_text())
    img=Image.open(ROOT/'references/road_network/north_roads_satellite.jpg')
    draw=ImageDraw.Draw(img)
    def pixel(p):
        lon,lat=geographic(p);z=meta['tile_zoom']
        return [((lon+180)/360*2**z-meta['tile_origin'][0])*256,
                ((1-math.asinh(math.tan(math.radians(lat)))/math.pi)/2*2**z-meta['tile_origin'][1])*256]
    for wid in ['268836529','265583820','265575543','266988252','266988253',
                '268206608','270537515','290099136','298812614','298812615','298812616']:
        draw.line([tuple(pixel(p)) for p in points(ways[wid])],fill='#ffff33',width=3)
    for wid in ['265575547','270537512','270537513','270537514','270537516','298741849','298741850']:
        pts=points(ways[wid]);draw.line([tuple(pixel(p)) for p in pts],fill='#00ffff',width=3)
        draw.text(pixel(pts[0]),wid,fill='#ff3333',stroke_width=1,stroke_fill='white')
    img.save(ROOT/'references/road_network/osm_satellite_overlay.jpg',quality=96)

def contains(poly,p):
    inside=False
    for a,b in zip(poly,poly[1:]+poly[:1]):
        if (a[1]>p[1]) != (b[1]>p[1]):
            if p[0] < (b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0]:
                inside=not inside
    return inside

def clip_rectangle(poly,bounds):
    result=poly
    for axis,limit,greater in [(0,bounds[0],True),(0,bounds[2],False),
                               (1,bounds[1],True),(1,bounds[3],False)]:
        out=[]
        def inside(p): return p[axis]>=limit if greater else p[axis]<=limit
        for a,b in zip(result,result[1:]+result[:1]):
            ina,inb=inside(a),inside(b)
            if ina: out.append(a)
            if ina != inb:
                t=(limit-a[axis])/(b[axis]-a[axis])
                out.append([a[0]+t*(b[0]-a[0]),a[1]+t*(b[1]-a[1])])
        result=out
    return [[round(x,3),round(z,3)] for x,z in result]

def line_boundary_clip(line,polygon):
    """Keep the connected in-campus section of a boundary-entry street."""
    out=[]
    def cross(a,b): return a[0]*b[1]-a[1]*b[0]
    for a,b in zip(line,line[1:]):
        delta=[b[0]-a[0],b[1]-a[1]]
        events=[0.0,1.0]
        for c,d in zip(polygon,polygon[1:]+polygon[:1]):
            edge=[d[0]-c[0],d[1]-c[1]]
            den=cross(delta,edge)
            if abs(den)<1e-8: continue
            q=[c[0]-a[0],c[1]-a[1]]
            t,u=cross(q,edge)/den,cross(q,delta)/den
            if 0<=t<=1 and 0<=u<=1: events.append(t)
        events=sorted(set(events))
        for lo,hi in zip(events,events[1:]):
            mid=(lo+hi)/2
            if not contains(polygon,[a[0]+mid*delta[0],a[1]+mid*delta[1]]): continue
            for t in [lo,hi]:
                p=[round(a[0]+t*delta[0],3),round(a[1]+t*delta[1],3)]
                if not out or math.dist(out[-1],p)>0.02: out.append(p)
    return out

def build_data():
    doc,nodes,ways,tags,points=osm()
    boundary=points(ways['262614785'])[:-1]
    core_widths={
        '268836529':7.0,'265583820':6.0, # east part narrows to pedestrian lane
        '265575543':6.0,'265583821':6.0,'266988252':6.0,'266988253':6.0,
        '268206608':7.0,'270537515':6.0,'290099136':5.5,
        '298812614':5.5,'298812615':5.5,'298812616':3.0,
        '265033444':6.0,'264872431':7.0,'264872430':6.5,
        '264872432':8.0,'478776411':8.0,'478776412':8.0,'345670547':8.0,
        '306372988':4.2,'306372990':4.2,
    }
    names={'268206608':'老北门—新北门连接路','266988252':'天使路北段接续',
        '266988253':'天使路北段接续','270537515':'北区学院楼北侧及东侧环路',
        '290099136':'MBA及管理科研楼周边支路','298812614':'教学行政楼南侧路·西段',
        '298812615':'教学行政楼南侧路·东段','298812616':'教五西入口步道',
        '265033444':'教五东侧连接路','264872430':'一教西侧连接路',
        '306372988':'一教西庭院出入口','306372990':'一教东庭院出入口'}
    important={'265032055','265032053','265032054','265032057','265032058',
        '265032060','265033439','265033441','265033442','265162182',
        '268206609','270792805','478761391','478761392','369507587',
        '268836529','265583820','298742074','298742072'}
    roads=[]
    for wid,w in ways.items():
        t=tags(w)
        if 'highway' not in t or t.get('area')=='yes': continue
        raw=points(w)
        p=raw[:7] if wid=='268206608' else line_boundary_clip(raw,boundary)
        if not p: continue
        if not any(contains(boundary,x) for x in p): continue
        if wid not in core_widths and wid not in important: continue
        width=core_widths.get(wid,6.0 if t['highway']=='service' else 7.0)
        name=names.get(wid,t.get('name','校内连接路'))
        source={'osm_way':wid,'url':f'https://www.openstreetmap.org/way/{wid}',
                'timestamp':w.attrib.get('timestamp'),'version':w.attrib.get('version'),
                'geometry':'OSM road centerline, unchanged local site.json transform',
                'map':'references/maps/east_campus.png'}
        roads.append({'id':'road_'+wid,'name':name,'points':p,'width':width,
            'sidewalk_width':1.5 if width>=5.5 else 0.0,
            'surface':'asphalt' if t['highway'] not in ['pedestrian','footway'] else 'paving',
            'osm_highway':t['highway'],'osm_node_ids':[n.attrib['ref'] for n in w.findall('nd')],
            'priority':'core_correction' if wid in core_widths else 'full_campus_registered',
            'source':source,
            **({'outside_reference_points':raw[len(p):]} if wid=='268206608' else {}),
            'clipped_to_campus_boundary':p!=raw,
            'width_basis':('Aerial visible pavement/curb proportions; 0.25m ground pixels; '
                 'canopy/shadows obscure parts. Visual estimate, not survey.'
                 if wid in core_widths else 'Initial game construction estimate; not yet image-measured.'),
            'estimated_width_range_m':([max(2.0,width-1.0),width+1.5] if wid in core_widths else [width-1.5,width+2.0])})
    corrected_names={'270537516':'中国科大专家楼饭店（餐饮、住宿接待）',
        '298741849':'所系结合专家公寓1号楼（专家楼宿舍）',
        '298741850':'所系结合专家公寓2号楼（专家楼宿舍）',
        '270537512':'教学行政楼（地球和空间科学学院）',
        '265575547':'第五教学楼','270537513':'管理科学教学科研楼',
        '270537514':'管理学院MBA中心'}
    buildings=[]
    for wid,name in corrected_names.items():
        p=points(ways[wid]);xs=[v[0] for v in p];zs=[v[1] for v in p]
        buildings.append({'osm_way':wid,'name':name,'outline':p[:-1] if p[0]==p[-1] else p,
            'center':[round((min(xs)+max(xs))/2,3),round((min(zs)+max(zs))/2,3)],
            'bounds':[min(xs),min(zs),max(xs),max(zs)],
            'source':f'https://www.openstreetmap.org/way/{wid}',
            'name_basis':('User identification + official map expert-apartment label and OSM tourism guest_house node2755623244'
                          if wid in ['270537516','298741849','298741850'] else 'Official campus map and department address')})
    north_polygon=clip_rectangle(boundary,[88,-84,378,55])
    lookup={r['source']['osm_way']:r for r in roads}
    def chain(ids):
        result=[]
        for wid,reverse in ids:
            p=lookup[wid]['points'];p=p[::-1] if reverse else p
            if result and math.dist(result[-1],p[0])<0.02: p=p[1:]
            result.extend(p)
        return result
    routes=[
        {'id':'qinfeng_cross_campus','name':'勤奋路东西贯通',
         'points':chain([('268836529',True),('265583820',True)])},
        {'id':'plaza_to_expert_hotel','name':'郭沫若广场—天使路—专家楼饭店',
         'points':chain([('265575543',False),('266988252',False)])},
        {'id':'old_gate_to_new_gate','name':'老北门—新北门','points':lookup['268206608']['points'][:7]},
        {'id':'tian_shi_to_new_gate','name':'天使路—新北门',
         'points':chain([('265575543',False),('266988252',False),('266988253',False)])+
                  lookup['268206608']['points'][4:7]},
        {'id':'new_gate_to_management','name':'新北门—北区学院楼环路',
         'points':lookup['270537515']['points'][::-1]},
        {'id':'fifth_teaching_approach','name':'北门连接路—教五西门步道',
         'points':chain([('298812614',False),('298812616',False)])},
        {'id':'north_buildings_south_lane','name':'教学行政楼—管理楼南侧连接',
         'points':chain([('298812614',False),('298812615',False)])+lookup['290099136']['points'][3:]},
    ]
    data={'schema_version':1,'unit':'meter','coordinate_system':'+X east +Z south in unchanged site.json meter frame',
        'origin_wgs84':SITE['origin_wgs84'],'south_rotation_radians':A,
        'source_snapshot':'renders/coverage/osm_east_full.xml',
        'roads':roads,'buildings':buildings,'walk_routes':routes,
        'north_extension':{'id':'north_academic_district','polygon':north_polygon,
            'bounds':[88,-84,378,55],'surface_top':0.08,'ground_y':0,
            'clipped_to_osm_campus_boundary':True,'campus_boundary_osm_way':'262614785',
            'old_region_overlap':{'polygon':[[88,-20],[104,-20],[104,50],[88,50]],'existing':'north_axis_layout.json'},
            'new_north_gate':{'name':'中国科大东区北门（新北门）','osm_node':'2755623225',
                'point':[111.927,-71.737],'approach_road':'road_268206608',
                'campus_side_spawn':[111.1,-54.0]},
            'construction_note':'Use exact boundary polygon; tree rows on east ring stay inside campus. Keep building footprint polygons free of ground trees.'},
        'landscape_corrections':[
            {'location':'勤奋路，一教南侧／郭沫若像北侧','road_ids':['road_268836529','road_265583820'],
             'species':'高大法国梧桐（悬铃木）','tree_spacing_m':14,'tree_height_range_m':[16,23],
             'basis':'User on-site identification; satellite dense mature canopy; individual placement approximated.'},
            {'location':'天使路','road_ids':['road_265575543','road_266988252','road_266988253'],
             'species':'法国梧桐（悬铃木）为主','tree_spacing_m':13,'tree_height_range_m':[17,24],
             'basis':'中国科大报《致新同学》 confirms plane-tree canopy above 天使路; spacing estimated from visible crowns.'},
            {'location':'郭沫若路/一教边绿化','species':'栾树、雪松与阔叶树混合',
             'basis':'Official 科大秋韵 captions name Koelreuteria on 郭沫若路 and cedars around 一教.'}
        ],
        'references':[
            {'url':'https://gis.ustc.edu.cn/','local':'references/maps/gis_index.html','use':'Campus GIS labels and map context'},
            {'url':'https://indico.pnp.ustc.edu.cn/event/3091/attachments/6396/12868/科大东区校园地图.pdf',
             'local':'references/maps/east_campus.png','use':'Building naming and road adjacency'},
            {'url':'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer',
             'local':'references/road_network/north_roads_satellite.jpg','metadata':'references/road_network/satellite_metadata.json',
             'use':'Visible mature tree canopy and street/building proportion; acquisition date unknown'},
            {'url':'https://zgkdb.ustc.edu.cn/ndetail/3705','use':'天使路法国梧桐；一教红砖和梧桐'},
            {'url':'https://business.ustc.edu.cn/2011/1026/c28419a526436/page.htm',
             'use':'Official photo captions: 勤奋路、郭沫若路栾树、一教雪松'},
            {'url':'https://ess.ustc.edu.cn/main.htm','use':'地空学院地址为东区教学行政楼'}],
        'attribution':'Geographic centerlines/footprints © OpenStreetMap contributors, ODbL 1.0; imagery used as local visual reference.'}
    (ROOT/'godot/data/campus_road_network.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'road_count':len(roads),'core_road_count':sum(r['priority']=='core_correction' for r in roads),
        'building_count':len(buildings),'north_polygon':north_polygon,'gate_in_polygon':contains(north_polygon,[111.927,-71.737])},ensure_ascii=False))

ROOT = Path(__file__).resolve().parents[1]
SITE = json.loads((ROOT / 'godot/assets/site.json').read_text(encoding='utf-8'))
LON, LAT = SITE['origin_wgs84']
A = SITE['south_rotation_radians']

def local(p):
    x, z = (p[0]-LON)*94500, (LAT-p[1])*111195
    return [round(x*math.cos(A)-z*math.sin(A), 3),
            round(x*math.sin(A)+z*math.cos(A), 3)]

def geographic(p):
    x = p[0]*math.cos(A)+p[1]*math.sin(A)
    z = -p[0]*math.sin(A)+p[1]*math.cos(A)
    return [LON+x/94500, LAT-z/111195]

def satellite():
    out = ROOT / 'references/road_network'
    out.mkdir(exist_ok=True)
    z=19
    def tile(lon,lat):
        return ((lon+180)/360*2**z,
                (1-math.asinh(math.tan(math.radians(lat)))/math.pi)/2*2**z)
    minx,miny=tile(117.2627,31.8441)
    maxx,maxy=tile(117.2677,31.8408)
    lo_x,lo_y,hi_x,hi_y=map(math.floor,(minx,miny,maxx,maxy))
    base='https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer'
    def fetch(p):
        x,y=p
        url=f'{base}/tile/{z}/{y}/{x}'
        with urllib.request.urlopen(url,timeout=30) as response:
            img=Image.open(io.BytesIO(response.read())).convert('RGB')
        return x,y,img
    coords=[(x,y) for y in range(lo_y,hi_y+1) for x in range(lo_x,hi_x+1)]
    mosaic=Image.new('RGB',((hi_x-lo_x+1)*256,(hi_y-lo_y+1)*256))
    with ThreadPoolExecutor(max_workers=8) as pool:
        for x,y,img in pool.map(fetch,coords):
            mosaic.paste(img,((x-lo_x)*256,(y-lo_y)*256))
    mosaic.save(out/'north_roads_satellite.jpg',quality=96)
    def geographic_corner(x,y):
        return [x/2**z*360-180,math.degrees(math.atan(math.sinh(math.pi*(1-2*y/2**z))))]
    info={'source_url':base,'retrieved_on':'2026-10-12','tile_zoom':z,
          'tile_origin':[lo_x,lo_y],'tile_count':len(coords),
          'image_size':list(mosaic.size),
          'top_left_wgs84':geographic_corner(lo_x,lo_y),
          'bottom_right_wgs84':geographic_corner(hi_x+1,hi_y+1),
          'attribution':'Esri, Vantor, Earthstar Geographics, and the GIS User Community',
          'capture_date':'Unknown; cross-check geometry with official map and OSM',
          'research_note':'Public MapServer export returned blank extent; public cached imagery tiles were used.'}
    (out/'satellite_metadata.json').write_text(json.dumps(info,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(info,ensure_ascii=False))

if __name__ == '__main__':
    overlay()
    build_data()
