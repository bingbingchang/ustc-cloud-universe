"""Build a review page from native captures and completed benchmark reports."""
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'renders/performance_upgrade'

def read(path):
    return json.loads(path.read_text(encoding='utf-8'))

labels = {'composition': '亭桥构图', 'water_edge': '东池水边', 'south_bank': '东池南岸', 'overview': '东池总览', 'west_lake': '西池南岸'}
cases = ['baseline', 'no_reflection', 'no_ssil', 'no_trees', 'lod_only', 'reflection_only', 'optimized', 'baseline_motion', 'optimized_motion', 'expanded', 'expanded_motion']
reports = {name: read(OUT / (name + '.json')) for name in cases}
assert all(r['completed'] and r['resolution_verified'] for r in reports.values())
assert all(v['focus_fraction'] == 1 for r in reports.values() for v in r['views'])
rows = []
for name, report in reports.items():
    rows.append([name] + [f"{v['effective_fps']:.1f}" for v in report['views']])

page = ['''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>校园性能与西池扩建 · 实机对照</title><style>
body{margin:0;background:#edf1e9;color:#263c35;font:16px/1.7 system-ui,sans-serif}main{max-width:1500px;margin:auto;padding:36px}h1{font-size:36px}h2{margin-top:56px}a{color:#28695b}table{border-collapse:collapse;width:100%;background:white}td,th{padding:10px 16px;text-align:left;border-bottom:1px solid #dce4db}figure{margin:0}figcaption{padding:10px;background:white}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin:20px 0 36px}img{display:block;width:100%;height:auto}p{max-width:1000px}.tag{font-size:13px;letter-spacing:2px;color:#627961}code{background:#dce6dc;padding:3px} @media(max-width:850px){main{padding:20px}.pair{grid-template-columns:1fr}table{font-size:12px}td,th{padding:6px}}
</style><main><div class="tag">USTC EAST CAMPUS / NATIVE GODOT CAPTURES</div>
<h1>把性能余量留给下一片校园</h1>
<p>保留莫奈方向的光色、14个生命元素与景物布局，加入离线LOD、24米空间批次与静止相机倒影复用。新入口：<code>OPEN_CAMPUS_OPTIMIZED.cmd</code>，原湖园入口也已接入。</p>
<p><a href="../../docs/PERFORMANCE_STANDARD.md">性能规范与官方依据</a> · <a href="../../docs/PERFORMANCE_RESULTS.md">完整测量与限制</a> · <a href="../../docs/EAST_CAMPUS_ROADMAP.md">完整东区推进表</a></p>
<h2>同轮短采样 · FPS</h2><p>RTX 5060 Ti，1600×900，4×MSAA + TAA，VSync关闭。每机位90帧预热、180帧采样。moving为小幅连续移动相机；expanded包含新增西池。诊断关闭效果的版本不作为交付。</p>
<table><tr><th>测试</th><th>亭桥</th><th>东池水边</th><th>东池南岸</th><th>东池总览</th><th>西池南岸</th></tr>''']
for row in rows:
    page.append('<tr>' + ''.join('<td>' + html.escape(x) + '</td>' for x in row + ['—'] * (6-len(row))) + '</tr>')
page.append('</table><p>同轮优化对照不含西池新增内容。历史23–30帧不用于计算本轮收益。短采样不能代表完整东区持续游玩性能。</p>')

def pairs(folder, title, before_label, after_label):
    page.append('<h2>' + title + '</h2>')
    r = read(ROOT / folder / 'after_live/report.json')
    for shot in r['shots']:
        file = shot['file']
        rel = '.' if folder == 'renders/performance_upgrade' else '../west_lake'
        page.append('<p>' + html.escape(file) + '</p><div class="pair">')
        for stage, label in [('before', before_label), ('after', after_label)]:
            src = f'{rel}/{stage}_live/{file}'
            assert (ROOT / folder / (stage + '_live') / file).exists()
            page.append(f'<figure><a href="{src}"><img loading="lazy" src="{src}" alt="{html.escape(label)}"></a><figcaption>{html.escape(label)}</figcaption></figure>')
        page.append('</div>')

pairs('renders/performance_upgrade', '11组原生画面 · 优化前后', '优化前，同一内容', '优化后，布局与可见实例数量一致')
page.append('<p>远景叶片经过LOD简化，水波、树叶和角色处于不同动画时刻，图片不应逐像素相同。近景构图、树冠主要色块、建筑和水面关系保留。</p>')
pairs('renders/west_lake', '西池 · 南岸、桥头与水面群落', '扩建前，已启用性能优化', '扩建后，4树 / 30花丛 / 122荷叶群 / 2石组')
page.append('<p>本轮复用已有眼镜湖参考和莫奈概念方向，保持GIS湖岸、桥和道路。新增的是现有区域精细内容；没有新造测绘范围。西岸背景建筑立面仍重复、部分岸线过直，是后续精修项。</p><p>技术检查：17条路线、9项禁入、148棵树的接触验证通过；12,834个接缝采样零缺口；115份原资产、贴图、布局哈希保持。全校流式加载与长时间穿区压力测试尚未实现。</p></main></html>')
(OUT / 'review.html').write_text(''.join(page), encoding='utf-8')
print(OUT / 'review.html')
