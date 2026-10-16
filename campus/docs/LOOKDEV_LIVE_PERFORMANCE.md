# LookDev Live 普通窗口性能采样

2026-09-08 实测完成。Godot 4.7.1 stable、Forward+ / Vulkan 1.4.341、NVIDIA GeForce RTX 5060 Ti。

与现有 `north_axis_profile.gd` 使用相同的墙钟交付帧统计：真实 **1600×900** 窗口、VSync 关闭、Engine.max_fps=0、3D 缩放 1.0、**4× MSAA（枚举 2）与 TAA 开启**。保留 HUD、全部 14 个生命元素及环境动态，只冻结玩家。每个机位预热 90 帧，采样 180 帧。

机位顺序为索引 3（一教原 LookDev 视角）、0（玉泉北路）、1（一鉴亭）、19（共享世界总览）。不是离线截图或视频编码速度，不读取截图纹理。

| 机位 | 实际交付 FPS | 帧时间中位数 | 帧时间 P95 | Draw 中位数 | 提交图元中位数 |
|---|---:|---:|---:|---:|---:|
| 3 · 一教原 LookDev 视角 | 93.13 | 10.71 ms | 11.63 ms | 1,847 | 59,115,044 |
| 0 · 玉泉北路 | 86.87 | 11.58 ms | 12.39 ms | 2,171 | 55,700,542 |
| 1 · 一鉴亭 | 95.35 | 10.49 ms | 11.39 ms | 1,383 | 54,163,683 |
| 19 · 共享世界总览 | 125.47 | 7.90 ms | 8.80 ms | 2,464 | 20,350,179 |

四处实际渲染尺寸均符合 1600×900，窗口焦点均为 180/180。原核心 9 个生命元素和第二波 5 个生命元素均加载，两个动画层在采样开始时启用处理且 `manual_time=-1`；每个机位的场景时钟持续推进。报告的 `completed`、`resolution_verified`、`requested_conditions_verified` 均为 true。

这次短采样中，人高机位在约 87–95 FPS，总览约 125 FPS。总览虽然 Draw 更多，提交图元更少，不能只凭 Draw 数解释帧率。人高机位阴影距离 95 m，总览 650 m，均沿用对应普通机位设置；相机、可见范围和提交内容不同，因此本表是同一构建的机位比较，不能直接视为 Diorama 对 LookDev 的性能回归结论。

运行命令（从项目根目录）：

```powershell
& 'D:\productivity\godot\Godot_v4.7.1-stable_win64_console.exe' --path 'D:\AI\Ai_blender\campus\godot' --script 'D:\AI\Ai_blender\campus\tools\profile_lookdev_live.gd' --log-file 'D:\AI\Ai_blender\campus\renders\lookdev_live\performance_runtime.log' -- --lookdev
```

入口显式实例化 `res://scenes/lookdev_live.tscn`，不依赖项目默认的 Diorama 场景。结果写入 `renders/lookdev_live/performance.json`，包含原始帧毫秒、Draw/图元统计、焦点比例、实际尺寸和镜头记录；不会覆盖旧 North Axis/Wave 2 报告。

FPS 为 `1000 / 平均墙钟帧毫秒`，来自相邻 `process_frame` 信号之间的 `Time.get_ticks_usec()` 差值。它包含 CPU、GPU 同步和操作系统调度，不是独立 GPU 执行时长。全帧图元包含阴影/深度重复提交，**不能当作模型唯一三角面数**。

每处有效测量约 1.43–2.07 秒，90 帧预热排除了最初的一段初始化影响，但不足以覆盖热稳定性、长时间漫游、所有动态交互、冷 Shader 缓存或其它硬件。4K 宣传截图/视频导出的速度不属于这次测量。未因结果正常而追加不必要的重复采样。

进程返回 0，日志无 `SCRIPT ERROR` 或 `ERROR`；退出时标准输出仍报告 `7 RIDs of type "Texture" were leaked` 的资源清理警告。退出警告位于 [`performance_stdout.log`](../renders/lookdev_live/performance_stdout.log)，不在 Godot 已关闭的运行日志中。该警告保留为生命周期检查线索，不应描述成日志完全无警告。

证据：[`performance.json`](../renders/lookdev_live/performance.json)、[`performance_runtime.log`](../renders/lookdev_live/performance_runtime.log)、[独立入口](../tools/profile_lookdev_live.gd)、[采样子类](../godot/scripts/lookdev_live_profile.gd)。基类末行沿用旧 Wave 2 的输出提示文字，实际写入由新子类的 `_save()` 覆盖，仅写 LookDev Live 的新报告；旧采样脚本和报告没有改写。
