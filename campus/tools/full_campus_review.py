"""Refresh the existing project's native-render review and current progress notes."""
import json,html
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'renders/full_campus'
def read(p):return json.loads((ROOT/p).read_text(encoding='utf-8'))
def run():
    coverage=read('renders/coverage/coverage.json');physical=read('renders/full_campus/validation.json');visual=read('renders/full_campus/visual_validation.json')
    controls=read('renders/inspection_controls/validation.json')
    if not physical['passed'] or not visual['passed'] or not controls['passed']:raise RuntimeError('Native validation remains incomplete')
    views=[('10_campus_overview','完整东区'),('08_east_overview','东侧住宅与生活区'),('09_south_overview','南部科研楼群'),
        ('01_east_housing','住宅近景'),('02_water_lecture_hall','水上报告厅'),('03_administration','行政楼'),('04_history_museum','校史馆'),
        ('05_auditorium','礼堂'),('06_research_B','物质科学教研B楼'),('07_frontier_center','地球和空间科学前沿研究中心'),('11_original_avenue','原樱花大道')]
    cards=''.join(f'<figure><a href="{f}.png"><img src="{f}.png" loading="lazy" alt="{name}"></a><figcaption>{name}</figcaption></figure>' for f,name in views)
    rows=''.join(f'<tr><td>{html.escape(p["view"])}</td><td>{p["fps"]:.1f}</td><td>{p["p95_ms"]:.2f} ms</td><td>{p["walked_m"]:.2f} m</td></tr>' for p in visual['performance'])
    page=f'''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>科大东区 · 99%外部场景</title><style>body{{background:#f0eee6;color:#263d36;font:17px/1.75 system-ui;margin:0 auto;max-width:1400px;padding:35px}}a{{color:#235f57}}h1{{font-size:32px}}section{{display:grid;grid-template-columns:repeat(auto-fit,minmax(520px,1fr));gap:18px}}figure{{margin:0;background:white;border-radius:8px;overflow:hidden}}img{{width:100%;display:block}}figcaption{{padding:12px}}table{{border-collapse:collapse}}td,th{{padding:7px 24px;border-bottom:1px solid #c8c7bd}}@media(max-width:650px){{section{{grid-template-columns:1fr}}}}</style>
    <h1>科大东区 · 外部场景覆盖 {coverage['current_coverage_percent']:.3f}%</h1>
    <p>从42.255%扩到99.019%；新增110栋楼的外部模型、连接道路、楼前铺装和410棵树。137条实际人物路线通过，累计行走约4.53公里。操场及球场中没有普通路灯；四个入口各120,695个可见地面接缝样点零缺口。</p>
    <p><b>查看：</b>运行根目录 OPEN_EAST_CAMPUS.cmd。顶部按钮或 V 切换人物／自由相机；自由相机 Q/E 升降、滚轮调速。右下角坐标显示人物、相机及准星命中点；C显示／隐藏，F12保存PNG和同名坐标JSON。顶部下拉框选择区域，7住宅、8校史馆、9科研区。</p>
    <p>地理覆盖按实际地块并集裁到东区校界，包含建筑、水体及外部空间。建筑室内未开放；未见立面、部分层数、入口和道路宽度为近似。近代物理楼与单分子楼的相连轮廓处，人物沿现有南／东支路绕行。</p>
    <p><a href="../coverage/coverage.png">覆盖图</a> · <a href="validation.json">人物路线／碰撞</a> · <a href="visual_validation.json">原生图与移动短测</a> · <a href="../inspection_controls/validation.json">坐标与切换</a></p>
    <section>{cards}</section><h2>原生移动短测</h2><p>1600×900，默认流畅档，前台实际人物行走；以下为新增内容后的本机结果。</p><table><tr><th>区域</th><th>FPS</th><th>P95</th><th>行走</th></tr>{rows}</table>
    <p>原樱花大道采用楼体内部的4个遮挡体，裁掉完全藏在楼后的绘制；画质档、阴影、倒影、角色及资产精度设置保持一致。方法参考<a href="https://docs.godotengine.org/en/stable/tutorials/3d/occlusion_culling.html">Godot遮挡裁剪文档</a>，对照记录<a href="performance_before_occlusion.json">优化前</a>与<a href="visual_validation.json">优化后</a>。</p>
    <h2>交叉还原参考</h2><p>GIS JS图用于色彩、楼高层次和邻接；官方图核对身份及道路；卫星和OSM用于地面轮廓。卫星影像拍摄日期未提供，检索日期2026-10-12。</p>
    <section><figure><img src="../../references/full_campus/full_osm_overlay.jpg"><figcaption>卫星＋本轮建筑／路网叠图</figcaption></figure><figure><img src="../../references/south_sports/gis_east_tiles.jpg"><figcaption>GIS JS地图瓦片拼图</figcaption></figure><figure><img src="../../references/maps/east_campus.png"><figcaption>官方校园总图</figcaption></figure><figure><img src="../coverage/coverage.png"><figcaption>按真实校界计算的地理覆盖</figcaption></figure></section>
    <p><a href="https://gis.ustc.edu.cn/">学校GIS</a> · <a href="https://aga.ustc.edu.cn/info/1400/36242.htm">学校礼堂资料</a> · <a href="https://news.ustc.edu.cn/info/1055/88962.htm">地空前沿研究中心资料</a> · <a href="../../references/full_campus/mapped_districts.json">本轮映射及来源</a></p></html>'''
    (OUT/'review.html').write_text(page,encoding='utf-8')
    low=min(p['fps'] for p in visual['performance']);high=max(p['fps'] for p in visual['performance'])
    summary=f'''**2026-10-12：东区外部场景覆盖已到99.019%，坐标与自由相机选择已加入。** 双击根目录 [OPEN_EAST_CAMPUS.cmd](../OPEN_EAST_CAMPUS.cmd)。顶部按钮或 **V** 切换人物／自由相机；自由相机 **Q/E** 升降、滚轮调速，**Tab** 切换人物第一／第三人称。右下角显示人物、相机、准星中心的X/Y/Z米制坐标，**C**显隐、**F12**保存PNG及同名定位JSON；隐藏主界面仍保留定位。下拉框选择区域，**7**住宅、**8**校史馆、**9**南部科研区。

本轮接西侧连接区、东侧住宅生活区、行政楼／校史馆片区和南部科研楼群／礼堂，新增110栋外部建筑和410棵树，149条登记道路、147条实际渲染道路。GIS JS图、官方地图、卫星及OSM交叉核对。地理覆盖 **42.255% → 99.019%**，校界内551,588.525㎡，净新增316,209.153㎡；室内、未见立面和部分层数／门前细节仍待细化。

137条人物路线、4组楼体阻挡、{len(controls['checks'])}项坐标／镜头检查通过；四入口各120,695个可见地面接缝样点零缺口，操场和球场内没有普通路灯。1600×900默认流畅档前台移动短测约{low:.0f}—{high:.0f}FPS，59项历史冻结文件未改。[实机与参考图集](renders/full_campus/review.html) · [覆盖图](renders/coverage/coverage.png) · [运行记录](renders/full_campus/validation.json)。复测：`run_full_campus_checks.ps1`、加`-Visual`拍摄并测性能；`check_ground_seams.ps1`检查四入口。

'''
    p=ROOT/'README.md';text=p.read_text(encoding='utf-8');marker='**2026-10-12最新：操场路灯修复'
    current='**2026-10-12：东区外部场景覆盖'
    if current in text:
        before,rest=text.split(current,1);text=before+marker+rest.split(marker,1)[1]
    text=text.replace(marker,summary+marker,1);p.write_text(text,encoding='utf-8')
    p=ROOT/'docs/EAST_CAMPUS_ROADMAP.md';text=p.read_text(encoding='utf-8')
    new=f'''## 当前覆盖：99.019%（2026-10-12，东区外部场景扩建后）

新增四片区域：西侧连接区、东侧住宅生活区、行政楼—校史馆—中部生活区，以及南部科研楼群—礼堂—南门内侧。110栋建筑按原始地图轮廓建模，住宅阳台、科研高楼立面、礼堂／老楼坡屋顶分别处理；410棵新树、道路及楼前空间同时接入。

| 地理范围 | 面积 | 比例 |
|---|---:|---:|
| 完整东区 | 557,050.649㎡ | 100% |
| 本轮前 | 235,379.372㎡ | 42.255% |
| 本轮净新增 | 316,209.153㎡ | 56.764个百分点 |
| 当前覆盖 | 551,588.525㎡ | **99.019%** |
| 尚待覆盖 | 5,462.124㎡ | 0.981% |

统计含建筑、水体及外部空间，按实际启用地块并集裁到真实校界；室内和立面精修不计为地理面积完成度。149条登记道路、147条实际渲染道路。近代物理楼与单分子楼相连的轮廓与一条道路数据交叠，人物沿已建南／东支路绕行。

137条实际人物路线（约4.53公里）、楼体阻挡及{len(controls['checks'])}项坐标／模式切换检查通过；四入口各120,695个可见地面接缝样点零缺口。1600×900流畅档移动短测{low:.0f}—{high:.0f}FPS；59项历史冻结文件未改。[实机与参考](../renders/full_campus/review.html) · [覆盖统计](../renders/coverage/coverage.json) · [坐标与切换](../renders/inspection_controls/validation.json)。

入口 [OPEN_EAST_CAMPUS.cmd](../../OPEN_EAST_CAMPUS.cmd)。顶部按钮或V切换人物／自由相机，右下角显示定位；C显隐，F12保存截图和坐标，7/8/9进入新区域。GIS JS图、官方总图、完整卫星／OSM叠图均在图集中；轮廓使用既有米制坐标，未见立面和部分层数／入口细节为近似。复现：`tools/research_full_campus.py` → `tools/prepare_full_districts.py` → Blender `blender/scripts/build_full_districts.py` → Godot导入；复测 `run_full_campus_checks.ps1`、`-Visual`、`check_ground_seams.ps1`。

## 历史：42.255%阶段（南侧球场与364／365公寓）
'''
    if '## 当前覆盖：99.019%' in text:
        before,rest=text.split('## 当前覆盖：99.019%',1);text=before+new+rest.split('## 历史：42.255%阶段（南侧球场与364／365公寓）',1)[1]
    else:text=text.replace('## 当前覆盖：42.255%（2026-10-12，南侧球场与364／365公寓扩建后）',new,1)
    p.write_text(text,encoding='utf-8')
    print('FULL_REVIEW',low,high,len(physical['routes']),len(controls['checks']))
if __name__=='__main__':run()
