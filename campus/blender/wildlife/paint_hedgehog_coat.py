"""Paint quill detail onto the reused hedgehog's back, keeping its original mesh."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
out=Path(__file__).resolve().parents[2]/'godot'/'wildlife'/'assets'/'textures'
rng=np.random.default_rng(417)
n=1024
colour=Image.new('RGB',(n,n),(101,86,65));draw=ImageDraw.Draw(colour)
height=Image.new('L',(n,n),100);relief=ImageDraw.Draw(height)
for _ in range(2100):
    x,y=rng.integers(-35,n+35,2);length=int(rng.integers(25,54));dx=int(rng.integers(-7,8))
    dark=int(rng.integers(-12,12));draw.line((x,y,x+dx,y+length),fill=(70+dark,61+dark,48+dark),width=5)
    draw.line((x+1,y+5,x+dx+1,y+length-5),fill=(156+dark,135+dark,98+dark),width=2)
    draw.line((x+dx,y+length-10,x+dx,y+length),fill=(195+dark,178+dark,143+dark),width=2)
    relief.line((x,y,x+dx,y+length),fill=175,width=4)
colour.save(out/'hedgehog_quills_albedo.png')
h=np.asarray(height.filter(ImageFilter.GaussianBlur(1)),dtype=float)/255
dy,dx=np.gradient(h);normal=np.stack([-dx*2,-dy*2,np.ones_like(h)],axis=2);normal/=np.linalg.norm(normal,axis=2)[:,:,None]
Image.fromarray(np.uint8((normal*.5+.5)*255)).save(out/'hedgehog_quills_normal.png')
