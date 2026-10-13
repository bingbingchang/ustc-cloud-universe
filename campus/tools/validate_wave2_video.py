"""Decode three frames from the delivered MP4 with Blender's bundled decoder.
Does not re-encode or change the source movie. Media integrity, not art approval.
"""
import bpy, json, hashlib
from pathlib import Path
from datetime import datetime, timezone
import numpy as np

root=Path(__file__).resolve().parents[1]/'renders/wave2'
video=root/'campus_life_demo.mp4'
stat=video.stat();source_hash=hashlib.sha256(video.read_bytes()).hexdigest()
clip=bpy.data.movieclips.load(str(video))
width,height=map(int,clip.size);fps=float(clip.fps);frames=int(clip.frame_duration)
report={
    'schema_version':1,'validated_at_utc':datetime.now(timezone.utc).isoformat(),
    'file':str(video),'file_bytes':stat.st_size,'sha256':source_hash,
    'decoder':'Blender '+bpy.app.version_string+' bundled MovieClip/Video Sequencer movie decoder',
    'width':width,'height':height,'fps':fps,'frame_count':frames,'duration_seconds':frames/fps if fps else None,
    'expected':{'width':1280,'height':720,'fps':12,'frames':1800,'duration_seconds':150},
    'scope':'Actual MP4 metadata plus first/middle/last frame decoding. Not all 1800 frames decoded; not an artistic-quality or gameplay-FPS assessment.',
    'decoded_samples':[],'passed':False
}
scene=bpy.context.scene
scene.render.resolution_x=width;scene.render.resolution_y=height;scene.render.resolution_percentage=100
scene.render.fps=12;scene.render.fps_base=1;scene.render.use_sequencer=True
scene.view_settings.view_transform='Standard';scene.view_settings.look='None';scene.view_settings.exposure=0;scene.view_settings.gamma=1
scene.use_nodes=False
editor=scene.sequence_editor_create()
strip=editor.strips.new_movie('Delivered MP4 decode proof',str(video),channel=1,frame_start=1)
report['sequencer_frame_count']=int(strip.frame_duration)
scene.frame_start=1;scene.frame_end=frames;scene.render.image_settings.file_format='PNG'
out=root/'video_checks';out.mkdir(exist_ok=True)
samples=[1,frames//2+1,frames]
all_nonempty=True
for frame in samples:
    scene.frame_set(frame);path=out/f'decoded_{frame:04d}.png';scene.render.filepath=str(path)
    bpy.ops.render.render(write_still=True)
    image=bpy.data.images.load(str(path),check_existing=False)
    pixels=np.empty(len(image.pixels),dtype=np.float32);image.pixels.foreach_get(pixels)
    rgb=pixels.reshape((-1,4))[:,:3];luma=rgb@np.array([.2126,.7152,.0722],dtype=np.float32)
    avg=float(luma.mean());sd=float(luma.std());dark=float((luma<.002).mean())
    valid=tuple(image.size)==(width,height) and sd>.005 and avg>.003 and dark<.995
    all_nonempty=all_nonempty and valid
    report['decoded_samples'].append({'source_frame_1based':frame,'time_seconds':(frame-1)/fps,'decoded_resolution':list(image.size),'mean_linear_luminance':avg,'luminance_stddev':sd,'near_black_fraction':dark,'nonempty':bool(valid),'png':str(path)})
    bpy.data.images.remove(image)
report['source_unchanged']=video.stat().st_size==stat.st_size and video.stat().st_mtime_ns==stat.st_mtime_ns and hashlib.sha256(video.read_bytes()).hexdigest()==source_hash
report['passed']=bool(width==1280 and height==720 and abs(fps-12)<.0001 and frames==1800 and report['sequencer_frame_count']==1800 and abs(report['duration_seconds']-150)<.0001 and all_nonempty and report['source_unchanged'])
(root/'video_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('WAVE2_VIDEO_VALIDATION',report['passed'],width,height,fps,frames,report['duration_seconds'],flush=True)
if not report['passed']:raise RuntimeError('Video metadata/decode check failed; inspect video_validation.json')
