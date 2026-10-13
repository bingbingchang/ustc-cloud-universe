"""Local gallery of unaltered native Godot captures and clearly labelled concept art."""
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'renders/sakura_avenue'
shots=[('01_avenue','大道纵深'),('02_human','人高看一教'),('03_layering','侧向植被层次'),('04_gate','回望老北门'),('05_garden','树间看湖园'),('06_overview','整体布局')]
cards=[]
for stem,title in shots:
    cards.append(f'<section><h2>{title}</h2><div class="pair"><figure><figcaption>修改前 · LookDev Live</figcaption><a href="before_live/{stem}.png"><img loading="lazy" src="before_live/{stem}.png"></a></figure><figure><figcaption>修改后 · LookDev Live</figcaption><a href="after_live/{stem}.png"><img loading="lazy" src="after_live/{stem}.png"></a></figure></div><details><summary>同机位 Diorama</summary><a href="after_diorama/{stem}.png"><img loading="lazy" src="after_diorama/{stem}.png"></a></details></section>')
checks=[]
for variant in ['live','diorama']:
    p=OUT/f'qa_{variant}/validation.json'
    if p.exists():
        d=json.loads(p.read_text(encoding='utf-8'));checks.append(f'<li>{variant}: '+('检查通过' if d['passed'] else '检查未全部通过')+f' · <a href="qa_{variant}/validation.json">完整记录</a></li>')
perform=[]
for stage in ['before','after']:
    p=OUT/f'performance_{stage}.json'
    if p.exists():
        d=json.loads(p.read_text(encoding='utf-8'))
        perform.append('<tr><td>'+stage+'</td>'+''.join(f'<td>{v["effective_fps"]:.1f} fps</td>' for v in d['views'])+'</tr>')
performance='<p>1600×900、4×MSAA、TAA、VSync 关闭，14 个生命元素和动画保持运行；每机位短时预热采样，不代表长时间游玩。</p><table><tr><th>版本</th><th>大道</th><th>一教</th><th>湖园</th><th>总览</th></tr>'+''.join(perform)+'</table>' if perform else ''
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>樱花大道 · 春日改造对照</title><style>body{max-width:1500px;margin:32px auto;padding:0 24px;background:#f4f2ec;color:#293d34;font:16px/1.7 system-ui}h1{font-size:32px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}figure{margin:0}img{width:100%;border-radius:8px}section{margin:36px 0}figcaption{margin-bottom:8px;color:#58665b}a{color:#346750}details{margin-top:16px}details img{max-width:1000px}summary{cursor:pointer}table{border-collapse:collapse}td,th{padding:8px 18px;border-bottom:1px solid #ced6cc}@media(max-width:800px){.pair{grid-template-columns:1fr}}</style><h1>樱花大道 · 春日环境升级</h1><p>在现有 campus 中增强花树、后排高树、低层植被、路侧铺装与轻微落花。保留原地图、建筑、双池、桥与14个生命元素。</p><p>下方为 Godot 原生 1920×1080 截图，点击查看原文件。前后机位与人物时间一致；光照使用各版本原有设置。</p>'''+''.join(cards)+'''<section><h2>概念方向（AI 生成，非实机截图）</h2><a href="../../references/sakura_avenue/concept/spring_direction_v1.png"><img loading="lazy" src="../../references/sakura_avenue/concept/spring_direction_v1.png"></a><p>概念图用于空间、配色、树冠与地面细节参考；实机效果以上方截图为准。<a href="../../references/sakura_avenue/index.html">10张真实参考照片</a> · <a href="../../references/sakura_avenue/concept/prompt.txt">ImageGen提示词</a></p></section><section><h2>验证</h2><ul>'''+''.join(checks)+'''<li><a href="preservation.json">已有资产与地图数据哈希检查</a></li></ul>'''+performance+'''</section><p>启动 campus/OPEN_SAKURA.cmd 进入当前大道；1 切换大道机位，P 从老北门步行，[ / ] 切换其他机位。<a href="../../docs/SAKURA_AVENUE_UPGRADE.md">实现与范围说明</a></p></html>'''
paint='''<section><h2>莫奈方向 · 实际材质贴图</h2><p>内置 ImageGen 生成一张四分区底色图，分别用于石材、树皮、绿叶和花瓣。按场景米制尺寸投射到表面，保留真实光照、粗糙度与原有细微法线；不是屏幕油画滤镜。</p><div class="pair"><figure><figcaption>同一批新模型 · 加笔触前</figcaption><a href="unpainted_live/03_layering.png"><img src="unpainted_live/03_layering.png"></a></figure><figure><figcaption>同一批新模型 · 莫奈方向贴图后</figcaption><a href="after_live/03_layering.png"><img src="after_live/03_layering.png"></a></figure></div><details><summary>查看实际使用的四分区纹理图与提示词</summary><img src="../../godot/assets/textures/sakura_monet_atlas_v1.png"><p><a href="../../references/sakura_avenue/concept/monet_texture_prompt.txt">完整生成提示词</a> · 生成输出实际为1254×1254，每格627×627。仅风格借鉴，未使用或复制具体画作。</p></details></section>'''
page=page.replace('<section><h2>大道纵深</h2>',paint+'<section><h2>大道纵深</h2>',1)
(OUT/'review.html').write_text(page,encoding='utf-8')
print(OUT/'review.html')
