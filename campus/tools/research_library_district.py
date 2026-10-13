"""Shared-frame reference and satellite extraction for the library/Teaching 2 district."""
from pathlib import Path
import json, math, urllib.request, io
from concurrent.futures import ThreadPoolExecutor
from PIL import Image,ImageDraw
import research_road_network as geo
ROOT=geo.ROOT
OUT=ROOT/'references/library_district'
OUT.mkdir(exist_ok=True)

def satellite():
    zoom=19
    def tile(lon,lat):
        return ((lon+180)/360*2**zoom,(1-math.asinh(math.tan(math.radians(lat)))/math.pi)/2*2**zoom)
    corners=[tile(*geo.geographic(p)) for p in [[-110,215],[210,215],[210,460],[-110,460]]]
    x0,y0=map(math.floor,[min(p[0] for p in corners),min(p[1] for p in corners)])
    x1,y1=map(math.floor,[max(p[0] for p in corners),max(p[1] for p in corners)])
    base='https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer'
    def fetch(p):
        x,y=p
        with urllib.request.urlopen(f'{base}/tile/{zoom}/{y}/{x}',timeout=30) as r:
            im=Image.open(io.BytesIO(r.read())).convert('RGB')
        return x,y,im
    coords=[(x,y) for y in range(y0,y1+1) for x in range(x0,x1+1)]
    mosaic=Image.new('RGB',((x1-x0+1)*256,(y1-y0+1)*256))
    with ThreadPoolExecutor(max_workers=8) as pool:
        for x,y,im in pool.map(fetch,coords):mosaic.paste(im,((x-x0)*256,(y-y0)*256))
    mosaic.save(OUT/'library_satellite.jpg',quality=96)
    meta={'source_url':base,'zoom':zoom,'tile_origin':[x0,y0],'size':list(mosaic.size),'capture_date':'unknown',
          'retrieved_date':'2026-10-12','attribution':'Esri, Vantor, Earthstar Geographics, GIS User Community'}
    (OUT/'satellite_metadata.json').write_text(json.dumps(meta,indent=2),encoding='utf-8')
    return mosaic,meta,tile

def references():
    doc,nodes,ways,tags,points=geo.osm()
    names={'284161540':'东区老图书馆（办公楼207）','284161541':'东区图书馆','271958257':'第二教学楼',
           '1135310337':'少年班学院204','284161542':'东区学生食堂208'}
    levels={'284161540':4,'284161541':6,'271958257':8,'1135310337':4,'284161542':3}
    buildings=[]
    for wid,name in names.items():
        p=points(ways[wid]);p=p[:-1] if p[0]==p[-1] else p
        buildings.append({'osm_way':wid,'name':name,'outline':p,'levels':levels[wid],
            'height':levels[wid]*3.5+.6,'source':f'https://www.openstreetmap.org/way/{wid}',
            'confidence':'OSM footprint; library 6/Teaching 2 8 floors confirmed official pages; other heights estimated'})
    # Every mapped street/path is retained; stairs remain stairs rather than vehicle streets.
    ids=['265033443','270829481','286026285','286026286','290099137','290099138','290099139',
         '290099140','290099141','290099142','306371632','306371633','306371634','306371635',
         '306496882','306496883','306496884','306496886','306373627','306373628','306373630','306373631',
         '306373632','1135725450','1135725451']
    roads=[]
    for wid in ids:
        t=tags(ways[wid]); roads.append({'osm_way':wid,'points':points(ways[wid]),'highway':t['highway'],
            'source':f'https://www.openstreetmap.org/way/{wid}'})
    d={'buildings':buildings,'paths':roads,'bounds':[-98,285,198,453],
       'sources':['https://gis.ustc.edu.cn/','https://www.teach.ustc.edu.cn/service/svc-resource/12388.html',
         'https://lib.ustc.edu.cn/本馆概况/东区图书馆简介/'],
       'composition':'Continue accepted warm stone/cool green palette: large library portal, red Teaching 2, mature plane crowns, open entrance courts; grounds follow satellite hardscape/green zones.'}
    (OUT/'mapped_features.json').write_text(json.dumps(d,ensure_ascii=False,indent=2),encoding='utf-8')
    return d

if __name__=='__main__':
    d=references();im,meta,tile=satellite();draw=ImageDraw.Draw(im)
    def px(p):
        a,b=tile(*geo.geographic(p));return ((a-meta['tile_origin'][0])*256,(b-meta['tile_origin'][1])*256)
    road_data=json.loads((ROOT/'godot/data/campus_road_network.json').read_text(encoding='utf-8'))
    for r in road_data['roads']:
        draw.line([px(p) for p in r['points']],fill='#ffff40',width=2)
    for r in d['paths']:draw.line([px(p) for p in r['points']],fill='#ffffff',width=2)
    for b in d['buildings']:
        p=b['outline'];draw.line([px(q) for q in p+[p[0]]],fill='#00ffff',width=3)
        draw.text(px(p[0]),b['osm_way'],fill='#f06040',stroke_width=1,stroke_fill='white')
    im.save(OUT/'library_osm_overlay.jpg',quality=96)
    print('LIBRARY_REFERENCES',meta['size'],len(d['buildings']),len(d['paths']))
