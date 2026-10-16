"""Encode actual Godot frames with Blender's bundled FFmpeg."""
import bpy,json,sys
from pathlib import Path
OUT=Path(__file__).resolve().parents[2]/'renders'/'wildlife'
second='--new-batch' in sys.argv
meta=json.loads((OUT/('second_batch_motion_manifest.json' if second else 'motion_manifest.json')).read_text(encoding='utf-8'))
frames=sorted((OUT/('second_batch_frames' if second else 'motion_frames')).glob('frame_*.jpg'))
movie_path=OUT/('second_batch_demo.mp4' if second else 'wildlife_demo.mp4')
assert len(frames)==meta['frames'],(len(frames),meta['frames'])
s=bpy.context.scene;s.render.resolution_x=meta['width'];s.render.resolution_y=meta['height'];s.render.resolution_percentage=100;s.render.fps=meta['fps']
s.frame_start=1;s.frame_end=len(frames);s.render.use_sequencer=True
s.view_settings.view_transform='Standard';s.view_settings.look='None';s.view_settings.exposure=0;s.view_settings.gamma=1
seq=s.sequence_editor_create()
if '--decode-only' not in sys.argv:
    strip=seq.strips.new_image('Godot wildlife footage',str(frames[0]),channel=1,frame_start=1)
    for path in frames[1:]:strip.elements.append(path.name)
    strip.frame_final_duration=len(frames)
    if hasattr(s.render.image_settings,'media_type'):s.render.image_settings.media_type='VIDEO'
    s.render.image_settings.file_format='FFMPEG';s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264'
    s.render.ffmpeg.constant_rate_factor='HIGH';s.render.ffmpeg.ffmpeg_preset='GOOD';s.render.ffmpeg.audio_codec='NONE'
    s.render.filepath=str(movie_path);bpy.ops.render.render(animation=True)
    seq.strips.remove(strip)
# Decode representative frames using the same actual movie decoder.
movie=seq.strips.new_movie('Decoded proof',str(movie_path),channel=1,frame_start=1)
assert movie.frame_duration==len(frames),(movie.frame_duration,len(frames))
if hasattr(s.render.image_settings,'media_type'):s.render.image_settings.media_type='IMAGE'
s.render.image_settings.file_format='PNG'
samples=[]
for frame in [1,len(frames)//2,len(frames)]:
    s.frame_set(frame);s.render.filepath=str(OUT/(('second_batch_decoded_' if second else 'video_decoded_')+f'{frame:04d}.png'));bpy.ops.render.render(write_still=True);samples.append(s.render.filepath)
(OUT/('second_batch_video_validation.json' if second else 'video_validation.json')).write_text(json.dumps(dict(passed=True,decoded_frames=samples,frames=len(frames),fps=meta['fps'],width=meta['width'],height=meta['height'],seconds=len(frames)/meta['fps']),indent=2))
print('WILDLIFE_VIDEO_OK',movie_path)
