# 校园小动物资产

现有动物包含狸花猫、成年绿头鸭雌雄变体、树麻雀，以及第二批灰松鼠和刺猬。独立试验场包含一猫、两鸭、三雀、一松鼠、一刺猬；正式校园部署由重建会话根据真实地形配置。

麻雀脸部已移除凸起白脸颊、黑色脸颊圆点、眼圈与喙下黑色团块；头部使用连续的棕色顶冠与浅褐羽色纹理，眼睛缩小。原有 8 个动作保留。猫与鸭保留当前版本。后续新增动物优先复用许可明确的现成资产，再做校园风格和行为适配。

## 打开与操作

双击 `campus/OPEN_ANIMALS.cmd`，或运行 `./campus/run_wildlife.ps1`。在 Godot 编辑器里也可直接运行 `res://wildlife/animal_lab.tscn`。默认校园游戏入口保持原引用。

| 操作 | 功能 |
|---|---|
| 1 / 2 / 3 | 猫、鸭、麻雀近景 |
| 5 / 6 | 松鼠、刺猬近景 |
| Tab | 下一个体，包括母鸭与不同麻雀 |
| 拖动左键 / 滚轮 | 近景转动镜头 / 缩放 |
| Space | 逐项播放所选动物的动作 |
| B | 恢复日常活动 |
| R | 重置行为、路线和随机种子 |
| 4 | 人高漫游，开启接近反应 |
| WASD / Shift / 鼠标 | 漫游移动 / 跑步 / 环顾 |
| Esc / 左键 | 释放 / 捕获鼠标 |
| F / F12 | 隐藏界面 / 实机截图 |

近景观察模式不触发接近反应；切到漫游模式后，动物观察玩家的位置和移动速度。猫先观察或起身，近距离或快速接近时沿已有路线避让；鸭离开近岸区域；麻雀跳开或飞到栖点。玩家离开后恢复活动。

## 资产与动作

生产源在 `campus/blender/wildlife/source/`；每个 `.blend` 内保存命名骨骼、蒙皮、独立 Action、静态初始姿态与打包纹理。`ConstructionCoat` 是猫的隐藏构造网格，最终可见网格经过表面融合，修改时可用它恢复构造依据。

运行资产在 `campus/godot/wildlife/assets/`；GLB 内含几何、蒙皮、动作和纹理。`manifest.json` 保存面数、骨骼数和动作来源信息。

| 资产 | 骨骼 | 基础三角面 | 动作 |
|---|---:|---:|---|
| `cat_tabby.glb` | 25 | 35,568 | idle、walk、trot、sit_down、sit、stand_up、lie_down、lie、rise、stretch、lick、observe |
| `mallard_male.glb` | 14 | 8,710 | idle、walk、swim、enter_water、exit_water、preen、rest、observe |
| `mallard_female.glb` | 14 | 8,456 | 与公鸭相同，使用相同骨骼结构 |
| `sparrow_tree.glb` | 13 | 6,966 | idle、peck、hop、takeoff、fly、land、preen、observe |
| `squirrel_gray.glb` | 7 | 844 | idle、walk、trot、sniff、observe、forage、jump |
| `hedgehog.glb` | 6 | 376 | idle、walk、sniff、observe、hide |

## 第二批：现成开放许可模型

松鼠和刺猬使用现成低多边形模型，保留原网格拓扑。原模型均为静态网格，此项目新增基础蒙皮和原地动作，并做米制尺寸与朝向适配；刺猬背部新增刺毛纹理。没有把静态模型标成作者自带动画的资源。

- 松鼠：**Squirrel / Poly by Google**，[原模型页面](https://poly.pizza/m/2WqY_AFEn-M)，[CC BY 3.0](https://creativecommons.org/licenses/by/3.0/)。全长约 0.36 米。试验场在树根附近的地面节点间走动、观察和觅食；玩家靠近时先警觉，再沿路线避让。`jump` 提供单独动作预览，本版自动路线只包含地面活动，上树和树间跳跃尚未接入。
- 刺猬：**Hedgehog / Poly by Google**，[原模型页面](https://poly.pizza/m/8UNni5IvK_c)，[CC BY 3.0](https://creativecommons.org/licenses/by/3.0/)。全长约 0.24 米。慢走与嗅探；近距离受惊时暂停、缩头，随后继续原路线。`hide` 是缩头反应，尚未做完全卷成球。

对应场景是 `res://wildlife/squirrel.tscn` 和 `res://wildlife/hedgehog.tscn`，使用相同的 `configure_habitat()`、`observer`、随机种子和行为信号。配置地面节点即可接入。Godot 材质保留其原贴图与新增刺毛纹理。

原下载文件在 `campus/blender/wildlife/third_party/squirrel_e.glb`、`hedgehog_google.glb`，可编辑派生源在 `source/squirrel_gray.blend`、`source/hedgehog.blend`。运行资产旁的 `THIRD_PARTY.txt` 与 GLB 元数据记录作者、来源、许可和修改，正式分发时保留署名。

新增演示为 `campus/renders/wildlife/second_batch_demo.mp4`，20 秒、1600×900、24fps；近景编号 16–21。这批是轻量级低多边形资产，刺毛采用纹理细节，未使用真实毛发系统。

单位为米，Godot `+Y` 向上、`-Z` 向前。动物比例由生产源决定；麻雀导出包含 0.8 的整体比例，保持其实际小体型，部署时通常不再放大。GLB 不包含世界位移，Godot 控制位置，`AnimationTree` 管理播放与过渡；按脚掌支撑期的实际步幅匹配步频。

Godot 导入启用自动网格 LOD。动画根据当前镜头距离更新：18 米以内正常更新，18–35 米约 30Hz，35 米以外约 15Hz；行为与位置仍按物理帧更新。

## 接入校园

实例化 `res://wildlife/cat.tscn`、`mallard.tscn` 或 `sparrow.tscn`。动物资产自行保留材质，不要对动物调用校园原有 `style()`，它会把导入材质换成不含毛色贴图的通用材质。

```gdscript
func add_cat(parent: Node3D, home: Vector3, safe_stop: Vector3, player: Node3D) -> Node3D:
    var cat = preload("res://wildlife/cat.tscn").instantiate()
    cat.random_seed = 218
    cat.boldness = 0.65
    parent.add_child(cat) # 在已进入 SceneTree 的 parent 下完成模型初始化。
    cat.configure_habitat(
        [home, safe_stop],
        ["ground", "ground"],
        [Vector2i(0, 1)]
    )
    cat.observer = player
    return cat
```

`home` 与 `safe_stop` 应来自校园实际地表和已确认的畅通路线。试验场坐标不用于校园正式部署。

| 参数 / 接口 | 用途 |
|---|---|
| `species`、`asset_name` | 包装场景已设置物种和模型；母鸭在 `add_child()` 前设 `asset_name="mallard_female"` |
| `random_seed`、`boldness` | 可复现的停留差异、接近时的胆量；胆量默认 0.5，通常使用 0–1 |
| `configure_habitat(nodes, modes, links, start=0)` | 初始化活动节点、节点类别、无向边和初始节点；节点使用世界坐标 |
| `node_modes` | `ground`、`shore`、`water`、`perch`，与节点逐项对应 |
| `route_links` | 索引对 `Vector2i(a,b)`；动物只走这些已经确认的连线 |
| `water_polygon`、`water_height` | 水域 X/Z 平面轮廓与真实水面高度；水中鸭的根节点默认比水面低 0.11 米 |
| `observer` | 玩家或其他 Node3D；位置差分得到移动速度，遮挡物阻断接近反应 |
| `current_behavior`、`behavior_changed(previous,current)` | 读取日常状态，订阅状态变化，供后续互动接入 |
| `available_clips()`、`preview_clip(name)`、`resume_behavior()` | 查看或演示动作，恢复日常行为 |
| `reset_behavior()`、`snapshot()` | 重置种子与初始节点，读取当前位置、动作、速度等 |

水鸟的上下岸必须通过 `shore ↔ water` 边连接。水中路线要处在可通行的水域内，避开亭岛、桥墩与荷叶密集区域。试验场中的两鸭使用错开的路线；正式部署可分别配置同样的局部偏移，保持个体间距。

麻雀相邻短距离地面节点使用跳步，较远节点或栖点之间使用起飞—飞行—减速落地。栖点根位置应对应枝条或栏杆上表面。此版本采用预先确认的局部路线，尚未提供全校园寻路、任意坡面逐脚 IK 或通用群体避障。

## 重建与验证

已有 GLB 可直接运行。仅在改模型或纹理后重建：

```powershell
./campus/build_wildlife.ps1                 # 六个模型、纹理、动作及导入
./campus/build_wildlife.ps1 -Species cat    # 只重建猫的模型和动作
./campus/build_wildlife.ps1 -Species open   # 适配现成松鼠、刺猬及新增动作
./campus/build_wildlife.ps1 -ImportOnly     # 只导入现有资源
./campus/run_wildlife.ps1 -Verify           # 绑定、脚步、120秒模拟行为、接近反应
./campus/run_wildlife.ps1 -Capture          # 原生近景与试验场截图
./campus/run_wildlife.ps1 -Motion           # 实机帧序列并编码、解码检查
./campus/run_wildlife.ps1 -NewMotion        # 松鼠、刺猬的20秒实机演示
./campus/run_wildlife.ps1 -Performance      # 1600×900、动画运行中的独立性能采样
```

构建脚本复用现有 `tools/find_apps.ps1`。纹理生成默认使用 Codex 自带 Python，可用 `-TexturePython` 指定装有 NumPy/Pillow 的解释器。Blender 在后台独立进程中制作，避免改变正在打开的校园场景。

实机证据在 `campus/renders/wildlife/`：`review.html`、静帧、`wildlife_demo.mp4`、`validation.json`、`performance.json` 与影片解码结果。性能记录只描述独立试验场，不替代正式校园集成后的测量。

## 制作依据与下一步

真实造型参考保存在 `campus/references/wildlife/`；参考照片不进入生产纹理。猫采用 [成年狸花猫侧面](https://www.redzet.lv/en/photo/walking-cat-D-019-23)与 [Muybridge 连续动作照片](https://commons.wikimedia.org/wiki/File:Cat_galloping_(rbm-QP301M8-1887-719).jpg)判断结构；鸟类参考 [Cornell 绿头鸭识别资料](https://www.allaboutbirds.org/guide/Mallard/id)与[树麻雀资料](https://www.allaboutbirds.org/guide/Eurasian_Tree_Sparrow/id)。纹理由 `make_textures.py` 原创生成。

已有五类动物可在独立试验场运行。后续优先寻找许可明确的现成鸳鸯、黑天鹅与鱼模型，再增加颈部动作和水下路线；主动投喂、抚摸和熟悉度留到下一轮。
