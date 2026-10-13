"""Build the local character identity gallery from real proof captures.

No raster edits or rendering are performed. Face comparisons use CSS crops with
links to the complete source images. Re-run after capture/encoding to refresh
the evidence status and replace any pending placeholders.
"""
from pathlib import Path
import html
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "renders/tiku_identity"
REF = "../../../references/characters/tiku_boy1/"
OUT.mkdir(parents=True, exist_ok=True)


def esc(value):
    return html.escape(str(value), quote=True)


def read_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def figure(src, title, note="", tag="GODOT 实机", crop=None, eager=False):
    target = (OUT / src).resolve()
    image_html = '<div class="pending">此视角尚未生成。完成捕获后重新运行画廊脚本。</div>'
    if target.is_file():
        image_html = f'<img src="{esc(src)}" alt="{esc(title)}" loading="{"eager" if eager else "lazy"}">'
        if crop:
            x, y, w, h, source_w = crop
            style = f"aspect-ratio:{w}/{h};--image-width:{source_w / w * 100:.5f}%;--image-left:{-x / w * 100:.5f}%;--image-top:{-y / h * 100:.5f}%"
            image_html = f'<div class="crop" style="{style}">{image_html}</div>'
        image_html = f'<a class="image-link" href="{esc(src)}" target="_blank" title="打开完整原图">{image_html}</a>'
    return f'<figure><div class="tag">{esc(tag)}</div>{image_html}<figcaption><strong>{esc(title)}</strong><span>{esc(note)}</span></figcaption></figure>'


def video(src, poster, title, note, manifest_src):
    manifest = read_json(OUT / manifest_src)
    available = (OUT / src).is_file()
    if available:
        body = f'<video controls preload="metadata" poster="{esc(poster)}"><source src="{esc(src)}" type="video/mp4"></video>'
    else:
        body = '<div class="pending video-pending">完整循环视频正在生成；静态画面不替代动作验收。</div>'
    info = ""
    if manifest:
        fps, frames = manifest.get("fps", 0), manifest.get("frames", 0)
        duration = frames / fps if fps else 0
        info = f'{manifest.get("width", "?")} × {manifest.get("height", "?")} · {fps} fps · {frames} 帧 · {duration:g} 秒'
    return (f'<article class="video-card"><h3>{esc(title)}</h3>{body}<p>{esc(note)}</p>'
            f'<p class="meta">{esc(info)} <a href="{esc(manifest_src)}">捕获清单</a></p></article>')


def validation_html():
    report = read_json(OUT / "animation_validation.json")
    if not report:
        return '<p>动作验证报告待生成。这里不会由截图反推“完整循环已通过”。</p>'
    closure, road = report.get("loop_closure", {}), report.get("roadside_loop", {})
    coverage = report.get("state_coverage", {})
    status = lambda v: "通过" if v is True else "未通过" if v is False else "待验证"
    rows = [
        ("数值与状态检查", status(report.get("passed"))),
        ("采样姿态数", str(report.get("poses_checked", "待生成"))),
        ("长椅基础循环闭合", status(closure.get("closed"))),
        ("校服基础循环闭合", status(road.get("closed"))),
        ("思考 / 侧目 / 扶镜 / 翻页 / 疲劳覆盖", " / ".join(status(coverage.get(k)) for k in ["thinking", "side_eye", "glasses", "page", "fatigue"])),
    ]
    return ('<table><tbody>' + ''.join(f'<tr><th>{esc(k)}</th><td>{esc(v)}</td></tr>' for k, v in rows)
            + '</tbody></table><p class="meta">状态来自当前 <a href="animation_validation.json">animation_validation.json</a>。'
              '数值闭合检查不包含玩家经过触发的外部分支，也不等于服装变形与表演质量已经达到最终标准。</p>')


CSS = """
:root{color-scheme:light;--paper:#f0ede5;--ink:#273843;--muted:#61727a;--line:#d4d7d2;--blue:#315e75;--card:#faf9f5}
*{box-sizing:border-box}body{margin:0;background:var(--paper);color:var(--ink);font-family:Inter,Segoe UI,Microsoft YaHei,sans-serif}
main{max-width:1480px;margin:auto;padding:48px 30px 70px}a{color:var(--blue);text-underline-offset:4px}p{line-height:1.85;margin:12px 0;max-width:1100px}
.eyebrow{font-size:12px;letter-spacing:.20em;color:var(--muted);font-weight:600}h1{font-size:clamp(32px,4vw,56px);line-height:1.2;font-weight:650;margin:15px 0 18px}h2{font-size:27px;margin:0 0 14px}h3{font-size:18px;margin:0 0 16px}section{scroll-margin-top:90px;margin-top:58px}.lead{font-size:18px;max-width:1000px}
nav{position:sticky;top:0;z-index:20;background:#f0ede5f0;backdrop-filter:blur(12px);padding:16px 0;border-bottom:1px solid var(--line);display:flex;gap:24px;flex-wrap:wrap}nav a{font-size:13px;text-decoration:none;font-weight:600}
.hero{display:grid;grid-template-columns:1.6fr 1fr;gap:32px;margin-top:32px;align-items:center}.hero .aside{padding:8px 0}.hero h2{font-size:25px}.hero p{font-size:15px}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:18px}.two{grid-template-columns:repeat(2,minmax(0,1fr))}.four{grid-template-columns:repeat(4,minmax(0,1fr))}.five{grid-template-columns:repeat(5,minmax(0,1fr))}
figure{margin:0;border:1px solid var(--line);border-radius:12px;overflow:hidden;background:var(--card);position:relative}.tag{padding:10px 14px;font-size:10px;font-weight:700;letter-spacing:.10em;color:var(--muted);background:var(--card)}img{width:100%;display:block}.image-link{display:block;overflow:hidden;background:#dddcd2}.crop{position:relative;overflow:hidden;width:100%;background:#dddcd2}.crop img{position:absolute;width:var(--image-width);max-width:none;left:var(--image-left);top:var(--image-top);height:auto}.image-link img{transition:filter .16s}.image-link:hover img{filter:brightness(1.025)}figcaption{padding:14px 16px 17px}figcaption strong{display:block;font-size:14px;font-weight:600}figcaption span{font-size:12px;color:var(--muted);line-height:1.7;display:block;margin-top:5px}
.note{border-left:3px solid #89a1a4;padding:8px 18px;background:#e6ebe6;font-size:14px;margin:20px 0 25px}.meta{font-size:12px;color:var(--muted)}.pending{display:grid;place-items:center;min-height:240px;padding:30px;background:#e7e6de;color:var(--muted);line-height:1.8;text-align:center;font-size:13px}.video-pending{aspect-ratio:16/9;min-height:0}.video-card{background:var(--card);border:1px solid var(--line);padding:22px;border-radius:12px}.video-card p{font-size:14px}video{width:100%;display:block;background:#1b282e;border-radius:5px}.video-card .meta{font-size:12px}.section-intro{color:var(--muted);font-size:14px;margin-bottom:22px}
table{border-collapse:collapse;width:100%;font-size:14px;background:var(--card)}th,td{text-align:left;padding:14px 16px;border-bottom:1px solid var(--line);vertical-align:top}th{font-weight:600;width:34%}details{margin:22px 0;border:1px solid var(--line);border-radius:10px;background:var(--card);padding:16px}summary{cursor:pointer;font-size:14px;font-weight:600}details .grid,details>figure{margin-top:18px}.review{display:grid;grid-template-columns:1fr 1fr;gap:28px}.review p{font-size:14px}.review ul{padding-left:20px;font-size:14px;line-height:1.9}.sources{font-size:13px;line-height:1.9}.footer{margin-top:50px;padding-top:22px;border-top:1px solid var(--line);font-size:12px;color:var(--muted)}
@media(max-width:1050px){.four,.five{grid-template-columns:repeat(2,minmax(0,1fr))}.hero{grid-template-columns:1fr}.hero .aside{padding:0}.review{grid-template-columns:1fr}}@media(max-width:650px){main{padding:28px 16px 45px}.grid,.two,.four,.five{grid-template-columns:1fr}.hero{gap:18px}nav{gap:14px}h2{font-size:23px}section{margin-top:40px}.crop{max-height:680px}th{width:42%}}
"""

parts = [f'<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>做题家小伙 · 身份回归 / Godot 实机评审</title><style>{CSS}</style></head><body><main>',
         '<div class="eyebrow">USTC DIORAMA / CHARACTER IDENTITY PASS / 2026.09.08</div><h1>让设定图中的人，走进实机。</h1>',
         '<p class="lead">先修正长椅写字版的脸型、眼睛、眼镜、短发与衣领，再沿用同一头部制作蓝白校服变体。这里把概念稿、旧模型、Blender 建模证据与 Godot 实机放在一起核对。</p>',
         '<nav><a href="#identity">人物身份</a><a href="#bench">长椅版</a><a href="#uniform">校服变体</a><a href="#motion">完整动作</a><a href="#blender">Blender 证据</a><a href="#review">评审与限制</a></nav>',
         '<div class="hero">', figure('08_study.png', '长椅写字版 · 实际校园光照', '本子由腿部承托，一手固定、一手写字；长椅前没有桌子。', eager=True),
         '<div class="aside"><div class="eyebrow">ONE IDENTITY, TWO CAMPUS MOMENTS</div><h2>识别来自具体面貌。</h2><p>下颌角、颧颊转折和鼻唇体积重新塑形；窄眼与稀疏胡茬通过绘制面部底色保存，镜框、镜腿与发际线继续由三维几何承担。Godot 侧目直接改变脸部着色中的瞳孔位置。</p><p>设定稿标注约 6.5 头身；当前三维约 5.7 头身，保留成人瘦长体型与微缩场景可读性。这是有意的比例概括，尚非逐笔复刻。</p><p class="meta"><a href="../../docs/characters/TIKU_IDENTITY_REVIEW.md">本轮 Art Review / 实现与来源</a></p></div></div>',
         '<section id="identity"><h2>01 / 设定图 → 旧实机 → 新实机</h2><p class="section-intro">相近尺度的脸部对照。裁切只在本页 CSS 中显示，点击可看完整原图；没有把设定图重绘成“实机截图”。</p><div class="grid four">']
parts.append(figure(REF+'character_sheet.png', '已认可的角色设定', '窄长脸、克制半睁眼、矩形镜框与胡茬是身份基准。', 'CONCEPT · 设定图', (585,624,280,365,1517), True))
parts.append(figure('../tiku_boy1/05_neutral.png', '旧 Godot 模型', '光滑蛋形头、粗折线镜框、条形眼与规则胡须使身份泛化。', 'GODOT · 修改前', (580,255,760,1050,1920), True))
parts.append(figure('05_neutral.png', '新 Godot · 正面', '明确下颌与鼻唇，柔和面部绘制，镜框轮廓重新收敛。', 'GODOT · 当前', (580,255,760,1050,1920), True))
parts.append(figure('06_side_eye.png', '新 Godot · 侧目', '检查瞳孔方向、镜框遮挡与 3/4 视角下的身份保留。', 'GODOT · 当前', (580,255,760,1050,1920), True))
parts += ['</div><details><summary>展开完整设定稿与原始身份参考</summary><div class="grid two">',
          figure(REF+'character_sheet.png', '完整 Character Sheet', '内置 imagegen 基于用户主参考生成；包含多视图、坐姿、表情及色板。', 'CONCEPT'),
          figure(REF+'primary_reference.png', '用户主参考', '仅作为角色设计参考；原作者与使用许可尚未可靠确认。', 'USER REFERENCE'),
          '</div></details></section><section id="bench"><h2>02 / 先让长椅版身份成立</h2><p class="section-intro">先看脸部近景，再检查写字、扶镜与校园受光。衣服仍是受控关节分件，近景如实保留其当前限制。</p><div class="grid">']
for file, title, note in [
    ('10_study_side_eye_close','校园近景 · 短暂侧目','实际长椅实例，不是单独的概念表情图。'),
    ('08_study','坐姿 · 一手固定本子，一手写字','本子放在腿上，人物在同一校园世界受光。'),
    ('11_study_adjust_glasses','动作 · 扶一下眼镜','手从本子附近抬起，动作幅度克制。'),
    ('05_neutral','Godot 正面静态身份','与设定稿中性表情对照。'),
    ('07_thinking','Godot 3/4 表情核对','用于观察眼睛、鼻唇与下颌的空间关系。'),
    ('09_campus','校园中景','核对人物、长椅、道路和建筑的尺度关系。')]:
    parts.append(figure(file+'.png', title, note))
parts += ['</div><details><summary>展开 Godot 全身转面</summary><div class="grid four">']
for file, title in [('01_front','正面'),('02_three_quarter','3/4 面'),('03_side','侧面'),('04_back','背面')]:
    parts.append(figure(file+'.png',title,'约 5.7 头身，成年偏瘦比例。'))
parts += ['</div></details></section><section id="uniform"><h2>03 / 同一个人，蓝白校服变体</h2><p class="section-intro">同用 tiku_head.py、面部底色、眼镜和寸头几何；改变外套裁片、袖条、运动裤与持书站姿。校服是角色衣着变体，不声称是科大的官方校服。</p><div class="grid">']
for file,title,note in [('12_uniform_front','校服正面','白肩胸、蓝色下摆、中央拉链与袖部条带。'),('13_uniform_three_quarter','校服 3/4','核对外套体积和袖口，保持朴素宽松的运动服逻辑。'),('14_uniform_face','校服版面部','与主角色共用头部，不能因换装改变人物身份。')]:
    parts.append(figure(file+'.png',title,note))
parts += ['</div><div class="grid" style="margin-top:18px">']
for file,title,note in [('15_roadside_thinking','路边 · 夹书思考','左臂夹书，停在路缘附近；微型叙事不占用主路。'),('16_roadside_side_eye','路边 · 短暂侧目','眼睛先动，头部轻微跟随。'),('17_roadside_glasses','路边 · 轻推眼镜','右手抬起，左臂继续保持书本夹持。')]:
    parts.append(figure(file+'.png',title,note))
parts += ['</div><details><summary>展开相近视角的身份一致性与校服参考</summary><div class="grid">',
          figure('06_side_eye.png','主角色 · 面部','同一构建脚本。'), figure('14_uniform_face.png','校服变体 · 面部','共用脸部和镜框，仅服装及场景动作改变。'),
          figure(REF+'c63b2f20-14ae-4fdf-a269-07242beac118.png','用户已有蓝白校服参考','具体裁片、翻领和条带的视觉依据。','USER REFERENCE'), '</div></details></section>',
          '<section id="motion"><h2>04 / 两段完整、低强度动作循环</h2><p class="section-intro">以下视频直接来自 Godot 逐帧视口。无配音；数值闭合与视觉审查分开记录。</p><div class="grid two">',
          video('campus_life_demo.mp4','08_study.png','长椅 · 写题、思考、侧目、扶镜','写题中停笔，抬眼观察，扶镜后回到本子；低频翻页和疲劳动作穿插其中。','motion_manifest.json'),
          video('roadside/campus_life_demo.mp4','15_roadside_thinking.png','路边 · 夹书、换重心、侧目、扶镜','左臂保持持书关系，身体缓慢换重心；抬头、侧目与扶镜之间留有停顿。','roadside/motion_manifest.json'),
          '</div><details open><summary>查看当前验证结果</summary>',validation_html(),'</details></section>',
          '<section id="blender"><h2>05 / 建模阶段证据</h2><p class="section-intro">直接打开生产 .blend，用 EEVEE 渲染同一模型及材质。影棚只添加相机、灯光、地面，并暂时隐藏书与笔；不使用只为截图制作的替代脸。</p><h3>长椅角色 · 静态生产资产</h3><div class="grid five">']
blender_shots = [('01_front','正面'),('02_three_quarter','3/4 面'),('03_side','侧面'),('04_face_front','正面近景'),('05_face_three_quarter','3/4 近景')]
for file,title in blender_shots:
    parts.append(figure('blender/'+file+'.png',title,'1200 × 1500 · EEVEE','BLENDER'))
parts += ['</div><p class="meta"><a href="blender/manifest.json">长椅版影棚相机与渲染参数</a></p><h3 style="margin-top:28px">校服变体 · 静态生产资产</h3><div class="grid five">']
for file,title in blender_shots:
    parts.append(figure('blender_uniform/'+file+'.png',title,'1200 × 1500 · EEVEE','BLENDER'))
parts += ['</div><p class="meta"><a href="blender_uniform/manifest.json">校服版影棚相机与渲染参数</a></p></section>',
          '<section id="review"><h2>06 / Art Review 与未完成部分</h2><div class="review"><div><h3>本轮解决的身份偏差</h3><ul><li>从均匀椭圆改为有颧颊转折、下颌角和短平下巴的头部。</li><li>用连续面部造型与绘制底色保存眼睑、鼻唇和不规则胡茬。</li><li>镜框从粗多边形收敛为较薄的横向圆角矩形，寸头包覆鬓角和后脑。</li><li>缩短白领、收敛肩宽，保留浅蓝衫与朴素长裤的组合。</li><li>校服变体共用同一人物头部，不重新抽象成通用低模学生。</li></ul></div><div><h3>仍需继续精修</h3><ul><li>肩肘仍有分件与刚性转折感，尚未达到连续蒙皮衣服的变形质量。</li><li>短发侧面的局部接缝与头皮衔接仍可见，近景需要进一步处理。</li><li>设定图约 6.5 头身，三维约 5.7 头身；轮廓与笔触并非逐笔一致。</li><li>手指不是逐指完整绑定，书页与笔的接触依靠有限的程序约束。</li><li>本轮是人物身份和实机可读性的明显提升，不宣称动画电影最终成片。</li></ul></div></div>',
          '<div class="note">内部近景审查先通过长椅版的身份方向，再生成校服变体。最终审美判断请同时看近景、全身、真实坐姿和完整循环；“有模型、有动画”不能代替人物身份验收。</div>',
          '<details><summary>来源与使用边界</summary><div class="sources"><p>面部底色 <a href="../../godot/assets/textures/tiku_face_albedo.png">tiku_face_albedo.png</a> 由内置 imagegen 基于已认可的设定稿生成，作为投影 UV 面部纹理；不是从网络人物照片裁出的脸。镜框、头发、鼻唇和下颌保持三维体积。<a href="'+REF+'face_albedo_prompt.txt">面部底色生成提示词</a></p><p>校服补充研究：<a href="https://www.hf168.net/col8/37580">合肥一六八中学校服介绍</a>与<a href="https://www.bjcpez.com/CampusDynamics/info/14564">昌平二中数学竞赛学生站姿页面</a>。两页文字已访问，原照片请求超时，未作近看结论。具体衣着裁片依据用户本地校服图，腋下夹书站姿为原创动作设计。未下载或把这些官方照片直接用作游戏纹理；不复制真实学生身份或学校徽记。</p></div></details></section>',
          '<p class="footer">静态设计图、Blender 渲染和 Godot 实机均分别标记。页面由 campus/tools/tiku_identity_review.py 生成，原图没有为对照而改写。<br><a href="../../docs/characters/TIKU_IDENTITY_REVIEW.md">完整审查记录</a> · <a href="../../docs/characters/TIKU_BOY.md">上一版 Character Bible（历史状态）</a></p></main></body></html>']

(OUT / "review.html").write_text(''.join(parts), encoding="utf-8")
expected = [OUT/(x+'.png') for x in ['01_front','02_three_quarter','03_side','04_back','05_neutral','06_side_eye','07_thinking','08_study','09_campus','10_study_side_eye_close','11_study_adjust_glasses','12_uniform_front','13_uniform_three_quarter','14_uniform_face','15_roadside_thinking','16_roadside_side_eye','17_roadside_glasses']]
print(json.dumps({"gallery":str(OUT/'review.html'),"godot_shots_available":sum(p.is_file() for p in expected),"godot_shots_expected":len(expected),"bench_video":(OUT/'campus_life_demo.mp4').is_file(),"roadside_video":(OUT/'roadside/campus_life_demo.mp4').is_file()},ensure_ascii=False))
