"""Public reference collection; reference-only images never enter game assets."""
from pathlib import Path
import urllib.request, urllib.parse, re, json, concurrent.futures
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]
html=(ROOT/'references/buildings/gallery.html').read_text(encoding='utf-8')
items=re.findall(r'<img src="([^"]+)" title="([^"]+)"',html)
items=[(p,n) for p,n in items if n.startswith('东区')]
def fetch(item):
    p,n=item; url='https://sz.ustc.edu.cn'+p
    target=ROOT/'references/buildings'/ (n.rsplit('.',1)[0]+'.jpg')
    try:
        urllib.request.urlretrieve(url,target)
        return {'file':str(target.relative_to(ROOT)), 'url':url,'title':n,'license':'Not stated; reference only, excluded from game assets'}
    except Exception as e: return {'url':url,'error':str(e)}
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as ex: results=list(ex.map(fetch,items))
(ROOT/'references/reference_manifest.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
valid=[x for x in results if 'file' in x]
board=Image.new('RGB',(1500,340*((len(valid)+2)//3)), '#e7e8df')
d=ImageDraw.Draw(board); font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',20)
for i,x in enumerate(valid):
    im=Image.open(ROOT/x['file']); im.thumbnail((490,300)); ox=(i%3)*500; oy=(i//3)*340
    board.paste(im,(ox+(500-im.width)//2,oy)); d.text((ox+10,oy+305),x['title'],font=font,fill='black')
board.save(ROOT/'references/screenshots/reference_board.jpg')
print(json.dumps(results,ensure_ascii=False,indent=2))
