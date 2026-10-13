"""Build a local evidence gallery from existing Godot output; never edit images."""
from __future__ import annotations

import html
import json
from collections import Counter
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "renders" / "population"
WARNINGS: list[str] = []


def esc(value: object) -> str:
    return html.escape(str(value), quote=True)


def read_json(path: Path) -> dict:
    if not path.is_file():
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError) as exc:
        WARNINGS.append(f"{path.name} 暂未读完：{type(exc).__name__}")
        return {}


SHOTS = [
    ("01_world.png", "一座校园，几处小故事", "全景 / 稀疏布置", "一教、樱花与完整底座保持主角地位；新增活动分散在前场东侧和后院。"),
    ("02_tiku_preserved.png", "一道题的下午", "保留 / 已接受 Hero", "长椅版做题家保留已接受的头脸与材料；本子在腿上，长椅前没有桌子。"),
    ("03_sakura_photographer.png", "把花期留在手机里", "统一升级 / 既有 Ambient 节点", "拍照节点保持原位置与故事，替换旧积木Q版外观，与新Ambient共享成人化比例和材质语言。"),
    ("04_cyclist_riding.png", "骑车归来", "新增 / Ambient", "低速骑行只占用东侧一段道路；手与车把、脚与踏板的接触需要同时成立。"),
    ("05_cyclist_pushing.png", "慢下来，推几步", "新增 / Ambient 动作", "同一骑车者从骑行过渡到推车，人车并排，给道路留出通行空间。"),
    ("06_courtyard_reader.png", "后院的一页书", "新增 / 静区 Ambient", "读书者放在后院既有长椅，坐读、抬眼和翻页，让前后两组空间都有安静用途。"),
    ("07_north_connection.png", "向北再走十二米", "扩展 / 144㎡接段", "沿玉泉北路延伸12×12米，8米中路接回现有地面。这是双池之间的陆路，不是桥；不新增人物。"),
    ("08_courtyard_context.png", "庭院仍然安静", "全景 / 后院留白", "检验新增读者是否融入U形庭院；人物不应成为填满草地的理由。"),
    ("09_tiku_uniform_preserved.png", "路灯旁的一点深思", "保留 / 同身份 Hero 变体", "蓝白校服版仍使用已接受的做题家头脸，左臂夹书，保持克制侧目与停顿。"),
    ("10_cyclist_pause.png", "在路边停一会儿", "新增 / Ambient 停顿", "停靠是循环的一部分；动作幅度和节奏服从安静校园。"),
    ("11_photo_review.png", "看看刚才那张照片", "统一升级 / 既有 Ambient 节点", "拍照者查看手机、轻微转向，再重新取景；外观统一但没有额外复制一名人物。"),
    ("12_reading_walk.png", "慢慢记住的一页", "统一升级 / 既有 Ambient 节点", "慢读节点保留路线，升级发型、身体和服装轮廓；继续慢走、停读、翻页，与骑行路线分开。"),
]
ZONE_NAMES = {
    "quiet_study": "写题静区", "axis_story": "路灯节点",
    "sakura_story": "樱花拍照", "light_activity": "前场轻活动",
    "east_cycle_stop": "东侧骑行", "quiet_courtyard": "后院静区",
}
CHECK_NAMES = {
    "population": "实际人口数量", "hero_frozen": "Hero 文件冻结",
    "finite_pose": "姿态数值有效", "cycle_land_clearance": "骑行范围陆地检查",
    "ik_contacts": "手脚接触约束", "quiet_cycle_speed": "克制骑行速度",
    "pose_loops": "关节循环闭合", "root_loop": "路线循环闭合",
    "connector_ground": "新接段连续地面", "yield_near": "靠近时让行",
    "yield_clear": "让行解除", "land_traversal": "真实玩家陆地游览",
    "connector_boundaries": "新终点与侧边阻挡",
    "local_density": "局部100米人口密度", "quiet_connector": "接段保持无人",
    "shoe_surface_contact": "鞋底与实际地表接触", "cyclist_blocks_player": "自行车实际阻挡",
    "reader_bench_blocks_player": "后院长椅实际阻挡", "yield_resumes": "让行后恢复",
    "yield_stops_clock": "让行时动作时钟停止",
}
TIER_COLORS = {"Hero": "#e4bb68", "Ambient": "#81b8b3", "Creature": "#d69da8"}


def metric(value: object, label: str, note: str = "") -> str:
    return f'<div class="metric"><strong>{esc(value)}</strong><span>{esc(label)}</span><small>{esc(note)}</small></div>'


def population_map(config: dict, modules: dict, site: dict) -> str:
    # The site geometry supplies spatial context; population positions remain the source of truth.
    scale = 4.0
    sx = lambda x: 42 + (float(x) + 80) * scale
    sy = lambda z: 30 + (float(z) - 106) * scale

    def points(poly: list) -> str:
        return " ".join(f"{sx(p[0]):.2f},{sy(p[1]):.2f}" for p in poly if isinstance(p, list) and len(p) >= 2)

    pieces = ['<svg viewBox="0 0 725 612" role="img" aria-label="由实际角色配置生成的人口平面图，北上南下">',
              '<defs><clipPath id="baseclip"><rect x="42" y="78" width="640" height="480"/></clipPath></defs>',
              '<rect x="42" y="78" width="640" height="480" rx="8" fill="#293630" stroke="#687265"/>']
    hall = site.get("hall_outline", [])
    if hall:
        pieces.append(f'<polygon points="{points(hall)}" fill="#745448" stroke="#ba8b72" stroke-width="1.5"/>')
    ponds = site.get("ponds", [])
    if isinstance(ponds, dict):
        ponds = list(ponds.values())
    for pond in ponds:
        poly = pond.get("outline", pond.get("points", [])) if isinstance(pond, dict) else pond
        if isinstance(poly, list) and poly:
            pieces.append(f'<polygon points="{points(poly)}" clip-path="url(#baseclip)" fill="#36525a" opacity=".85"/>')
    # Existing core circulation is schematically shown; exact new module bounds come from config.
    pieces += [f'<path d="M{sx(0)},{sy(118)}V{sy(165)} M{sx(-76)},{sy(158)}H{sx(76)}" stroke="#999984" stroke-width="19" opacity=".43" fill="none"/>']
    for mod in modules.get("modules", []):
        if not mod.get("enabled", False):
            continue
        x0, z0, x1, z1 = mod["bounds"]
        area = abs((x1 - x0) * (z1 - z0))
        pieces.append(f'<rect x="{sx(x0)}" y="{sy(z0)}" width="{(x1-x0)*scale}" height="{(z1-z0)*scale}" fill="#999984" stroke="#d1c499" stroke-width="1.5"/>')
        pieces.append(f'<text x="{sx(x1)+12}" y="{sy(z0)+16}" class="map-label">北向接段 · {area:g}㎡</text>')
    for actor in config.get("actors", []):
        p = actor.get("position", [])
        if len(p) < 3:
            continue
        tier = actor.get("tier", "Ambient")
        color = TIER_COLORS.get(tier, "#aaa")
        end = actor.get("path_end", [])
        if len(end) >= 3:
            pieces.append(f'<path d="M{sx(p[0])},{sy(p[2])}L{sx(end[0])},{sy(end[2])}" stroke="{color}" stroke-width="2" stroke-dasharray="5 5" opacity=".8"/>')
        radius = 6 if tier == "Hero" else 5 if tier == "Ambient" else 3
        pieces.append(f'<circle cx="{sx(p[0])}" cy="{sy(p[2])}" r="{radius}" fill="{color}" stroke="#202623" stroke-width="1.5"><title>{esc(actor.get("name", actor.get("id", "")))} · {esc(tier)} · {esc(p)}</title></circle>')
    pieces += [f'<text x="{sx(0)}" y="{sy(177)}" text-anchor="middle" class="map-label">第一教学楼</text>',
               f'<text x="{sx(-27)}" y="{sy(218.8)+25}" text-anchor="middle" class="map-label">后院静区</text>',
               '<text x="54" y="45" class="map-label">N ↑</text>',
               '<path d="M570 584h80m-80-4v8m80-8v8" stroke="#cec4ac"/>',
               '<text x="610" y="604" text-anchor="middle" class="map-label">20 m</text></svg>']
    return "".join(pieces)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    config = read_json(ROOT / "godot/data/population.json")
    modules = read_json(ROOT / "godot/data/module_layout.json")
    site = read_json(ROOT / "godot/assets/site.json")
    assets = read_json(OUT / "asset_manifest.json")
    capture = read_json(OUT / "capture_report.json")
    validation = read_json(OUT / "validation.json")
    motion = read_json(OUT / "motion_manifest.json")
    animation = read_json(OUT / "animation_validation.json")
    performance = read_json(OUT / "performance.json")
    config_counts = Counter(a.get("tier", "Unknown") for a in config.get("actors", []))
    counts = validation.get("counts") or config_counts
    count_note = "运行验证计数" if validation.get("counts") else "当前部署配置，待运行核对"
    existing = [s for s in SHOTS if (OUT / s[0]).is_file()]
    by_file = {s.get("file"): s for s in capture.get("shots", [])}
    cards = []
    for filename, title, tag, caption in existing:
        metadata = by_file.get(filename, {})
        detail = f'动作 {metadata["time"]:g}s' if isinstance(metadata.get("time"), (int, float)) else "动作参数待捕获报告"
        if metadata.get("view") == 1:
            detail += " · 正交 / size 150m"
        elif isinstance(metadata.get("fov"), (int, float)):
            detail += f' · FOV {metadata["fov"]:g}°'
        if metadata.get("camera"):
            detail += " · 相机 " + str(metadata["camera"])
        provenance = "Godot 实际视口 / 捕获报告已登记" if metadata else "Godot 输出文件已产生 / 等待捕获报告登记"
        cards.append(f'<figure class="shot"><a href="{esc(filename)}" target="_blank"><img src="{esc(filename)}" alt="{esc(title)}" loading="lazy"></a><figcaption><span class="eyebrow">{esc(tag)}</span><h3>{esc(title)}</h3><p>{esc(caption)}</p><small>{esc(provenance)}<br>{esc(detail)}</small></figcaption></figure>')
    pending = [s[1] for s in SHOTS if not (OUT / s[0]).is_file()]
    pending_html = '<p class="pending">尚未产生的机位：' + esc("、".join(pending)) + '。这些项目不计作已交付截图。</p>' if pending else ""
    intro_image = '<a class="lead-image" href="01_world.png" target="_blank"><img src="01_world.png" alt="本轮校园人口与北侧接段的 Godot 总览"></a>' if (OUT / "01_world.png").is_file() else '<div class="empty">Godot 新总览尚未捕获。下方部署图与报告来自当前文件，不能替代实机视觉验收。</div>'
    report_state = "自动检查通过" if validation.get("passed") is True else "自动检查有待修正项" if validation else "自动检查待运行"
    failed = [CHECK_NAMES.get(k, k) for k, v in validation.get("checks", {}).items() if v is False]
    report_note = "技术结果不自动构成艺术验收。" + (" 当前失败：" + "、".join(failed) + "。" if failed else "")
    checks_html = "".join(f'<li class="{"good" if value else "bad"}"><span>{"✓" if value else "待修正"}</span>{esc(CHECK_NAMES.get(name, name))}</li>' for name, value in validation.get("checks", {}).items())
    checks_html = '<ul class="checks">' + checks_html + '</ul>' if checks_html else '<p class="pending">validation.json 尚未产生。</p>'
    asset_rows = "".join(f'<tr><td>{esc({"cyclist":"骑车同学（新节点）","bench_reader":"后院读者（新节点）","photographer":"拍照同学（统一升级）","study_walk":"慢读同学（统一升级）"}.get(key,key))}</td><td>{esc(data.get("triangles", "未记录"))}</td><td>{esc(data.get("mesh_nodes", "未记录"))}</td><td>{esc(data.get("glb", ""))}</td></tr>' for key, data in assets.items() if isinstance(data, dict))
    actor_rows = "".join(f'<tr><td><i class="dot" style="background:{TIER_COLORS.get(a.get("tier"),"#aaa")}"></i>{esc(a.get("name",a.get("id")))}</td><td>{esc(a.get("tier",""))}</td><td>{esc(ZONE_NAMES.get(a.get("zone"),a.get("zone","")))}</td><td>{esc(a.get("position",[]))}</td></tr>' for a in config.get("actors", []))
    video_path = OUT / "campus_life_demo.mp4"
    if video_path.is_file():
        frames, fps = motion.get("frames"), motion.get("fps")
        timing = f'{frames} 帧 / {fps} fps / {frames/fps:g} 秒' if isinstance(frames,(int,float)) and isinstance(fps,(int,float)) and fps > 0 else "时长以本地视频及 manifest 为准"
        video = f'<video controls preload="metadata" src="campus_life_demo.mp4"></video><p>{esc(timing)}。来自 Godot 实际视口序列；不使用 AI 补帧或重绘。静态采样/截图读回不代表稳定游玩帧率。</p>'
        if motion.get("clips"):
            video += '<p class="subtle">片段：' + esc(" · ".join(f'{c.get("name")} {c.get("seconds")}s' for c in motion["clips"])) + '</p>'
    else:
        video = '<p class="pending">短片尚未产生；不嵌入空视频，也不以静态图片宣称完成动作展示。</p>'
    proof_cards = []
    for filename, title in [("cyclist_ride_blender.png","骑行姿态"),("cyclist_push_blender.png","推车姿态"),("bench_reader_read_blender.png","长椅坐读"),("photographer_photo_front_blender.png","拍照者正面"),("photographer_photo_three_quarter_blender.png","拍照者3/4"),("photographer_photo_side_blender.png","拍照者侧面"),("study_walk_read_front_blender.png","慢读者正面"),("study_walk_read_three_quarter_blender.png","慢读者3/4"),("study_walk_read_side_blender.png","慢读者侧面")]:
        if (OUT / filename).is_file():
            proof_cards.append(f'<figure><a href="{filename}" target="_blank"><img src="{filename}" alt="Blender 生产资产 · {title}" loading="lazy"></a><figcaption>Blender 生产资产 · {title}，不是 Godot 实机截图。</figcaption></figure>')
    baseline_dir = ROOT / "benchmarks/accepted_v0_4"
    baseline_cards = []
    for filename, title in [("tiku_front.png","已接受 Hero 正面"),("tiku_study.png","已接受长椅版 Godot 近景"),("environment_ortho.png","历史环境基准，早于最终 Hero")]:
        if (baseline_dir / filename).is_file():
            href = "../../benchmarks/accepted_v0_4/" + filename
            baseline_cards.append(f'<figure><a href="{href}" target="_blank"><img src="{href}" alt="{esc(title)}" loading="lazy"></a><figcaption>{esc(title)}</figcaption></figure>')
    report_links = []
    for filename in ["capture_report.json","validation.json","asset_manifest.json","animation_validation.json","performance.json","motion_manifest.json"]:
        if (OUT / filename).is_file():
            report_links.append(f'<a href="{filename}">{filename}</a>')
    animation_summary = []
    for key, item in animation.items():
        if isinstance(item, dict) and "passed" in item:
            animation_summary.append(f'{key}：{item.get("poses_checked", "—")} 姿态采样，' + ("通过" if item["passed"] else "待修正"))
    comparison_rows = []
    for filename, title, note in [
        ("03_sakura_photographer.png", "拍照同学：故事不变，外观统一", "首轮仍是旧积木Q头；最终以同一Ambient造型系统重建，保留拍照节点。"),
        ("06_courtyard_reader.png", "后院读者：鞋面从地垫中回到地面上", "首轮鞋底埋入垫面；最终按实际y=.07地垫调整到鞋底y=.075，并补足垫面碰撞。"),
        ("12_reading_walk.png", "背资料者：把既有角色也带入同一风格", "首轮新旧人物比例不一致；最终保留慢读路线，升级头发、衣服与成年比例。"),
    ]:
        before = OUT / "round01" / filename
        after = OUT / filename
        if before.is_file() and after.is_file():
            comparison_rows.append(f'<article style="margin:28px 0 38px"><h3>{esc(title)}</h3><p>{esc(note)}</p><div class="gallery"><figure><a href="round01/{filename}" target="_blank"><img src="round01/{filename}" alt="首轮 Godot · {esc(title)}" loading="lazy"></a><figcaption>首轮实际 Godot / round01</figcaption></figure><figure><a href="{filename}" target="_blank"><img src="{filename}" alt="最终 Godot · {esc(title)}" loading="lazy"></a><figcaption>最终实际 Godot / 本轮基准</figcaption></figure></div></article>')
    comparisons = '<section id="comparison"><span class="eyebrow">RENDER → REVIEW → FIX</span><h2>这一轮不只增加人数，也修正不统一的地方</h2><p>直接并列首轮与最终原图，没有重绘或图像编辑。前三张旧新比较分别检查比例、接地和衣服轮廓；机位参数以各轮capture_report为准，必要的近景调整不冒充完全同机位。</p>' + "".join(comparison_rows) + '</section>' if comparison_rows else ""
    performance_html = ""
    if performance.get("completed") and performance.get("views"):
        rows = []
        for view in performance["views"]:
            median = view.get("median_frame_ms", view.get("frame_ms", {}).get("median"))
            p95 = view.get("p95_frame_ms", view.get("frame_ms", {}).get("p95"))
            fmt = lambda value: f"{value:.3f}" if isinstance(value, (int, float)) else "未记录"
            rows.append(f'<tr><td>{esc(view.get("name",view.get("id","")))}</td><td>{fmt(median)}</td><td>{fmt(p95)}</td><td>{esc(view.get("draw_calls",{}).get("median","未记录"))}</td><td>{esc(view.get("samples","未记录"))}</td></tr>')
        resolution = "×".join(str(v) for v in performance.get("resolution", []))
        performance_html = f'<section id="performance"><span class="eyebrow">PERFORMANCE · NORMAL GAME VIEWPORT</span><h2>性能用实际运行测量</h2><p>{esc(resolution)}普通实时视口 · {esc(performance.get("gpu",""))} · {esc(performance.get("renderer",""))}。角色、风、云与场景灯光继续运行，采样期间没有图片读回或编码。</p><div class="table-wrap panel"><table><thead><tr><th>机位</th><th>中位帧时 ms</th><th>P95帧时 ms</th><th>绘制调用中位</th><th>样本帧数</th></tr></thead><tbody>{"".join(rows)}</tbody></table></div><p class="subtle">VSync模式 {esc(performance.get("quality",{}).get("vsync_mode","未记录"))}，引擎帧率上限 {esc(performance.get("quality",{}).get("engine_max_fps","未记录"))}。帧时为实际交付延迟，包含CPU、GPU同步和刷新/限帧等待，不是单独GPU执行时间；绘制调用含阴影/深度等通道。4K Ultra截图时的fps含截图读回开销，不能当成此运行性能。<a href="performance.json">原始样本与画质记录</a></p></section>'
    art_review = '<p><a href="../../docs/POPULATION_REVIEW.md">本轮人工 Art Review 与保留问题 ↗</a></p>' if (ROOT / "docs/POPULATION_REVIEW.md").is_file() else ""
    metrics = metric(counts.get("Hero",0), "Hero 实例", "同一身份两种衣着") + metric(counts.get("Ambient",0), "Ambient", "两位新增、两位统一升级") + metric(counts.get("Creature",0), "Creature", "一猫两鸟") + metric(f'{len(existing)} / {len(SHOTS)}', "Godot 截图文件", "完成数量按文件存在统计")
    css = '''
*{box-sizing:border-box}html{color-scheme:dark;scroll-behavior:smooth}body{margin:0;background:#191e1d;color:#ece5d5;font:16px/1.75 system-ui,"Microsoft YaHei",sans-serif}main{max-width:1420px;margin:auto;padding:48px 32px 70px}a{color:#b3ccc0;text-decoration:none}a:hover{text-decoration:underline}h1,h2,h3,p{margin:0}h1{font-size:clamp(32px,5vw,58px);line-height:1.2;letter-spacing:.01em;margin:14px 0 20px;font-weight:600}h2{font-size:28px;font-weight:550;margin:12px 0 18px}h3{font-size:21px;font-weight:550;margin:8px 0}p{margin:12px 0}.eyebrow{font-size:12px;letter-spacing:.14em;color:#bdb39b}.intro{max-width:880px;color:#ccc5b7}.toolbar{display:flex;flex-wrap:wrap;gap:22px;margin:24px 0 30px;font-size:14px}.lead-image{display:block}.lead-image img{display:block;width:100%;border-radius:12px}.metrics{display:grid;grid-template-columns:repeat(4,1fr);border-block:1px solid #414741;margin:28px 0 0}.metric{padding:22px 16px;border-right:1px solid #414741}.metric:last-child{border:0}.metric strong{display:block;font-size:35px;line-height:1.2;color:#e6cf9a;font-weight:500}.metric span{display:block;margin-top:8px}.metric small{color:#a9afa4}.subtle,small{color:#aab1a7;font-size:13px}section{margin-top:64px}.split{display:grid;grid-template-columns:1.1fr 1fr;gap:30px;align-items:start}.panel{background:#242b27;border:1px solid #414a40;border-radius:12px;padding:22px}.map{padding:8px}.map svg{display:block;width:100%;height:auto}.map-label{font:12px system-ui,"Microsoft YaHei",sans-serif;fill:#c9c4b4}.legend{display:flex;gap:20px;flex-wrap:wrap;font-size:13px;margin:12px 16px}.dot{display:inline-block;width:9px;height:9px;border-radius:50%;margin-right:9px}.table-wrap{overflow:auto}table{border-collapse:collapse;width:100%;font-size:13px}th,td{text-align:left;padding:11px 8px;border-bottom:1px solid #414741;vertical-align:top}th{color:#b5bfaf;font-weight:500}td:last-child{font-variant-numeric:tabular-nums}.gallery{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:26px}figure{margin:0;min-width:0}figure img{display:block;width:100%;height:auto;background:#252c27;border-radius:10px}figcaption{padding:17px 3px 22px}figcaption p{font-size:15px;color:#c8c8bb}figcaption small{overflow-wrap:anywhere}.proof-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:20px}.proof-grid figcaption{font-size:13px;color:#b5baaf}.empty,.pending{border:1px dashed #666650;border-radius:10px;padding:24px;color:#c4b992;background:#292d25}.checks{list-style:none;padding:0;display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px}.checks li{padding:7px 9px;background:#242c27;border-radius:5px;font-size:14px}.checks span{display:inline-block;min-width:48px;font-size:12px}.good span{color:#a0c29e}.bad span{color:#e3b889}.status{display:inline-block;border:1px solid #6d7661;border-radius:20px;padding:5px 13px;font-size:13px}.links{display:flex;flex-wrap:wrap;gap:16px;font-size:13px;overflow-wrap:anywhere}video{width:100%;max-height:80vh;background:#101412;border-radius:12px}.review-note{border-left:3px solid #a3ad8b;padding:5px 20px;background:#222a25;color:#c7cebf}footer{margin-top:65px;padding-top:24px;border-top:1px solid #414741;color:#939e94;font-size:12px}@media(max-width:900px){main{padding:28px 18px}.split,.gallery{grid-template-columns:1fr}.proof-grid{grid-template-columns:1fr 1fr}.metrics{grid-template-columns:1fr 1fr}.metric:nth-child(2){border-right:0}.checks{grid-template-columns:1fr}}@media(max-width:520px){.proof-grid{grid-template-columns:1fr}.metric strong{font-size:28px}h2{font-size:24px}}
'''
    html_text = f'''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>科大东区 · 轻轻呼吸的校园</title><style>{css}</style></head><body><main>
<header><span class="eyebrow">USTC EAST CAMPUS · POPULATION STUDY</span><h1>几处小故事，<br>一座安静的校园。</h1><p class="intro">保留已接受的做题家，新增骑车与后院阅读两个节点，统一升级既有拍照与背资料两个节点。用同一套角色语言与布置规则，向北衔接144㎡真实校园空间。</p><nav class="toolbar"><a href="#gallery">本轮实机</a><a href="#comparison">首轮对照</a><a href="#layout">人口布置</a><a href="#motion">动态展示</a><a href="#performance">运行性能</a><a href="#qa">验证记录</a><a href="../../docs/WORKFLOW_INDEX.md">项目工作流入口 ↗</a></nav></header>
{intro_image}<div class="metrics">{metrics}</div><p class="subtle">{esc(count_note)}。截图存在不等于已完成艺术验收；当前捕获来源：{esc(capture.get("source", "等待 capture_report.json"))}。</p>
{art_review}
<section id="layout"><span class="eyebrow">PLACEMENT · SPACE TO BREATHE</span><h2>把活动分散，让留白留下来</h2><div class="split"><div class="panel map">{population_map(config, modules, site)}<div class="legend"><span><i class="dot" style="background:#e4bb68"></i>Hero</span><span><i class="dot" style="background:#81b8b3"></i>Ambient</span><span><i class="dot" style="background:#d69da8"></i>Creature</span><span>虚线：配置路径端点</span></div><p class="subtle" style="padding:0 16px">由 population.json、module_layout.json 与 site.json 生成。人物点表示初始部署，点大小为阅读而放大；道路为示意，虚线不是逐帧运动轨迹。</p></div><div><p>西侧长椅是写题静区，东侧道路承接慢骑与停靠，读书者在后院已有长椅上。樱花拍照与背资料者继续复用。北向144㎡接段保持无人，优先说明道路与双池之间的空间关系。</p><div class="table-wrap"><table><thead><tr><th>角色</th><th>类型</th><th>分区</th><th>初始位置</th></tr></thead><tbody>{actor_rows}</tbody></table></div><p class="subtle">配置预算：每约100×100米最多2 Hero、4 Ambient、3 Creature；不是必须填满的配额。<a href="../../docs/SCENE_POPULATION_RULES.md">布置规则</a> · <a href="../../godot/data/population.json">实际配置</a></p></div></div></section>
<section id="gallery"><span class="eyebrow">GODOT · ACTUAL VIEWPORT</span><h2>本轮实机截图</h2><p>点击图片查看原始尺寸。所有下列图片仅在本地文件真实存在时显示；近景关注接地与动作，全景关注微缩尺度和静谧感。</p>{pending_html}<div class="gallery">{"".join(cards)}</div></section>
{comparisons}
<section id="motion"><span class="eyebrow">MOTION · SMALL AND UNHURRIED</span><h2>停顿也是动作的一部分</h2>{video}</section>
<section id="qa"><span class="eyebrow">EVIDENCE · REPRODUCIBLE</span><h2>验证记录</h2><span class="status">{esc(report_state)}</span><p>{esc(report_note)}</p>{checks_html}<div class="split"><div class="panel"><h3>新资产成本</h3><div class="table-wrap"><table><thead><tr><th>角色</th><th>三角面</th><th>网格节点</th><th>GLB</th></tr></thead><tbody>{asset_rows}</tbody></table></div><p class="subtle">来自 asset_manifest.json。网格节点不等于实际 Draw Calls；不宣称当前已完成LOD优化。</p></div><div class="panel"><h3>接触与地面</h3><p>接段地面采样：{esc(validation.get("connector_samples", "待验证"))}。最大IK误差：{esc(validation.get("max_ik_error_m", "待验证"))} m。最大路线速度：{esc(validation.get("max_speed_mps", "待验证"))} m/s。</p><p class="subtle">{esc("；".join(animation_summary) or "独立角色动画报告待产生")}</p></div></div><p class="links">{"".join(report_links)}</p><div class="review-note">Art Review 需要实际看图和动作：做题家是否仍像、骑行是否自然、后院读书是否融入静区、北接段是否可信。自动报告只证明它检查过的数值与物理项目，不证明每张图已达到宣传成片质量。</div></section>
{performance_html}
<section><span class="eyebrow">BLENDER · PRODUCTION PROOF</span><h2>生产资产姿态证据</h2><div class="proof-grid">{"".join(proof_cards)}</div></section>
<section><span class="eyebrow">BASELINE · PRESERVED</span><h2>保留已有成果，才谈继续扩展</h2><div class="proof-grid">{"".join(baseline_cards)}</div><p><a href="../../benchmarks/accepted_v0_4/manifest.json">冻结清单</a> · <a href="../../docs/CHARACTER_PIPELINE.md">角色流程</a> · <a href="../../docs/CHARACTER_REGISTRY.md">角色总表</a> · <a href="../../docs/ENVIRONMENT_EXPANSION_PLAN.md">完整东区路线</a> · <a href="../../docs/QA_CHECKLIST.md">QA检查表</a></p></section>
<footer>生成于 {esc(datetime.now().isoformat(timespec="seconds"))} · tools/population_review.py 只读取配置与证据、生成本页，不建模、不改图。<br>{esc("；".join(WARNINGS))}</footer>
</main></body></html>'''
    (OUT / "review.html").write_text(html_text, encoding="utf-8")
    print(json.dumps({"gallery": str(OUT / "review.html"), "godot_images": len(existing), "planned": len(SHOTS), "video": video_path.is_file(), "validation_passed": validation.get("passed"), "warnings": WARNINGS}, ensure_ascii=True))


if __name__ == "__main__":
    main()
