"""Wave 2 local evidence gallery. Reads outputs; never renders or edits imagery."""
from __future__ import annotations

import html
import hashlib
import json
import re
from collections import Counter
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "renders/wave2"
READ_WARNINGS = []
COLORS = {"Hero": "#d8b775", "Ambient": "#91beb6", "Creature": "#d7a0ab"}
NAME = {"raiden": "雷电将军", "march7": "三月七", "meituan": "美团袋鼠", "doubao": "豆包共读伙伴", "leaf_cat": "观察落叶的猫"}
PLANNED = {
    "01_overview": ("五处故事，仍是一座校园", "Godot / 全景", "空间、树影和留白仍是主体，五个新节点分散在相邻小区域。"),
    "02_baseline": ("熟悉的核心区仍在", "Godot / 环境回归", "保留一教U形、花树和原人口布局；人物身份另看15号做题家近景。"),
    "03_raiden_close": ("树荫读书 · 雷电将军", "Godot / 新Hero近景", "辨认深紫发、长辫、紫花金簪、交领和酒红束腰。"),
    "04_raiden_story": ("在树影里读完这一页", "Godot / Hero故事", "读书、微抬眼、翻页是校园改编；人物服从安静环境。"),
    "05_march7_close": ("校园取景 · 三月七", "Godot / 新Hero近景", "原冰/存护外观的粉白发束、蓝色夹饰、层叠衣服与实体相机。"),
    "06_march7_story": ("给花树留一张照片", "Godot / Hero故事", "用相机取景，区别于原手机摄影同学；没有战斗或强粒子表演。"),
    "07_meituan_close": ("等取餐的袋鼠", "Godot / 品牌Ambient", "长双耳、大黑鼻、奶油胸口与长尾共同识别，不能只靠一片黄色。"),
    "08_meituan_order": ("检查一下保温箱", "Godot / 轻活动节点", "手随箱盖移动，尾部留出路面空间；配送等候小故事由项目创作。"),
    "09_doubao_close": ("带着资料的豆包伙伴", "Godot / 头像校园化", "官方只确认头肩头像；深棕偏分bob与脸部保留，朴素全身由项目补全。"),
    "10_doubao_story": ("指一行字，再继续读", "Godot / 共读节点", "共读动作轻且慢，道具与手接触，不用悬浮Logo代替身份。"),
    "11_cat_leaf": ("猫与一片落叶", "Godot / 原创Creature", "与原长椅趴猫分开：短暂看叶、嗅闻、停坐，保持小体量。"),
    "12_west_walk": ("西南树荫步道", "Godot / 连接区域", "地图核对的道路旁停留点，避免落在后勤楼实体中。"),
    "13_east_garden": ("东花园的取景角落", "Godot / 连接区域", "围绕真实路径与花园关系组织人物，不复制新建筑填背景。"),
    "14_south_reading": ("广场东侧的一页资料", "Godot / 连接区域", "共读点位在陆地侧，避开中央水池，留出舒适通行面。"),
    "15_tiku_preserved": ("做题家的这一页还没写完", "Godot / Hero身份回归", "沿用已接受长椅版身份与原始动作，长椅前没有新桌子。"),
}


def esc(value):
    return html.escape(str(value), quote=True)


def read_json(path):
    if not path.is_file():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, ValueError) as exc:
        READ_WARNINGS.append(f"{path.name}: {type(exc).__name__}")
        return {}


def actor_list(data):
    if isinstance(data, list):
        return [x for x in data if isinstance(x, dict)]
    if isinstance(data, dict):
        items = data.get("actors", data.get("nodes", data.get("characters", [])))
        if isinstance(items, dict):
            return [dict(value, id=key) for key, value in items.items() if isinstance(value, dict)]
        if isinstance(items, list):
            return [x for x in items if isinstance(x, dict)]
    return []


def vector(value):
    if isinstance(value, (list, tuple)) and len(value) >= 3:
        return [float(v) for v in value[:3]]
    if isinstance(value, dict) and all(k in value for k in ("x", "y", "z")):
        return [float(value[k]) for k in ("x", "y", "z")]
    if isinstance(value, str):
        parts = re.findall(r"[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?", value)
        if len(parts) == 3:
            return [float(v) for v in parts]
    return None


def join_story_positions(actors, modules):
    """Runtime coordinates live only in module_layout story_nodes."""
    positions = {
        node.get("id"): node
        for module in modules.get("modules", [])
        for node in module.get("story_nodes", [])
        if module.get("enabled", True) and node.get("id")
    }
    joined = []
    for actor in actors:
        item = dict(actor, _wave2=True)
        node = positions.get(actor.get("node_ref"))
        if node and vector(node.get("position")):
            item["position"] = node["position"]
        else:
            READ_WARNINGS.append(f"Unresolved story position: {actor.get('id', '')}")
        joined.append(item)
    return joined


def local_media(name):
    """Accept output-relative existing media, never a remote or traversing URL."""
    if not isinstance(name, str):
        return None
    candidate = (OUT / name).resolve()
    if candidate.is_relative_to(OUT.resolve()) and candidate.is_file():
        return candidate.relative_to(OUT).as_posix()
    return None


def frame_card(filename, title, label, note, detail=""):
    return f'<figure><a href="{esc(filename)}" target="_blank"><img src="{esc(filename)}" alt="{esc(label + " · " + title)}" loading="lazy"></a><figcaption><span class="tag">{esc(label)}</span><h3>{esc(title)}</h3><p>{esc(note)}</p><small>{esc(detail)}</small></figcaption></figure>'


def map_svg(actors, site, modules):
    placed = [(a, vector(a.get("position", a.get("pos")))) for a in actors]
    placed = [(a, p) for a, p in placed if p]
    enabled_modules = [m for m in modules.get("modules", []) if m.get("enabled", True)]
    bounds = [m["bounds"] for m in enabled_modules if isinstance(m.get("bounds"), list) and len(m["bounds"]) == 4]
    xmin = min([-84] + [p[0] - 15 for _, p in placed] + [b[0] - 4 for b in bounds])
    xmax = max([84] + [p[0] + 15 for _, p in placed] + [b[2] + 4 for b in bounds])
    zmin = min([102] + [p[2] - 15 for _, p in placed] + [b[1] - 4 for b in bounds])
    zmax = max([242] + [p[2] + 15 for _, p in placed] + [b[3] + 4 for b in bounds])
    scale = min(760 / (xmax - xmin), 550 / (zmax - zmin))
    x = lambda v: 28 + (float(v) - xmin) * scale
    y = lambda v: 25 + (float(v) - zmin) * scale
    width = (xmax - xmin) * scale + 56
    height = (zmax - zmin) * scale + 70
    out = [f'<svg viewBox="0 0 {width:.1f} {height:.1f}" role="img" aria-label="新旧全部人口的配置平面示意">',
           f'<rect x="{x(-80):.2f}" y="{y(118):.2f}" width="{160*scale:.2f}" height="{120*scale:.2f}" fill="#303e35" stroke="#758070" rx="5"/>']
    hall = site.get("hall_outline", []) if isinstance(site, dict) else []
    if hall:
        points = " ".join(f"{x(p[0]):.2f},{y(p[1]):.2f}" for p in hall)
        out.append(f'<polygon points="{points}" fill="#75584b" stroke="#ae846d"/>')
    for mod in enabled_modules:
        b = mod.get("bounds")
        poly = mod.get("polygon")
        if poly:
            points = " ".join(f"{x(p[0]):.2f},{y(p[1]):.2f}" for p in poly)
            out.append(f'<polygon points="{points}" fill="#566653" stroke="#adbb9b" opacity=".8"/>')
        elif isinstance(b, list) and len(b) == 4:
            x0, z0, x1, z1 = b
            out.append(f'<rect x="{x(x0):.2f}" y="{y(z0):.2f}" width="{(x1-x0)*scale:.2f}" height="{(z1-z0)*scale:.2f}" fill="#566653" stroke="#adbb9b" opacity=".8"/>')
        for road in mod.get("paths", []):
            points = " ".join(f"{x(p[0]):.2f},{y(p[1]):.2f}" for p in road.get("points", []))
            out.append(f'<polyline points="{points}" fill="none" stroke="#b7b0a0" stroke-width="{road.get("width",2)*scale:.2f}" opacity=".7"/>')
    for barrier in modules.get("protected_polygons", []):
        points = " ".join(f"{x(p[0]):.2f},{y(p[1]):.2f}" for p in barrier.get("polygon", []))
        color = "#45676c" if barrier.get("kind") == "water" else "#69594f"
        out.append(f'<polygon points="{points}" fill="{color}" stroke="#898779"><title>{esc(barrier.get("id", ""))}</title></polygon>')
    for actor, p in placed:
        tier = actor.get("tier", actor.get("type", "Ambient"))
        color = COLORS.get(tier, "#b0b6a4")
        radius = 6 if tier == "Hero" else 5 if tier == "Ambient" else 3.3
        fresh = actor.get("_wave2", False)
        if fresh:
            out.append(f'<circle cx="{x(p[0]):.2f}" cy="{y(p[2]):.2f}" r="{radius+4}" fill="none" stroke="{color}" opacity=".65"/>')
        out.append(f'<circle cx="{x(p[0]):.2f}" cy="{y(p[2]):.2f}" r="{radius}" fill="{color}" stroke="#1c2720"><title>{esc(actor.get("name",actor.get("id","")))} · {esc(tier)} · {esc(p)}</title></circle>')
        end = vector(actor.get("path_end"))
        if end:
            out.append(f'<path d="M{x(p[0]):.2f},{y(p[2]):.2f}L{x(end[0]):.2f},{y(end[2]):.2f}" stroke="{color}" stroke-dasharray="3 4" opacity=".6"/>')
    out.append(f'<text x="28" y="16" fill="#d8d1bd" font-size="12">N ↑ · 单位米</text><text x="{width-26:.1f}" y="{height-15:.1f}" text-anchor="end" fill="#d8d1bd" font-size="11">外圈标记 = 本轮新节点</text></svg>')
    return "".join(out)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    original = actor_list(read_json(ROOT / "godot/data/population.json"))
    new_config = read_json(ROOT / "godot/data/wave2_nodes.json")
    module_config = read_json(ROOT / "godot/data/module_layout.json")
    new = join_story_positions(actor_list(new_config), module_config)
    merged = original + new
    site = read_json(ROOT / "godot/assets/site.json")
    validation = read_json(OUT / "validation.json")
    capture = read_json(OUT / "capture_report.json")
    motion = read_json(OUT / "motion_manifest.json")
    media_validation = read_json(OUT / "video_validation.json") or read_json(OUT / "media_validation.json")
    performance = read_json(OUT / "performance.json")
    manifests = {**read_json(OUT / "cameo_manifest.json"), **read_json(OUT / "mascot_manifest.json")}
    all_counts = Counter(a.get("tier", a.get("type", "Ambient")) for a in merged)
    new_counts = Counter(a.get("tier", a.get("type", "Ambient")) for a in new)
    cards, published, camera_rows = [], [], []
    for shot in capture.get("shots", []) if isinstance(capture, dict) else []:
        if not isinstance(shot, dict):
            continue
        filename = local_media(shot.get("file", shot.get("path", "")))
        if not filename or Path(filename).suffix.lower() not in (".png", ".jpg", ".jpeg", ".webp"):
            continue
        key = Path(filename).stem
        title, tag, caption = PLANNED.get(key, (shot.get("name", key), "Godot / 实际捕获", "此机位由实际capture_report登记。"))
        details = []
        for k, label in [("time", "动作时间"), ("camera", "实际相机"), ("fov", "FOV")]:
            if k in shot:
                details.append(f"{label}: {shot[k]}")
        if "position" in shot and "camera" not in shot:
            details.append("相机位置: " + str([round(v, 3) for v in shot["position"]]))
        if "projection" in shot:
            details.append("投影: " + str(shot["projection"]))
        if "size" in shot:
            details.append("正交尺寸: " + str(shot["size"]))
        cards.append(frame_card(filename, title, tag, caption, " · ".join(details)))
        published.append(key)
        camera_rows.append(f'<tr><td><a href="{esc(filename)}">{esc(key)}</a></td><td>{esc(shot.get("camera", shot.get("position", "未记录")))}</td><td>{esc(shot.get("fov", "—"))}</td><td>{esc(shot.get("time", "—"))}</td></tr>')
    pending = [value[0] for key, value in PLANNED.items() if key not in published]
    pending_html = f'<p class="pending">尚未由本轮捕获报告确认：{esc("、".join(pending))}。计划项不算已完成图。</p>' if pending else ""
    lead = local_media("01_overview.png") if "01_overview" in published else None
    lead_html = f'<a class="lead" href="{lead}" target="_blank"><img src="{lead}" alt="五故事节点实际Godot总览"></a>' if lead else '<div class="pending">新总览尚未由capture_report确认。已存在的Blender图只是生产证明，不代替Godot场景。</div>'
    actor_rows = "".join(f'<tr><td>{"新 · " if a.get("_wave2") else "保留 · "}{esc(a.get("name",a.get("id","")))}</td><td>{esc(a.get("tier",a.get("type","")))}</td><td>{esc(a.get("position",a.get("pos","待配置")))}</td></tr>' for a in merged)
    asset_rows = "".join(f'<tr><td>{esc(NAME.get(k,k))}</td><td>{esc(v.get("triangles","未记录"))}</td><td>{esc(v.get("mesh_nodes","未记录"))}</td><td>{esc(v.get("period",v.get("cycle_seconds","未记录")))}</td><td>{esc(v.get("glb",""))}</td></tr>' for k,v in manifests.items() if isinstance(v,dict))
    checks = validation.get("checks", {}) if isinstance(validation,dict) else {}
    check_labels = {"density":"全人口密度","hero_frozen":"旧Hero冻结","population":"实际人口","land":"陆地可达","finite_pose":"姿态数值","loops":"动作闭环"}
    check_labels.update({"accepted_assets_frozen":"既有受保护资产保持", "connected_routes":"连接路线实走", "core_land":"原核心陆地承托", "expanded_boundaries":"新外边界阻挡", "expanded_ground":"新陆地承托", "five_new_nodes":"五个新故事节点", "ik_contact":"手/道具IK接触", "local_density":"新旧全人口局部密度", "pose_finite":"姿态数值有限", "soles_grounded":"鞋底接地", "story_actions":"故事动作覆盖", "story_nodes_on_land":"故事节点处于陆地"})
    check_html = '<ul class="checks">' + "".join(f'<li class="{"good" if value is True else "bad" if value is False else ""}"><span>{"✓" if value is True else "待修" if value is False else "记录"}</span>{esc(check_labels.get(k,k))}</li>' for k,value in checks.items()) + '</ul>' if checks else '<p class="pending">本轮完整场景validation.json尚未产生。</p>'
    proof_cards = []
    contact_names = {"meituan_order_blender": "袋鼠 · 看订单", "meituan_open_blender": "袋鼠 · 整理保温箱", "doubao_point_blender": "豆包 · 手指与资料", "leaf_cat_paw_blender": "校园猫 · 爪与落叶"}
    for file in sorted(OUT.glob("*_blender.png")):
        if file.stem in contact_names:
            proof_cards.append(frame_card(file.name, contact_names[file.stem], "Blender / Godot姿态接触复核", "把Godot实际关节矩阵回放到生产模型，检查手/道具接触或爪/落叶距离；这是中性影棚渲染。"))
        else:
            label = file.stem.replace("_blender", "").replace("_", " · ")
            proof_cards.append(frame_card(file.name, label, "Blender / 生产资产", "直接读取生产模型的姿态与轮廓证据，不是Godot实机截图。"))
    comparison_cards = []
    for key in ("03_raiden_close", "05_march7_close", "09_doubao_close", "11_cat_leaf"):
        previous, current = OUT / "round01" / (key + ".png"), OUT / (key + ".png")
        if previous.is_file() and current.is_file() and key in published:
            if hashlib.sha256(previous.read_bytes()).digest() != hashlib.sha256(current.read_bytes()).digest():
                title, _, _ = PLANNED[key]
                comparison_cards.append(frame_card("round01/" + previous.name, title + " · 首轮", "Godot / 迭代留档", "保存原PNG与首轮相机记录，未重绘或调色。"))
                comparison_cards.append(frame_card(current.name, title + " · 当前", "Godot / 当前捕获", "与首轮并列评估身份、受光和背景；若相机有调整，请同时核对两份报告。"))
    comparison_html = '<section><span class="tag">RENDER → REVIEW → FIX</span><h2>看见问题，再看修改后的结果</h2><p>以下只列真实文件发生变化的首轮/当前画面。相机调整本身不是模型改进的证明，身份和校园背景分别检查。</p><div class="gallery">' + ''.join(comparison_cards) + '</div><a href="round01/capture_report.json">首轮捕获记录</a></section>' if comparison_cards else ''
    refs = [
        ("雷电将军", "../../../references/characters/wave2/research/raiden_3.png", "HoYoLAB官方角色资料；查看深紫长辫、紫花/金簪与交领腰带", "https://www.hoyolab.com/article/760845"),
        ("三月七", "../../../references/characters/wave2/research/march7_1.jpg", "HoYoLAB官方原冰/存护外观；粉白发束、蓝饰物和相机", "https://www.hoyolab.com/article/4373020"),
        ("美团袋鼠", "../../../references/characters/wave2/research/meituan_mascot_pack_01.jpg", "美团官方媒体包；长耳、大黑鼻、小眼、浅胸口与长尾", "https://www.meituan.com/media"),
        ("豆包头像", "../../../references/characters/wave2/research/doubao_official_icon.png", "官网当前192px头肩头像；全身/道具/共读行为由项目补全", "https://www.doubao.com/download/desktop"),
    ]
    refs_html = "".join(f'<tr><td>{esc(name)}</td><td>{esc(note)}</td><td><a href="{esc(local)}" target="_blank">本地研究原图</a> · <a href="{esc(page)}" target="_blank">来源页</a></td></tr>' for name,local,note,page in refs if (OUT/local).is_file())
    video = None
    for name in ("wave2_demo.mp4", "campus_life_demo.mp4", "motion_manifest.mp4"):
        if local_media(name):
            video = name
            break
    if video:
        seconds = motion.get("frames",0) / motion.get("fps",1) if motion.get("fps") else None
        timing = f'{motion.get("width","—")}×{motion.get("height","—")} · {motion.get("fps","—")} fps · {motion.get("frames","—")} 帧' + (f' · {seconds:g}s' if seconds else "")
        playback = "首/中/末三帧与元数据解码通过，见video_validation.json；没有解码全部1800帧，也不声称GUI连续播放验收。" if media_validation.get("passed") is True else "视频文件已存在；可播放性和完整时长仍需实际解码验证。"
        clip_rows = "".join(f'<tr><td>{esc(clip.get("name", ""))}</td><td>{esc(clip.get("seconds", "—"))}</td><td>{esc(clip.get("frames", "—"))}</td></tr>' for clip in motion.get("clips", []))
        video_html = f'<video controls preload="metadata" src="{esc(video)}"></video><p class="muted">{esc(timing)}。来自Godot实际帧，不含AI重绘或补帧；{esc(playback)}</p><div class="table-wrap"><table><thead><tr><th>实际片段</th><th>秒数</th><th>帧数</th></tr></thead><tbody>{clip_rows}</tbody></table></div>'
    else:
        video_html = '<p class="pending">本轮完整动作视频尚未产生。计划按五个实际周期32+28+32+30+28秒捕获，共150秒；单独的动作JSON、帧数计划或Blender截图不等于完成实机短片。</p>'
    report_links = "".join(f'<a href="{p.name}">{p.name}</a>' for p in [OUT/x for x in ("capture_report.json","validation.json","cameo_manifest.json","mascot_manifest.json","cameo_validation.json","mascot_contact_review.json","motion_manifest.json","video_validation.json","media_validation.json","delivery_validation.json","performance.json")] if p.is_file())
    qa_facts = []
    if validation:
        if "added_area_m2" in validation:
            qa_facts.append(f'新增多边形陆地 {validation["added_area_m2"]:g} ㎡')
        if "ground_samples" in validation:
            qa_facts.append(f'陆地格点 {validation["ground_samples"]}')
        if "routes" in validation:
            qa_facts.append(f'实际步行 {sum(r.get("reached") is True for r in validation["routes"])}/{len(validation["routes"])} 条到达')
        if "frozen_files" in validation:
            qa_facts.append(f'受保护文件 {sum(v is True for v in validation["frozen_files"].values())}/{len(validation["frozen_files"])} 保持')
        if "max_ik_error_m" in validation:
            qa_facts.append(f'最大IK误差 {validation["max_ik_error_m"]:.3g} m')
    qa_facts_html = '<p class="muted">' + esc(' · '.join(qa_facts)) + '</p>' if qa_facts else ''
    review_links = "".join(f'<a href="../../docs/{name}">{label}</a>' for name,label in [("IP_CHARACTER_PIPELINE.md","IP角色流程"),("HERO_CHARACTER_REGISTRY.md","角色总表"),("STORY_NODE_LAYOUT.md","节点布局"),("WAVE2_ART_REVIEW.md","本轮Art Review"),("WAVE2_PERFORMANCE.md","性能解释")] if (ROOT/"docs"/name).is_file())
    performance_html = ''
    if performance.get("completed") and performance.get("resolution_verified"):
        rows = ''.join(f'<tr><td>{esc(view.get("name", view.get("id", "")))}</td><td>{float(view.get("effective_fps", 0)):.2f}</td><td>{float(view.get("median_frame_ms", 0)):.2f} ms</td><td>{float(view.get("p95_frame_ms", 0)):.2f} ms</td><td>{float(view.get("draw_calls", {}).get("median", 0)):,.0f}</td></tr>' for view in performance.get("views", []))
        resolution = '×'.join(str(n) for n in performance.get("requested_resolution", []))
        performance_html = f'<section id="performance"><span class="tag">PERFORMANCE · ORDINARY LIVE WINDOW</span><h2>普通游览窗口的实际表现</h2><p>{esc(resolution)} · {esc(performance.get("gpu", ""))} · Forward+。每机位预热{esc(performance.get("warm_frames_per_view", "—"))}帧，采样{esc(performance.get("measured_frames_per_view", "—"))}帧，全部新旧人物与环境动态运行。</p><div class="table-wrap"><table><thead><tr><th>当前场景机位</th><th>交付FPS</th><th>帧时间中位</th><th>P95</th><th>Draw中位</th></tr></thead><tbody>{rows}</tbody></table></div><p class="muted">VSync开启；每机位有效采样约1.25秒，不推断未限速余量或长时间稳定性。所有视角加载当前版本，不是新旧版本回归比较；也不是4K导出速度。退出时保留7个Texture RID清理警告。<a href="../../docs/WAVE2_PERFORMANCE.md">完整测量条件与局限</a></p></section>'
    css = '''
*{box-sizing:border-box}html{color-scheme:dark}body{margin:0;background:#19201c;color:#eee8da;font:16px/1.75 system-ui,"Microsoft YaHei",sans-serif}main{max-width:1380px;margin:auto;padding:50px 30px 70px}a{color:#bad2bc;text-decoration:none}a:hover{text-decoration:underline}h1,h2,h3,p{margin:0}h1{font-size:clamp(32px,5.1vw,62px);line-height:1.17;letter-spacing:.02em;font-weight:550;margin:12px 0 24px}h2{font-weight:550;font-size:29px;margin:9px 0 18px}h3{font-size:21px;font-weight:550;margin:7px 0}p{margin:12px 0}.tag{font-size:11px;letter-spacing:.14em;color:#c4b792}.intro{max-width:860px;color:#c8cbbd}nav,.links{display:flex;gap:22px;flex-wrap:wrap;font-size:14px;margin:22px 0 30px}.lead img{width:100%;display:block;border-radius:12px}.counts{display:grid;grid-template-columns:repeat(4,1fr);margin:26px 0;border-block:1px solid #4a5547}.count{padding:22px 17px;border-right:1px solid #4a5547}.count:last-child{border:0}.count b{font-size:34px;font-weight:500;color:#e6ca8e;display:block;line-height:1.3}.count span{display:block}.count small,.muted,small{color:#a9b2a1;font-size:13px}section{margin-top:58px}.split{display:grid;grid-template-columns:1fr 1fr;gap:28px;align-items:start}.panel{padding:22px;background:#253126;border:1px solid #465543;border-radius:12px}.map{padding:8px}.map svg{width:100%;height:auto;display:block}.legend{display:flex;gap:17px;flex-wrap:wrap;font-size:13px;padding:14px}.dot{width:8px;height:8px;border-radius:50%;display:inline-block;margin-right:7px}.table-wrap{overflow:auto}table{border-collapse:collapse;width:100%;font-size:13px}th,td{padding:10px 8px;border-bottom:1px solid #495346;text-align:left;vertical-align:top}th{color:#c1cbb7;font-weight:500}.gallery{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:25px}figure{margin:0;min-width:0}figure img{width:100%;height:auto;display:block;border-radius:11px;background:#232f25}figcaption{padding:18px 3px 22px}figcaption p{font-size:15px;color:#c2c9b8}figcaption small{overflow-wrap:anywhere}.proof{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:20px}.proof h3{font-size:15px}.proof p{font-size:12px}.pending{padding:24px;background:#293026;border:1px dashed #72805e;color:#c1c8ae;border-radius:10px}.checks{display:grid;grid-template-columns:1fr 1fr;gap:8px;list-style:none;padding:0}.checks li{padding:8px 12px;background:#243126;font-size:13px;border-radius:6px}.checks span{display:inline-block;min-width:47px}.good span{color:#acd6a3}.bad span{color:#dfb17b}.badge{display:inline-block;border:1px solid #778060;padding:5px 12px;border-radius:20px;font-size:13px}video{width:100%;max-height:80vh;background:#0f1711;border-radius:10px}footer{border-top:1px solid #4a5547;margin-top:60px;padding-top:22px;font-size:12px;color:#929e8a}@media(max-width:860px){main{padding:28px 18px}.split,.gallery{grid-template-columns:1fr}.proof,.counts{grid-template-columns:1fr 1fr}.count:nth-child(2){border-right:0}}@media(max-width:520px){.proof,.checks{grid-template-columns:1fr}h2{font-size:25px}.count b{font-size:28px}}
'''
    count = lambda value,label,note: f'<div class="count"><b>{esc(value)}</b><span>{esc(label)}</span><small>{esc(note)}</small></div>'
    metrics = count(len(new),"新配置节点","目标5，按部署文件统计") + count(f'{new_counts.get("Hero",0)} / {new_counts.get("Ambient",0)} / {new_counts.get("Creature",0)}',"新增 H / A / C","Hero / Ambient / Creature") + count(len(published),"报告确认实机图","15个当前机位，报告可追加") + count(f'{all_counts.get("Hero",0)} / {all_counts.get("Ambient",0)} / {all_counts.get("Creature",0)}',"新旧合并 H / A / C","全局数量，不是单区预算")
    status = "场景自动检查通过" if validation.get("passed") is True else "场景检查存在待修项目" if validation else "场景检查待运行"
    page = f'''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>科大校园 · 五处新故事</title><style>{css}</style></head><body><main>
<header><span class="tag">USTC EAST CAMPUS · WAVE 2 / FIVE STORY NODES</span><h1>熟悉的角色，<br>校园里的新片刻。</h1><p class="intro">两位游戏角色校园cameo、两位品牌形象校园伙伴与一只观察落叶的猫。新节点分散放进资料支持的相邻区域，保留原做题家与既有校园生活。</p><nav><a href="#godot">实机场景</a><a href="#layout">新旧人口</a><a href="#motion">动作展示</a><a href="#qa">运行验证</a><a href="#references">参考依据</a><a href="../../docs/WORKFLOW_INDEX.md">工作流入口 ↗</a></nav></header>
{lead_html}<div class="counts">{metrics}</div><p class="muted">本页只读取真实文件。新配置不存在时显示0个已配置，不代表研究被取消；模型已导出、截图已产生与艺术验收通过分别记录。</p>
<section id="layout"><span class="tag">STORY NODES · EXISTING + NEW</span><h2>把新故事放远一点，让原来的校园留下来</h2><div class="split"><div class="panel map">{map_svg(merged,site,module_config)}<div class="legend"><span><i class="dot" style="background:#d8b775"></i>Hero</span><span><i class="dot" style="background:#91beb6"></i>Ambient</span><span><i class="dot" style="background:#d7a0ab"></i>Creature</span></div></div><div><p>原population配置与wave2_nodes合并显示；小点为初始位置，外圈表示本轮新角色。每约100×100米仍检查1–2 Hero、2–4 Ambient、1–3 Creature，不能只统计新人。精确道路和可达范围以场景模块与物理报告为准。</p><div class="table-wrap"><table><thead><tr><th>角色</th><th>类型</th><th>配置位置</th></tr></thead><tbody>{actor_rows}</tbody></table></div></div></div></section>
<section id="godot"><span class="tag">GODOT · ACTUAL VIEWPORT</span><h2>五个节点的实际样子</h2><p>图片仅从capture_report登记的现有文件读取，点击可看原图。人物近景检查身份，场景中景检查小故事与校园关系。</p>{pending_html}<div class="gallery">{"".join(cards)}</div></section>
{comparison_html}
<section id="motion"><span class="tag">MOTION · QUIET STORY LOOPS</span><h2>有动作，也有足够的停顿</h2>{video_html}</section>
<section id="qa"><span class="tag">VALIDATION · NOT AUTOMATIC ART APPROVAL</span><h2>运行证据</h2><span class="badge">{esc(status)}</span><p>数值、接触与密度通过不自动等于人物身份或艺术质量通过。原Hero保留、新角色像参考、静谧尺度与连续游览都需要真实看图和动作。</p>{qa_facts_html}{check_html}<div class="links">{report_links}{review_links}</div><div class="panel table-wrap"><table><thead><tr><th>角色</th><th>三角面</th><th>网格节点</th><th>循环秒数</th><th>运行资产</th></tr></thead><tbody>{asset_rows}</tbody></table><p class="muted">清单面数不是包含阴影/深度通道的渲染提交量；网格节点也不等于真实Draw Calls。未实测的性能或LOD不包装成已完成。</p></div></section>
{performance_html}
<section><span class="tag">BLENDER · PRODUCTION ASSETS</span><h2>先验证造型，再检查实机</h2><div class="proof">{"".join(proof_cards)}</div></section>
<section id="references"><span class="tag">REFERENCES · RESEARCH ONLY</span><h2>什么来自参考，什么属于校园改编</h2><div class="table-wrap"><table><thead><tr><th>身份</th><th>已查看的依据</th><th>研究链接</th></tr></thead><tbody>{refs_html}</tbody></table></div><p class="muted">这些原图只在本地reference中研究，不是运行贴图。游戏人物与品牌形象仍属于原IP，本项目未声称获官方授权或合作；校园动作和衍生几何是项目制作，inspired variant不自动解决许可。豆包仅头像有官方依据，身体/服装补全与共读行为是本项目设计。奶蛙、牛来的来源/具体版本未收敛，本轮没有硬做。<a href="../../../references/characters/wave2/sources.json">来源总索引</a></p></section>
<details><summary>查看捕获机位记录</summary><div class="table-wrap"><table><thead><tr><th>文件</th><th>相机</th><th>FOV</th><th>动作时间</th></tr></thead><tbody>{"".join(camera_rows)}</tbody></table></div></details>
<footer>生成于 {datetime.now().isoformat(timespec="seconds")} · tools/wave2_review.py仅生成HTML，不修改图像或模型。{esc("；".join(READ_WARNINGS))}</footer>
</main></body></html>'''
    (OUT / "review.html").write_text(page, encoding="utf-8")
    print(json.dumps({"gallery":str(OUT/"review.html"),"new_configured":len(new),"godot_report_images":len(published),"blender_proofs":len(proof_cards),"video":video,"validation_passed":validation.get("passed"),"warnings":READ_WARNINGS},ensure_ascii=True))


if __name__ == "__main__":
    main()
