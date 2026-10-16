# LookDev Live 同内容验收

本入口只验证较写实 LookDev 对最新世界内容和物理的接入；它不以灰盒能运行替代画面审查。原 Diorama 北轴验收证据和旧 LookDev 归档不被覆盖。

## 复用边界

`godot/scripts/lookdev_live_qa.gd` 继承北轴实机测试类，直接使用已验证的 `walk`、`push_barrier`、`ray` 和连续性记录。旧两个 `validate` 函数包含固定目录写入或退出操作，因此不会调用。新文件只组织通用检查、数据采样与 LookDev 特有的模型碰撞对齐，不复制玩家驱动实现。

12 条测绘路径从 `north_axis_layout.json` 读取；穿亭、两处接口、两条旧草地路径作为 5 条回归用例保留，共 17 条实际路线。使用生产 CharacterBody3D、W 前進、1.8m/s，240Hz / 时间倍率 4，保持 1/60s 积分。每路点要达到 0.14m 内，禁止途中移位；逐步水平/空间位移与失败接触尾迹由父测试原样记录。

## 必查项目

- 两份 accepted 清单合并为 59 个独立文件，逐一核 SHA256。
- 14 个生命节点：4 Hero、6 Ambient、4 Creature；100m 滑窗密度与原预算一致。
- 五个漫步者完整周期采样：有移动、有步行阶段、低速，并对实际静态场景做胶囊重叠查询。
- 新北轴陆地和水体采样、可见草地与水洞检查；补旧核心地面射线回归。
- 17 条实际连续步行与 9 次建筑、水和底座外部的推入阻挡。
- 新细叶树的实际树干几何，与生产碰撞在离地 0.65m 的四向截面比较；容差 0.18m。
- 新一教入口可见台阶与生产承托高度比较；容差 0.16m。至少 6 个有效入口点，不能用“没有采样”作为通过。
- 对北轴最终报告、失败记录、修复记录的哈希做前后比对，验证本次没有覆盖它们。

模型对齐使用临时第 21 层三角形碰撞，来源是实际可见 Mesh / MultiMesh 实例。玩家只碰第 1 层，不会被 QA 临时几何改变通行；检查结束立即释放。若树批次或入口根节点未提供、有效样本不足，报告为不通过，不推断为已对齐。

无界面 Godot 的 Dummy RenderingServer 对 MultiMesh 实例矩阵的读取返回单位矩阵，不能把它当成真实位置。实际实现使用 `world.lookdev_tree_contacts` metadata 中**原样提交给 MultiMesh 的 placement 矩阵**，乘以 `asset_cache[actual_asset]` 中实际 Trunk / Bark 网格的局部矩阵。只复制该材质的真实三角形到 QA 层，再独立测量；不使用 metadata 的碰撞半径来构造视觉证明。树种变体必须是实际提交的那一个，不能对明确的 diotree 变体再次随机分配。

本轮必须逐一覆盖 103 棵可玩范围内的树、四个方向共 412 个样本，缺少矩阵或网格记为失败；外围不可进入的背景树不混入可玩碰撞检查。旧树碰撞的清理另检查 `lookdev_replaced_trunk` 元数据，避免 Godot 匿名重名节点绕过按名称删除。

场景通过 `lookdev_architecture_root` 提供新一教根节点。默认入口采样 X=-3/0/3、Z=165/165.6/166.2/166.8；特殊模型可提供 `lookdev_entry_probe_points`，仍需实际射线验收。

## 启动与输出

场景就绪后用 Godot headless 运行 `tools/validate_lookdev_live.gd`，项目路径指向 `campus/godot`，加用户参数 `--lookdev`。主场景为 `res://scenes/lookdev_live.tscn`。

输出仅为 `renders/lookdev_live/runtime_qa.json` 和 `renders/lookdev_live/validation.json`。`validate(campus)` 返回 Dictionary，本身不退出程序；独立 runner 按通过状态退出 0 / 1。

首次整场运行：59 个冻结文件、14 人口及密度、5 漫步者及障碍、地水与旧核心回归、17 实走、9 禁入推入、北轴证据不变均通过；入口 12 个实际几何高度样本误差均为 0。树干检查发现上述无界面实例矩阵读取限制，初次报告保留为 `validation_failed_tree_readback.json` 与 `runtime_qa_failed_tree_readback.json`，不能作为树碰撞失败的证据。修正数据来源后进行最终整场复测；状态以 `validation.json` 为准。

独立启动器还检查 `live_initialized`：如果生产场景初始化途中报错，直接结束，避免对半初始化场景跑出误导性报告。

实际网格复测发现真实碰撞缺陷：树根在约 Y=0.04m 时向外伸至 0.68m，但圆柱采样取 Y=0..2.2m 的统一最大半径，导致贴地根宽沿整个躯干高度外挤。103 株的 412 个方向在 Y=0.65m 均超出 0.18m 容差，最大偏离 0.562m；该版本其余七类检查全部通过。失败证据单独保留为 `validation_failed_root_flare_extrusion.json` / `runtime_qa_failed_root_flare_extrusion.json`。修复必须改变碰撞体几何，不能放宽容差。

可加 `--lookdev-alignment-only` 仅复测真实树干和入口对齐，结果写 `alignment_diagnostic.json`；此诊断不覆盖完整验收结果，也不替代最终 17 路实走回归。

## 最终结果（2026-09-08）

生产修复把实际 Trunk / Bark 三角形裁到局部 Y≤2.4m，按九种实际资产缓存低树干静态三角碰撞，并给 103 个实例使用原样 placement 矩阵。碰撞半径不再参与生成实体；贴地树根只在真实高度阻挡。

最后一次完整 headless 验收耗时 148.536 秒，退出码 0，八类检查全部通过：

| 项目 | 实测结果 |
| --- | --- |
| 人口与漫步 | 14 节点，4 Hero / 6 Ambient / 4 Creature；5 个完整漫步周期无静态胶囊重叠 |
| 冻结与历史证据 | 59 文件 SHA256 一致；北轴原最终与失败报告哈希不变 |
| 连续实走 | 17 路全部到达，29,824 个物理步，途中不传送 |
| 单步连续性 | 最大水平位移 0.060003m；最大空间位移 0.305942m，来自原接口低台阶 |
| 地水 | 5,739 新陆地、1,186 水体、1,092 旧核心点通过；20 个外墙内采样点单独排除 |
| 禁入 | 9 次实际推入建筑、水体、外边界均受阻 |
| 树干对齐 | 103 棵 / 412 截面，最大偏差 0.0000458m，旧树干碰撞残留为 0 |
| 新入口 | 12 个实际台阶几何样本，承托高度最大误差 0 |

结果为 `renders/lookdev_live/validation.json` 与 `runtime_qa.json`。诊断与失败文件保留，未覆盖 Diorama / 北轴最终证据。此验收限定内容、静态通行、配置执行与几何接触正确；画面审查和实时性能由独立截图与采样流程判断。
