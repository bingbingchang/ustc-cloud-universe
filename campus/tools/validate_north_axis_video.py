"""Read the delivered native movie and decode selected frames without changing it."""
import bpy, json, hashlib
from pathlib import Path
import numpy as np
root=Path(__file__).resolve().parents[1]/'renders/north_axis'
video=root/'campus_life_demo.mp4';meta=json.loads((root/'motion_manifest.json').read_text(encoding='utf-8'))
digest=hashlib.sha256(video.read_bytes()).hexdigest();clip=bpy.data.movieclips.load(str(video))
w,h=map(int,clip.size);fps=float(clip.fps);frames=int(clip.frame_duration)
s=bpy.context.scene;s.render.resolution_x=w;s.render.resolution_y=h;s.render.resolution_percentage=100;s.render.use_sequencer=True;s.render.fps=meta['fps']
s.view_settings.view_transform='Standard';s.view_settings.look='None';s.view_settings.exposure=0;s.view_settings.gamma=1
s.sequence_editor_create().strips.new_movie('Native Godot delivery',str(video),channel=1,frame_start=1)
s.render.image_settings.file_format='PNG';out=root/'video_checks';out.mkdir(exist_ok=True)
samples=[]
for frame in [1,frames//2,frames]:
    path=out/f'decoded_{frame:04d}.png';s.frame_set(frame);s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
    img=bpy.data.images.load(str(path),check_existing=False);a=np.empty(len(img.pixels),dtype=np.float32);img.pixels.foreach_get(a)
    rgb=a.reshape((-1,4))[:,:3];samples.append({'frame':frame,'mean':float(rgb.mean()),'std':float(rgb.std()),'file':str(path)})
passed=(w,h)==(meta['width'],meta['height']) and frames==meta['frames'] and abs(fps-meta['fps'])<.001 and all(x['std']>.03 for x in samples)
report={'passed':passed,'width':w,'height':h,'fps':fps,'frames':frames,'duration':frames/fps,'sha256':digest,'file_bytes':video.stat().st_size,'decoded_samples':samples,'scope':'Metadata and first/middle/last decoded frames; not a continuous GUI playback claim'}
report['source_unchanged']=hashlib.sha256(video.read_bytes()).hexdigest()==digest
passed=passed and report['source_unchanged']
report['passed']=passed
(root/'video_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('NORTH_VIDEO_VALIDATION',passed,frames/fps)
if not passed:raise RuntimeError('Delivered movie validation failed')
