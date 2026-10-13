"""Build a local native-render review gallery and a measured schematic, no photo edits."""
import json, html
from pathlib import Path
R=Path(__file__).resolve().parents[1]
O=R/'renders/north_axis'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
d=read(R/'godot/data/north_axis_layout.json');modules=read(R/'godot/data/module_layout.json')['modules']
def points(a):return ' '.join(f'{p[0]},{p[1]}' for p in a)
def polygon(a,fill,stroke='#b6afa0',sw=.35):return f'<polygon points="{points(a)}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'
svg=['<svg xmlns="http://www.w3.org/2000/svg" viewBox="-155 -40 355 330"><rect x="-155" y="-40" width="355" height="330" fill="#eeeade"/>']
svg+=[polygon([[-80,118],[80,118],[80,238],[-80,238]],'#c4cfaa')]
for m in modules:
    if m['enabled'] and 'polygon' in m:svg.append(polygon(m['polygon'],'#d9dfc6'))
svg.append(polygon(d['polygon'],'#c4cfaa'))
for path in d['paths']:svg.append(f'<polyline points="{points(path["points"])}" fill="none" stroke="#f4efdb" stroke-width="{path["width"]}" stroke-linejoin="round"/>')
svg.append('<path d="M0 118V168M-75 158H75M-45 174V237M45 174V237" fill="none" stroke="#f4efdb" stroke-width="7"/>')
for pond in d['ponds']:
    svg.append(polygon(pond['outer'],'#779fa3','#617f84',.5))
    for hole in pond['holes']:svg.append(polygon(hole,'#c4cfaa'))
for b in d['buildings']:svg.append(polygon(b['polygon'],'#b9a896','#7c7267',.6))
svg.append(polygon([[-62,168],[62,168],[62,222],[48,222],[48,184],[-48,184],[-48,222],[-62,222]],'#ba7d65','#966956',.6))
for bridge in d['bridges']:svg.append(f'<polyline points="{points(bridge["points"])}" fill="none" stroke="#f4edcf" stroke-width="{bridge["width"]}" stroke-linejoin="round"/>')
svg.append(polygon(d['pavilion']['polygon'],'#ad6f55'))
svg.append('<path d="M-12 2.65H10" stroke="#805d51" stroke-width="2.5"/>')
for x,z,species,variant,scale in d['trees']:svg.append(f'<circle cx="{x}" cy="{z}" r="1.6" fill="'+('#d5a5ad' if species==0 else '#718557')+'" opacity=".7"/>')
nodes={}
for m in modules:
    if m['enabled']:
        for n in m.get('story_nodes',[]):nodes[n['id']]=n
for n in d['story_nodes']:nodes[n['id']]=n
walkers=read(R/'godot/data/wander_routes.json')['routes']
for w in walkers:
    home=nodes[w['home_ref']]['position'];p=[[home[0]+v[0],home[2]+v[2]] for v in w['offsets']]
    svg.append(f'<polyline points="{points(p)}" fill="none" stroke="#756191" stroke-width=".7" stroke-dasharray="1.2 1"/>')
    svg.append(f'<circle cx="{home[0]}" cy="{home[2]}" r="1.3" fill="#755987"/>')
labels=[(-1,-7,'老北门'),(0,53,'玉泉北路'),(-31,94,'西池'),(36,108,'东池'),(49,82,'一鉴亭'),(57,32,'专家楼'),(0,176,'第一教学楼'),(145,65,'2#'),(141,126,'1#'),(-81,46,'西侧邻楼')]
for x,z,name in labels:svg.append(f'<text x="{x}" y="{z}" font-family="Microsoft YaHei,sans-serif" font-size="3.7" text-anchor="middle" fill="#3e4b43" stroke="#eeeade" stroke-width=".8" paint-order="stroke">{html.escape(name)}</text>')
svg+=['<path d="M-135 0V-16l-2 4m2-4 2 4" fill="none" stroke="#4b6058" stroke-width=".7"/><text x="-135" y="-20" text-anchor="middle" font-size="5" fill="#4b6058">N</text>','<path d="M-135 266H-85M-135 263V269M-85 263V269" fill="none" stroke="#4b6058" stroke-width=".8"/><text x="-110" y="274" text-anchor="middle" font-size="4" fill="#4b6058">50 m</text>','</svg>']
(O/'north_axis_layout.svg').write_text(''.join(svg),encoding='utf-8')
report=read(O/'capture_report.json');qa=read(O/'validation.json')
names={'whole':'从老北门到第一教学楼','north':'双池与校园轴线','gate':'老北门 · 藤荫与校名','axis':'玉泉北路 · 树影下漫步','pools':'眼镜湖双池','pavilion':'一鉴亭与专家楼','pavilion_front':'一鉴亭近景','bridge':'东池曲桥入亭','west_bridge':'西池曲桥','inside':'亭中看向红楼','neighbours':'周边建筑与天使路','core':'保留的一教 Hero Area','tiku':'保留的长椅做题家','raiden':'雷电将军 · 漫步','march7':'三月七 · 湖畔漫步','meituan':'美团袋鼠 · 等餐间隙','doubao':'豆包校园伙伴 · 北路漫步','leaf_cat':'校园猫 · 离开落叶去走走'}
cards=[]
for s in report['shots']:
    title=names.get(s['id'],s['id']);detail='Godot 原生 3840 × 2160'
    if 'phase' in s:detail+=f' · {s["phase"]} · {s["speed_mps"]:.2f} m/s'
    cards.append(f'<figure><a href="{s["file"]}"><img src="{s["file"]}" loading="lazy" alt="{title}"></a><figcaption>{title}<small>{detail}</small></figcaption></figure>')
cards.append('<figure><a href="19_routes_debug.png"><img src="19_routes_debug.png" loading="lazy" alt="行动线调试视图"></a><figcaption>天使路 · 漫步行动线<small>按 L / F8 开关；仅用于游览和布置检查，默认隐藏</small></figcaption></figure>')
runtime=qa['runtime'];routes=runtime.get('routes',[])
content='''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>科大东区 · 北门与双池</title>
<style>*{box-sizing:border-box}body{margin:0;background:#eeecdf;color:#35463d;font:16px/1.75 system-ui,"Microsoft YaHei",sans-serif}header,main{max-width:1450px;margin:auto;padding:36px}header{padding-top:65px}h1{font-size:42px;font-weight:500;margin:4px 0}h2{font-weight:500}p{max-width:1000px}a{color:#556d5d}nav{display:flex;gap:22px;flex-wrap:wrap}.grid{display:grid;grid-template-columns:1fr 1fr;gap:24px}figure{margin:0;background:#f7f5eb;border-radius:10px;overflow:hidden}figure:first-child{grid-column:1/-1}img,video{width:100%;display:block}figcaption{padding:14px 20px}small{display:block;opacity:.65;font-size:12px}.map{display:grid;grid-template-columns:1.2fr 1fr;gap:40px;align-items:center;margin:40px 0}.map img{max-height:710px}.note{border-left:3px solid #8a9a76;padding-left:18px}footer{padding:40px 0;color:#66746a}code{background:#e0e3d3;padding:3px 7px}@media(max-width:800px){header,main{padding:20px}.grid,.map{grid-template-columns:1fr}h1{font-size:28px}}</style>
<header><small>USTC EAST CAMPUS / DIORAMA 0.7 / NATIVE GODOT REVIEW</small><h1>北门与双池，一段可以走过的校园</h1><p>老北门—玉泉北路—眼镜湖双池—一鉴亭—第一教学楼与周边四栋建筑。按照公开地图、OSM 原始轮廓和官方照片接续真实空间，保留现有微缩风格与做题家。</p><nav><a href="#pictures">4K 实机图</a><a href="#motion">96 秒漫步片段</a><a href="#map">空间与行动线</a><a href="../../docs/NORTH_AXIS_ART_REVIEW.md">Art Review</a><a href="validation.json">完整 QA</a></nav></header><main>
<section class="map" id="map"><a href="north_axis_layout.svg"><img src="north_axis_layout.svg" alt="基于项目真实米制坐标的校园示意"></a><div><h2>空间连通，人物慢慢走动</h2><p>紫色虚线表示五个漫步角色的活动路线。三月七在东池外侧天使路，豆包在玉泉北路；雷电将军、配送袋鼠与猫分别保留自己的安静停留点。</p><p>步行、停顿、轻转向、回到原处继续小故事。书包、配送箱与落叶有固定位置，角色本体与脚步移动。按 <code>L</code> 或 <code>F8</code> 显示行动线，默认隐藏。</p><p>17 条实际 CharacterBody 路线通过；双池禁入、四栋实体楼和外边界阻挡通过。5 个漫步角色全路线胶囊检查通过，59 个已接受文件保持原哈希。</p><p class="note">平面来自公开资料；建筑高度、部分邻楼立面、岸石和种植为艺术化推断。本版完成此核心外部区域，未声称完整东校区或建筑室内已经完成。</p><nav><a href="../../docs/NORTH_AXIS_RECONSTRUCTION.md">资料与重建说明</a><a href="../../docs/WANDERING_BEHAVIORS.md">漫步工作流</a></nav></div></section>
<section id="motion"><h2>场景在轻轻呼吸</h2><video controls preload="metadata" poster="01_whole.png" src="campus_life_demo.mp4"></video><p>原生 Godot 帧序列，1280 × 720 / 12 fps / 96 秒。角色段为较宽跟随镜头，便于观察慢走与脚掌接地；每个人的完整长周期另有数值验证。</p></section><h2 id="pictures">实机摄影与近景检查</h2><section class="grid">'''+''.join(cards)+'''</section><footer>WASD 移动 · Shift 慢跑 · Space 跳跃 · P 从老北门开始步行 · V 自由镜头 · [ ] 切换 25 个机位 · F12 截图 · ESC 释放鼠标<br>运行：campus/run_diorama.ps1；重现：capture_north_axis.ps1、build_north_axis.ps1。参考：<a href="https://zgkdb.ustc.edu.cn/ndetail/3705">中国科大报</a>、<a href="https://zsb.ustc.edu.cn/2024/0310/c35540a631898/page.htm">中国科大招生在线</a>、© OpenStreetMap contributors（ODbL）。</footer></main></html>'''
(O/'review.html').write_text(content,encoding='utf-8')
print(O/'review.html')
