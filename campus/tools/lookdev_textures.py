"""Original, seamless, restrained PBR surfaces. No downloaded image content."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter
R=Path(__file__).resolve().parents[1]/'godot/assets/textures';R.mkdir(exist_ok=True)
N=1024;rng=np.random.default_rng(1958)
def noise(res):
 a=rng.random((res,res)).astype('float32');a=np.pad(a,((0,1),(0,1)),mode='wrap')
 return np.asarray(Image.fromarray(a).resize((N+N//res,N+N//res),Image.Resampling.BICUBIC))[:N,:N]
y,x=np.mgrid[0:N,0:N]/N
large=noise(8);small=noise(80);grain=rng.random((N,N))
for kind,base in [('brick',(159,106,82)),('paving',(164,162,146)),('grass',(105,122,78)),('stone',(185,179,160)),('bark',(109,104,86)),('wood',(116,99,76))]:
 variation=(large-.5)*.045+(small-.5)*.028+(grain-.5)*.014
 height=small*.015;ao=np.ones((N,N));rough=np.full((N,N),.80)
 if kind=='brick':
  row=np.floor(y*20);u=np.mod(x*16+(row%2)*.5,1);v=np.mod(y*20,1)
  edge=np.minimum(np.minimum(u,1-u)*.25,np.minimum(v,1-v)*.1)
  mask=np.clip((edge-.0018)/.003,0,1)
  cells=rng.random((20,17));variation+=(cells[row.astype(int),np.floor(x*16+(row%2)*.5).astype(int)]-.5)*.055
  height=mask*.17+small*.026;ao=.78+.22*mask;rough=.77+(small-.5)*.13
  col=np.array(base)[None,None,:]*(1+variation[:,:,None]);col=col*mask[:,:,None]+np.array([153,145,126])*(1-mask[:,:,None])
 elif kind=='paving':
  u=np.mod(x*6,1);v=np.mod(y*8,1);edge=np.minimum(np.minimum(u,1-u),np.minimum(v,1-v));mask=np.clip((edge-.002)/.006,0,1)
  cells=rng.random((8,6));variation+=(cells[np.floor(y*8).astype(int),np.floor(x*6).astype(int)]-.5)*.09
  height=mask*.05+small*.012;ao=.82+.18*mask;rough=.76+(large-.5)*.10
  col=np.array(base)[None,None,:]*(1+variation[:,:,None])*(.88+.12*mask[:,:,None])
 elif kind=='grass':
  variation=(noise(5)-.5)*.22+(large-.5)*.12+(small-.5)*.09
  height=small*.11;rough=np.full((N,N),.94);col=np.array(base)[None,None,:]*(1+variation[:,:,None]);col[:,:,0]+=(large-.5)*14
 elif kind=='bark':
  ridges=noise(21);height=ridges*.035+small*.023;ao=.94+.06*ridges
  col=np.array(base)[None,None,:]*(.95+ridges[:,:,None]*.1+variation[:,:,None]);col+=(noise(14)>.61)[:,:,None]*7
 elif kind=='wood':
  ridges=np.sin((x*37+large*.14)*np.pi*2)*.5+.5;height=ridges*.024;rough=.63+(large-.5)*.16
  col=np.array(base)[None,None,:]*(.94+ridges[:,:,None]*.1+variation[:,:,None])
 else:
  height=small*.023;rough=.77+(large-.5)*.12;col=np.array(base)[None,None,:]*(1+variation[:,:,None])
 dx=(np.roll(height,-1,1)-np.roll(height,1,1))*6;dy=(np.roll(height,-1,0)-np.roll(height,1,0))*6
 norm=np.stack([-dx,-dy,np.ones_like(dx)],axis=-1);norm/=np.linalg.norm(norm,axis=-1,keepdims=True)
 Image.fromarray(np.uint8(np.clip(col,0,255))).save(R/f'{kind}_albedo.png')
 Image.fromarray(np.uint8((norm*.5+.5)*255)).save(R/f'{kind}_normal.png')
 Image.fromarray(np.uint8(np.stack([ao,np.clip(rough,0,1),np.zeros_like(ao)],-1)*255)).save(R/f'{kind}_orm.png')
print('LOOKDEV_PBR_TEXTURES_OK')
