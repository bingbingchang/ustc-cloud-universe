"""Decode the delivered MP4s and inspect every cafe chapter."""
import json
import sys
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[2]
videos = ROOT / '展示/视频'
output = ROOT / 'campus/renders/showcase/decoded'
output.mkdir(parents=True, exist_ok=True)
cases = [
    ('01_USTC1958咖啡厅.mp4',1920,1080,30,1800,[120,360,600,810,1040,1335,1560,1740]),
    ('02_东区校园漫步_既有样片.mp4',1280,720,12,1152,[36,220,600,1110]),
    ('03_樱花大道_既有片段.mp4',1280,720,12,144,[72]),
    ('04_完整东区校园漫游_当前版.mp4',1280,720,30,1290,[60,165,255,345,435,525,615,705,795,885,975,1065,1155,1245]),
]
full_campus_only = '--full-campus' in sys.argv
if full_campus_only:cases=cases[-1:]
scene = bpy.context.scene
scene.render.use_sequencer = True
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'None'
scene.view_settings.exposure = 0
scene.view_settings.gamma = 1
scene.render.image_settings.file_format = 'PNG'
sequence = scene.sequence_editor_create()
report = []
for name,width,height,fps,frames,samples in cases:
    path = videos / name
    clip = bpy.data.movieclips.load(str(path))
    actual = (int(clip.size[0]),int(clip.size[1]),round(clip.fps),clip.frame_duration)
    if actual != (width,height,fps,frames):
        raise RuntimeError(f'{name}: unexpected metadata {actual}')
    for strip in list(sequence.strips):sequence.strips.remove(strip)
    sequence.strips.new_movie(name,str(path),channel=1,frame_start=1)
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.fps = fps
    scene.frame_start = 1
    scene.frame_end = frames
    decoded = []
    for frame in samples:
        file = output / f'{name[:2]}_{frame:04d}.png'
        scene.frame_set(frame)
        scene.render.filepath = str(file)
        bpy.ops.render.render(write_still=True)
        decoded.append(str(file.relative_to(ROOT)))
    report.append({'file':name,'width':width,'height':height,'fps':fps,'frames':frames,'seconds':frames/fps,'bytes':path.stat().st_size,'decoded':decoded})
(output.parent / ('full_campus_video.json' if full_campus_only else 'videos.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('SHOWCASE_VIDEOS_DECODED_OK', [(x['file'],x['seconds']) for x in report])
