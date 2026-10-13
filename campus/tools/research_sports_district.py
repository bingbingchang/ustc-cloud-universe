"""Map and visual references for the west athletic field and 320–323 dorms."""
import json, math, urllib.request, io
from concurrent.futures import ThreadPoolExecutor
from PIL import Image, ImageDraw
import research_road_network as geo

ROOT=geo.ROOT
OUT=ROOT/'references/sports_district'

def run():
    OUT.mkdir(exist_ok=True)
    _,_,ways,tags,points=geo.osm()
    boundary=points(ways['262614785'])[:-1]
    bounds=[-335,356,-70,552]
    polygon=geo.clip_rectangle(boundary,bounds)
    names={'267624863':'学生公寓320号楼','267624864':'学生公寓321号楼',
           '267624865':'学生公寓322号楼','267624866':'学生公寓323号楼',
           '1135360068':'体育教学部'}
    buildings=[]
    for wid,name in names.items():
        p=points(ways[wid])[:-1]
        buildings.append({'osm_way':wid,'name':name,'outline':p,
            'levels':6 if wid.startswith('267') else 3,
            'height':19.5 if wid.startswith('267') else 11.0,
            'source':f'https://www.openstreetmap.org/way/{wid}',
            'confidence':'Official campus map labels and OSM footprint; unsighted facade bays, storeys and entrances estimated.'})
    ids=['265575541','308701271','302181056','1135310345','551220504','265032058','265575538']
    paths=[{'osm_way':wid,'points':points(ways[wid]),'highway':tags(ways[wid])['highway'],
            'source':f'https://www.openstreetmap.org/way/{wid}'} for wid in ids]
    d={'bounds':bounds,'polygon':polygon,'buildings':buildings,'paths':paths,
       'soccer_outline':points(ways['1502386124'])[:-1],
       'grandstand_outline':points(ways['267624862'])[:-1],
       'sources':[{'url':'https://www.tj.ustc.edu.cn/1441/list.htm','use':'East athletic field, red track, green infield and west grandstand photographs'},
                  {'local':'references/maps/east_campus.png','use':'320–323 building names and adjacency'},
                  {'url':'https://www.openstreetmap.org/way/1502386124','use':'Football turf footprint'}],
       'attribution':'© OpenStreetMap contributors, ODbL 1.0; Esri imagery is a visual reference.'}
    (OUT/'mapped_features.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    zoom=19
    def tile(lon,lat):return ((lon+180)/360*2**zoom,(1-math.asinh(math.tan(math.radians(lat)))/math.pi)/2*2**zoom)
    corners=[tile(*geo.geographic(p)) for p in [[-355,330],[-55,330],[-55,570],[-355,570]]]
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
    im.save(OUT/'sports_satellite.jpg',quality=95)
    meta={'source_url':base,'retrieved_date':'2026-10-12','capture_date':'unknown','zoom':zoom,
          'tile_origin':[x0,y0],'size':list(im.size),'attribution':'Esri, Vantor, Earthstar Geographics, GIS User Community'}
    (OUT/'satellite_metadata.json').write_text(json.dumps(meta,indent=2)+'\n',encoding='utf-8')
    def px(p):
        x,y=tile(*geo.geographic(p));return ((x-x0)*256,(y-y0)*256)
    draw=ImageDraw.Draw(im)
    draw.line([px(p) for p in polygon+[polygon[0]]],fill='#ffcc00',width=3)
    for b in buildings:
        p=b['outline'];draw.line([px(q) for q in p+[p[0]]],fill='#00ffff',width=2);draw.text(px(p[0]),b['osm_way'],fill='#ffffff',stroke_width=1,stroke_fill='black')
    for r in paths:draw.line([px(p) for p in r['points']],fill='#ffff66',width=2)
    im.save(OUT/'sports_osm_overlay.jpg',quality=95)
    photo_base='https://www.tj.ustc.edu.cn/_upload/article/images/fb/51/3fab9b6e4ff28c6d048b1d09751b/'
    for name,url in [('official_field.jpg','1e030f87-3918-4f05-9284-2f38e8a4f821.jpg'),('official_grandstand.jpg','dbca2071-033a-4328-a1cc-0d8685852438.jpg')]:
        urllib.request.urlretrieve(photo_base+url,OUT/name)
    print('SPORTS_REFERENCES',len(buildings),len(paths),meta['size'],polygon)

if __name__=='__main__':run()
