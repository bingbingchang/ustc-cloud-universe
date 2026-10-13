"""Cross-reference GIS image tiles, official campus plan and aerial court geometry."""
import json,math,urllib.request,io,re
from concurrent.futures import ThreadPoolExecutor
from PIL import Image,ImageDraw
import research_road_network as geo
ROOT=geo.ROOT
OUT=ROOT/'references/south_sports'

def run():
    OUT.mkdir(exist_ok=True)
    _,_,ways,tags,points=geo.osm()
    bounds=[-380,535,-70,675];poly=geo.clip_rectangle(points(ways['262614785'])[:-1],bounds)
    names={'271959068':('研究生公寓364／365号楼',6,19.8),
           '1135310336':('人文与社会科学学院',4,14.0),
           '271959067':('东区羽毛球馆',1,8.0),
           '1135310342':('可再生资源与洁净能源实验室',3,11.2),
           '270334649':('国际学院／国际合作与交流中心',4,14.0),
           '271958264':('科大洗浴中心',2,7.0),
           '270334648':('学生服务中心',3,10.8),
           '298766878':('水电管理中心',2,7.0),
           '686072850':('化学与材料科学学院办公楼',2,7.0),
           '271958265':('校园服务小店',1,4.0)}
    buildings=[{'osm_way':wid,'name':name,'outline':points(ways[wid])[:-1],
         'levels':levels,'height':height,'source':f'https://www.openstreetmap.org/way/{wid}',
         'confidence':'OSM footprint cross-checked against GIS image and campus plan; storeys and unseen facade details estimated.'}
         for wid,(name,levels,height) in names.items()]
    paths=[{'osm_way':wid,'points':geo.line_boundary_clip(points(ways[wid]),points(ways['262614785'])[:-1]),
            'highway':tags(ways[wid])['highway'],'source':f'https://www.openstreetmap.org/way/{wid}'}
           for wid in ['265033437','265032060','298766877','265033438']]
    sources=[{'url':'https://gis.ustc.edu.cn/','local':'references/south_sports/gis_east_tiles.jpg',
              'js':'references/south_sports/gis_xbgis_readable.js',
              'use':'GIS JS reveals mapdata/zoom3/x_y.jpg tile source; cross-check names, court groups and road adjacency.'},
             {'local':'references/maps/east_campus.png','use':'Official plan: 364/365 west of south courts; humanities and badminton hall west of court spine.'},
             {'url':'https://news.ustc.edu.cn/info/1055/95289.htm','use':'2026 official east tennis photographs: blue/green hard courts, green wire fence and nets.'},
             {'url':'https://gradunion.ustc.edu.cn/2012/0317/c5709a61204/page.psp','use':'364 south and 365 north have balconies, with west connecting block.'}]
    d={'bounds':bounds,'polygon':poly,'buildings':buildings,'paths':paths,
       'court_areas':[{'id':wid,'sport':tags(ways[wid])['sport'],'polygon':points(ways[wid])[:-1]}
                      for wid in ['1135310343','1135310344']],
       'sources':sources,'attribution':'© OpenStreetMap contributors, ODbL 1.0. GIS/official imagery used as visual references.'}
    (OUT/'mapped_features.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    zoom=19
    def tile(lon,lat):return ((lon+180)/360*2**zoom,(1-math.asinh(math.tan(math.radians(lat)))/math.pi)/2*2**zoom)
    corners=[tile(*geo.geographic(p)) for p in [[-400,515],[-50,515],[-50,695],[-400,695]]]
    x0,y0=map(math.floor,[min(p[0] for p in corners),min(p[1] for p in corners)])
    x1,y1=map(math.floor,[max(p[0] for p in corners),max(p[1] for p in corners)])
    base='https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer'
    def fetch(p):
        x,y=p
        with urllib.request.urlopen(f'{base}/tile/{zoom}/{y}/{x}',timeout=30) as r:im=Image.open(io.BytesIO(r.read())).convert('RGB')
        return x,y,im
    im=Image.new('RGB',((x1-x0+1)*256,(y1-y0+1)*256))
    with ThreadPoolExecutor(max_workers=8) as pool:
        for x,y,t in pool.map(fetch,[(x,y) for y in range(y0,y1+1) for x in range(x0,x1+1)]):im.paste(t,((x-x0)*256,(y-y0)*256))
    im.save(OUT/'south_satellite.jpg',quality=96)
    meta={'source_url':base,'zoom':zoom,'tile_origin':[x0,y0],'size':list(im.size),
          'retrieved_date':'2026-10-12','capture_date':'unknown','attribution':'Esri, Vantor, Earthstar Geographics, GIS User Community'}
    (OUT/'satellite_metadata.json').write_text(json.dumps(meta,indent=2)+'\n',encoding='utf-8')
    def px(p):
        x,y=tile(*geo.geographic(p));return ((x-x0)*256,(y-y0)*256)
    draw=ImageDraw.Draw(im)
    draw.line([px(p) for p in poly+[poly[0]]],fill='#ffcc00',width=3)
    for b in buildings:
        p=b['outline'];draw.line([px(q) for q in p+[p[0]]],fill='#00ffff',width=2);draw.text(px(p[0]),b['osm_way'],fill='white',stroke_width=1,stroke_fill='black')
    for c in d['court_areas']:
        p=c['polygon'];draw.line([px(q) for q in p+[p[0]]],fill='#ff77ff',width=2)
    for r in paths:draw.line([px(p) for p in r['points']],fill='#ffff66',width=2)
    im.save(OUT/'south_osm_overlay.jpg',quality=96)
    urls=['https://news.ustc.edu.cn/__local/5/F7/F6/D63F652BE140D417175FC6A66A6_B396F802_1D289.jpeg',
          'https://news.ustc.edu.cn/__local/B/E2/A6/DEAA182139F5CB6C9B9D8572C45_1C223658_1A4F2.jpeg']
    for i,url in enumerate(urls):urllib.request.urlretrieve(url,OUT/f'tennis_2026_{i+1}.jpg')
    print('SOUTH_REFERENCES',len(buildings),'buildings',poly,meta['size'])
if __name__=='__main__':run()
