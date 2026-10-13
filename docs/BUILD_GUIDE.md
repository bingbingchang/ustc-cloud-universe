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

## 版本状态

首个公开版本为 `v0.1.0-alpha`。当前可体验校园空间与控制；账号、信息发布、多人在线互动和现实服务接口按发展路线逐步建设。
