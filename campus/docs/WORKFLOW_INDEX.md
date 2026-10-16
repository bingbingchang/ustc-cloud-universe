# 项目工作入口

**团队接手入口：** [运行与协作](team/README.md) · [现有实现与代码地图](team/ARCHITECTURE.md) · [模块分工与迭代计划](team/DEVELOPMENT_PLAN.md)。以下按原样保留历史阶段交接，旧“当前”“下一步”不作为今天的开发计划。

**2026-10-12当前交接：路灯修正与南侧球场／364—365公寓。** `south_sports_08` 新增5篮球场、5网球场、羽毛球馆、364／365公寓及服务楼，共10处外部建筑要素、56棵树、4件GLB。覆盖35.545%→42.255%（净增37,378.021㎡）；路网登记77条，实际渲染70条。普通游戏 **6** 到新区域，[OPEN_SOUTH_SPORTS.cmd](../../OPEN_SOUTH_SPORTS.cmd)直接启动。

`sports_district.json` 中 (-184,438)、(-184,482) 的路灯移至x=-174.6东侧绿化带，`prepare_sports_district.py` 同步修正。`validate_south_sports.gd` 从实际MultiMesh变换核对168个路灯实例，跑道和新球场内均为零。新区域部署读取 `data/south_sports.json`，代码 `scripts/south_sports.gd`，资产清单 `assets/south_sports_manifest.json`。构建：`prepare_south_sports.py` → Blender执行 `build_south_sports.py` → `prepare_south_sports.py --finish-entrances` → Godot导入。原59项冻结文件保持。

依据归档在 `references/south_sports/`：GIS JS图片路径 `mapdata/zoom3/{x}_{y}.jpg`，本轮瓦片x14—22／y5—12，256像素；GIS是斜视绘制图，用于色彩／院落／邻接，地面使用OSM与地理卫星坐标。官方总图核对楼号，2026网球照片核对围网与蓝绿场地。横向通道位于两排网球场之间z=614.4，洗浴中心入口朝北接路。26条实走、4组实体阻挡、跳跃通过；四入口接缝各60,555点零缺口；1600×900前台流畅档移动短测约144FPS。[实机与参考](../renders/south_sports/review.html)、[报告](../renders/south_sports/validation.json)、[性能](../renders/south_sports/visual_validation.json)。下一块从物理楼路向南接学院／科研楼、礼堂和南门。

## 10月12日运动场阶段交接

**2026-10-12当前交接：运动场与320—323学生公寓。** 已接续此前中断的图书馆／二教阶段，从郭沫若路向南建设 `sports_district_07`，包含八道田径跑道、足球草坪／球门、看台／主席台、体育教学部、4栋公寓外部空间及65棵树。地理覆盖从27.403%到35.545%（净增45,352.617㎡）；数据与后续区域见 [当前推进表](EAST_CAMPUS_ROADMAP.md)。实际路网登记69条、渲染60条，主路带人行道，支路与窄步道分开处理。普通游戏 **5** 到运动场，**4** 到图书馆；独立入口为 [OPEN_SPORTS_DISTRICT.cmd](../../OPEN_SPORTS_DISTRICT.cmd)。

本轮运行代码为 `scripts/sports_district.gd`，部署读取 `data/sports_district.json` 与 `module_layout.json`，参考位于 `references/sports_district/`。仅新建4件GLB，原59项冻结文件保持。公寓门前铺装与树木以新资产manifest中的 `front_approach` 为依据；看台首阶0.28米，其余每阶0.18米。跑道划线采用分段条带，闭环轮廓不能直接填充为多边形；新平面材质显式保留向上法线，避免背面受光导致全场发暗。复现与检查命令见推进表；真实输出在 `renders/sports_district/`。

验收：11条实际人物路线、3组楼体阻挡、跳跃及道路分级通过，含咖啡馆／图书馆跨区连接、整圈跑道、四栋楼门前及看台台阶。四入口接缝各53,748点零缺口。1600×900流畅档、前台焦点100%的实际移动短测：跑道143.8FPS、公寓巷143.2FPS、既有图书馆195.2FPS。原生图和当前报告见 [本轮图集](../renders/sports_district/review.html)、[实走](../renders/sports_district/validation.json)、[移动性能](../renders/sports_district/visual_validation.json)。下一块为运动场南侧球场与364／365公寓。

## 10月12日早期交接（下方数值为历史快照）

**2026-10-12最新交接：真实道路、成熟树种与北侧教学区。** 游戏仍使用 `OPEN_GAME.cmd`／F5；**3** 到教五／新北门，**2** 到广场，**R** 回老北门，北区独立入口为仓库根目录的[OPEN_NORTH_CAMPUS.cmd](../../OPEN_NORTH_CAMPUS.cmd)。保留人物走跑跳、实体碰撞和第一／第三人称镜头。

`godot/data/campus_road_network.json` 登记38条主要道路、校界内北区地块和正确建筑名称；`campus_network.gd` 在已建区域渲染28条道路段，南区待建路段仅登记。当前补齐勤奋路东西横路、天使路北段、新旧北门连接、教五与学院楼周边道路。专家楼饭店在天使路西侧，专家公寓宿舍在东侧；地空学院对应教学行政楼。新增教五、63.8米教学行政楼、64.4米管理科研楼、MBA中心及黄山路新北门，体量与相对位置有依据，部分立面近似。

树种部署读取 `campus_tree_planting.json`，现有156棵、5件新树GLB（三种法桐变体、针叶树、庭园阔叶树），包含一教／广场旧树替换。主行树约18米间距、14–17米高，主要路宽约6–8米，属于视觉估计。建筑与树种成本、依据分别在 `north_teaching_manifest.json`、`campus_tree_species_manifest.json`；真实新卫星图与OSM叠图在 `references/road_network/`。

当前覆盖 **112,199.823㎡／20.142%**，广场阶段基线71,212.736㎡／12.784%，本轮净增40,987.087㎡；全东区557,050.649㎡，剩444,850.826㎡／79.858%。[覆盖统计](../renders/coverage/coverage.json)与[推进表](EAST_CAMPUS_ROADMAP.md)沿用真实边界、面积并集和重叠扣除，范围含建筑和水体。

`campus_game.gd.apply_quality()` 将四级阴影的 `directional_shadow_pancake_size` 调至120，开启级联混合；修复一教庭院随镜头滑动的明暗横带。`tools/validate_shadow_band.gd` 冻结日照与NPC，以固定世界地面投影取样，64张1600×900图验证两画质及4类镜头，8组最终阴影稳定性检查通过。旧流畅默认镜头P95光度漂移0.126→0.052，[报告](../renders/shadow_band/validation.json)。

原生[路网实走](../renders/campus_network/validation.json)已通过11条人物路线及7组检查，含教五楼前新增通道、3栋楼体外壳／法桐网格碰撞和北区跳跃；修正新北门设施挡路后，同一路线复测通过。四栋楼入口铺装接入GIS主路，外级台阶约0.16米可正常行走。地块只扣先建区域，消除互相裁剪缺口；4个场景入口各33,699个接缝样点零缺口；旧59项冻结文件未改。

本轮[原生前走短测](../renders/campus_network/visual_validation.json)：1600×900、流畅档、4×MSAA／TAA、焦点100%，勤奋路162.7FPS／P95 7.142ms，天使路154.7／7.475，教五266.5／4.444，广场272.9／4.393。下方旧通过数及帧率为历史阶段结果。

## 历史交接记录

**最新：郭沫若广场实际扩区。** `OPEN_PLAZA.cmd` 或游戏按2进入，R回北门。`module_layout.json` 中 `guo_plaza_03` 定义真实要素和艺术地块边界，`plaza_environment.gd` 构建连续地面、池、铺装、植物、标志与碰撞。两件新地标由 `build_plaza_assets.py` 独立构建，新增GLB约4.53万三角面；旧身份资产保持。现有16NPC／动物加玩家，总树169。

完整东区约55.71公顷，本轮净扩15,843.6㎡，校界内覆盖从9.9%到12.8%。[覆盖图与统计](../renders/coverage/coverage.json)、[实际人物图与路线](../renders/plaza_expansion/validation.json)。7条实走（含一教西侧绕树进入新广场、旧西南连接、咖啡露台）、水池／建筑／纪念像／外边界碰撞及跳跃通过；四入口可见接缝各18,399点零缺口；59冻结文件未改。核心旧区域polygon保留，新地面明确扣旧模块重叠，内部围栏按区域交点拆段后移除。

复现：`check_ground_seams.ps1`；`run_plaza_checks.ps1 -Baseline`。实走短测前台焦点100%，流畅档原樱花大道95FPS（扩前102）、广场轴线309、咖啡馆前169；同机原机位平均帧时间约增7.2%。旧图书馆仅是背景，地块未建；下一块从广场南端接图书馆前路，详见 [推进表](EAST_CAMPUS_ROADMAP.md)。

**2026-10-12：当前目标为可玩的校园游戏。** `OPEN_GAME.cmd` 或 Godot F5 默认操控学生；WASD移动、Shift跑步、Space跳跃、鼠标跟随视角、滚轮距离、Tab第一／第三人称、R回北门、F3画质。使用当前155棵树、16个NPC／动物及西林场景，玩家另计；人物复用普通学生资产，仅此实例隐藏书本，走跑跳采用简单程序动画。默认游戏场景 `campus_game.tscn`，继承优化校园并通过 `create_player()` 替换控制器，历史摄影入口仍显式使用原场景。

本轮19项操作／碰撞检查通过，6条实际人物路线通过，包括北门轴线、西池曲桥、桥亭穿行、西林步道和一教台阶；跳跃约1.03米，建筑玻璃、树干和水域有真实水平碰撞记录，墙边镜头由4.2米收至约1.12米。原生图与报告在 `renders/gameplay/`；`run_gameplay_checks.ps1` 复现。本机1600×900、4×MSAA、TAA、关闭VSync的连续转镜头短测，流畅档约95／101／138FPS，精细档约78／78／126FPS，分别为樱花大道／亭桥／西林。所有采样窗口焦点100%。

推进顺序按用户要求：先试玩移动与场景，修正手感后再做互动；完整东区按 [分区推进表](EAST_CAMPUS_ROADMAP.md) 建设。本轮没有增加地理覆盖。后续环境优化优先远景HLOD、建筑遮挡体和按区异步加载，随实际扩区规模实施。

**最新：西侧林荫步道向北延伸，新增2位普通学生，总人口16、树155。** `OPEN_WEST_GROVE.cmd` 从新区域进入，新增人口仅在当前优化场景，历史Live/Diorama仍为14。部署与行为统一在 `west_grove.json`，全场景验证改用 `validate_west_grove.gd`，不能以旧14人口检查代替。[实现与复现](WEST_GROVE.md) · [交付对照](../renders/west_grove/review.html)。

**最新：樱花大道8个树池对齐，西池北岸—西北角延伸。** 树池直接绑定实际树木变换与根部尺寸，清除旧版错位边框及框内灌草；见 [修复与预防规范](TREE_BASINS_AND_NORTHWEST.md)、[原生对照](../renders/tree_basin_northwest/review.html)。`OPEN_TREE_BASIN_REVIEW.cmd` 从树池近景启动，按 `]` 看新增西北岸。现有优化入口同步包含更新。

**最新交接：性能优化与西池扩建。** 默认湖园入口及 `OPEN_CAMPUS_OPTIMIZED.cmd` 已接入离线LOD、24米空间批次和静止倒影复用，新增西池南岸/桥头景观。先读 [性能规范](PERFORMANCE_STANDARD.md)、[本轮结果](PERFORMANCE_RESULTS.md)、[全东区推进表](EAST_CAMPUS_ROADMAP.md)，原生对照见 [review.html](../renders/performance_upgrade/review.html)。157个材质面、282级LOD、11组同机位及可见实例数一致；115份资产/贴图/布局保持。148树、17路线、9禁入等8组QA通过，接缝12834采样零缺口。全校流式加载和长时间穿区测试待后续，西岸背景立面仍需精修。

**最新：共享地面接缝修复与北岸/东桥入口扩展。** 核心草地取消10厘米缩进，可见面与碰撞共用边界；扩建必跑 `check_ground_seams.ps1`，详见 [GROUND_CONTINUITY.md](GROUND_CONTINUITY.md)。连续湖园现为五段，入口仍为 `OPEN_LAKE_GARDEN.cmd`。

**当前：用户认可莫奈方向并要求扩展，继续制作东池连续湖园。** 统一流程见 [ART_SCENE_WORKFLOW.md](ART_SCENE_WORKFLOW.md)。新入口 `OPEN_LAKE_GARDEN.cmd`，从亭桥向东岸、南岸和樱花接湖处延伸；保留原概念、地图与样段。下方“暂停扩展”为此前状态，已由本次明确要求更新；剩余美术问题仍需跟进。

**最新标准：样段必须用实机证明接近概念图的空间与光色关系，不能以物件齐全、贴图生效验收。** 先读 [一鉴亭构图样段](LAKE_COMPOSITION_STUDY.md)，入口 `OPEN_LAKE_STUDY.cmd`，[六机位对照](../renders/lake_study/review.html)。此处为历史样段结论；用户随后认可方向并要求扩建，按最新交接继续。下方旧湖园的“流程完成”是历史制作记录，不代表符合这个新的美术标准。

**2026-09-09 第二个区域：一鉴亭东池湖园。** [完整流程与实机对照](../renders/yijian_garden/review.html)、[实现说明](YIJIAN_GARDEN_UPGRADE.md)。6张真实参考→概念图→莫奈方向图集→东岸样段→修复水面隐藏/花瓣细节→东池全域。新增3柳、242荷叶组、44岸草、39岸石组、28灌木；当前117树、14生命元素。两版17连续路线/9禁入等8组检查全部通过。新入口 `OPEN_LAKE.cmd`，独立构建 `build_lake.ps1`，地图及上一轮樱花资产保持；后续区域沿用这一流程，概念图和实机分开验收。

**2026-09-09 樱花大道更新：** 先读 [SAKURA_AVENUE_UPGRADE.md](SAKURA_AVENUE_UPGRADE.md)，实机图见 [春日与材质对照](../renders/sakura_avenue/review.html)。`OPEN_SAKURA.cmd` 进入大道；新种植模块与莫奈方向贴图共享到两版，地图和14个生命元素保持。新资产用 `build_sakura.ps1` 单独重建；材质 atlas 与 shader 在场景运行时接入。当前树数114，下方103树为升级前历史记录。

当前入口：**LookDev Live与Diorama同内容双表现，14人口与五位漫步已实际共享，本轮技术同步完成**。先读 [LOOKDEV_VS_DIORAMA.md](LOOKDEV_VS_DIORAMA.md)，比较图在 [lookdev_live/review.html](../renders/lookdev_live/review.html)。Live继承当前地面/北轴/人口/路线，覆写一教、细叶树、材质、光照与相机，并按实际低干三角形建立匹配碰撞。`run_lookdev.ps1`默认Live，`-Archive`旧版；`run_diorama.ps1`仍原微缩。以后更新人物/布局优先修改共享数据并验证两个入口，禁止旧整包architecture叠进新北轴。

本轮证据：[场景QA](../renders/lookdev_live/validation.json) 8/8通过，[原生物理](../renders/lookdev_live/runtime_qa.json) 17路线/9禁入通过；103树412截面最大差0.0000458m、入口12点零误差。历史59冻结保持；另有 [迁移保护验证](../renders/lookdev_live/preservation_validation.json) 88文件与21旧图SHA全部保持，两清单有重叠。`python tools/lookdev_live_review.py` 只读原图，重生成17组同机位比较与画廊。最终重拍和新视频验证按本轮报告单独记录，不沿用旧影片通过结论。

共享世界基底：2026-09-08，Diorama 0.7 北轴与漫步。工程在 `campus/`，根目录旧 `godot/` 独立保留。该阶段画廊为 `renders/north_axis/review.html`；重建看 `NORTH_AXIS_RECONSTRUCTION.md`，动作看 `WANDERING_BEHAVIORS.md`，复核看 `NORTH_AXIS_ART_REVIEW.md`。Tiku身份基准仍为 `renders/tiku_identity/`，Wave2身份资产保留，不因扩展动作重做角色。

0.7交接：新北轴31932㎡、底座并集55933.5㎡，双池relation与岛/四桥正确读取，四栋邻楼有地图轮廓；5位Wave2漫步，总人口14不变。17条连续实走、9项禁入、5739陆地/1186水域采样及59项冻结文件全部通过。19张4K图（含行动线）、96秒原生MP4已输出，视频元数据与首/中/尾解码通过；不是连续GUI播放验收。桥头实际卡点为指示牌侵路，visual/collision移至(73,82.2)，完整证据在`bridge_exit_fix.json`。默认从全核总览开始，P从老北门步行，L/F8行动线。重现仅用`build_north_axis.ps1`、`capture_north_axis.ps1`，不要重建旧Hero。当前完成此核心外部空间，邻楼高度/部分立面有推断，室内及完整东区仍待后续。

当前数据合同：`north_axis_layout.json` 负责新域、双池outer/holes、建筑、路径、桥、摄影和北轴home。`scene_modules.story_nodes()`合并并覆盖三月七/豆包位置；`wander_routes.json`只存相对home偏移。不要用旧 `site.json` 手描东池。144㎡旧connector已停用，东侧32㎡重叠须保持无内部墙/重复地面；水阻挡扣除桥与亭岛，陆地物理独立于艺术网格。路测偏离先查跟踪及阻挡日志，不为通过测试移动真实建筑。

Live 最终交付：17组4K同机位一致性通过；64秒720p/12fps影片的元数据和首/中/末解码通过；Ultra交互窗口实际打开，日志无启动ERROR。具体范围分别见 `comparison_validation.json`、`video_validation.json`、`delivery_validation.json`。[Live Art Review](LOOKDEV_LIVE_ART_REVIEW.md) 记录入口、树根、远景雾和纹理的修正。高空图是空间附图，人高01/04与角色07优先用于两版选择。

## 每次只读所需资料

| 任务 | 先读 | 需要细查时再读 |
|---|---|---|
| 新角色 / 衣着变体 | [CHARACTER_PIPELINE](CHARACTER_PIPELINE.md)、[CHARACTER_REGISTRY](CHARACTER_REGISTRY.md) | 该角色 Bible、[Tiku 身份教训](characters/TIKU_IDENTITY_REVIEW.md) |
| IP校园cameo / Wave2 | [IP_CHARACTER_PIPELINE](IP_CHARACTER_PIPELINE.md)、[HERO_CHARACTER_REGISTRY](HERO_CHARACTER_REGISTRY.md) | [STORY_NODE_LAYOUT](STORY_NODE_LAYOUT.md)、[当前画廊](../renders/wave2/review.html) |
| 摆放 / 生命感 | [SCENE_POPULATION_RULES](SCENE_POPULATION_RULES.md)、`godot/data/population.json` | [ART_DIRECTION](ART_DIRECTION.md)、当前总览 |
| 扩区 | [ENVIRONMENT_EXPANSION_PLAN](ENVIRONMENT_EXPANSION_PLAN.md)、`godot/data/module_layout.json` | `site.json`、该接段地图/照片与 [SOURCE_LOG](SOURCE_LOG.md) |
| 回归 / 截图 | [QA_CHECKLIST](QA_CHECKLIST.md)、[STYLE_BENCHMARKS](STYLE_BENCHMARKS.md) | 本轮失败日志与对应脚本 |

先查看上述短入口和实际变更文件，不重复读取全部聊天、全部历史审查或几十张参考。研究、身份、运行、艺术审查四类结论分别保留；历史长日志用于定位具体问题，不作为每轮必读材料。

## 固定执行约定

1. 明确本轮范围、复用资产和要改变的少数参数。地图坐标来自 `godot/assets/site.json`；部署、类别、区域和动作路径读 `population.json`，模块实例、边界及资料置信度读 `module_layout.json`。文档只是解释与快照，禁止同时手改多份数值副本。
2. 做题家 `tiku_boy1.glb`、`tiku_boy1_uniform.glb`、`tiku_head.py`、面部纹理和身份基准已冻结。新 Ambient 构建单独输出；生成器不得顺便覆盖已验收资产。修改共享模块时先检查依赖与哈希，再做限定回归。
3. 默认使用已有软件、GLB、材质与摄影脚本。只构建被改资产，只复测受影响路线和机位；共享光照/地面变化才扩大回归，不重复全项目生成来消耗时间与 token。
4. 依次 Research → Build → Run → Observe → Compare → Fix → Render → Review。一次失败先读对应日志、缩小故障再修复；不要把概念图好看或数值测试通过当作实机艺术验收。
5. 每轮只追加一条交接：改了什么、真实输出路径、验证结果、剩余问题、下一步入口。完成状态必须有文件或日志支撑，不把计划中的截图写成已完成。

历史冻结清单为 `benchmarks/accepted_v0_4/manifest.json` 与 `accepted_v0_5/manifest.json`，合并59项；本轮 `renders/lookdev_live/baseline.json` 是更广的88文件/21旧图迁移留档，不是新的用户接受清单。本入口是项目文档约定，不安装技能、不建立额外的用户审批流程。用户已经明确的角色与风格批准持续有效。

0.5交接：2 Hero + 4 Ambient + 3 Creature；两新节点、两旧节点外观升级。12张4K图、100秒实机MP4完成并曾在浏览器播放至结束；20项检查、993核心+176接段格点和8条实际步行路线通过。历史证据与命令见 `population/review.html`，不要与Wave2的视频验收方式混写。

Wave2交接：新5节点为雷电将军、三月七、美团袋鼠、豆包头像校园伙伴、观察落叶猫；总人口4 Hero + 6 Ambient + 4 Creature。三相邻多边形4833.5㎡，14项技术QA、59旧文件冻结、15张二轮4K图与代理艺术复核完成，150秒五完整周期MP4已编码。坐标只存 `module_layout.json/modules[*].story_nodes`，`wave2_nodes.json` 按`node_ref`关联身份/动作，旧 `population.json` 不变。

复现：`run_diorama.ps1 -Wave2Focus`从新总览启动，`[ ]`切19机位，`P`步行。`build_wave2.ps1`只构建本轮五套资产；`capture_wave2.ps1 -Verify`验证、无参数静帧、`-Motion`捕获并编码、`-EncodeOnly`复用帧；`python tools/wave2_review.py`刷新画廊。下一轮先读 [Art Review](WAVE2_ART_REVIEW.md)、[性能边界](WAVE2_PERFORMANCE.md) 和扩展计划；不重建已接受Hero，不用新模型导出覆盖旧接受记录。
