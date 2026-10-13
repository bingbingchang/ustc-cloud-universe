from pathlib import Path
import xml.etree.ElementTree as ET
import urllib.request,urllib.parse,json,re,concurrent.futures
from PIL import Image,ImageDraw,ImageFont
R=Path(__file__).resolve().parents[1]
root=ET.parse(R/'references/maps/osm.xml').getroot()
nodes={n.attrib['id']:(float(n.attrib['lon']),float(n.attrib['lat'])) for n in root.findall('node')}
features=[]
for w in root.findall('way'):
 t={t.attrib['k']:t.attrib['v'] for t in w.findall('tag')}
 pts=[nodes[n.attrib['ref']] for n in w.findall('nd') if n.attrib['ref'] in nodes]
 if pts and ('building' in t or 'highway' in t or t.get('natural')=='water'):
  features.append({'id':w.attrib['id'],'tags':t,'points':pts})
(R/'references/maps/features.json').write_text(json.dumps(features,ensure_ascii=False,indent=2),encoding='utf-8')
im=Image.new('RGB',(1300,1200),'#eef1e4'); d=ImageDraw.Draw(im); f=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',16)
def xy(p):return ((p[0]-117.262)*195000, (31.845-p[1])*232000)
for t in features:
 pts=[xy(p) for p in t['points']]; tags=t['tags']
 if 'building' in tags:d.polygon(pts,fill='#c3a395',outline='#70584b')
 elif tags.get('natural')=='water':d.polygon(pts,fill='#85bfd0',outline='#598297')
 else:d.line(pts,fill='#aaa69c',width=3)
 if tags.get('name'):d.text(pts[0],tags['name'],font=f,fill='#193e39')
im.save(R/'references/maps/osm_reference.png')
print([(x['tags'],x['points'][0]) for x in features if x['tags'].get('name')])
pages=[('hall','https://zgkdb.ustc.edu.cn/ndetail/3705'),('pavilion','https://zsb.ustc.edu.cn/2024/0310/c35540a631898/page.htm'),('autumn','https://business.ustc.edu.cn/2011/1026/c28419a526436/page.htm')]
def get_page(t):
 name,url=t
 try:
  html=urllib.request.urlopen(url,timeout=20).read().decode('utf-8')
  (R/f'references/buildings/{name}.html').write_text(html,encoding='utf-8')
  imgs=re.findall(r'<img[^>]+src=[\"\x27]([^\"\x27]+)',html)
  out=[]
  for i,src in enumerate(imgs):
   if any(k in src.lower() for k in ['upload','_upload','attached']):
    u=urllib.parse.urljoin(url,src); p=R/f'references/buildings/{name}_{i}.jpg'
    try:urllib.request.urlretrieve(u,p);out.append((str(p.relative_to(R)),u))
    except Exception:pass
  return out
 except Exception as e:return [(name,str(e))]
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as e:results=list(e.map(get_page,pages))
(R/'references/additional_manifest.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
ims=[]
for p in (R/'references/buildings').glob('*_*.jpg'):
 try:
  im=Image.open(p);im.thumbnail((480,310));ims.append((p.name,im.copy()))
 except Exception:pass
board=Image.new('RGB',(1500,345*((len(ims)+2)//3)),'#e5e5dd');d=ImageDraw.Draw(board)
for i,(n,im) in enumerate(ims):
 x=i%3*500;y=i//3*345;board.paste(im,(x,y));d.text((x,y+313),n,font=f,fill='black')
board.save(R/'references/screenshots/details.jpg')
