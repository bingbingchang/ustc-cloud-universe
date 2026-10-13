"""Encode actual Godot JPEG frames with Blender's bundled video encoder."""
import bpy,json,sys
from pathlib import Path
R=Path(sys.argv[sys.argv.index('--')+1]) if '--' in sys.argv else Path(__file__).resolve().parents[1]/'renders/life'
meta=json.loads((R/'motion_manifest.json').read_text(encoding='utf-8'))
frames=sorted((R/'motion_frames').glob('frame_*.jpg'))
assert len(frames)==meta['frames'], (len(frames),meta['frames'])
s=bpy.context.scene;s.render.resolution_x=meta['width'];s.render.resolution_y=meta['height'];s.render.resolution_percentage=100;s.render.fps=meta['fps'];s.frame_start=1;s.frame_end=len(frames)
s.render.use_sequencer=True;s.view_settings.view_transform='Standard';s.view_settings.look='None';s.view_settings.exposure=0;s.view_settings.gamma=1
seq=s.sequence_editor_create();strip=seq.strips.new_image('Actual Godot frames',str(frames[0]),channel=1,frame_start=1)
for path in frames[1:]:strip.elements.append(path.name)
strip.frame_final_duration=len(frames)
if hasattr(s.render.image_settings,'media_type'):s.render.image_settings.media_type='VIDEO'
s.render.image_settings.file_format='FFMPEG';s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.constant_rate_factor='HIGH';s.render.ffmpeg.ffmpeg_preset='GOOD';s.render.ffmpeg.audio_codec='NONE';s.render.filepath=str(R/'campus_life_demo.mp4')
bpy.ops.render.render(animation=True)
print('LIFE_VIDEO_ENCODE_OK',s.render.filepath)
