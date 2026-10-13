"""Download the public USTC map Yanjing Lake album as modeling references."""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from hashlib import sha256
from html import escape
from io import BytesIO
import json
from pathlib import Path
from urllib.parse import urlencode, urljoin
from urllib.request import Request, urlopen

from PIL import Image, ImageOps, ImageDraw

BASE = 'https://map.ustc.edu.cn/'
OUT = Path(__file__).resolve().parents[1] / 'references' / 'yijian_garden'


def fetch(url, data=None):
    request = Request(url, data=data, headers={'Referer': BASE, 'User-Agent': 'Mozilla/5.0'})
    with urlopen(request, timeout=40) as response:
        return response.read()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    payload = fetch(urljoin(BASE, 'album'), urlencode({'action': 'getalbum', 'id': 10842}).encode())
    album = json.loads(payload)
    if not album.get('state') or not album.get('data'):
        raise RuntimeError('Album returned no images')
    (OUT / 'source_album.json').write_bytes(payload)

    def download(pair):
        index, item = pair
        url = urljoin(BASE, item['filename'])
        name = f"{index:02d}_lake_{item['id']}{Path(item['filename']).suffix}"
        raw = fetch(url)
        with Image.open(BytesIO(raw)) as picture:
            picture.load()
            width, height = picture.size
        (OUT / name).write_bytes(raw)
        return dict(file=name, url=url, album_id=item['id'], title=item['title'],
                    width=width, height=height, bytes=len(raw), sha256=sha256(raw).hexdigest())

    with ThreadPoolExecutor(max_workers=4) as pool:
        images = list(pool.map(download, enumerate(album['data'], 1)))
    manifest = dict(place='眼镜湖', poi_id=10842,
                    source_page=BASE + '#&gid=1&pid=1',
                    source_api=BASE + 'album', source_request={'action': 'getalbum', 'id': 10842},
                    retrieved_at=datetime.now(timezone.utc).isoformat(),
                    usage='建模参考；来源未注明再分发许可，不作为游戏贴图。',
                    capture_date='未提供；文件名中的日期不作为拍摄日期。', images=images)
    (OUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    cards = ''.join(f'<figure><a href="{i["file"]}"><img loading="lazy" src="{i["file"]}" alt="眼镜湖参考 {n:02d}"></a><figcaption>{n:02d} · {i["width"]} × {i["height"]} · <a href="{escape(i["url"])}">来源原图</a></figcaption></figure>' for n, i in enumerate(images, 1))
    page = '<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>眼镜湖 · 建模参考图库</title><style>body{margin:32px auto;max-width:1200px;padding:0 20px;background:#f4f2ee;color:#28372e;font:16px/1.65 system-ui}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:20px}figure{margin:0;background:white;padding:12px;border-radius:8px}img{width:100%;height:270px;object-fit:contain;background:#eeede9}a{color:#346d52}figcaption{padding-top:8px}</style><h1>眼镜湖 · 建模参考图库</h1><p>中科大校园地图 · 地点 10842 · 共 ' + str(len(images)) + ' 张网站原文件。点击图片查看原图。</p><p>拍摄时间与精确方位未提供；用于空间、树形、色彩及设施观察，不据单张照片确定精确尺寸。</p><main>' + cards + '</main><p><a href="manifest.json">来源与尺寸清单</a> · <a href="https://map.ustc.edu.cn/#&gid=1&pid=1">校园地图</a></p></html>'
    (OUT / 'index.html').write_text(page, encoding='utf-8')
    sheet = Image.new('RGB', (1200, ((len(images)+2)//3)*260), '#f4f2ee')
    draw = ImageDraw.Draw(sheet)
    for index, item in enumerate(images):
        with Image.open(OUT / item['file']) as picture:
            thumbnail = ImageOps.contain(picture.convert('RGB'), (380, 220))
        x, y = (index % 3)*400, (index//3)*260
        sheet.paste(thumbnail, (x+(400-thumbnail.width)//2, y+(220-thumbnail.height)//2))
        draw.text((x+12,y+230), f'{index+1:02d} | {item["width"]} x {item["height"]}', fill='#28372e')
    sheet.save(OUT / 'contact_sheet.jpg', quality=92)
    print(json.dumps({'directory':str(OUT),'count':len(images),'images':images},ensure_ascii=False,indent=2))


if __name__ == '__main__':
    main()
