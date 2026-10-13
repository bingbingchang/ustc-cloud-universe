from pathlib import Path
import json,math,re,urllib.request,urllib.parse
R=Path(__file__).resolve().parents[1]
features=json.loads((R/'references/maps/features.json').read_text(encoding='utf-8'))
# Local tangent-plane meters. Rotate by measured avenue heading to make south +Z.
LON,LAT=117.2634979,31.8427261
A=math.atan2((117.2636165-LON)*94500,(LAT-31.8413751)*111195)
def local(p):
 x=(p[0]-LON)*94500;z=(LAT-p[1])*111195
 return [round(x*math.cos(A)-z*math.sin(A),3),round(x*math.sin(A)+z*math.cos(A),3)]
hall=next(x for x in features if x['tags'].get('name')=='第一教学楼')
west=next(x for x in features if x['tags'].get('name')=='眼镜湖')
# East pond missing from returned OSM ways: traced against downloaded Esri image,
# checked with official PDF, not presented as survey geometry.
east=[[12,57],[25,52],[49,55],[62,67],[64,93],[60,114],[45,123],[24,123],[12,113],[9,92]]
data={'origin_wgs84':[LON,LAT],'south_rotation_radians':A,'unit':'meter',
 'hall_outline':[local(p) for p in hall['points']],
 'ponds':[{'name':'眼镜湖·西池','outline':[local(p) for p in west['points']],'confidence':'OSM footprint + official map'}, {'name':'眼镜湖·东池','outline':east,'confidence':'Manual satellite trace; approximate'}],
 'pavilion':local([117.26401,31.84203]), 'background':[]}
for f in features:
 if 'building' not in f['tags'] or f is hall or '老北门' in f['tags'].get('name',''):continue
 pts=[local(p) for p in f['points']];xs=[p[0] for p in pts];zs=[p[1] for p in pts]
 x=(min(xs)+max(xs))/2;z=(min(zs)+max(zs))/2
 if -100<x<200 and -60<z<265:
  h=int(f['tags'].get('building:levels','3'))*3.3
  if f['id']=='270537516':h=12.5
  if f['id']=='268207470':h=4.5
  if max(xs)-min(xs)<8:h=3.5
  data['background'].append({'name':f['tags'].get('name','背景建筑'),'center':[round(x,2),round(z,2)],'size':[round(max(xs)-min(xs),2),round(max(zs)-min(zs),2)],'outline':pts,'height':h,'osm_id':f['id']})
(R/'godot/assets/site.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
# Retrieve the first teaching building's official photograph, not surrounding UI.
html=(R/'references/buildings/teaching1.html').read_text(encoding='utf-8')
paths=re.findall(r'<img[^>]+src=["\x27]([^"\x27]+)',html)
for i,p in enumerate([x for x in paths if '/article/' in x]):
 try:
  urllib.request.urlretrieve(urllib.parse.urljoin('https://business.ustc.edu.cn',p),R/f'references/buildings/teaching1_{i}.jpg')
  print('photo',p)
 except Exception as e:print(e)
print('hall',data['hall_outline']);print('pavilion',data['pavilion'])
