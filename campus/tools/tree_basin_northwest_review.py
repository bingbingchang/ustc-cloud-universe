import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
out = root / 'renders/tree_basin_northwest'
def read(name):
    return json.loads((out / name).read_text(encoding='utf-8'))

before, after = read('before_live/report.json'), read('after_live/report.json')
assert len(before['shots']) == len(after['shots']) == 4
for a, b in zip(before['shots'], after['shots']):
    assert all(a[k] == b[k] for k in ('file', 'position', 'target', 'fov'))
checks = {name: read(name)['passed'] for name in ['basin_validation_campus_performance.json', 'basin_validation_diorama.json', 'qa/validation.json', 'seams.json', 'preservation.json']}
assert all(checks.values()), checks
parts = ['''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>樱花大道树池修复 · 西北湖岸延伸</title><style>
body{margin:0;background:#edf0e7;color:#293f34;font:16px/1.75 system-ui,sans-serif}main{max-width:1500px;margin:auto;padding:36px}h1{font-size:36px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin:18px 0 40px}figure{margin:0;background:white}img{width:100%;display:block}figcaption{padding:12px}a{color:#347760}table{width:100%;border-collapse:collapse;background:white}td,th{padding:12px;text-align:left;border-bottom:1px solid #d4ddcf}p{max-width:1000px}@media(max-width:850px){.pair{grid-template-columns:1fr}main{padding:16px}}</style><main>
<h1>让树木真正长在树池里</h1><p>旧边框与后来种植的树木分别使用两套间距，造成错位。本轮保留树木定位，清除旧边框，按实际根部大小与树的位置生成8个树池，并清开框内灌草。</p>
<p>双击 <b>OPEN_TREE_BASIN_REVIEW.cmd</b> 从树池近景开始，按 ] 查看西北湖岸。<a href="../../docs/TREE_BASINS_AND_NORTHWEST.md">实现与防复发规范</a></p>
<p>近地504个树根顶点均在方框内，Live与Diorama均通过；边框与树干使用同一中心。路线、碰撞与人物检查通过，12,834个接缝样点无缺口，115份既有资产/贴图/布局保持。</p>''']
labels = ['树池与根部', '南段树列', '西北岸人高视角', '西北湖岸总览']
for label, shot in zip(labels, after['shots']):
    parts.append(f'<h2>{label}</h2><div class="pair">')
    for stage, caption in [('before', '修改前 · 本轮原生归档'), ('after', '修改后 · 当前原生画面')]:
        src = stage + '_live/' + shot['file']
        parts.append(f'<figure><a href="{src}"><img loading="lazy" src="{src}" alt="{caption}"></a><figcaption>{caption}</figcaption></figure>')
    parts.append('</div>')
parts.append('<h2>西池北岸—西北角继续细化</h2><p>新增2树、27花丛、17岸草组、56芦苇组、60荷叶群与3石组。沿现有GIS水岸延续已认可的莫奈方向，保留开阔水面与通行开口；本次没有新增地理底座。西侧建筑重复立面仍是后续精修项。</p><h2>性能短采样 · FPS / P95毫秒 / 焦点占比</h2><p>1600×900、4×MSAA、TAA，14个生命元素与动画保留。每机位90帧预热、180帧采样；移动为小幅连续相机移动。性能“扩建前”已包含树池修复，只停用新西北岸，不与历史测试跨轮比较。</p><table><tr><th>测试</th><th>树池近景</th><th>树列</th><th>西北岸</th><th>总览</th></tr>')
for name, label in [('static_before_expansion', '扩建前静止'), ('moving_before_expansion', '扩建前移动'), ('static', '扩建后静止'), ('moving', '扩建后移动')]:
    r = read(name + '.json')
    assert r['completed'] and r['resolution_verified']
    # Focus changes invalidate strict cross-run conclusions; expose them rather than hide them.
    parts.append('<tr><td>' + label + '</td>' + ''.join(f"<td>{v['effective_fps']:.1f} / {v['p95_frame_ms']:.1f} / {v['focus_fraction']:.0%}</td>" for v in r['views']) + '</tr>')
parts.append('</table><p>本轮存在窗口焦点切换，采样条件未完全一致；表中数据仅供诊断，不用于稳定帧率或严格扩建损耗结论。短采样不是完整校园持续运行承诺。7个Texture RID退出释放警告仍存在。原始JSON及日志与本页同目录保存。</p></main></html>')
(out / 'review.html').write_text(''.join(parts), encoding='utf-8')
(out / 'delivery.json').write_text(json.dumps({'passed': True, 'camera_pairs': 4, 'checks': checks, 'native_resolution': after['resolution'], 'performance_controlled_comparison_passed': False, 'performance_limitation': 'Window focus changed during sampling; do not claim stable FPS or strict regression result.'}, indent=2), encoding='utf-8')
print(out / 'review.html')
