"""Decode three frames of the delivered Godot video; do not modify the movie."""
import bpy, json, hashlib
from pathlib import Path
import numpy as np

root=Path(__file__).resolve().parents[1]/'renders/lookdev_live'
video=root/'campus_life_demo.mp4'
meta=json.loads((root/'motion_manifest.json').read_text(encoding='utf-8'))
digest=hashlib.sha256(video.read_bytes()).hexdigest()
clip=bpy.data.movieclips.load(str(video))
w,h=map(int,clip.size);fps=float(clip.fps);frames=int(clip.frame_duration)
s=bpy.context.scene
s.render.resolution_x=w;s.render.resolution_y=h;s.render.resolution_percentage=100
s.render.use_sequencer=True;s.render.fps=meta['fps']
s.view_settings.view_transform='Standard';s.view_settings.look='None';s.view_settings.exposure=0;s.view_settings.gamma=1
s.sequence_editor_create().strips.new_movie('Native Godot delivery',str(video),channel=1,frame_start=1)
s.render.image_settings.file_format='PNG'
out=root/'video_checks';out.mkdir(exist_ok=True);samples=[]
for frame in [1,frames//2,frames]:
    path=out/f'decoded_{frame:04d}.png';s.frame_set(frame);s.render.filepath=str(path)
    bpy.ops.render.render(write_still=True)
    img=bpy.data.images.load(str(path),check_existing=False)
    data=np.empty(len(img.pixels),dtype=np.float32);img.pixels.foreach_get(data)
    rgb=data.reshape((-1,4))[:,:3]
    samples.append({'frame':frame,'mean':float(rgb.mean()),'std':float(rgb.std()),'file':str(path)})
unchanged=hashlib.sha256(video.read_bytes()).hexdigest()==digest
passed=(w,h)==(meta['width'],meta['height']) and frames==meta['frames'] and abs(fps-meta['fps'])<.001 and all(x['std']>.03 for x in samples) and unchanged
report={'passed':passed,'width':w,'height':h,'fps':fps,'frames':frames,'duration':frames/fps,'sha256':digest,'file_bytes':video.stat().st_size,'decoded_samples':samples,'source_unchanged':unchanged,'scope':'Metadata and first/middle/last decoded frames; not continuous GUI playback'}
(root/'video_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('LOOKDEV_VIDEO_VALIDATION',passed,frames/fps)
if not passed:raise RuntimeError('Delivered movie validation failed')
