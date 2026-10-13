"""Evidence gallery: references, generated concept/atlas, native sample and final."""
from pathlib import Path
from html import escape
from html.parser import HTMLParser
import json,hashlib
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'renders/yijian_garden'
baseline=json.loads((OUT/'baseline.json').read_text(encoding='utf-8'))
changed=[k for k,v in baseline.items() if hashlib.sha256((ROOT/k).read_bytes()).hexdigest()!=v]
(OUT/'preservation.json').write_text(json.dumps({'count':len(baseline),'changed':changed,'passed':not changed},indent=2),encoding='utf-8')
shots=[('01_east_bridge','东侧曲桥'),('02_water_edge','岸边近景'),('03_north_approach','北侧入亭'),('04_from_pavilion','亭内回望'),('05_cherry_connection','与樱花大道衔接'),('06_overview','全域空间')]
def picture(path,label):return f'<figure><figcaption>{label}</figcaption><a href="{path}"><img loading="lazy" src="{path}" alt="{label}"></a></figure>'
cards=''
for stem,title in shots:
 cards+=f'<section><h2>{title}</h2><div class="pair">'+picture(f'before_live/{stem}.png','修改前 · 已包含上一轮樱花大道')+picture(f'after_live/{stem}.png','修改后 · Live原生实机')+'</div><details><summary>同机位 Diorama 对照</summary><div class="pair">'+picture(f'before_diorama/{stem}.png','修改前 · Diorama')+picture(f'after_diorama/{stem}.png','修改后 · Diorama')+'</div></details></section>'
checks=''
for variant in ['live','diorama']:
 f=OUT/f'qa_{variant}/validation.json'
 if f.exists():
  d=json.loads(f.read_text(encoding='utf-8'));checks+=f'<li>{variant}：'+('全部通过' if d['passed'] else '未全部通过')+f' · <a href="qa_{variant}/validation.json">原始检查记录</a></li>'
performance=''
for stage in ['before','after']:
 f=OUT/f'performance_{stage}.json'
 if f.exists():
  d=json.loads(f.read_text(encoding='utf-8'));performance+='<tr><td>'+stage+'</td>'+''.join(f'<td>{v["effective_fps"]:.1f} fps</td>' for v in d['views'])+'</tr>'
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>一鉴亭湖园 · 完整美术流程</title><style>body{max-width:1450px;margin:32px auto;padding:0 24px;background:#f0f3ed;color:#293d34;font:16px/1.75 system-ui}h1{font-size:32px}h2{font-size:23px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:18px}figure{margin:0}img{width:100%;border-radius:8px}section{margin:38px 0}figcaption{padding-bottom:8px;color:#55675e}a{color:#316a5b}details{margin-top:18px}summary{cursor:pointer}td,th{padding:8px 16px;border-bottom:1px solid #c9d2c7}table{border-collapse:collapse}@media(max-width:780px){.pair{grid-template-columns:1fr}}</style><h1>眼镜湖东池—一鉴亭 · 春日湖园</h1><p>真实参考提取特征 → 概念图 → 莫奈方向纹理与模块化资产 → 东侧桥头样段 → 多视角检查 → 东池全域。</p><p>复用现有校园地图、桥亭与14个生命元素。春日樱花与少量荷花同场是艺术化季节组合。新增种植和装饰密度不是实地测量结果。</p><section><h2>1 · 真实参考与特征</h2><p><a href="../../references/yijian_garden/index.html">校园地图6张原始照片</a> · <a href="../../references/yijian_garden/FEATURES.md">照片特征与设计取舍</a></p>'''+picture('../../references/yijian_garden/contact_sheet.jpg','真实参考索引：夏季、秋季与冬季照片，不能当作同一时刻')+'''</section><section><h2>2 · 概念方向与实际纹理</h2>'''+picture('../../references/yijian_garden/concept/direction_v1.png','AI概念图 · 设计目标，非实机成果')+'''<details><summary>查看实际接入的纹理图与提示词</summary>'''+picture('../../godot/assets/textures/lake_monet_atlas_v1.png','水面 / 苔色石材 / 叶片 / 冷灰屋瓦，四分区底色图')+'''<p>内置 ImageGen 生成；纹理实际1254×1254，按世界米制尺度采样。<a href="../../references/yijian_garden/concept/prompt.txt">概念提示词</a> · <a href="../../references/yijian_garden/concept/texture_prompt.txt">贴图提示词</a></p></details></section><section><h2>3 · 东侧桥头样段</h2><p>先只在东岸约23×36米范围内种植：1株柳、15组荷叶、19丛岸草。检查后修复新水材质被旧底座清理逻辑隐藏的问题，调整花瓣弧面、花蕊尺度和柳叶密度。</p><div class="pair">'''+picture('sample_live/01_east_bridge.png','样段 · 桥头视线')+picture('sample_live/02_water_edge.png','样段 · 花叶和岸石近景')+'''</div></section><section><h2>4 · 扩展后的六组原生机位</h2><p>以下为Godot原生1920×1080截图，未通过AI或后期修饰。两版本、前后机位相同，人物固定在同一动作时间。概念图的树林密度和反射细节尚不等同于实时版本。</p></section>'''+cards+'''<section><h2>5 · 运行与保护检查</h2><ul>'''+checks+f'<li>既有{len(baseline)}个模型、贴图、数据文件：'+('哈希保持' if not changed else '存在变化')+''' · <a href="preservation.json">原始记录</a></li></ul><p>短时性能：RTX5060Ti，1600×900，4×MSAA/TAA，14个生命元素运行。每机位预热90帧、采样180帧；桌面窗口焦点和系统负载会影响结果，不代表持续游玩。</p><table><tr><th>版本</th><th>曲桥</th><th>水岸</th><th>樱花大道</th><th>湖园总览</th></tr>'''+performance+'''</table><p><a href="performance_before.json">修改前详细数据</a> · <a href="performance_after.json">修改后详细数据</a></p></section><p>双击 campus/OPEN_LAKE.cmd 进入湖园，P 切换步行，[ / ] 切换机位。<a href="../../docs/YIJIAN_GARDEN_UPGRADE.md">实现与交接说明</a></p></html>'''
page=page.replace('<table><tr><th>版本</th>','<p>本次修改前窗口有焦点，修改后无焦点：前后条件不完全一致，不能将全部帧率差归因于本轮改造，也未声称稳定60帧。</p><table><tr><th>版本</th>')
(OUT/'review.html').write_text(page,encoding='utf-8')
class Links(HTMLParser):
 def handle_starttag(self,tag,attrs):
  for k,v in attrs:
   if k in ['href','src'] and not v.startswith('http'):assert (OUT/v).exists(),v
Links().feed(page)
print(OUT/'review.html');print('Existing files',len(baseline),'changed',changed)
