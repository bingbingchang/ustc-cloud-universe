# 北轴普通游玩性能采样

0.7最终版本于2026-09-08 21:22（UTC+8）重新采样，包含本轮湖岸水草与石头。实测完整 `diorama.tscn`，Godot 4.7.1 Forward+、NVIDIA GeForce RTX 5060 Ti，实际窗口与 3D 视口均为 **1600 × 900**。普通项目画质：4× MSAA、TAA、1.0 渲染比例；未开启 Ultra，未创建 4K 截图 SubViewport。VSync 明确关闭，`Engine.max_fps=0`。14 个既有人物/动物实例、植被、天空和五位角色漫步持续运行；仅冻结玩家输入以固定机位。

每个机位先预热 90 帧，再采样 180 帧；四个机位全部前台聚焦。这里的序号是代码中从 0 开始的 `viewpoint` 索引。

| 机位 | 中位帧耗时 | P95 帧耗时 | 实际平均交付 FPS | 中位 Draw Calls |
|---|---:|---:|---:|---:|
| 19 · 整体校园 | 8.02 ms | 9.16 ms | 123.3 | 2437 |
| 21 · 玉泉北路望一教 | 9.06 ms | 10.14 ms | 109.7 | 2522 |
| 22 · 一鉴亭与专家楼 | 5.89 ms | 6.84 ms | 168.2 | 474 |
| 17 · 漫步校园猫近景 | 2.69 ms | 3.53 ms | 359.9 | 206 |

测量使用实际相邻帧的墙钟时间，包含 CPU、GPU 同步与系统调度；不是纯 GPU 时间。**这是短时机位采样，不是持续压力测试，也不是 4K 离线截图导出帧率。** 宽图提交量高于近景；后续扩区优先检查宽图阴影和批次成本。本轮没有用这组数据承诺所有硬件或长时间游玩的固定帧率。

数据与全部原始帧：`renders/north_axis/performance.json`；运行日志：`renders/north_axis/performance.log`。四机位完成、1600 × 900 和 VSync 关闭均已核实。退出码 0，运行期间无 Script/Shader/Runtime ERROR；退出时出现 7 个 Texture RID 释放警告，记录保留在日志中。

独立入口复用上轮性能采样器，不更改主场景的 `_ready()`：

```powershell
& 'D:\productivity\godot\Godot_v4.7.1-stable_win64_console.exe' --path .\campus\godot --script res://../tools/profile_north_axis.gd --resolution 1600x900 -- --lookdev
```

测试代码为 `godot/scripts/north_axis_profile.gd`，报告写入独立北轴目录，未覆盖上轮 Wave 2 的结果。
