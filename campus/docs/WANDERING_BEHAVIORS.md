# 校园漫步与驻足行为

本轮把第二波五个站立故事节点改为“慢走—停顿—转身—继续—回原处继续故事”。不新增人物，不重建身份 GLB；坐着做题、长椅读书继续保留静区，既有骑车和背资料角色继续使用已完成的运动机制。

## 唯一数据来源

- `godot/data/wave2_nodes.json`：角色身份、资产、朝向、故事节点引用。
- `scene_modules.story_nodes()`：合并 `module_layout.json` 与 `north_axis_layout.json` 后的真实 home。北轴覆盖同名 `march7`、`doubao`，没有在漫步文件再抄一份 home 坐标。
- `godot/data/wander_routes.json`：相对 home 的安全路线点、最高速度、步幅、抬脚高度、停顿和起始时间偏移。
- `godot/scripts/campus_wander.gd`：从这些参数计算实际世界坐标路线与完整周期。

文档中的周期是本轮验证时的结果。改路线后重新运行验证，以新 JSON 为准，不手工修正文档去代替配置。

## 五个节点

| 节点 | 漫步范围与叙事 | 最高速度 | 往返累计路程 | 本轮完整周期 |
|---|---|---:|---:|---:|
| 雷电将军 | 原西南树荫与研究过的步道短接；捧书漫步，回原地翻页 | 0.62 m/s | 17.19 m | 99.69 s |
| 三月七 | 北轴天使路摄影走廊；低位持相机行走，回停留点取景 | 0.66 m/s | 36.02 m | 138.63 s |
| 美团袋鼠 | 原东侧接收点附近的小圈；手机随手，保温箱留在停靠点 | 0.48 m/s | 13.38 m | 115.46 s |
| 豆包 | 老北门一侧平直铺装通道；捧平板慢走、停顿、返回阅读 | 0.52 m/s | 38.00 m | 182.71 s |
| 校园狸花猫 | 原西南草边小圈；四足交错迈步，回原地闻落叶 | 0.38 m/s | 10.63 m | 97.65 s |

三月七沿地图代理确认的天使路中心线，豆包沿老北门接近段；两条路线按至少 5 m 的净空走廊布置。南侧三条路线局限在既有第二波铺装/草边。它们是可重复验证的人工安全路线，不是任意穿越地图的随机寻路。完整区域的水体、建筑、树木和边界仍需通过场景物理验算。

每位角色在原故事点停留 28–32 s；途中停留约 2–5.4 s。各自周期和起始偏移不同。速度在每段起终点平滑归零，转身另分配小步时间，不在脚底固定时整个人突然旋转。最高速度是瞬时峰值，平均速度更低。

## 脚步与模型

`CampusWander.sample(id,t)` 是纯时间采样。根位置和朝向、左右脚/四足的着地点来自同一个步态相位，固定任意时间都能复现。支撑期保存世界坐标脚点；摆动期才抬脚和前移。每个运动段结束在多足支撑状态，停顿时不会把一只脚冻在半空。

- 游戏角色沿用原 `Human → Leg → Knee → Foot` 两段 IK。行走时骨盆略降低，避免腿打直；原头部、衣服、手与书本/相机接触保持。
- 三个吉祥物/动物沿用原腿和鞋/爪网格。`wander_legs.gd` 在运行时增加两段腿控制，将腿部顶点形变加入原 NPR 材质；鞋/爪是实际可测的节点。没有把人物转成贴片，也没有覆写源 GLB。
- 膝部过渡使用短距离平滑混合，保留材质色板与法线。验算同时检查传给 GPU 的绑定端点，避免“数学 IK 正确，但裤脚离开鞋面”。
- 双足交错；猫采用四足不同相位和较长支撑占比。抬脚 2.5–4.2 cm，不大幅蹦跳。

这是针对当前平整、已核实路线的确定性地面适配。尚未实现坡面逐脚射线、跨台阶、玩家绕行或全校园动态避让，不能把它当成通用 NavMesh NPC 系统直接放到任意地形。

## 固定道具与碰撞

美团的 `Parcel` 与猫的 `Leaf` 被重挂到原故事点的固定 anchor，保留原来的本地动作坐标。角色离开期间使用原故事的静息姿态；回到 home 并恢复朝向以后才继续查单、开箱、闻落叶。箱体碰撞仍位于停靠点。

五个角色的碰撞改为角色根节点下的 `AnimatableBody3D`；身体碰撞随人物位移和转身，原地不再留下人物的静态碰撞块。道具不会因人物漫步被拖着走。

## 集成与复现接口

```gdscript
# 默认游戏更新，时间单位为秒。
wave2_layer.pose(t)

# 截图/验证时固定时间；关闭恢复自动累计。
wave2_layer.manual_time = 12.0
wave2_layer.manual_time = -1.0

# 明确的静态身份对照入口；不代替日常游戏漫步。
wave2_layer.pose_story(t)

# 当前角色的真实鞋底/爪底与理想路径状态。
var state = wave2_layer.snapshot()
var sole_points = state["march7"]["feet_world"]
var motion = state["march7"]["locomotion"]

# 任意时刻纯采样，不需要先渲染。
var motion_at_t = wave2_layer.wander.sample("march7", t)
var route_points = wave2_layer.wander.routes["march7"].points
var cycle_seconds = wave2_layer.wander.duration("march7")

# 默认隐藏的细路线与方向箭头。项目 L 键调用；F8 也可调试。
wave2_layer.toggle_routes()
wave2_layer.set_route_debug(false)
```

`motion` 包括 `position`、`heading`、`phase`、`speed_mps`、`gait_units`、`walking_weight`、`story_active`、`story_time`、`feet`。每只脚提供 `position`、`stance`、`plant_id`、`lift`；`feet_world` 是模型实际结果。角色近景截图应在同一时间调用 `pose(t)` 后根据当前角色位置布相机，不按旧 home 寻找已经走开的角色。

## 验证与艺术复核

已完成独立进口 GLB 的完整周期验证：`renders/wandering/locomotion_validation.json`，五位全部通过。每位按 20 Hz 遍历整个周期，共 12,690 个姿态样本；检查有限变换、真实脚点、实际绑定端点、完整循环、抬脚、速度和固定道具 anchor。

- 最高速度符合 0.38–0.66 m/s。
- 五个模型的循环首尾位置/基向量误差为 0。
- 最大全局支撑期脚点残差约 2.33 mm/s，包含百米坐标处单精度变换量化。
- 最大 IK / GPU 绑定端点偏差约 0.056 mm。
- 已输出 7 张实际 Godot Forward+ 近景：`renders/wandering/proof/`。使用与校园一致的 NPR 材质；用于查看腿脚连接和身份保持，纯背景 proof 不冒充最终校园宣传图。

首轮 GPU proof 捕获了材质变量名冲突，以及单段腿转两段后脚踝连接不足的问题；已修正并重新渲染。最终近景复核确认脚/爪没有脱离腿端，人物身份、服装和手中道具保持，慢步中的膝弯曲可读。

随后完整校园实机已完成五条路线的角色胶囊障碍检测，`renders/north_axis/validation.json` 中 `walk_routes_obstacle_free=true`，人口密度检查也通过。整合后的角色近景 14–18 已由根代理查看，身份、腿脚保持可接受；这是代理实机复核，不代表用户已逐一做最终美术验收。草地、湖岸、模块边界的其他检查以同一北轴报告为准。

`[ ]` 切换角色机位时读取人物当前的位置和朝向；角色已走开时不会仍然拍旧故事点。调试箭头约每 2 m 一个，节点只有小十字标记；L/F8 默认关闭。

从项目根目录运行：

```powershell
& 'D:\productivity\godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path .\campus\godot --script res://../tools/validate_wander.gd
& 'D:\productivity\godot\Godot_v4.7.1-stable_win64_console.exe' --path .\campus\godot --script res://../tools/wander_proof.gd --resolution 1600x1000
```

后续增加漫步角色时，先复用控制器与相对路线数据，再为其已验收骨架实现 `apply_locomotion`。不要为增加一个行走节点重做头部，也不要用逐帧根平移掩盖没有迈步的腿。

普通 1600 × 900 完整场景的四机位短时性能采样已完成，VSync 关闭，五位漫步角色与原人口持续运行。整体/北轴/湖亭/校园猫近景中位帧耗时分别为 8.02 / 9.06 / 5.89 / 2.69 ms；方法与限制见 [NORTH_AXIS_PERFORMANCE.md](NORTH_AXIS_PERFORMANCE.md)，不以离线截图导出速度代替游玩性能。

行动线用9cm宽的紫色带与方向箭头表示，保持默认隐藏；最终 `north_axis/19_routes_debug.png` 使用天使路局部高位视角，避免总览中路线过小无法辨认。`north_axis/campus_life_demo.mp4` 为96秒原生帧序列；已核实1280×720、12fps、1152帧并解码首/中/尾帧，见 `video_validation.json`，不声称进行了连续GUI播放。
