# Wave 2 · 普通窗口性能实测

最终有效命令使用 `--lookdev --wave2-profile`，与普通 Diorama 初始化一致，未开启 Ultra、图片捕获、视频输出或无窗口渲染。运行入口：[profile_wave2.ps1](../tools/profile_wave2.ps1)。

环境：Godot 4.7.1、Forward+ / Vulkan、NVIDIA GeForce RTX 5060 Ti。实际渲染尺寸三机位均为 **1600×900**，3D 缩放 1.0、MSAA 枚举 2、TAA 开启，VSync 开启、Engine.max_fps=0。普通 HUD、人物、树叶、天空和光照动态持续运行；只冻结玩家输入。每视角预热 90 帧、采样 180 帧，采样期间窗口焦点均为 180/180。

| 机位 | 实际交付 FPS | 帧时间中位数 | 帧时间 P95 | Draw 中位数 | 提交图元中位数 |
|---|---:|---:|---:|---:|---:|
| 原核心区正交 | 143.99 | 6.90 ms | 7.95 ms | 2,970 | 13,708,083 |
| 第二波总体正交 | 144.09 | 7.01 ms | 8.03 ms | 3,161 | 13,826,647 |
| 东侧教学花园 3/4 | 144.02 | 6.85 ms | 8.03 ms | 2,832 | 14,789,129 |

FPS 来自真实 `process_frame` 之间的墙钟间隔：1000 / 平均帧毫秒。没有读取或编码任何截图，**不是离线截图导出速度**。提交图元来自 Godot 全帧监视器，包含阴影、深度等重复提交；不能当作模型唯一三角面数。

结果表明这三个普通画质视角在本次短采样中都维持约 144 FPS，帧时间 P95 在约 8 ms。由于 VSync 开启，不能据此推断未限速性能余量。每个机位的有效采样约 1.25 秒，不能代替长时间游玩、热稳定性或其他硬件测试；它也不是旧版本与新版本的回归比较，三个机位都加载当前全部角色和环境。高画质 4K 截图的性能不属于这次测量。

退出时出现 `7 RIDs of type "Texture" were leaked` 的资源清理警告；进程返回 0，运行日志没有 SCRIPT ERROR 或 ERROR。该警告保留在日志供后续资源生命周期检查，不应描述为所有日志完全无告警。

证据：[完整原始帧数据与画质记录](../renders/wave2/performance.json)、[运行日志](../renders/wave2/performance_runtime.log)、[采样实现](../godot/scripts/wave2_profile.gd)。旧 `renders/population/performance.json` 保持不变。
