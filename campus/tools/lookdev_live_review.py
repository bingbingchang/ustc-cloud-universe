"""Build an offline gallery from native Godot evidence; never edit images."""
from __future__ import annotations

import html
import hashlib
import json
import math
import struct
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "renders/lookdev_live"
WARNINGS: list[str] = []
FIELDS = {"camera": "相机变换", "fov": "FOV", "projection": "投影", "size": "正交尺寸", "time": "动作时间"}
SHOTS = {
    "01_hall": ("红砖与梧桐", "人高 / 建筑", "先看同一教室楼的墙体、窗框、檐口与细叶树影。两版主体尺寸没有整体缩放。"),
    "02_axis": ("走向一教", "人高 / 轴线", "道路、草地与校园纵深共用；比较冠层透空、远景和空气透视。"),
    "03_gate": ("老北门", "环境 / 北轴", "两版都接入本轮北轴建筑与道路；较高观察点用于检查门区结构。"),
    "04_bridge": ("从桥头看一鉴亭", "近人高 / 湖岸", "四桥、亭岛与水陆边界共用。比较树叶、反射与湖岸层次。"),
    "05_pavilion_front": ("亭前的一小段路", "环境 / 亭岛", "同一亭岛的植被与接触层次；不要将高位观察误认为人物眼高。"),
    "06_pools": ("双池空间关系", "附图 / 高位", "核对双池、岛孔与连接道路；高位构图作为空间补充。"),
    "07_tiku": ("仍是长椅上的做题家", "身份 / 近景", "保留已接受的脸型、镜框、服装与坐写动作；检查新光照是否改变身份。长椅前没有桌子。"),
    "08_photo": ("树下拍照的同学", "人口 / 原节点", "同一原校园摄影节点与模型，比较脸部受光、衣料与环境协调。"),
    "09_cyclist": ("慢慢骑过楼前", "人口 / 原节点", "自行车与原骑行机制共用，截图固定到相同动作时间。"),
    "10_reader": ("后院的一页书", "人口 / 静区", "原后院坐读保留，坐姿节点不被强行改成漫步者。"),
    "11_raiden": ("西南树荫漫步", "五位漫步 / 雷电将军", "共享身份 GLB 与实际迈步；光照和树叶外观来自两个表现入口。"),
    "12_march7": ("天使路上的取景", "五位漫步 / 三月七", "共享新北轴路线：慢走、停留、转身，再继续校园摄影。"),
    "13_meituan": ("离开箱边走一小圈", "五位漫步 / 美团袋鼠", "保温箱留在停靠点，角色独立慢走后返回原故事。"),
    "14_doubao": ("玉泉路边慢读", "五位漫步 / 豆包伙伴", "共用北轴路线与资料道具；官方头像参考、校园身体与动作由项目补全。"),
    "15_leaf_cat": ("猫也有自己的小路线", "五位漫步 / 校园猫", "四足小范围行走与停留，原落叶保持故事锚点。"),
    "16_whole": ("同一校园的两种观看方式", "附图 / 世界总览", "共用世界范围，LookDev 隐藏展示底座并添加不可游玩的远景衔接；地图没有因此扩大。"),
    "17_routes": ("行动路线调试", "附图 / 默认隐藏", "L 显示的紫色细带与箭头用于核对路线。两版正常画面均默认隐藏。"),
}
CHECK_NAMES = {
    "actual_visual_collision_alignment": "新模型与碰撞对齐",
    "fifty_nine_frozen_files": "59 项既有资源保护",
    "five_wanderers_and_clear_routes": "五位漫步及路线净空",
    "fourteen_population_and_density": "14 人口及局部密度",
    "land_water_and_core_regression": "草地 / 水体 / 原核心回归",
    "nine_forbidden_region_tests": "9 项禁入推入测试",
    "north_axis_evidence_untouched": "原北轴证据保持",
    "seventeen_actual_continuous_routes": "17 条真实连续步行",
}


def esc(value):
    return html.escape(str(value), quote=True)


def read_json(path):
    if not path.is_file():
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError) as exc:
        WARNINGS.append(f"{path.name} 暂时不可读：{type(exc).__name__}")
        return {}


def local_file(name, within=ROOT):
    path = (OUT / name).resolve()
    if path.is_relative_to(within.resolve()) and path.is_file():
        return Path(name).as_posix()
    return None


def link(name, title):
    return f'<a href="{esc(name)}">{esc(title)}</a>' if local_file(name) else ""


def status(value):
    if value is True:
        return '<span class="status good">报告通过</span>'
    if value is False:
        return '<span class="status bad">报告未通过</span>'
    return '<span class="status pending">尚待报告</span>'


def equal(a, b):
    if a is None or b is None:
        return False
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        return math.isclose(a, b, rel_tol=1e-9, abs_tol=1e-7)
    return a == b


def indexed_shots(report, prefix=""):
    found = {}
    for shot in report.get("shots", []):
        if not isinstance(shot, dict) or not isinstance(shot.get("file"), str):
            continue
        filename = prefix + shot["file"]
        if Path(filename).suffix.lower() != ".png" or not local_file(filename, OUT):
            continue
        found[Path(shot["file"]).stem] = dict(shot, local_file=filename)
    return found


def png_size(filename):
    """Read only the PNG IHDR header; preserve all source bytes."""
    try:
        with (OUT / filename).open("rb") as stream:
            header = stream.read(24)
        if header[:8] == b"\x89PNG\r\n\x1a\n" and header[12:16] == b"IHDR":
            return list(struct.unpack(">II", header[16:24]))
    except OSError:
        pass
    return None


def compare_reports(live_report, dio_report, live, dio):
    pairs = []
    for key in sorted(live.keys() & dio.keys()):
        a, b = live[key], dio[key]
        checks = {field: equal(a.get(field), b.get(field)) for field in FIELDS}
        checks["resolution"] = equal(live_report.get("resolution"), dio_report.get("resolution"))
        sizes = {"lookdev": png_size(a["local_file"]), "diorama": png_size(b["local_file"])}
        checks["actual_png_dimensions"] = sizes["lookdev"] == sizes["diorama"] == [3840, 2160]
        pairs.append({"id": a.get("id",key), "file":a["file"], "lookdev":a["local_file"], "diorama":b["local_file"], "checks":checks, "passed":all(checks.values()), "actual_resolution":sizes})
    all_keys = list(FIELDS) + ["resolution", "actual_png_dimensions"]
    checks = {key: bool(pairs) and all(pair["checks"][key] for pair in pairs) for key in all_keys}
    checks["seventeen_expected_pairs"] = set(live) == set(dio) == set(SHOTS)
    checks["all_reported_images_present"] = len(live) == len(live_report.get("shots",[])) and len(dio) == len(dio_report.get("shots",[])) and bool(pairs)
    result = {"passed":all(checks.values()), "checks":checks, "pair_count":len(pairs), "expected_pairs":17, "pairs":pairs,
              "reports_sha256":{name:hashlib.sha256((OUT/name).read_bytes()).hexdigest() for name in ["capture_report.json", "diorama_ab/capture_report.json"] if (OUT/name).is_file()},
              "method":"Read two capture reports and real PNG IHDR dimensions. Camera Transform3D strings are compared exactly; numeric values use rel_tol 1e-9 / abs_tol 1e-7. No image edits or pixel similarity claim.",
              "scope":"Equal cameras/animation sample times/resolution do not mean identical materials, sun or pixels; those are the intentional art variables.",
              "created_local":datetime.now().isoformat(timespec="seconds")}
    (OUT / "comparison_validation.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    return result


def short(value):
    if isinstance(value, float):
        return f"{value:.6g}"
    return "未记录" if value is None else str(value)


def comparison_card(key, live, dio, live_report, dio_report, eager=False):
    title, category, caption = SHOTS.get(key, (key, "Godot 实际捕获", "由两份 capture_report.json 登记。"))
    rows, matching = [], []
    for field, label in FIELDS.items():
        a, b = live.get(field), dio.get(field)
        same = equal(a, b)
        matching.append(same)
        rows.append(f'<tr><th>{label}</th><td>{esc(short(a))}</td><td>{esc(short(b))}</td><td class="{"good" if same else "bad"}">{"相等" if same else "缺失 / 不同"}</td></tr>')
    size_equal = equal(live_report.get("resolution"), dio_report.get("resolution"))
    matching.append(size_equal)
    rows.append(f'<tr><th>输出像素</th><td>{esc(live_report.get("resolution", "未记录"))}</td><td>{esc(dio_report.get("resolution", "未记录"))}</td><td class="{"good" if size_equal else "bad"}">{"相等" if size_equal else "缺失 / 不同"}</td></tr>')
    summary = "6 项捕获参数相等" if all(matching) else "存在缺失或不同参数：请先查记录"
    load = "eager" if eager else "lazy"
    camera_details = f'FOV {short(live.get("fov"))}° · t={short(live.get("time"))} s · {"透视" if live.get("projection") == 0 else "正交" if live.get("projection") == 1 else "其他投影"}'
    markup = f'''<article class="pair" id="{esc(key)}">
<div class="pair-heading"><div><span class="eyebrow">{esc(key[:2])} / {esc(category)}</span><h3>{esc(title)}</h3></div><small>{esc(camera_details)}</small></div>
<div class="compare" style="--split:50%" data-pair="{esc(key)}">
  <div class="stage" aria-label="{esc(title)}，左侧 LookDev Live，右侧 Diorama">
    <img class="base" src="{esc(dio['local_file'])}" alt="Diorama · {esc(title)}" loading="{load}" decoding="async" width="3840" height="2160" draggable="false">
    <img class="overlay" src="{esc(live['local_file'])}" alt="LookDev Live · {esc(title)}" loading="{load}" decoding="async" width="3840" height="2160" draggable="false">
    <span class="image-label live">LookDev Live</span><span class="image-label dio">Diorama</span><span class="divider" aria-hidden="true"><i>↔</i></span>
  </div>
  <div class="slider-row"><button type="button" data-value="100">只看 LookDev</button><input type="range" min="0" max="100" value="50" aria-label="{esc(title)} 两版分界位置" aria-valuetext="LookDev Live 占左侧 50%"><button type="button" data-value="0">只看 Diorama</button><button class="reset" type="button" data-value="50" aria-label="恢复一半一半">各半</button></div>
</div>
<div class="caption"><p>{esc(caption)}</p><div class="downloads"><a href="{esc(live['local_file'])}" target="_blank" rel="noopener">LookDev 原始全尺寸 ↗</a><a href="{esc(dio['local_file'])}" target="_blank" rel="noopener">Diorama 原始全尺寸 ↗</a></div></div>
<details><summary class="{"good" if all(matching) else "bad"}">{summary} · 查看逐项记录</summary><div class="table-scroll"><table><thead><tr><th>项目</th><th>LookDev Live</th><th>Diorama</th><th>核对</th></tr></thead><tbody>{''.join(rows)}</tbody></table></div><p class="fine">动作时间是动画采样值，可为负数并按循环求模；不是太阳时刻。投影 0=透视，1=正交；size 在透视下也记录，但不控制当前视野。图像没有经后期重绘或调色。</p></details>
</article>'''
    return markup, all(matching)


CSS = '''
:root{color-scheme:dark;--ink:#eceadf;--muted:#adb6b3;--bg:#151b1d;--panel:#1d2628;--line:#394446;--green:#b7ccae;--rose:#e6bac5;--warm:#ded0aa}*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.75 system-ui,-apple-system,"Segoe UI","Microsoft YaHei",sans-serif}a{color:var(--warm);text-underline-offset:4px}a:hover{color:white}header,main,footer{width:min(1320px,calc(100% - 64px));margin:auto}header{padding:68px 0 35px}h1,h2,h3,p{margin-top:0}h1{font-size:clamp(34px,5vw,64px);font-weight:560;line-height:1.15;letter-spacing:-.03em;max-width:920px;margin-bottom:25px}h2{font-size:clamp(25px,3vw,36px);font-weight:550;margin-bottom:12px}h3{font-size:25px;font-weight:550;line-height:1.3;margin:4px 0 0}.eyebrow{font-size:12px;letter-spacing:.10em;color:var(--green)}.intro{font-size:18px;max-width:810px;color:var(--muted)}.navigation,.downloads,.links{display:flex;flex-wrap:wrap;gap:12px 24px}.navigation{border-top:1px solid var(--line);padding-top:24px;margin-top:30px}.navigation a{font-size:14px}.metrics{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin:28px 0}.metric{padding:20px;background:var(--panel);border:1px solid var(--line);border-radius:8px}.metric strong{display:block;font-size:30px;line-height:1.2;color:var(--warm);font-weight:550}.metric small,.fine,small{color:var(--muted);font-size:13px}.section{padding:38px 0 24px;border-top:1px solid var(--line);scroll-margin-top:20px}.section>p{max-width:850px;color:var(--muted)}.pair{background:var(--panel);border:1px solid var(--line);border-radius:12px;overflow:hidden;margin:28px 0 42px;scroll-margin-top:24px}.pair-heading{display:flex;justify-content:space-between;gap:20px;align-items:end;padding:24px 26px}.pair-heading small{max-width:250px;text-align:right}.stage{position:relative;aspect-ratio:16/9;overflow:hidden;background:#101718;touch-action:pan-y;cursor:ew-resize}.stage img{display:block;width:100%;height:100%;object-fit:contain;user-select:none}.stage .overlay{position:absolute;inset:0;clip-path:inset(0 calc(100% - var(--split)) 0 0)}.divider{position:absolute;left:var(--split);top:0;bottom:0;width:2px;background:#f0eee5;transform:translateX(-1px);pointer-events:none;box-shadow:0 0 9px #0007}.divider i{position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);font-style:normal;border:1px solid #e8ead8;background:#182526d9;border-radius:50%;display:grid;place-items:center;width:39px;height:39px;color:white}.image-label{position:absolute;top:18px;padding:6px 13px;background:#152022d9;font-size:12px;border:1px solid #8b969666;backdrop-filter:blur(8px);border-radius:4px;pointer-events:none}.image-label.live{left:18px;color:var(--green)}.image-label.dio{right:18px;color:var(--rose)}.slider-row{display:flex;align-items:center;gap:16px;padding:14px 24px;border-bottom:1px solid var(--line)}input[type=range]{width:100%;min-width:55px;accent-color:var(--green);cursor:ew-resize}button{font:inherit;font-size:12px;white-space:nowrap;border:1px solid #5c6a6a;border-radius:5px;background:#253033;color:var(--ink);padding:6px 10px;cursor:pointer}button:hover,button:focus-visible{background:#3c4d4c;outline:1px solid var(--green)}.caption{padding:20px 26px 18px}.caption p{color:var(--muted);margin-bottom:11px;font-size:14px}.downloads a{font-size:13px}details{border-top:1px solid var(--line);padding:15px 26px}summary{font-size:13px;cursor:pointer}details .fine{margin:14px 0 3px}.table-scroll{overflow:auto;margin-top:15px}table{width:100%;border-collapse:collapse;font-size:12px}th,td{border-bottom:1px solid var(--line);padding:10px;text-align:left;vertical-align:top}th{font-weight:500;color:var(--muted)}td{overflow-wrap:anywhere;min-width:90px}.status{display:inline-block;padding:3px 9px;border:1px solid currentColor;border-radius:4px;font-size:12px}.good{color:var(--green)}.bad{color:#efb3a1}.pending{color:var(--warm)}.report-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:16px}.report{background:var(--panel);padding:22px;border:1px solid var(--line);border-radius:8px}.report h3{font-size:18px;margin:0 0 14px}.report p{font-size:13px;color:var(--muted);margin:13px 0}.checks{list-style:none;padding:0;margin-bottom:8px;font-size:13px}.checks li{padding:6px 0;border-bottom:1px solid var(--line)}.checks li span{margin-right:8px}.video{width:100%;max-height:740px;background:#0e1516;border:1px solid var(--line);border-radius:10px;display:block}.empty{border:1px dashed var(--line);border-radius:10px;padding:32px;color:var(--muted)}.archive{display:grid;grid-template-columns:1fr 1fr;gap:28px;align-items:center;background:var(--panel);border-radius:10px;padding:24px}.archive img{display:block;width:100%;border-radius:5px}.archive h3{font-size:22px;margin-bottom:14px}.archive p{font-size:14px;color:var(--muted)}.stat-list{font-size:13px;color:var(--muted)}footer{padding:25px 0 50px;color:var(--muted);font-size:12px}noscript p{padding:20px;border:1px solid var(--warm)}@media(max-width:780px){header,main,footer{width:calc(100% - 32px)}header{padding-top:36px}.metrics{grid-template-columns:repeat(2,1fr)}.metric{padding:15px}.report-grid{grid-template-columns:1fr}.pair-heading{display:block;padding:18px}.pair-heading small{display:block;text-align:left;margin-top:10px}.pair-heading h3{font-size:22px}.slider-row{padding:11px 12px;gap:9px}.slider-row button{font-size:10px;padding:5px}.reset{display:none}.caption,details{padding-left:18px;padding-right:18px}.image-label{top:9px;font-size:10px;padding:4px 7px}.image-label.live{left:9px}.image-label.dio{right:9px}.divider i{width:28px;height:28px}.archive{grid-template-columns:1fr;padding:18px;gap:20px}.navigation{gap:10px 20px}}@media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}}
'''

JS = '''
document.querySelectorAll('.compare').forEach(box=>{
 const input=box.querySelector('input'),stage=box.querySelector('.stage');
 const update=value=>{const n=Math.max(0,Math.min(100,Number(value)));input.value=n;box.style.setProperty('--split',n+'%');input.setAttribute('aria-valuetext','LookDev Live 占左侧 '+Math.round(n)+'%');box.querySelector('.image-label.live').hidden=n<1;box.querySelector('.image-label.dio').hidden=n>99;box.querySelector('.divider').hidden=n<1||n>99;};
 input.addEventListener('input',()=>update(input.value));
 box.querySelectorAll('button[data-value]').forEach(b=>b.addEventListener('click',()=>update(b.dataset.value)));
 let pointer=null;
 const at=e=>{const r=stage.getBoundingClientRect();update(100*(e.clientX-r.left)/r.width);};
 stage.addEventListener('pointerdown',e=>{if(e.button!==0)return;pointer=e.pointerId;stage.setPointerCapture(pointer);at(e);});
 stage.addEventListener('pointermove',e=>{if(e.pointerId===pointer)at(e);});
 stage.addEventListener('pointerup',e=>{if(e.pointerId===pointer){stage.releasePointerCapture(pointer);pointer=null;}});
 stage.addEventListener('pointercancel',()=>pointer=null);
});
'''


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    live_report = read_json(OUT / "capture_report.json")
    dio_report = read_json(OUT / "diorama_ab/capture_report.json")
    live, dio = indexed_shots(live_report), indexed_shots(dio_report, "diorama_ab/")
    validation = read_json(OUT / "validation.json")
    runtime = read_json(OUT / "runtime_qa.json")
    comparison = compare_reports(live_report, dio_report, live, dio)
    video_validation = read_json(OUT / "video_validation.json")
    motion = read_json(OUT / "motion_manifest.json")
    delivery = read_json(OUT / "delivery_validation.json")
    common = live.keys() & dio.keys()
    cards, equal_count = {}, 0
    for key in sorted(common):
        cards[key], matching = comparison_card(key, live[key], dio[key], live_report, dio_report, eager=key == "01_hall")
        equal_count += matching
    population = validation.get("population", {})
    population_count = population.get("count", "待报告")
    checks = validation.get("checks", {})
    check_rows = ''.join(f'<li class="{"good" if value is True else "bad" if value is False else "pending"}"><span>{"✓" if value is True else "×" if value is False else "·"}</span>{esc(CHECK_NAMES.get(key,key))}</li>' for key, value in checks.items())
    report_links = [link(name, title) for name, title in [
        ("capture_report.json", "LookDev 捕获记录"), ("diorama_ab/capture_report.json", "Diorama 捕获记录"),
        ("comparison_validation.json", "相机一致性报告"), ("validation.json", "完整场景 QA"),
        ("runtime_qa.json", "连续步行与接触记录"), ("delivery_validation.json", "交互启动记录"),
        ("performance.json", "普通窗口性能记录"), ("baseline.json", "迁移前保护清单"),
    ]]
    sections = []
    groups = [
        ("human", "先站进校园，再比较风格", "这三个近人高或人物近景优先：建筑比例、步行尺度与角色身份，比俯视总览更能解释沉浸感。", ["01_hall", "04_bridge", "07_tiku"]),
        ("environment", "同一条路、同一座亭", "北轴、草地、水陆边界和建筑布置共用；改变的是夏末细叶、春日冠簇以及表面和光照表现。", ["02_axis", "03_gate", "05_pavilion_front"]),
        ("life", "人物与动作没有留在另一个版本", "目标共享 14 个生命节点、五位漫步者。原骑车与慢读沿用各自机制，坐写与坐读保留静区故事；数量和运行结果见下方实际 QA。", [f"{i:02d}_{name}" for i,name in [(8,"photo"),(9,"cyclist"),(10,"reader"),(11,"raiden"),(12,"march7"),(13,"meituan"),(14,"doubao"),(15,"leaf_cat")]]),
        ("spatial", "空间附图与路线", "用于检查地图与行动范围。高位图保留作为补充，不替代人眼高度的风格对照。", ["06_pools", "16_whole", "17_routes"]),
    ]
    used = set()
    for anchor,title,note,keys in groups:
        content = ''.join(cards[key] for key in keys if key in cards)
        used.update(key for key in keys if key in cards)
        if content:
            sections.append(f'<section class="section" id="{anchor}"><span class="eyebrow">NATIVE GODOT / A–B</span><h2>{title}</h2><p>{note}</p>{content}</section>')
    if common-used:
        sections.append('<section class="section"><h2>追加的实际机位</h2>'+''.join(cards[k] for k in sorted(common-used))+'</section>')
    missing = [key for key in SHOTS if key not in common]
    pending = f'<p class="fine">尚无两份捕获报告与对应 PNG：{esc("、".join(missing))}。不计入已输出对照。</p>' if missing else ''
    video = local_file("campus_life_demo.mp4", OUT)
    frames, fps = motion.get("frames"), motion.get("fps")
    duration = frames/fps if isinstance(frames,(int,float)) and isinstance(fps,(int,float)) and fps else None
    timing = f'{motion.get("width","—")}×{motion.get("height","—")} · {fps or "—"} fps · {frames or "—"} 帧' + (f' · {duration:g} 秒' if duration is not None else '')
    if video:
        video_html = f'<video class="video" controls preload="metadata" playsinline><source src="{video}" type="video/mp4">浏览器不支持内嵌播放，请打开下方 MP4。</video><p class="fine">{esc(timing)} · {link(video,"原始 MP4")}</p>'
    else:
        video_html = '<div class="empty">64 秒展示片计划待生成：当前尚无 MP4 文件，不计为已完成视频。</div>'
    video_note = '视频验证报告已通过；具体解码范围以报告为准，不将它扩大表述为 GUI 连续播放验收。' if video_validation.get('passed') is True else '影片验证尚未通过或报告未产生；原生播放控件只表示可以打开文件，不表示已验证。'
    archive = local_file("../lookdev/hero_04.png")
    archive_html = f'<section class="section" id="archive"><h2>旧 LookDev 仍然独立保留</h2><div class="archive"><a href="{archive}" target="_blank" rel="noopener"><img src="{archive}" alt="历史 LookDev hero_04 原始截图" loading="lazy" width="3840" height="2160"></a><div><span class="eyebrow">ARCHIVE / 原始图片</span><h3>最初的红砖与树影</h3><p>这是历史 LookDev 画面，保留为单独入口。它没有新人口与北轴的实际加载，也不作为这一轮同时间、同机位 A/B 的一半。</p><a href="{archive}" target="_blank" rel="noopener">打开旧版 hero_04 原图 ↗</a></div></div></section>' if archive else ''
    doc_links = [link(name,title) for name,title in [
        ("../../docs/LOOKDEV_VS_DIORAMA.md","模型差异与迁移边界"), ("../../docs/LOOKDEV_LIVE_QA.md","LookDev Live QA 方法"),
        ("../../docs/LOOKDEV_LIVE_ASSETS.md","模型迁移说明"), ("../../docs/LOOKDEV_LIVE_ART_REVIEW.md","本轮实机艺术复核"),
        ("../../docs/WANDERING_BEHAVIORS.md","漫步行为与静坐例外"), ("../../docs/WORKFLOW_INDEX.md","项目工作流入口"),
    ]]
    page = f'''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>同一座校园 · LookDev Live × Diorama</title><style>{CSS}</style></head><body>
<header><span class="eyebrow">USTC EAST CAMPUS / 同内容 · 双表现</span><h1>同一座校园，<br>两种光与树影。</h1><p class="intro">LookDev Live 的夏末细叶与 Diorama 的春日冠簇。把分界线左右拖动，在同机位、同姿态下比较建筑、树木、人物和校园尺度。</p>
<div class="metrics"><div class="metric"><strong>{len(common)}</strong><small>已有原生图片对照 / 17 计划</small></div><div class="metric"><strong>{equal_count}/{len(common)}</strong><small>捕获参数逐项相等</small></div><div class="metric"><strong>{esc(population_count)}</strong><small>生命节点 / 实际 QA 记录</small></div><div class="metric"><strong>5</strong><small>共用漫步者 / 下方报告验算</small></div></div>
<p class="fine">原始 Godot PNG，未重绘、未后期调色。拖动图片或下方滑块，也可聚焦滑块后使用方向键。灯光、材质和季节是比较变量；相机与动作采样是固定变量。</p>
<nav class="navigation"><a href="#human">先看人高</a><a href="#environment">建筑与北轴</a><a href="#life">角色与漫步</a><a href="#spatial">空间附图</a><a href="#motion">动态展示</a><a href="#evidence">验证记录</a><a href="#archive">旧版原图</a></nav>{pending}</header>
<main><noscript><p>JavaScript 已禁用，图片保留默认一半一半。每组下方仍可打开两张全尺寸原图。</p></noscript>{''.join(sections)}
<section class="section" id="motion"><span class="eyebrow">NATIVE GODOT / MOTION</span><h2>人在走，树影也在呼吸</h2><p>展示片计划由八段各 8 秒组成，覆盖校园环境与五位漫步者。它是动作片段展示，不等同每位角色完整行为周期验证；周期检查见独立 QA。</p>{video_html}<p class="fine">{video_note} {link("motion_manifest.json","帧与片段清单")} {link("video_validation.json","视频验证记录")}</p></section>
<section class="section" id="evidence"><span class="eyebrow">EVIDENCE / 可核对</span><h2>画面与验证分开陈述</h2><p>本画廊展示本轮实机产物与代理复核依据，不把技术通过自动写成用户已批准美术效果。画面有多少对、参数是否相等，都读取现存捕获报告与本地文件。</p>
<div class="report-grid"><div class="report"><h3>同机位一致性</h3>{status(comparison.get('passed'))}<p>画廊独立交叉核对得到 {equal_count}/{len(common)} 组相机变换、FOV、投影、size、动作时间与像素尺寸相等。外部比较报告的通过状态单独显示。</p>{link('comparison_validation.json','打开完整比较报告')}</div><div class="report"><h3>世界与人口回归</h3>{status(validation.get('passed'))}<ul class="checks">{check_rows or '<li>完整验证报告尚未产生。</li>'}</ul>{link('validation.json','打开实际结果')}</div><div class="report"><h3>实走与启动</h3>{status(runtime.get('passed'))}<p>连续路线与可见模型接触由 runtime_qa 记录。交互窗口启动属于另一份证据。</p><p>交互启动：{status(delivery.get('passed'))}</p>{link('runtime_qa.json','查看实际步行 / 接触记录')} {link('delivery_validation.json','查看启动结果')}</div></div>
<div class="links" style="margin-top:24px">{''.join(report_links)}</div><details style="margin-top:22px"><summary>外部相机比较报告 · 原始字段</summary><pre style="white-space:pre-wrap;overflow-wrap:anywhere;font-size:12px">{esc(json.dumps(comparison,ensure_ascii=False,indent=2)) if comparison else '尚未产生 comparison_validation.json。'}</pre></details>
<p class="fine">共用地图与基本物理规则，并不表示树干碰撞形状完全相同：LookDev 按细叶树实际低干网格重新测量，以免视觉树干与碰撞错位。外侧远景仅用于视觉衔接，不增加可游玩面积。</p></section>
{archive_html}<section class="section"><h2>继续核对工程依据</h2><div class="links">{''.join(doc_links)}</div><p class="fine">角色与品牌形象的参考来源和使用边界沿用项目资料记录；同内容对照不代表取得官方授权。</p></section></main>
<footer>由 tools/lookdev_live_review.py 读取现存报告生成 · {datetime.now().isoformat(timespec='seconds')} · 离线页面，无外部字体、脚本或分析服务。<br>{esc('；'.join(WARNINGS))}</footer><script>{JS}</script></body></html>'''
    (OUT / "review.html").write_text(page, encoding="utf-8")
    print(json.dumps({"output":str(OUT / "review.html"),"pairs":len(common),"matching_parameters":equal_count,"pending":missing,"video_exists":bool(video),"comparison_passed":comparison.get("passed"),"scene_qa_passed":validation.get("passed"),"warnings":WARNINGS},ensure_ascii=True))


if __name__ == "__main__":
    main()
