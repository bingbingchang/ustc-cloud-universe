"""Download observed references. Reference pixels never enter production textures."""
import json, urllib.request
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / 'references' / 'wildlife'
OUT.mkdir(parents=True, exist_ok=True)
SOURCES = [
    ('cat_profile.jpg', 'https://www.redzet.lv/images/large/3/25/D-019-23.jpg', 'https://www.redzet.lv/en/photo/walking-cat-D-019-23', 'Adult tabby profile, muzzle and limb proportions; research only'),
    ('mallard_pair.jpg', 'https://media.snl.no/media/28729/standard_compressed_Anas_platyrhynchos_male_female_quadrat.jpg', 'https://snl.no/seksuell_dimorfi', 'Mallard sex-specific plumage and body proportions; research only'),
    ('sparrow_profile.jpg', 'https://www.berlin.de/sen/uvk/_assets/natur-gruen/naturschutz/artenschutz/rote-listen/sperling_680.jpg', 'https://www.berlin.de/sen/uvk/natur-und-gruen/naturschutz/artenschutz/artenlisten-rote-listen/voegel/', 'Tree sparrow cap, cheek spot, wing bars and feet; research only'),
]
rows = []
for filename, url, page, purpose in SOURCES:
    request = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    data = urllib.request.urlopen(request, timeout=45).read()
    (OUT / filename).write_bytes(data)
    rows.append(dict(file=filename, image=url, page=page, purpose=purpose, texture_usage=False))
rows += [
    dict(page='https://commons.wikimedia.org/wiki/File:Cat_galloping_(rbm-QP301M8-1887-719).jpg', purpose='Muybridge locomotion phase reference; fast gait, not a walking-cycle prescription'),
    dict(page='https://www.allaboutbirds.org/guide/Mallard/id', purpose='Cornell identification photographs and video behavior reference'),
    dict(page='https://www.allaboutbirds.org/guide/Eurasian_Tree_Sparrow/id', purpose='Cornell identification photographs and video behavior reference'),
]
(OUT / 'sources.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding='utf-8')
print('WILDLIFE_REFERENCES', OUT)
