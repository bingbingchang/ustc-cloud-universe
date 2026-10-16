# 现有实现与代码地图

路径以工作区根目录为基准；Godot中的 `res://` 指向 `campus/godot/`。这里描述已经存在的代码；新模块建议见 [迭代计划](DEVELOPMENT_PLAN.md)。

## 1. 一次启动到底发生什么

```text
OPEN_EAST_CAMPUS.cmd
  → campus/run_game.ps1
  → Godot：campus/godot/scenes/campus_game.tscn
  → scripts/campus_game.gd
      → 共享环境构建：地面、建筑、路网、树木、碰撞和光照
      → 玩家：third_person_player.gd + player_avatar.gd
      → 背景人物：scene_life.gd、wave2_life.gd、grove_life.gd
      → 知识人物：hero_interactions.gd + hero_actor.gd
      → 传入联机参数时：net_session.gd + remote_player.gd
```

`project.godot` 的默认入口也是 `campus_game.tscn`。该场景只挂接主脚本；完整校园主要由运行时代码组装，编辑器打开入口看不到完整校园是这种实现方式的结果。

`OPEN_KNOWLEDGE_HEROES.cmd` → `run_heroes.ps1` → `run_game.ps1 -Heroes`，仍运行同一个游戏。15位知识NPC在普通游戏中也会创建，`-Heroes`主要使人物列表在启动时打开。各区域启动参数主要改变玩家起点。

### 当前继承链

```text
campus.gd → diorama.gd → lookdev_live.gd → lake_study.gd
          → lake_garden_expanded.gd → campus_performance.gd → campus_game.gd
```

箭头表示后者继承前者，不是七个独立世界。基础 `_ready()` 调用的地面、材质、人物等方法可以被后面的版本替换；不能只读 `campus.gd` 就判断当前实际使用的模型。

这条链保留了历史制作过程。新UI、背包、房间等功能不必继续往链上增加版本；在现有游戏入口挂接独立组件即可。拆短继承链应另领任务，保持启动与相关路线行为，不与某个新功能一起大改。

## 2. 文件夹的分工

| 目录 | 内容与用途 |
|---|---|
| `campus/godot/scenes/` | 当前游戏入口、历史预览入口及展示入口；不是全部同时运行 |
| `campus/godot/scripts/` | 世界构建、玩家、人物、交互、联机及部分历史检查脚本 |
| `campus/godot/assets/` | 运行GLB、贴图、场地数据和资产清单；资源在这里不等于已部署进校园 |
| `campus/godot/data/` | 区域、路网、种植、人物、路线与外形配置 |
| `campus/godot/shaders/` | 建筑、树叶、水面及人物材质的渲染程序 |
| `campus/godot/samples/` | 咖啡小院、梧桐路、USTC1958、Three.js导入等独立样景 |
| `campus/godot/wildlife/` | 独立动物资产、包装场景、行为与试验场 |
| `campus/godot/tests/` | 知识NPC检查、动作展示及放置诊断 |
| `campus/godot/environment/` | 当前空目录，当前环境主要由脚本建立 |
| `campus/godot/.godot/` | 本机自动生成的导入与编辑器缓存 |
| `campus/blender/` | 建模生成器、Blender母版、导出文件和动物制作流程 |
| `campus/ai/` | Python RAG服务、资料、向量索引及模型连接 |
| `campus/tools/` | 地图准备、截图、性能和路线检查、报告生成；不是玩家功能 |
| `campus/references/`、根目录 `references/` | 校园地图、建筑与角色参考；部分生成器或文档仍使用根目录参考 |
| `campus/renders/`、`campus/benchmarks/` | 实机结果、日志和历史基准；不是游戏逻辑 |

## 3. 世界与场景：谁放置建筑、谁决定能不能走

`campus.gd._ready()`建立World，准备材质、地面、道路、模型、碰撞、植被、家具、光照、人物、玩家和界面。当前版本由继承链各层补充或替换相应方法。

`diorama.gd.terrain()`接入 `scene_modules.gd.build()`；后者读取 `module_layout.json`，按template调用区域构建器，再统一建立登记道路与树木。湖园、西林等另由环境继承链的 `compose_garden()` 接入，所以并非所有场景都只经过 `scene_modules.gd`。

| 代码／数据 | 责任 |
|---|---|
| `scene_modules.gd`、`data/module_layout.json` | 区域启用、边界开口、区域构建入口、故事锚点合并 |
| `north_axis_environment.gd`、`north_axis_solids.gd`、`north_axis_landscape_detail.gd`、`data/north_axis_layout.json` | 北门—双湖—一教的地形、设施、实体阻挡和景观细节 |
| `campus_network.gd`、`road_surfaces.gd`、`data/campus_road_network.json`、`data/campus_tree_planting.json` | 地块、道路、路面、树种及种植 |
| `plaza_environment.gd` | 郭沫若广场等区域内容 |
| `wave2_environment.gd` | 第二批人物附近的景观接段，以及被其他片区复用的多边形几何辅助 |
| `library_district.gd`、`data/library_district.json` | 图书馆与邻近教学区 |
| `sports_district.gd`、`data/sports_district.json` | 操场与相关建筑 |
| `south_sports.gd`、`data/south_sports.json` | 南侧球场及相关建筑 |
| `full_districts.gd`、`data/full_districts.json` | 东侧住宅、校史馆和南部等扩建片区 |
| `sakura_avenue.gd`、`sakura_paint.gd` | 樱花大道构景和材质 |
| `lake_garden.gd`、`lake_paint.gd` | 湖园布置和材质 |
| `west_lake_garden.gd`、`northwest_lake_garden.gd` | 西池与西北湖岸 |
| `west_grove.gd`、`tree_basins.gd`、`data/west_grove.json` | 西侧林地、树池与局部布置 |
| `lookdev_live_visuals.gd` | 灯光和视觉环境 |
| `campus_performance.gd` | 离线LOD使用、空间批次及倒影更新优化，同时保留部分西侧环境接入 |

模型决定外观；布局决定位置；碰撞体决定能否通行。楼外贴图或外壳不构成室内。制作楼内场景时，要明确室内入口、落脚点、镜头、碰撞和返回校园位置，不能仅在外壳里塞家具。

世界使用米制坐标：X向校园轴线东侧、Y向上、Z向校园轴线南侧。Blender导出转换与数据依据见 [场景说明](../SCENE_SPEC.md)。该旧文档中的早期人物速度不作为当前控制器参数。

## 4. 玩家：物理身体、模型与相机

| 文件 | 责任 |
|---|---|
| `player.gd` | 基础CharacterBody3D、胶囊碰撞、相机及基础控制 |
| `third_person_player.gd` | 当前游戏控制器；走跑跳、台阶、第一／第三人称、自由相机 |
| `player_avatar.gd` | 复用学生GLB，根据实际速度和离地状态摆动身体关节 |
| `scene_locator.gd` | 坐标显示、观察模式辅助、截图位置反馈 |

`campus_game.gd.create_player()`返回第三人称控制器。每个物理帧读取输入，以镜头方向计算速度，执行重力和跳跃，再通过 `move_and_slide()`移动并碰撞。实际位移用于更新人物朝向与动画。当前走路2.6m/s、跑步5m/s。

镜头由CameraPivot和SpringArm3D组织；支架碰墙缩短。自由相机移动相机，人物身体留在原处。新UI需要释放鼠标并阻止玩家移动，关闭后恢复原控制状态。

当前玩家没有跨登录保存的角色档案、背包或个人房间。头顶名字、角色面板和玩家身份也不能用知识NPC姓名来代替。

## 5. 背景人物与知识NPC

| 文件／数据 | 责任 |
|---|---|
| `scene_life.gd`、`data/population.json` | 原校园生活人物、猫鸟实例与配置 |
| `wave2_life.gd`、`data/wave2_nodes.json` | 第二批校园人物与故事节点 |
| `grove_life.gd`、`data/west_grove.json` | 西林的两位生活人物 |
| `ambient_actor.gd` | 普通人物关节准备、姿态与共用动作能力 |
| `tiku_actor.gd` | 做题角色的专门动作 |
| `cameo_actor.gd`、`mascot_actor.gd` | 既有客串人物与吉祥物动作 |
| `campus_wander.gd`、`wander_legs.gd`、`data/wander_routes.json` | 预定漫步路线、迈步与局部腿部变形 |
| `hero_interactions.gd`、`data/hero_npcs.json` | 创建15位知识NPC，人物列表、交谈、HTTP请求、来源展示与各人会话历史 |
| `hero_actor.gd`、`data/npc_appearance.json` | 加载各自GLB、名牌、碰撞和职业动作状态 |

知识NPC统一由 `campus_game.gd._ready()`创建交互组件，组件按配置逐人实例化。玩家接近约3.2米显示交谈提示，按E打开对话；J打开搜索与前往列表。

当前六类知识NPC动画由 `hero_actor.gd.make_clips()`在Godot运行时根据姿态规则生成AnimationPlayer轨道，并根据工作、招呼、倾听、回答和走动状态切换。Blender提供人物模型与可驱动的关节层次，不能把这套实现描述成90段Blender手工动画。部分旧注释和说明把二者混称，应以该函数为准。

当前知识人物短距离走动和背景人物路线主要是预定局部路线，不是全校园通用寻路。NPC会话与探索进度保存在当前游戏会话，尚未绑定账号持久化。

## 6. RAG：客户端与后台之间传什么

```text
Godot hero_interactions.gd
  → POST /chat：npc_id、message、history
  → FastAPI app.py：按角色限定资料
  → retrieval.py：查询向量 + BM25，RRF融合取片段
  → persona + 片段 + 最近对话 → Qwen3-8B
  → answer、sources、has_valid_citations等字段
  → 游戏显示回答与原文，切换人物回答动作
```

| `campus/ai/`文件 | 责任 |
|---|---|
| `sources.json` | 来源配置、资料与角色的对应 |
| `ingest.py` | 获取PDF／网页，提取正文和位置，切块 |
| `build_index.py` | 生成并保存文本向量索引 |
| `retrieval.py` | 中文二元词与英文词分词、BM25、向量相似度、RRF融合 |
| `app.py` | `/health`、`/npcs`、`/retrieve`、`/chat`，提示词、模型请求和响应组织 |
| `qwen_server.py` | 兼容模型接口的本机／云端生成服务 |
| `prepare_embedding.py` | 向量模型准备 |
| `cloud_prepare.sh`、`cloud_start.sh` | 原云环境准备和启动 |
| `cloud_ssh.py`、`tunnel.py` | 原云环境连接与端口转发工具 |
| `evaluate.py`、`evaluate_cast.py`、`test_rag.py` | 回答评估、全角色评估和检索接口测试 |
| `evaluation.json`、`cast_evaluation.json` | 已保存的评估记录，不能当实时健康状态 |
| `npc_expansion_design.json` | 扩展角色设计资料；运行身份以Godot角色配置为准 |
| `knowledge/raw/`、`knowledge/chunks.json`、`knowledge/vectors.npz` | 原始资料、切块及向量 |
| `requirements.txt`、`.env.example` | Python依赖与环境变量示例；代码不自动加载.env |

15位角色共用模型与检索实现，以npc_id区分资料。AI后台从 `../godot/data/hero_npcs.json`读取身份配置，因此单独部署AI时也要带上该文件并维持路径。更新角色配置后，客户端重新加载，后台也要重新启动以读取新身份。

当前语料记录为17份来源、191个片段。引用编号合法只说明编号对应召回资料，回答是否充分受原文支持还需要按问题核对。AI服务不是游戏账号或背包服务器。

## 7. 联机：目前同步到哪一层

`campus_game.gd.setup_net()`仅在有联机参数时创建会话；平时不建立ENet连接。

| 文件 | 责任 |
|---|---|
| `net_session.gd` | ENet主机／客户端、连接信号、移动状态和文字聊天转发 |
| `remote_player.gd` | 根据收到的位置和朝向插值显示其他玩家，复用player_avatar动画 |
| `campus_game.gd`中的联机部分 | 提供本机状态，创建／移除远端人物，接聊天界面 |

移动状态数组目前为 `[x, y, z, heading, speed, vertical_speed, grounded]`，约20Hz发送；移动采用不可靠消息，聊天采用可靠消息。客户端经主机转发给其他客户端。

当前位置由客户端报告，姓名也来自会话参数，没有账号认证、持久化角色ID和服务器权威物品状态。后续背包或房间物品接入网络时，应发送操作请求并由服务器决定结果，不能把客户端显示数量直接作为多人资产事实。

远端人物存在一个实际挂载约束：其avatar通过父节点关系调用校园材质方法，远端节点必须按当前代码挂在校园根节点下。调整场景树时要同时处理这个依赖。

## 8. 动物、独立样景与资产制作

`wildlife/animal.gd`封装物种、模型、AnimationTree、活动节点、岸水转换与玩家接近反应；`animal_lab.gd`组装试验场，`evidence.gd`做该场景检查。猫、鸭、麻雀、松鼠和刺猬的包装场景与GLB位于该目录。试验场完成不代表这些动物已全部在主校园部署。

`samples/threejs_road/preview.gd`提供样景预览基础；该目录的 `review.gd`、`material_import.gd`用于导入样板展示和材质处理。`samples/cafe_courtyard/review.gd`、`samples/plane_avenue/review.gd`、`samples/ustc1958/review.gd`各自加载对应样景，后者另有 `showcase.gd`拍摄展示。这些入口不会因文件存在就自动进入主校园。

| Blender生成脚本（`campus/blender/scripts/`） | 制作内容 |
|---|---|
| `build_campus.py`、`diorama_assets.py`、`lookdev_assets.py`、`build_lookdev_live.py` | 早期校园、美术表现与资源升级 |
| `build_north_axis.py`、`build_north_gate.py`、`build_north_lake_props.py`、`build_north_teaching.py` | 北轴、北门、湖畔设施与北侧教学建筑 |
| `build_plaza_assets.py`、`build_library_district.py`、`build_sports_district.py`、`build_south_sports.py`、`build_full_districts.py` | 广场及后续各片区建筑、设施 |
| `build_campus_tree_species.py`、`build_sakura.py`、`build_lake_garden.py`、`build_lake_study.py` | 树种、樱花和湖园资产 |
| `build_life.py`、`build_population.py`、`build_npc_cast.py` | 校园生活角色与15位知识角色 |
| `build_tiku.py`、`tiku_head.py`、`build_tiku_v1_archive.py` | 做题角色、头部与旧版留档 |
| `build_cameos.py`、`build_mascots.py` | 既有客串人物与吉祥物 |
| `build_cafe_courtyard.py`、`build_plane_avenue.py`、`refine_plane_avenue.py`、`build_ustc1958.py`、`import_threejs_road.py` | 独立美术样景和导入样板 |
| `render_cameo_proof.py`、`render_north_axis_proof.py`、`render_population_proof.py`、`render_tiku_proof.py` | Blender资产观察图，不属于实时游戏逻辑 |

动物制作另在 `campus/blender/wildlife/`，包含生成、适配、纹理和视频工具。一般流程为资料／布局 → Blender脚本或母版 → GLB和贴图 → Godot导入 → 对应区域或角色接入。

## 9. 为什么scripts目录看起来很多

下面这些文件主要用于检查、测量或展示，不应按“每个都是一个游戏系统”理解：

| 类型 | 现有脚本 |
|---|---|
| 通用／早期检查 | `check_ground.gd`、`population_proof.gd`、`population_profile.gd` |
| 角色展示与检查 | `tiku_proof.gd`、`tiku_proof_v1.gd`、`tiku_spot_test.gd`、`wave2_proof.gd`、`wave2_profile.gd` |
| 北轴检查 | `north_axis_proof.gd`、`north_axis_profile.gd`、`north_axis_runtime_qa.gd` |
| 美术升级检查 | `lookdev_live_proof.gd`、`lookdev_live_profile.gd`、`lookdev_live_qa.gd` |
| 樱花与湖园检查 | `sakura_profile.gd`、`sakura_qa.gd`、`lake_profile.gd`、`lake_qa.gd`、`lake_study_profile.gd`、`lake_study_qa.gd`、`lake_garden_expanded_profile.gd`、`lake_garden_expanded_qa.gd` |
| 后续优化与扩区检查 | `campus_performance_profile.gd`、`campus_performance_qa.gd`、`tree_basin_northwest_profile.gd`、`tree_basin_northwest_qa.gd`、`west_grove_profile.gd`、`west_grove_qa.gd` |
| 实机展示 | `full_campus_showcase.gd` |

`godot/tests/hero_smoke.gd`检查15位NPC放置、动画、交谈与控制恢复；带API参数时才检查真实模型回答。`npc_animation_showcase.gd`拍摄动作，`npc_placement_probe.gd`诊断放置。`campus/tools/`还保留各片区的实走、接缝、性能和截图工具。检查脚本有继承和调用关系，不能仅按名称批量删除。

## 10. 从一个小修改学会协作

- 改某位知识NPC的位置：改 `hero_npcs.json`对应条目，在游戏中前往该人物，确认落地、接近交谈和相机；通常不用重建模型。
- 改某位NPC外形：改 `npc_appearance.json`及必要建模逻辑，重建对应资产，并检查动作接触点；资料检索一般不用改。
- 改图书馆回答内容：更新来源与原文，重新切块／索引，检查该角色召回和回答；不用重建校园。
- 改一条道路：先定位配置和区域构建器，检查可见路面与碰撞，再走相邻连接；不会自动影响账号或背包。
- 新增一个UI面板：独立实现界面，接入游戏；验证鼠标释放、移动暂停、关闭恢复，以及与J对话和聊天输入的关系。

这些是当前真实边界。未来新增模块尽量接在边界上，而不是复制整个游戏脚本。
