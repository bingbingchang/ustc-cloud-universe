"""Reuse the existing campus film and extract its cherry avenue chapter."""
import json
import shutil
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[2]
SHOW = ROOT / '展示'
VIDEOS = SHOW / '视频'
POSTERS = SHOW / '封面'
for folder in (VIDEOS, POSTERS):
    folder.mkdir(parents=True, exist_ok=True)
source = ROOT / 'campus/renders/north_axis/campus_life_demo.mp4'
campus_video = VIDEOS / '02_东区校园漫步_既有样片.mp4'
shutil.copy2(source, campus_video)
shutil.copy2(ROOT / 'campus/renders/north_axis/motion_frames/frame_0144.jpg', POSTERS / '03_樱花大道.jpg')
shutil.copy2(ROOT / 'campus/renders/north_axis/motion_frames/frame_0036.jpg', POSTERS / '02_东区校园漫步.jpg')
shutil.copy2(ROOT / 'publish/ustc-cloud-universe/docs/VISION_ROADMAP.md', SHOW / '项目愿景与路线.md')

clip = bpy.data.movieclips.load(str(source))
fps = int(round(clip.fps))
assert fps == 12, clip.fps
width, height = map(int, clip.size)
scene = bpy.context.scene
scene.render.resolution_x = width
scene.render.resolution_y = height
scene.render.resolution_percentage = 100
scene.render.fps = fps
scene.frame_start = 1
scene.frame_end = 12 * fps
scene.render.use_sequencer = True
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'None'
scene.view_settings.exposure = 0
scene.view_settings.gamma = 1
sequence = scene.sequence_editor_create()
# At timeline frame 1 this reads source frame 145: the existing 12–24 second chapter.
sequence.strips.new_movie('Existing cherry avenue chapter', str(source), channel=1, frame_start=1-12*fps)
if hasattr(scene.render.image_settings, 'media_type'):
    scene.render.image_settings.media_type = 'VIDEO'
scene.render.image_settings.file_format = 'FFMPEG'
scene.render.ffmpeg.format = 'MPEG4'
scene.render.ffmpeg.codec = 'H264'
scene.render.ffmpeg.constant_rate_factor = 'HIGH'
scene.render.ffmpeg.ffmpeg_preset = 'GOOD'
scene.render.ffmpeg.audio_codec = 'NONE'
scene.render.filepath = str(VIDEOS / '03_樱花大道_既有片段.mp4')
bpy.ops.render.render(animation=True)
info = {
    'campus_video': campus_video.name,
    'source': str(source.relative_to(ROOT)),
    'campus_seconds': clip.frame_duration / clip.fps,
    'cherry_video': Path(scene.render.filepath).name,
    'cherry_source_seconds': [12,24],
    'cherry_seconds': 12,
    'width': width, 'height': height, 'fps': fps,
}
output = ROOT / 'campus/renders/showcase'
output.mkdir(exist_ok=True)
(output / 'archive.json').write_text(json.dumps(info, ensure_ascii=False, indent=2), encoding='utf-8')
print('SHOWCASE_ARCHIVE_READY', info)
