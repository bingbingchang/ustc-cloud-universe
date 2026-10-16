"""Original, deterministic brush/fur/feather textures. No photo-derived pixels."""
from pathlib import Path
import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parents[2] / 'godot' / 'wildlife' / 'assets' / 'textures'
OUT.mkdir(parents=True, exist_ok=True)
N = 1024
y, x = np.mgrid[0:N, 0:N].astype(float) / N
rng = np.random.default_rng(1958)
noise = rng.normal(0, 1, (N, N))
brush = (np.sin(x*163+y*47) + .55*np.sin(x*357-y*197) + .3*noise)*.015

def save(name, base, pattern='fur'):
    c = np.tile(np.array(base)[None,None,:]/255, (N,N,1))
    h = brush.copy()
    if pattern == 'tabby':
        phase = x*11 + .27*np.sin(y*13) + .10*np.sin(y*51+x*23)
        bands = np.exp(-((np.sin(phase*np.pi))/.23)**2)
        bands *= .55 + .45*np.sin(y*19+x*22)**2
        c *= 1 - bands[:,:,None]*.60
        back = np.exp(-((y-.25)/.14)**2)
        c *= 1-back[:,:,None]*.25
        c += (np.sin(x*14+y*5)*.023)[:,:,None]*np.array([1,.6,.2])
        h += np.sin(x*300 + np.sin(y*80)*2)*.008
    elif pattern == 'head':
        phase=(x-.75)*15 + .16*np.cos(y*19)
        bars=np.exp(-(np.sin(phase*np.pi)/.23)**2)
        mask=np.exp(-((x-.75)/.26)**8)*np.clip((.61-y)*8,0,1)*np.clip(y*8,0,1)
        c*=1-(bars*mask*.58)[:,:,None]
        c += np.clip((y-.57)*.20,0,.10)[:,:,None]
    elif pattern == 'feather':
        row = np.floor(y*18)
        u = (x*12 + (row%2)*.5)%1
        v = (y*18)%1
        edge = np.exp(-((v - (.23+.60*np.sqrt(np.maximum(0,1-(u*2-1)**2))))/.06)**2)
        c *= 1-edge[:,:,None]*.33
        c += (np.sin(y*240+x*27)*.014)[:,:,None]
        h += edge*.025
    elif pattern == 'mottle':
        row=np.floor(y*24);u=(x*22+row*.37)%1;v=(y*24)%1
        marks=np.exp(-((u-.5-.12*np.sin(v*6))/.14)**2)*np.exp(-((v-.55)/.33)**2)
        c *= 1-marks[:,:,None]*.55
        c += np.sin(x*34-y*58)[:,:,None]*.021
        h += marks*.018
    elif pattern == 'iris':
        r = np.sqrt((x-.5)**2+(y-.5)**2)
        a = np.arctan2(y-.5,x-.5)
        c *= (.85+.15*np.sin(a*83+r*60))[:,:,None]
        c *= (1-.6*np.clip((r-.35)*6,0,1))[:,:,None]
    elif pattern == 'sparrow_head':
        # UV latitude follows the head surface. Blend the crown into buff face
        # feathers rather than attaching pale discs and black cheek "pupils".
        crown = np.clip((y-.49)/.12,0,1)
        crown = crown*crown*(3-2*crown)
        cap = np.array([128,75,45])/255
        face = np.array([187,165,127])/255
        c = face[None,None,:]*(1-crown[:,:,None])+cap[None,None,:]*crown[:,:,None]
        feather = np.sin(x*285+y*91)*.008 + np.sin(x*513-y*149)*.004
        c += feather[:,:,None]
    c += brush[:,:,None]
    Image.fromarray(np.uint8(np.clip(c,0,1)*255)).save(OUT / (name+'_albedo.png'))
    dy, dx = np.gradient(h)
    normal = np.stack([-dx*80,-dy*80,np.ones_like(x)],axis=2)
    normal /= np.linalg.norm(normal,axis=2)[:,:,None]
    Image.fromarray(np.uint8((normal*.5+.5)*255)).save(OUT / (name+'_normal.png'))

for args in [
    ('cat_coat',(125,119,100),'tabby'), ('cat_head',(132,122,103),'head'), ('cat_cream',(203,194,175),'fur'),
    ('cat_iris',(156,164,74),'iris'), ('duck_gray',(163,164,153),'feather'),
    ('duck_brown',(91,49,40),'feather'), ('duck_female',(161,125,78),'mottle'), ('duck_female_head',(145,127,94),'fur'),
    ('duck_green',(30,82,54),'fur'), ('sparrow_back',(138,91,51),'feather'),
    ('sparrow_cap',(128,75,45),'fur'), ('bird_cream',(214,200,169),'fur'),
    ('sparrow_head',(128,75,45),'sparrow_head'),
]: save(*args)
print('WILDLIFE_TEXTURES', OUT)
