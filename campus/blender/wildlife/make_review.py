"""Gallery assembled from untouched native Godot evidence."""
import json,html
from pathlib import Path
CAMPUS=Path(__file__).resolve().parents[2]
OUT=CAMPUS/'renders'/'wildlife'
capture=json.loads((OUT/'capture_report.json').read_text(encoding='utf-8'))
qa=json.loads((OUT/'validation.json').read_text(encoding='utf-8'))
assets=json.loads((CAMPUS/'godot'/'wildlife'/'assets'/'manifest.json').read_text(encoding='utf-8'))
labels={
 '01_cat_front.png':'狸花猫 · 正面','02_cat_side.png':'狸花猫 · 侧面','03_cat_walk.png':'狸花猫 · 脚步',
 '04_cat_sit.png':'狸花猫 · 坐姿','05_cat_rest.png':'狸花猫 · 趴卧','06_cat_lick.png':'狸花猫 · 舔爪',
 '07_mallard_male.png':'绿头鸭 · 公鸭','08_mallard_female.png':'绿头鸭 · 母鸭',
 '09_sparrow_front.png':'树麻雀 · 近景','10_sparrow_side.png':'树麻雀 · 侧面','11_sparrow_wings.png':'树麻雀 · 展翅',
 '16_squirrel_front.png':'灰松鼠 · 近景','17_squirrel_walk.png':'灰松鼠 · 走路','18_squirrel_forage.png':'灰松鼠 · 觅食',
 '19_hedgehog_front.png':'刺猬 · 近景','20_hedgehog_walk.png':'刺猬 · 走路','21_hedgehog_hide.png':'刺猬 · 缩头',
 '13_cat_rear.png':'狸花猫 · 背面','14_mallard_side.png':'绿头鸭 · 侧面','15_mallard_preen.png':'绿头鸭 · 理羽',
}
cards=''.join(f'<figure><a href="{r["file"]}"><img src="{r["file"]}" loading="lazy" alt="{labels.get(r["file"],r["file"])}"></a><figcaption><b>{labels.get(r["file"],r["file"])}</b><span>{html.escape(r["asset"])} · {html.escape(r["clip"])} · {r["time"]}s</span></figcaption></figure>' for r in capture['shots'])
rows=''.join(f'<tr><td>{a["asset"]}</td><td>{a["bones"]}</td><td>{a["triangles"]:,}</td><td>{len(a["clips"])}</td></tr>' for a in assets['assets'])
passed=sum(c['passed'] for c in qa['checks'])
performance=''
if (OUT/'performance.json').exists():
    perf=json.loads((OUT/'performance.json').read_text(encoding='utf-8'))
    details=' · '.join(f'{v["view"]} {v["median_frame_ms"]:.2f}ms' for v in perf['views'])
    performance=f'<p>首批六个动物的性能记录：1600×900，{perf["gpu"]}，实时动画。帧时间中位数：{details}。窗口焦点情况见性能记录。</p>'
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>校园小动物 · 实机交付</title><style>
*{box-sizing:border-box}body{margin:0;background:#e9e9dc;color:#283a30;font:16px/1.65 "Microsoft YaHei",sans-serif}main{max-width:1250px;margin:auto;padding:46px 30px}h1{font-size:38px;line-height:1.2;margin:8px 0 18px}h2{font-size:24px;margin-top:36px}p{max-width:900px}a{color:#355b45}video{width:100%;border-radius:12px;background:#222}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:22px}figure{margin:0;background:#f9f8ef;border-radius:12px;overflow:hidden}img{width:100%;display:block}figcaption{padding:14px 18px}figcaption span{display:block;color:#67756b;font-size:13px}table{border-collapse:collapse;width:100%;background:#f9f8ef}td,th{padding:12px;text-align:left;border-bottom:1px solid #dbded0}.badge{display:inline-block;padding:6px 14px;background:#d2ddc4;border-radius:25px;font-size:14px}@media(max-width:720px){.grid{grid-template-columns:1fr}main{padding:24px 16px}h1{font-size:29px}}</style><main>
<span class="badge">Godot 原生画面 · 五类动物</span><h1>校园里的小动物</h1><p>狸花猫、绿头鸭、麻雀、灰松鼠、刺猬。新增松鼠与刺猬复用 Poly by Google 的开放许可模型，补绑定、基础动作与生活行为。试验场共八个动物，正式校园布置交给重建会话。</p>
<p><a href="../../docs/WILDLIFE_ASSETS.md">接入说明</a> · <a href="validation.json">行为与动画检查</a> · <a href="performance.json">性能记录</a></p>
<h2>新增松鼠与刺猬</h2><video controls preload="metadata" poster="16_squirrel_front.png" src="second_batch_demo.mp4"></video><p>20秒 / 1600×900 / 24fps。两种动物真实移动、觅食、观察、嗅探及缩头动作。原模型：Poly by Google，CC BY 3.0，<a href="https://poly.pizza/m/2WqY_AFEn-M">松鼠来源</a> · <a href="https://poly.pizza/m/8UNni5IvK_c">刺猬来源</a>；新增绑定、动作与刺猬背部纹理。</p><h2>首批实机动画与日常活动</h2><video controls preload="metadata" poster="12_lab_overview.png" src="wildlife_demo.mp4"></video><p>56秒 / 1600×900 / 24fps。首次动作演示，麻雀脸部为修改前版本；下方近景已更新为当前模型。</p>
<h2>资产</h2><table><tr><th>模型</th><th>骨骼</th><th>三角面</th><th>动作</th></tr>'''+rows+f'''</table><p>自动检查 {passed}/{len(qa['checks'])} 通过，包含120秒模拟行为、脚掌支撑、连续路线、水域约束、栖点到达和接近后的恢复。</p>'''+performance+'''<h2>近景与关键姿态</h2><div class="grid">'''+cards+'''</div><h2>独立试验场</h2><figure><a href="12_lab_overview.png"><img src="12_lab_overview.png" loading="lazy"></a><figcaption>草地、铺装、浅岸、水面与栖点</figcaption></figure><p>双击校园目录中的 OPEN_ANIMALS.cmd。1/2/3 查看首批动物，5/6 查看松鼠与刺猬，Tab 查看下一个体，Space 播放动作，B 恢复日常行为，4 进入漫游并开启接近反应。</p></main></html>'''
(OUT/'review.html').write_text(page,encoding='utf-8')
print('WILDLIFE_REVIEW',OUT/'review.html')
