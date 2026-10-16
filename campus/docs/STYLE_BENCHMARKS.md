# 固定风格基准

## LookDev Live · 同内容比较

本轮新比较使用 `renders/lookdev_live/` 与其 `diorama_ab/` 的17组**同相机、同FOV/投影、同人物时间**原生4K图，由 `lookdev_live_proof.gd` 共用摄影定义。优先看01一教人高、04曲桥、07做题家，再看02轴线/03北门和各人物。比较保留各自光照、树冠、材料和展示边界，这些正是要评估的美术变量，不能称为只改变模型的隔离实验。差异核对由 `comparison_validation.json` 记录；当前图不覆盖旧接受记录。旧LookDev `renders/lookdev/hero_04.png` 保留为迁移前参考，而不是已经具备最新人口的版本。

基准是未来扩区和增员的比较尺，不是“所有画面已达最终宣传质量”的声明。当前角色身份冻结于用户接受的 `renders/tiku_identity/`。归档清单为 `benchmarks/accepted_v0_4/manifest.json`，保留 Tiku 身份图与旧 life 宽图；**旧 life 宽图是环境历史基准，不能作为最新人物脸部基准**。

## 0.7当前比较图 · 北轴与漫步

当前完整场景有 **25个游览机位**，`[ ]` 切换，`P` 返回步行，L/F8开启默认隐藏的9cm紫色路线窄带与方向箭头。五位 Wave2 漫步、总人口14未增；新增区域、湖岸细节与当前角色的18张原生3840×2160图记录在 [north_axis/capture_report.json](../renders/north_axis/capture_report.json)。另有独立的 [19 行动线调试图](../renders/north_axis/19_routes_debug.png)，使用天使路局部高视角，验证路线可读性，不纳入无覆盖层的宣传比较组。以下六图固定为本轮自评比较组；**代理看图并不等于用户已批准新美术基准**，不会覆盖 accepted_v0_4 或历史人口图。

这里都是实际相机世界坐标，已包含眼高，不再加1.65米。完整朝向矩阵、投影和动作时间以捕获报告为准；本轮艺术复核与局限见 [NORTH_AXIS_ART_REVIEW.md](NORTH_AXIS_ART_REVIEW.md)。

| 当前实际图 | 相机世界位置 / 投影 | 动作时间 | 比较目的 |
|---|---|---:|---|
| [01 整体校园](../renders/north_axis/01_whole.png) | (-258,233.65,-171)，正交size310 | 24s | 老北门—双池—一教与周边区域的连续空间、底座与人口留白 |
| [02 北轴总览](../renders/north_axis/02_north.png) | (-168,154,-142)，正交size212 | 24s | 双池、轴路、门与岸线层次；不以宽图判断角色脸部 |
| [03 老北门](../renders/north_axis/03_gate.png) | (-.8,5.4,-24)，49°透视 | 24s | 门梁、校名、树冠框景与入口尺度 |
| [06 一鉴亭](../renders/north_axis/06_pavilion.png) | (16,25,111)，42°透视 | 24s | 红瓦亭、曲桥、湖岸水草/石头与邻楼关系 |
| [08 曲桥人高](../renders/north_axis/08_bridge.png) | (72,2.15,78)，52°透视 | 24s | 实际可走的桥口、栏杆、铺装与水面边界 |
| [13 做题家回归](../renders/north_axis/13_tiku.png) | (-18.3,1.45,145.1)，38°透视 | 3s | 与冻结长椅身份同视角；无桌、原头脸/服装和接触保留 |

14–18是五位漫步角色的实际近景，人物位置随采样时间变化，不能按旧 home 布相机。角色姿态与模型绑定的独立 proof 留在 `renders/wandering/proof/`；它们是实际 Godot 影棚图，不是校园宣传画。01/02用于空间总览，03/06/08用于环境层次，13及14–18用于身份/动作，各自有明确用途。

0.7最终普通1600×900性能已重测，包含本轮水草与石头，见 [NORTH_AXIS_PERFORMANCE.md](NORTH_AXIS_PERFORMANCE.md)。本轮96秒、1280×720、12fps、1152帧MP4已完成，元数据及首/中/末三帧解码通过且由根代理查看，见 [video_validation.json](../renders/north_axis/video_validation.json)；这不代表GUI连续播放或逐帧艺术验收。下面0.5、0.6的13/19机位和影片保留为历史记录。

## 历史环境与人口机位

来源为 `renders/life/photo_spots.json` / `diorama.gd`。表中 `feet` 是玩家根节点，实际相机比它高 **1.65 m**，不能误当相机世界坐标。单位米；美术时间春日16:10，动作时间另列。

| 基准 | feet → target | 投影 / 参数 | 动作时间 | 检查内容 |
|---|---|---|---|---|
| E01 总览 | (-152,145,2) → (0,2,177) | 正交size150 | 6s | 完整底座、U形、留白、人口分布 |
| E02 透视 A/B | (-100,96,62) → (0,2,177) | 透视50° | 6s | 与E01同方向；区分摄影与几何差异 |
| E03 樱花红楼 | (-24,27,113) → (0,3,159) | 透视44° | 5s | 花团明暗、树影、入口轴线 |
| E04 入口 | (24,6,143) → (0,3.5,168) | 透视46° | 10s | 窗洞、雨棚、台阶、自行车尺度 |
| E05 后院 | (123,101,303) → (0,2,178) | 透视44° | 14s | U形背面、后院静区、新读书节点分布 |
| L06 长椅故事 | (-20.3,2.1,143.4) → (-17,1.02,146.9) | 透视40° | 3s | 做题家保留、无桌、本子与猫 |
| L07 拍照 | (8.5,2.2,136.4) → (10.4,1,140.8) | 透视42° | 7s | 举手机与花树，剪影清楚、不堵路 |
| L09 背资料 | (23,2.05,153.3) → (19.3,1,155.6) | 透视42° | 12s | 慢行、资料、停步与路面净空 |
| L10 校服 Hero | (1.8,1.72,142.35) → (3.4,1.14,145) | 透视38° | 9.6s | 同身份、夹书、铺装接地、路灯 |

历史环境图：[E01](../renders/life/hero_01.png)、[E03](../renders/life/hero_03.png)、[E04](../renders/life/hero_04.png)、[E05](../renders/life/hero_05.png)。它们可能早于做题家身份修复，不能以旧 L06 人脸作为当前人物风格。

## 冻结的 Hero 身份图

以下为 `tiku_proof.gd` 的**相机世界位置**，不加玩家眼高。影棚角色放在x1000；S01–S03坐标相对于影棚原点，不是正常游览位置。

| 基准 / 实际 PNG | 相机 → target / FOV | 状态与用途 |
|---|---|---|
| [S01 正面全身](../renders/tiku_identity/01_front.png) | (0,1,-3.8) → (0,.95,0) / 32° | 中性0s；成人约5.7头身、服装剪影 |
| [S02 3/4](../renders/tiku_identity/02_three_quarter.png) | (-2.3,1.25,-3.3) → (0,.95,0) / 32° | 中性0s；鼻唇、下颌、衣领、镜框 |
| [S03 侧面](../renders/tiku_identity/03_side.png) | (-3.8,1.1,0) → (0,.95,0) / 32° | 中性0s；额头、鼻、下巴、短发侧面 |
| [H01 实际坐写](../renders/tiku_identity/08_study.png) | (-18.3,1.45,145.1) → (-17,1.05,146.85) / 38° | 3s；场景受光、书/手/腿、脸部身份 |
| [H02 坐姿侧目](../renders/tiku_identity/10_study_side_eye_close.png) | (-17.20,1.42,145.72) → (-17,1.34,146.90) / 32° | 12.15s；窄眼、瞳孔、镜架、胡茬 |
| [H03 校服扶镜](../renders/tiku_identity/17_roadside_glasses.png) | (1.8,1.72,142.35) → (3.4,1.14,145) / 38° | 12.5s；同身份、夹书、自然小动作 |

完整 [对照页](../renders/tiku_identity/review.html) 包含已接受设定图、旧新 Godot、Blender 和两段32秒循环。Hero图1920×1440，Blender1200×1500，环境历史图3840×2160。比较保持同输出尺寸、投影、画质和动作时间，不能因新图更大/更亮就判断质量更好。

## 0.5人口与接段成果

本轮 `renders/population/` 已产生12张3840×2160 Godot静帧，并完成逐组实机审查。当前新增机位使用**真实相机位置**，不加1.65米。最终值在 [capture_report.json](../renders/population/capture_report.json)，复现逻辑在 `population_proof.gd`，不以按键机位的玩家脚点冒充近景捕获参数。

| 本轮实际文件 | 相机 / 投影 | 动作时间 | 本轮基准用途 |
|---|---|---|---|
| [01_world.png](../renders/population/01_world.png) | (-152,146.65,2)，正交size150 | 8s | 当前完整人口与144㎡接段总览 |
| [02_tiku_preserved.png](../renders/population/02_tiku_preserved.png) | (-18.3,1.45,145.1)，38° | 3s | 与H01相同近景；Hero身份与无桌叙事保留 |
| [03_sakura_photographer.png](../renders/population/03_sakura_photographer.png) | (8.5,1.8,138)，43° | 6s | 既有拍照节点统一成人化外观、举手机 |
| [04_cyclist_riding.png](../renders/population/04_cyclist_riding.png) | (40.55,1.895,153.5)，42° | 7s | 新增骑行、手脚与车接触 |
| [05_cyclist_pushing.png](../renders/population/05_cyclist_pushing.png) | (56.97755,1.895,153.5)，42° | 25s | 人车并排推行、相对位置 |
| [06_courtyard_reader.png](../renders/population/06_courtyard_reader.png) | (-24.4,1.7,221.9)，42° | 12s | 新增后院静区、鞋底/地垫与坐姿 |
| [07_north_connection.png](../renders/population/07_north_connection.png) | (-18,21.65,88)，46° | 8s | 12×12米陆路接段、双池边界与接缝 |
| [08_courtyard_context.png](../renders/population/08_courtyard_context.png) | (123,102.65,303)，44° | 14s | E05同机位，后院人口与留白 |
| [09_tiku_uniform_preserved.png](../renders/population/09_tiku_uniform_preserved.png) | (1.8,1.72,142.35)，38° | 9.6s | 同身份校服版冻结回归 |
| [10_cyclist_pause.png](../renders/population/10_cyclist_pause.png) | (59.1,1.895,153.5)，42° | 34s | 停靠低强度状态 |
| [11_photo_review.png](../renders/population/11_photo_review.png) | (8.5,1.8,138)，43° | 15.5s | 查看手机与轻微转向 |
| [12_reading_walk.png](../renders/population/12_reading_walk.png) | (22.3,1.9,152.7)，42° | 12s | 既有慢读节点统一外观、资料和道路接地 |

首轮03/06/12保存在 `renders/population/round01/`：用来观察旧拍照/慢读者的积木Q头、后院埋鞋问题，以及最终改进。画廊直接并列原 PNG，不编辑或重绘图像。当前比对优先用最终12图，历史环境仍用冻结宽图，Hero脸部仍用accepted_v0_4。

性能独立存为 [performance.json](../renders/population/performance.json)：1600×900普通实时视口、Forward+、RTX5060Ti、VSync开启，3机位各120帧，中位7.016–7.043ms、P95为7.846–7.860ms。它包含同步和刷新等待，不是单独GPU耗时，也不能拿4K导出期间10–33fps去替代实际运行测量。

复现：`capture_population.ps1` 捕获静帧，`-Verify` 验证，`-Motion` 捕获并编码；`python tools/population_review.py` 刷新 [画廊](../renders/population/review.html)。当前动作序列目标/manifest为100秒、1280×720、12fps、1200帧：64秒完整骑车循环 + 8秒后院 + 8秒拍照 + 12秒慢读 + 8秒Hero。MP4完成情况以实际文件/画廊为准，manifest存在不单独证明编码结束。普通游览按 `[ ]` 切换全部13机位，`P`回步行。

更新基准先保存旧文件和元数据，再写新轮次。只有通过本轮 Art Review 的新机位才进固定表；“已截图”与“已作为基准”是不同状态。

## Wave2过程基准

最新15张3840×2160原生Godot图已经代理实机艺术复核，固定相机世界XYZ、完整朝向矩阵、FOV/正交尺寸和动作时间统一保存在 [Wave2 capture_report.json](../renders/wave2/capture_report.json)，查看 [画廊](../renders/wave2/review.html) 与 [Art Review](WAVE2_ART_REVIEW.md)。03/05/07/09/11用于五节点近景，04/06/08/10用于动作和环境关系，01/02及12–14用于整体/连接/密度，15与原做题家近景回归。首轮15图与报告保存在`renders/wave2/round01/`，是迭代证据，不是当前图。新增cameo还未获得用户逐个接受记录。

01灰色展示背景较多，14前景树会遮住共读者；宽图说明连接/留白，人物身份用近景判断，不将所有宽图称宣传特写。8张游戏Blender证明和4张吉祥物接触/距离证明与Godot图分开。150秒、1280×720、12fps、1800帧MP4已编码，首/中/末三帧与元数据解码通过，未声称全帧或GUI播放验收。性能条件另见 [WAVE2_PERFORMANCE.md](WAVE2_PERFORMANCE.md)。

`capture_wave2.ps1`复拍本轮机位，`-Verify`验证，`-Motion`捕获并编码；`run_diorama.ps1 -Wave2Focus`从新总览进入，`[ ]`切全部19机位、`P`步行。上述0.5的13机位和100秒影片保留作历史基准。
