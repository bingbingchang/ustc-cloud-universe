"""Check exported identity geometry and measured runtime animation, not source string matching."""
import hashlib,json,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def inspect(name):
 data=(ROOT/'godot/assets'/name).read_bytes();jlen=struct.unpack_from('<I',data,12)[0];doc=json.loads(data[20:20+jlen]);binary=data[28+jlen:]
 def acc(index):
  a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']];start=v.get('byteOffset',0)+a.get('byteOffset',0)
  size={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]*{5126:4,5125:4,5123:2,5121:1}[a['componentType']]
  return b''.join(binary[start+i*v.get('byteStride',size):start+i*v.get('byteStride',size)+size] for i in range(a['count']))
 def descendants(i):
  yield i
  for c in doc['nodes'][i].get('children',[]):yield from descendants(c)
 head=next(i for i,n in enumerate(doc['nodes']) if n.get('name')=='Tiku_Head')
 digest=hashlib.sha256();head_triangles=0
 for i in descendants(head):
  n=doc['nodes'][i]
  if 'mesh' not in n:continue
  for p in doc['meshes'][n['mesh']]['primitives']:
   for a in ['POSITION','NORMAL','TEXCOORD_0']:
    if a in p['attributes']:digest.update(acc(p['attributes'][a]))
   if 'indices' in p:head_triangles+=doc['accessors'][p['indices']]['count']//3
 total=sum(doc['accessors'][p['indices']]['count']//3 for m in doc['meshes'] for p in m['primitives'] if 'indices' in p)
 return {'file':name,'head_geometry_sha256':digest.hexdigest(),'head_triangles':head_triangles,'triangles':total,'materials':len(doc['materials']),'bytes':len(data)}
a=inspect('tiku_boy1.glb');b=inspect('tiku_boy1_uniform.glb')
animation=json.loads((ROOT/'renders/tiku_identity/animation_validation.json').read_text(encoding='utf-8'))
samples=animation['samples'];road=animation['roadside_samples']
pinch=max(s.get('pinch_to_pen_error_m',0) for s in samples)
paper=max(s.get('paper_contact_error_m',0) for s in samples)
ik=max(max(s['arm_target_error_m'].values()) for s in samples+road)
road_activities=sorted(set(s['activity'] for s in road))
result={'identity_geometry_identical':a['head_geometry_sha256']==b['head_geometry_sha256'],'assets':[a,b],
 'runtime_poses':animation['poses_checked'],'bench_loop_closed':animation['loop_closure']['closed'],'roadside_loop_closed':animation['roadside_loop']['closed'],
 'max_pinch_to_pen_error_m':pinch,'max_paper_contact_error_m':paper,'max_arm_ik_target_error_m':ik,'roadside_activities':road_activities,
 'scope':'Geometry hash covers actual exported head positions/normals/UV. Contact values are analytic rig measurements; visual inspection remains required.'}
result['passed']=result['identity_geometry_identical'] and animation['passed'] and result['bench_loop_closed'] and result['roadside_loop_closed'] and pinch<.001 and paper<.0011 and ik<.025 and len(road_activities)>=4
(ROOT/'renders/tiku_identity/identity_validation.json').write_text(json.dumps(result,indent=2,ensure_ascii=False),encoding='utf-8')
print(json.dumps(result,indent=2,ensure_ascii=False))
raise SystemExit(0 if result['passed'] else 1)
