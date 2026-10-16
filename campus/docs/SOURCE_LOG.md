# 来源与许可记录

## 南侧球场、364／365公寓与路灯修正 · 2026-10-12

| 来源 | 用途与实际归档 |
|---|---|
| [官方GIS](https://gis.ustc.edu.cn/) | 解析 `inc/api/maps.js` 和匿名网页会话的 `xbgis?t=1`，得到 `mapdata/zoom3/{x}_{y}.jpg`。x14—22、y5—12拼图为 `references/south_sports/gis_east_tiles.jpg`，可读JS与元数据归档。斜视图用于外观、院落、球场分组和邻接；地面坐标不从斜视图投影。 |
| [官方校园总图](https://indico.pnp.ustc.edu.cn/event/3091/attachments/6396/12868/科大东区校园地图.pdf) | `references/maps/east_campus.png`，核对364／365、羽毛球馆、人文学院及球场相对位置。 |
| [公开卫星服务](https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer)与OSM快照 | `south_satellite.jpg`／`south_osm_overlay.jpg` 核对轮廓、五篮球场、五网球场和小路；拍摄日期未知，2026-10-12取得，沿用site.json米制坐标。 |
| [2026东区网球照片](https://news.ustc.edu.cn/info/1055/95289.htm) | `tennis_2026_1.jpg`／`tennis_2026_2.jpg` 核对蓝绿硬地、绿色围网与球网。 |
| [364／365阳台说明](https://gradunion.ustc.edu.cn/2012/0317/c5709a61204/page.psp) | 结合GIS和卫星保留联体公寓内院及朝内阳台；楼层和未见门窗细节为近似。 |

官方图片与地图作本地视觉参考，OSM几何沿用贡献者归属与ODbL记录。跑道内两根路灯为上一轮布置错误，本轮移至步道外绿化带，并以实际路灯实例检查验证。

## 校园路网、成熟树种与北侧教学区 · 2026-10-12

本轮沿用 `site.json` 的WGS84原点与米制旋转，不混用国内地图偏移坐标。`campus_road_network.json` 登记38条主要道路，当前已建区域实际渲染28条；未建南区保留登记。覆盖区域并集112,199.823㎡／20.142%，净增40,987.087㎡，校园边界仍为way262614785、557,050.649㎡。

| 来源 | 核查内容与本地证据 |
|---|---|
| [OpenStreetMap](https://www.openstreetmap.org/way/262614785)，`renders/coverage/osm_east_full.xml` | 勤奋路268836529／265583820、天使路265575543及北段266988252／253、新旧北门连接268206608、学院楼环路270537515；教五265575547、教学行政270537512、管理科研270537513、MBA270537514的原始轮廓。南区登记路段尚未建设。 |
| [官方校园GIS](https://gis.ustc.edu.cn/)与[东区校园总图](https://indico.pnp.ustc.edu.cn/event/3091/attachments/6396/12868/科大东区校园地图.pdf) | 复用 `references/maps/gis_index.html`／`east_campus.png`，核对道路邻接、教五与北门、学院楼及专家公寓名称。 |
| [Esri World Imagery](https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer) | 新取公开level19图块，拼为 `references/road_network/north_roads_satellite.jpg`，另有OSM叠图；metadata记录56图块、2048×1792、地理角点和署名。实际查看北区道路、树冠和楼体比例，像素地面间距约0.25米，影像拍摄日期未知。主要路宽约6–8米为可见边缘的比例估计；高楼屋顶视差不能用来搬动地基。 |
| [中国科大报：致新同学](https://zgkdb.ustc.edu.cn/ndetail/3705)与[管理学院：科大秋韵](https://business.ustc.edu.cn/2011/1026/c28419a526436/page.htm) | 前者确认天使路法国梧桐；后者图题支持一教雪松、郭沫若路栾树与勤奋路光影。已失效的小图标未作实景照片；已见 `teaching_north.jpg` 和广场本地图用于成熟树干、树冠形态。 |
| [教育基金会：用落叶，拼起对母校的思念](https://ef.ustc.edu.cn/info/1061/2005.htm) | 明确一教北面梧桐、眼镜湖香樟、郭沫若广场广玉兰／枇杷、1958旁松树。树种部署层156棵、5件原创GLB；约18米行树间距、14–17米树高是场景布置尺度，非逐树实测。 |
| [地空学院](https://ess.ustc.edu.cn/main.htm)、[地空实验教学中心](https://essetc.ustc.edu.cn/zxgk/list.htm)与[管理科研楼1607答辩记录](https://faculty.ustc.edu.cn/caichen/zh_CN/article/1021455/content/5480.htm) | 地空学院地址对应东区教学行政楼；行政楼8／16层实验室和管理科研楼1607会议室支持两栋高层建筑的楼层依据。 |
| [2019年外立面改造工程公开清单](https://www.ezhujianpt.com/project/list_0_0_121013_1213_36.html) | 第三方工程列表的搜索索引文本列出教学行政楼／管理科研楼地上16层、63.8／64.4米，本轮按此体量建模。16层另由学校页面支持；精确米数未由学校官网独立确认。窗格、材质、屋顶与部分入口安排仍为外部近似。 |
| [教务处教五资源](https://www.teach.ustc.edu.cn/service/svc-resource/12388.html)、[官方校园词典](https://en.ustc.edu.cn/Dictionary.htm)与[百度地图教五照片](https://map.baidu.com/place/9d869de78b9635fd344aae90) | 核查五层及“王璞楼”名称；已见本地 `references/buildings/teaching5_front.jpg` 的白墙、细铝框玻璃入口、玻璃雨棚、金字与台阶。教五21.3米高度由楼层估计。 |
| [新闻网：科学家的大学](https://news.ustc.edu.cn/info/1056/68537.htm)、[黄山路北门照片1](https://commons.wikimedia.org/wiki/File:The_North_Gate_of_East_University_of_Science_and_Technology_of_China_1.jpg)及[照片2](https://commons.wikimedia.org/wiki/File:The_North_Gate_of_East_University_of_Science_and_Technology_of_China_2.jpg) | 新北门采用电动门、圆柱形岗亭、铭字粗石和紫藤，区别老北门拱梁。两张2022-09-10照片作者深鸣，已见本地 `new_northgate_2022.jpg`／`new_northgate_inside_2022.jpg`；设施尺寸为照片推定，门节点2755623225保留。 |
| 用户现场辨识、官方总图、OSM guest_house节点2755623244及[专家楼接待中心公告](https://www.ustc.edu.cn/info/1366/22595.htm) | 校正天使路西侧专家楼为餐饮／住宿接待饭店，东侧1／2号楼为所系结合专家公寓宿舍；名称不再混用。 |

本轮模型与材质由 `build_north_teaching.py`、`build_north_gate.py` 和树种构建脚本生成；建筑依据与树种成本保存在 `north_teaching_manifest.json`、`campus_tree_species_manifest.json`。公开照片、校园图和卫星图仅作本地参考，未贴入运行资产；OSM衍生坐标沿用 © OpenStreetMap contributors／ODbL 1.0归属，卫星署名为Esri、Vantor、Earthstar Geographics及GIS User Community。

四栋楼入口的小径和铺装依据已见入口方向与映射主路作概括连接，约0.16米外级台阶用于可走的游戏空间；这些短连接不是另行测绘的道路中心线。

阴影机制查阅 [Godot DirectionalLight3D](https://docs.godotengine.org/en/stable/classes/class_directionallight3d.html)，最终120与级联混合来自本场景实测，证据在 `renders/shadow_band/validation.json`。64张原生图与固定世界地面取样检验的是投影正确性。

## 郭沫若广场扩区与全东区覆盖 · 2026-10-12

- 完整东区范围：本地原始OSM way262614785，54个独立闭合顶点，版本17、2025-09-08；使用现有米制坐标变换，完整边界约557,050.6㎡。新全东区建筑采集保存在 `renders/coverage/`，与官方东区总图交叉核对道路邻接。当前覆盖统计为已启用区域并集与校区边界的交集。
- 郭沫若广场way306496885、郭沫若路265032055、东侧步道306496882、郭沫若像node3026612881、USTC1958 way268207470、小池264871517用于定位。新的外部地块边界是本项目建设范围，局部景观与支路是艺术布置。
- 建筑照片：[科大招生办校园生活](https://zsb.ustc.edu.cn/xysj/list.htm)、[科大报咖啡馆](https://zgkdb.ustc.edu.cn/ndetail/6404)、本地 `东区1958咖啡.jpg`；可见竖肋外墙、浅色柱梁、大玻璃、木露台和户外伞桌。
- 雕像照片：[科大报](https://zgkdb.ustc.edu.cn/ndetail/7454)与[科大实验室照片](https://metalisotopes.ustc.edu.cn/news/MgCuFePbSiV.html)确认交叉双臂、中山装全身立像；[校园百科](https://m.baike.ustc.edu.cn/wiki/detail?id=394)确认广场北侧、面南。肖像与基座细节是概括模型。
- 广场空间参考本地 `东区郭沫若广场.jpg`；南侧旧图书馆轮廓来自OSM way284161540，本轮仅作背景，未算新增可玩地块。

新资产均为本项目生成几何，照片作为参考，未贴入游戏。图中已建／待建范围以该轮布局为准；全部OSM归属和ODbL约定沿用下方记录。

## 角色身份实机修复 · 2026-09-08

- 最高优先级：用户已认可的 `references/characters/tiku_boy1/character_sheet.png`；主肖像继续作为身份源头。
- 新生产纹理：`campus/godot/assets/textures/tiku_face_albedo.png`，内置 imagegen 基于上述已认可设计生成。原文件与完整提示词见 `references/characters/tiku_boy1/face_albedo_prompt.txt`。未把第三方照片剪贴到脸部。
- 校服裁片依据用户本地 `c63b2f20-14ae-4fdf-a269-07242beac118.png`，蓝白V形胸肩拼接、白袖蓝条与短翻领。并非声称科大存在统一制式校服；这是虚构角色穿着变体。
- 补充语境核查：[合肥一六八校服介绍](https://www.hf168.net/col8/37580)、[昌平二中数学竞赛页面](https://www.bjcpez.com/CampusDynamics/info/14564)。页面文字可访问，原照片请求超时，未依据未看到的照片推导面孔或衣服细节。
- 两个角色的几何、绑定、书本及程序动作由本项目生成。身份一致性以实际GLB头部几何哈希和同视角渲染核对。

核查日期：2026-09-08。图片全部放在 references，未作为游戏贴图。游戏几何、材质和音频由本项目自行生成。研究资料不是统一拍摄日期的现状测绘；V0.1 为公开资料支持的艺术化复原。

| ID | 来源 | 核查与用途 | 权利／限制 |
|---|---|---|---|
| S01 | [科大官方 GIS](https://gis.ustc.edu.cn/) | 东区地标与校园地图入口，页面归档 maps/gis_index.html | 未声明开放许可；参考 |
| S02 | [官方东区校园地图 PDF](https://indico.pnp.ustc.edu.cn/event/3091/attachments/6396/12868/科大东区校园地图.pdf) | 已下载并渲染 east_campus.png；北门、双湖、一教 U 形、郭沫若广场、道路邻接 | 未声明开放许可；参考，不在游戏中分发 |
| S03 | [OpenStreetMap 数据 API](https://api.openstreetmap.org/api/0.6/map?bbox=117.262,31.840,117.268,31.845) | 原始 osm.xml、整理 features.json、可视地图 osm_reference.png；提取老北门节点2705289540、一教265575551、西湖290098995、玉泉北路264872432、一鉴亭306372994 | © OpenStreetMap contributors，ODbL 1.0；衍生 site.json 以 ODbL 提供并保留归属。https://www.openstreetmap.org/copyright |
| S04 | [Esri World Imagery](https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer) | 单张 export 卫星参考：bbox117.2615,31.840,117.2665,31.844；核查双湖、U形、专家楼、树冠覆盖；satellite/esri_reference.jpg | 服务 metadata 归属：Esri, Vantor, Earthstar Geographics, GIS User Community；仅本地研究参考，不嵌入游戏、不宣称开放许可。拍摄日期未核实 |
| S05 | [科大苏州高研院官方校园相册](https://sz.ustc.edu.cn/wdxz_show/61.html) | 2022-02-23 页面含明确标注“东区”的照片：眼镜湖、一鉴亭、樱花大道、图书馆等；9张与URL见 reference_manifest.json | 未声明开放许可；形体/植被/色彩参考 |
| S06 | [科大招生办：夏日一鉴亭](https://zsb.ustc.edu.cn/2024/0310/c35540a631898/page.htm) | 已观察 pavilion_4.jpg：暖色柱、翘角红瓦、浅色桥栏、荷叶、深绿树冠；亭桥精化主要依据 | 未声明开放许可；参考 |
| S07 | [中国科大报：致新同学](https://zgkdb.ustc.edu.cn/ndetail/3705) | 老北门照片 hall_2.jpg；一鉴亭 hall_3.jpg；文字核查一教红砖和梧桐、一教北面的湖与曲桥 | 未声明开放许可；参考 |
| S08 | [管理学院：第一教学楼](https://business.ustc.edu.cn/2010/1214/c28419a526438/page.htm) | 官方建筑照片，核查屋顶、层数、窗与红砖关系；teaching1.html | 未声明开放许可；参考，早期照片与现状可能有差异 |
| S09 | [科大报：樱花大道](https://zgkdb.ustc.edu.cn/ndetail/2734) | 老北门向南至一教，报道约200米；不是工程测距，采用OSM约160米核心段 | 未声明开放许可；事实参考 |
| S10 | [科大官方校园百科：樱花](https://m.baike.ustc.edu.cn/wiki/detail?id=3) | 樱花位于一教和老北门之间；夏季使用叶态，不用花海 | 事实参考 |
| S11 | [Wikimedia 北门照片](https://commons.wikimedia.org/wiki/File:The_North_Gate_of_East_University_of_Science_and_Technology_of_China_1.jpg) | 2022年，深鸣；坐标表明这是较北的新入口，不能当作老北门原点 | CC BY-SA 4.0；未使用为资产，作为识别排除记录 |
| S12 | [方块科大官方介绍](https://ef.ustc.edu.cn/info/1061/1946.htm) | 确认这些地标的校园记忆价值；不使用其模型或MC图片作为建筑外观依据 | 未复用资产 |
| T01 | [Godot Spatial Shader](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html) | 自定义柔和分层光照、风、粗糙度、AO | 技术文档 |

## 置信度

- 高：老北门—玉泉北路—一教邻接；双池分列路两侧；亭在东池；一教向南开口的U形。
- 中：OSM平面坐标与建筑轮廓（非测绘）；照片中的门梁比例、亭桥形体、窗格节奏。
- 低／艺术估计：楼高、窗净尺寸、桥栏细部、每株树的位置、草坡高差、东池手描岸线、下午太阳角度。建筑正面最终按照片而非单靠OSM楼层标签。
- 卫星影像不能和国内GCJ-02地图点直接混用。工程以OSM WGS84本地切平面为统一基准。

## 资产来源

所有游戏模型来自 blender/scripts/build_campus.py 与 lookdev_assets.py；表面PBR贴图由 tools/lookdev_textures.py 原创生成。LookDev天空 academic_sky_v2.png 使用内置imagegen按原创天空规格生成（2026-09-08，原始1774×887），嵌入实时天空材质；不是实拍HDRI，也没有把AI生成的校园图当作运行截图。没有下载收费或许可不明的游戏模型，没有用校园照片投影冒充真实几何。界面中文采用系统字体查找，不复制Windows字体到项目。照片参考集只用于本地研究，公开打包应排除 references。

LookDev专家楼沿用OSM平面，为了匹配S06照片可见的灰色坡屋面而补充估算屋顶；坡度、分段与窗套尺寸仍为中低置信度，不能作为测绘数据。

技术核查：[Godot Spatial Shader](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html)、[Environment](https://docs.godotengine.org/en/stable/classes/class_environment.html)、[ReflectionProbe](https://docs.godotengine.org/en/stable/classes/class_reflectionprobe.html)、[RenderingServer](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html)。

## 用户提供的Diorama视觉语言参考（2026-09-08）

位置：工作区 references/art_direction。三图文件为 a2267869-25a1-4803-9804-dbfbc4415b62.png、e3e8add4-d7aa-4d07-a08b-e2ea70b447b4.png、e7d8342e-db50-42ef-86c4-2b253e877957.png。已逐张查看，只分析配色、块面层次、阴影和摄影方式；不复用图片作材质，不移植神社/鸟居/角色/布局。作者和许可未提供，因此仅作用户提供的本地美术参考，不作为可再分发游戏资产。

新Diorama树冠、展示底座和建筑细化由 blender/scripts/diorama_assets.py 原创生成。Diorama保留一教既有坐标，后立面补齐与庭院铺装为中低置信度艺术估算。春日粉白花团来自本轮用户明确要求，不声称与旧夏末版本或具体实拍日期一致。

## Scene Life 原创资产（2026-09-08）

后续做题家小伙 1 角色迭代使用用户提供的蓝衫侧目肖像为身份参考；图源原作者尚未可靠确认。工作区 references/characters/tiku_boy1/research/sources.json 记录六张公开辅助照片、来源页面、用途和许可未知状态。照片不作为模型纹理。character_sheet.png 为内置 imagegen 根据用户主参考生成的概念稿，提示词存放于同目录 character_sheet_prompt.txt；实际模型由 build_tiku.py 编写生成，经 Godot 真实渲染，两者在评审页明确区分。

blender/scripts/build_life.py 生成三位原创校园学生、猫、鸟、桌子、书包、公告栏和分类桶，源文件为 blender/source/campus_life.blend；godot/scripts/scene_life.gd 实现关节动画。没有使用第三方角色、现成商业 IP、照片纹理或外部动作资源。这些人物与小品的位置属于艺术化叙事设计，不是对真实个人或现有设施的测绘。动态展示由 Godot 视口真实渲染，tools/encode_life_video.py 使用本机 Blender 的内置 H.264 编码器，未添加第三方音乐。

## Diorama 0.5 角色体系与北向接段（2026-09-08）

`blender/scripts/build_population.py` 原创生成骑车者、后院读者、拍照者、背资料者四套 Ambient；后两套替换旧节点外观，不增加人数。身体、头发、衣服、车、书和手机均为项目生成几何与材质，未下载角色、动作或照片纹理。猫鸟沿用既有原创资产，做题家沿用用户已接受版本。位置和微型故事属于艺术布置，不能视作真实人员与设施记录。生产来源和实际资产成本见 `docs/characters/AMBIENT_CAST.md`、`renders/population/asset_manifest.json`。

北向12×12米接段复核既有资料 `references/maps/east_campus.png`、`references/satellite/esri_reference.jpg` 与 OSM way 264872432。道路方向依据地图；东池手描岸线仍为近似，模块只沿双池之间的已有陆路接续，未推定新桥或填湖。来源、边界与置信度一并记录在 `godot/data/module_layout.json`。图集与100秒短片来自 Godot 实际视口；Blender仅编码原始序列，没有生成式改图、补帧或第三方配乐。

## Wave2 · 五个校园故事节点（2026-09-08）

本节补充本轮外部IP参考；前文“没有使用商业IP”只描述当时的原创Scene Life批次，不适用于新增cameo。来源总索引为 `references/characters/wave2/sources.json`，游戏逐图依据在 `research/sources.json`，品牌核实与未选择候选在 `research/mascot_sources.json`。原图均已由相应研究代理实际查看，只在references研究，未裁作运行贴图。

| ID | 页面 / 本地图 | 本轮用途与边界 | 权利状态 |
|---|---|---|---|
| W2-G01 | [HoYoLAB雷电将军官方资料](https://www.hoyolab.com/article/760845)，`raiden_1.jpg`、`raiden_2.jpg`、`raiden_3.png` | 深紫发、长辫、花饰金簪、交领与束腰；校园读书行为由项目改编 | 原角色归HoYoverse，未取得本项目官方合作/再分发授权 |
| W2-G02 | [HoYoLAB三月七官方资料](https://www.hoyolab.com/article/4373020)，`march7_1.jpg`至`march7_3.jpg` | 固定原始冰/存护外观，粉白发束、蓝夹饰、白蓝服装与相机；不混新变体 | 同上，研究来源不等于游戏资产许可 |
| W2-M01 | [美团媒体资源](https://www.meituan.com/media)，`meituan_mascot_pack_01.jpg` | 官方下载包完整吉祥物；双长耳、大黑鼻、小眼、奶油胸口、长尾；配送等候为原创校园小故事 | 媒体页说明个人/编辑使用，未取得游戏或周边使用许可；不称官方联动 |
| W2-M02 | [豆包官方下载页](https://www.doubao.com/download/desktop)，`doubao_official_icon.png` | 官网引用官方CDN192px头肩头像；深棕不对称bob、脸与黑衣浅领；身体、下装、平板和共读动作为项目补全 | 未找到开放资产许可，不把官方头像说成官方全身设定 |
| W2-M03 | [奶蛙自称品牌站](https://milkyfrog.com/)、[非官方变体档案](https://www.naiwa.world/)，`naiwa_site_portrait.png` | 名称对应自称品牌、不同开发者App与AI网络变体，唯一原型未收敛；本轮不制作 | 自称版权不等于已核实原作者，不将奶龙/奶蛙混为一个官方IP |
| W2-M04 | [牛来粉丝站](https://www.niulaifilm.com/)，`niulai_fansite_still.jpg` | 已查看多人剧照，但成年牛/小牛/梗图身份不确定；本轮不制作 | 明确粉丝来源，不能用站名冒充官方 |

校园猫为原创狸花小生物，区别原长椅趴猫，未引入第三方动物模型。五套本轮几何/道具/动作由项目生成；“inspired variant”只描述改编，不自动解决原IP许可。本轮是用户授权的本地项目制作，没有对外发布、申请官方合作或发送授权请求。

三处新增陆地模块复用已归档官方地图、OSM与卫星图，逐段来源随 `module_layout.json` 留存：西南265032056/306371636、东花园264872431/369507581–586、广场东侧306496882。剔除后勤楼内原候选与广场中水池；道路中心线有地图依据，宽度、树位、家具和小支路过渡属于艺术概括。`polygon` 内部才是新增地面，`bounds` 不是面积或碰撞的替代证明。完成状态以本轮真实验证和截图报告为准。


## 北轴连续复原 · 2026-09-08

本节是当前北轴资产的研究增补，旧“东池手描”与短接段描述保留为历史记录；本轮已用归档 OSM 原始水域关系和桥道重新整理双湖、亭岛和四条曲桥，详见 `godot/data/north_axis_layout.json`。S02/S03/S04 的来源和署名继续适用，不表示地图或卫星提供了精确的建筑立面。

| ID | 官方来源 / 本地证据 | 已观察内容与用途 | 权利和置信度 |
|---|---|---|---|
| N01 | [党建思政网：东区老北门](https://djyszw.ustc.edu.cn/info/1041/3325.htm)，2016-05-30；`references/buildings/northgate_official_2016.jpg` | 本次实际看完整门、车辆和行人比例；四柱三开口、浅色梁柱、红字、檐底与上缘紫藤。结合 S07 的仰拍。 | 未声明开放资产许可；只作本地几何参考。柱宽/高度为照片推定。 |
| N02 | [新闻网：半亩方塘映书香](https://news.ustc.edu.cn/info/1056/94500.htm)，2026-04-07；`pavilion_official_2026.jpg`，照片李丰/摄 | 本次实际查看，六角亭、飞檐、钝顶饰、柱顶简洁木格、亭中座与低桥栏；与 S06 夏季近照交叉核查。 | 新闻转载和照片均无游戏资产许可；未用为材质。材质色相受季节/相机影响，非色卡测量。 |
| N03 | [科大报：科大的门道](https://zgkdb.ustc.edu.cn/ndetail/4877)，2018-06-05；[官方校园百科老北门](https://m.baike.ustc.edu.cn/wiki/detail?id=230) | 文本确认老北门三门格局、旧门与新门区别、紫藤记忆。 | 事实参考。未假定获取到的文字等同于所有配图均看过。 |
| N04 | `references/maps/osm.xml`，本轮提取 `north_axis_layout.json` | 东池 relation11542038 外圈290098996、亭岛840391562；亭306372994；东桥306372996/840891953 与306372998/840891954，西曲桥290098999及短支290098998。替代旧手绘桥中心线。 | © OpenStreetMap contributors，ODbL；平面为公开地图精度，水位、桥宽与高程仍为艺术估计。 |
| N05 | 同一 OSM，专家楼270537516、西侧267646978、住宅298741850/298741849 | 保留原始凹凸轮廓和位置；专家楼局部坡屋面参考 S06 背景，三栋周边作为中低精度围合。 | 完整立面照片不足；楼高、窗数、入口、屋脊分段均不能声称实测或逐窗真实。 |

原始图地址：N01 来自 `https://djyszw.ustc.edu.cn/__local/B/FE/D5/89C5C39A3E83FDF45AD09444A87_9A76C34F_14D82.jpg`；N02 来自 `https://news.ustc.edu.cn/__local/F/4E/1F/25A739CCA5DBB1C51EBCF339D82_25115AFC_14EE0.jpg`。下载后实际查看，未改变原始图片。S05 目录名“东区一鉴亭.jpg”的实际内容为湖岸叠石小径，本轮只据其观察岸线，未误用作亭身；pavilion_0/2/5 等网页logo、横幅、二维码已排除。

新增运行资产由 `blender/scripts/build_north_axis.py` 独立制作，输出 `north_axis_architecture.glb`、`north_axis_surroundings.glb`；门字为本机楷体的几何导出，不包含字体文件，也不是郭沫若题字精确描摹。独立Blender证据与真实Godot截图严格区分。地面、岸线和碰撞职责详见 `docs/NORTH_AXIS_ASSETS.md` 与环境模块，不能仅凭截图宣称完成行走验收。

北轴实机审图后补充 `build_north_lake_props.py`：5片盘形荷叶及3石组合均为原创程序几何，仅依据S05/S06已实际观察的荷塘、岸石轮廓制作；没有增加春季盛花或把照片作纹理。湖岸摆放属于受水域polygon约束的艺术整理，并非记录真实每块石头/每片荷叶。
