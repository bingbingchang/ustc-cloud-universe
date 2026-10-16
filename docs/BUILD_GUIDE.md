# 源码运行与构建

## 运行校园工程

使用Godot 4.7.1标准版打开 `campus/godot/project.godot`，等待资源导入后按F5。工程已经包含生成模型，运行场景无需先安装Blender。

命令行运行：

```powershell
godot --path campus/godot
```

项目使用Forward+渲染器。公开试玩首版面向Windows x86_64，网页和移动端体验属于后续适配工作。

## 导出Windows试玩包

在Godot中安装与4.7.1匹配的导出模板，使用工程内的 `Windows Desktop` 导出预设：

```powershell
godot --headless --path campus/godot --export-release "Windows Desktop" "../../dist/USTC-Cloud-Universe-Windows/USTCCloudUniverse.exe"
```

或者在Godot的Project → Export窗口选择该预设导出。分发时保留exe、pck、Godot许可和操作说明。

## 编辑场景与资产

`campus/godot/data/module_layout.json` 管理启用区域，`campus_road_network.json` 管理道路与建筑轮廓，`full_districts.json` 管理最近扩建的片区。Blender生成脚本位于 `campus/blender/scripts/`，选取的建筑母版位于 `campus/blender/source/`。

生成器沿用本项目坐标：X向东、Y向上、Z向校园南侧，单位为米。部分生成器需要本地参考资料；研究原始影像不随此仓库分发，可按来源说明获取。几何数据和现有模型足以直接运行当前原型。

## 截图反馈

在场景中将问题对准中央准星，按F12。编辑器运行保存至工程旁的 `campus/renders/`；Windows独立试玩版保存至 `%APPDATA%\USTCCloudUniverse\screenshots`。PNG旁会有同名JSON，包含人物、相机与中心命中点坐标以及镜头方向。

## 知识 NPC 与 Agent

当前 `main` 包含 15 位知识 NPC、RAG 后台和校园向导 Agent。先按 [AI 运行说明](../campus/ai/README.md) 启动服务，在游戏 J 面板设置地址；E 交谈，K 打开行动向导。可通过 `CAMPUS_AI_URL` 环境变量或 `run_game.ps1 -AiUrl` 指定后台地址。

## 最小联机

在仓库根目录执行，先将 `GODOT_EXE` 设置为 Godot 可执行文件完整路径：

```powershell
./campus/run_game.ps1 -Server
./campus/run_game.ps1 -NetJoin 127.0.0.1
```

两条命令在不同终端运行。同机使用无窗口主机与一个图形客户端；跨机器将加入地址改为主机局域网 IP。当前同步玩家移动与文字聊天，端口默认 45888/UDP。

## 版本状态

当前源码标记为 `0.2.0-dev`；`v0.1.0-alpha` Windows 下载包保留此前的校园漫游功能，本次未重新发布安装包。AI、联机与动物试验场等新增内容从当前源码运行。
