"""Original synthetic wind and occasional bird phrases. No sampled recordings."""
from pathlib import Path
import wave,math,random,struct
R=Path(__file__).resolve().parents[1];random.seed(1958)
sr=22050;seconds=40;out=bytearray();low=0.0
calls=[(5.3,2400),(13.8,3000),(26.1,2100),(34.6,2750)]
for i in range(sr*seconds):
 t=i/sr;n=random.uniform(-1,1);low=low*.975+n*.025
 wind=low*.30*(.65+.2*math.sin(t*.31)+.1*math.sin(t*.91))
 bird=0
 for start,f in calls:
  for j in range(3):
   u=t-start-j*.21
   if 0<u<.14:bird+=.055*math.sin(math.pi*u/.14)**2*math.sin(math.tau*(f*u+1700*u*u))
 fade=min(1,t/2,(seconds-t)/2)
 v=int(max(-1,min(1,(wind+bird)*fade))*32767);out.extend(struct.pack('<h',v))
with wave.open(str(R/'godot/assets/campus_ambience.wav'),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(sr);w.writeframes(out)
print('SYNTH_AUDIO_OK')
