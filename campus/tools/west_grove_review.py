import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
out=root/'renders/west_grove'
def read(name):return json.loads((out/name).read_text(encoding='utf-8'))
checks={name:read(name)['passed'] for name in ['qa/validation.json','people_validation.json','seams.json','preservation.json']}
assert all(checks.values()),checks
before,after=read('before_live/report.json'),read('after_live/report.json')
assert len(before['shots'])==len(after['shots'])==4
assert all(all(a[k]==b[k] for k in ['file','position','target','fov']) for a,b in zip(before['shots'],after['shots']))
parts=['''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>西侧林荫步道 · 两位学生</title><style>
body{margin:0;background:#eff2e9;color:#2b4137;font:16px/1.7 system-ui,sans-serif}main{max-width:1440px;margin:auto;padding:36px}h1{font-size:38px}a{color:#347861}.pair,.people{display:grid;grid-template-columns:1fr 1fr;gap:16px;margin:24px 0 44px}.people{grid-template-columns:repeat(3,1fr)}figure{margin:0;background:white}img{display:block;width:100%}figcaption{padding:12px}table{width:100%;border-collapse:collapse;background:white}td,th{padding:12px;border-bottom:1px solid #d8e2d4;text-align:left}p{max-width:1000px}@media(max-width:850px){main{padding:16px}.pair,.people{grid-template-columns:1fr}table{font-size:12px}td,th{padding:5px}}</style><main>
<h1>从西池，走向北边的树荫</h1><p>精细景观沿现有西侧步道向北推进：5棵树、36组花丛、18组岸草、2组石景。复用GIS路径与莫奈方向，保留草地空处和通行空间，没有新增地理底座。</p>
<p>两位普通学生加入其中：停步取景、低头查看手机；林下慢走、停读翻页、回转返回。复用已有普通学生模型，原14个人物/动物保留，新版共16实例。</p>
<p>入口：<b>OPEN_WEST_GROVE.cmd</b>。<a href="../../docs/WEST_GROVE.md">区域范围、角色说明与验证方式</a></p>
<p>18条连续路线、9项禁入、16人口与局部密度、树木接触检查通过。两位新学生274个完整周期动作采样通过；12,834个地面接缝采样零缺口；115份原资产/贴图/布局保持。</p>''']
for shot in after['shots']:
    parts.append('<h2>'+shot['file'].removesuffix('.png')+'</h2><div class="pair">')
    for stage,label in [('before','扩建前'),('after','扩建后 · Godot原生1920×1080')]:
        src=stage+'_live/'+shot['file'];parts.append(f'<figure><a href="{src}"><img loading="lazy" src="{src}" alt="{label}"></a><figcaption>{label}</figcaption></figure>')
    parts.append('</div>')
parts.append('<h2>动作阶段与人物近景</h2><p>完整循环由动画与位置采样验证；以下为12张关键阶段原生截图。当前为Ambient级模型，没有对话或主动避让系统。</p><div class="people">')
for shot in read('people/report.json'):
    src='people/'+shot['file'];parts.append(f'<figure><a href="{src}"><img loading="lazy" src="{src}" alt="{shot["id"]}"></a><figcaption>{shot["id"]} · {shot["time"]}秒 · {shot["state"]["phase"]}</figcaption></figure>')
parts.append('</div><h2>性能短采样</h2><p>1600×900、4×MSAA、TAA，VSync关闭，90帧预热、180帧采样。每格为 FPS / P95毫秒 / 窗口焦点占比，移动测试为小幅连续镜头移动。</p><table><tr><th>版本</th><th>步道</th><th>取景学生</th><th>慢读学生</th><th>总览</th></tr>')
controlled=True
for name in ['static_before_expansion','static','moving']:
    r=read(name+'.json');assert r['completed'] and r['resolution_verified']
    controlled=controlled and all(v['focus_fraction']==1 for v in r['views'])
    parts.append('<tr><td>'+name+'</td>'+''.join(f"<td>{v['effective_fps']:.1f} / {v['p95_frame_ms']:.1f} / {v['focus_fraction']:.0%}</td>" for v in r['views'])+'</tr>')
parts.append('</table><p>'+('采样窗口持续聚焦。' if controlled else '采样发生窗口焦点变化，不作为严格性能回归或稳定帧率结论。')+'短采样不代表完整校园持续运行。原有7个Texture RID退出释放警告仍存在。西侧建筑立面与部分近景人物细节仍可继续打磨。</p></main></html>')
(out/'review.html').write_text(''.join(parts),encoding='utf-8')
(out/'delivery.json').write_text(json.dumps({'passed':True,'checks':checks,'camera_pairs':4,'people_keyframes':12,'population':16,'performance_focus_controlled':controlled},indent=2),encoding='utf-8')
print(out/'review.html')
