"""Read native captures; never retouch images or substitute concept pixels."""
from pathlib import Path
import json, html

root = Path(__file__).resolve().parents[1]
out = root / 'renders/lake_garden_expanded'
before = json.loads((out/'before_live/report.json').read_text())
after = json.loads((out/'after_live/report.json').read_text())
assert len(before['shots']) == len(after['shots']) == 11
for a,b in zip(before['shots'], after['shots']):
    assert all(a[k] == b[k] for k in ['file','position','target','fov'])
    assert (out/'before_live'/a['file']).is_file() and (out/'after_live'/b['file']).is_file()
qa = json.loads((out/'qa/validation.json').read_text())
preserved = json.loads((out/'preservation.json').read_text())
labels = ['亭桥主构图','东岸低机位','东桥看亭','亭内反看东岸','樱花路看湖','空间总览','东岸花石','南岸疏林','樱花接湖','北岸桥头','东桥入口']
rows = []
for s,label in zip(after['shots'], labels):
    name = s['file']
    rows.append(f'''<section><h2>{label}</h2><div class="pair">
    <figure><figcaption>扩展前样段 · 相同机位</figcaption><a href="before_live/{name}"><img loading="lazy" src="before_live/{name}"></a></figure>
    <figure><figcaption>连续湖园 · 原生实机</figcaption><a href="after_live/{name}"><img loading="lazy" src="after_live/{name}"></a></figure></div>
    <p class="meta">位置 {html.escape(s['position'])} · 目标 {html.escape(s['target'])} · FOV {s['fov']}°</p></section>''')
perf = ''
if (out/'performance_after.json').exists():
    p = json.loads((out/'performance_after.json').read_text())
    perf = '<p>性能：<a href="performance_before.json">上一版原始报告</a> · <a href="performance_after.json">样段原始报告</a>。短时普通窗口采样，不能代替持续游玩测试。</p>'
page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>东池 · 连续湖园</title><style>
body{margin:0;background:#eef0e7;color:#243e38;font:16px/1.75 system-ui,sans-serif}main{max-width:1440px;margin:auto;padding:36px}h1{font-size:32px}h2{font-size:22px;margin-top:40px}p{max-width:1050px}a{color:#356254}.status{padding:16px 22px;background:#fff4da;border-left:5px solid #9c763e}.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}figure{margin:0}img{display:block;width:100%;height:auto;border-radius:5px}figcaption{padding:8px 0}.meta{font-size:13px;color:#61716b}.concept{max-width:1000px}section{margin:32px 0}li{margin:8px 0}@media(max-width:800px){main{padding:18px}.pair{grid-template-columns:1fr}}
</style><main><h1>东池 · 连续湖园</h1>
<p class="status"><b>按用户认可的莫奈方向扩展：东岸、南岸、樱花接湖处，以及北岸桥头和东桥入口。</b><br>判断依据是实际画面与概念图的空间、主次、光色和疏密关系。物件数量、贴图生效和物理通过不代表美术通过。</p>
<p>本轮在此前亭桥样段基础上，用五段疏密不同的花灌木、石草与中小树扩展连续湖岸。前后对照均保留此前垂柳、亭桥与倒影，仅对比本轮扩展。地图、建筑、亭桥位置和现有人物沿用。<a href="../../docs/ART_SCENE_WORKFLOW.md">标准与实现说明</a></p>
<h2>目标概念图 · AI生成参考，不是实机</h2><figure class="concept"><a href="../../references/yijian_garden/concept/direction_v1.png"><img src="../../references/yijian_garden/concept/direction_v1.png"></a><figcaption>沿用上一轮概念，不修改目标来迁就当前模型。</figcaption></figure>
<h2>当前判断</h2><ul><li>主机位中，浅色亭桥、深色树林与水面倒影的关系较上一版明确。</li><li>临水柳枝已进入前景，新增花灌木与不规则石组；岸线和树冠的重复感、水面的碎光与色彩交融仍需继续打磨。</li><li>东桥及反向视角仍有空旷处；不能只凭主视角宣布通过。</li></ul>
<p>以下全部为1920×1080原生渲染，无AI修图。左右机位、目标、FOV逐项核对一致；点击图片查看原图。</p>
''' + '\n'.join(rows) + f'''<h2>技术验证，单独记录</h2><p>原生检查：{'通过' if qa['passed'] else '未通过'}，8组条件；既有文件保护：{preserved['checked_files']}个文件，{'通过' if preserved['passed'] else '未通过'}。</p><p><a href="qa/validation.json">完整检查</a> · <a href="qa/runtime_qa.json">17路线、9禁入及网格接触</a> · <a href="preservation.json">文件保护</a></p>{perf}<p>运行入口：campus/OPEN_LAKE_GARDEN.cmd。原亭桥样段及旧湖园入口分别保留；扩展仍保留树冠重复感与水面色彩待改进的记录。</p></main></html>'''
(out/'review.html').write_text(page,encoding='utf-8')
(out/'comparison_validation.json').write_text(json.dumps({'eleven_matching_cameras': True,'native_capture': True,'art_accepted_for_expansion':False},indent=2))
print(out/'review.html')
