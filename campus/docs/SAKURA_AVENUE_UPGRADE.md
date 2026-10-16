# 樱花大道 · 春日与莫奈方向材质

2026-09-09，已接入现有 LookDev Live 和 Diorama，尚待用户审美反馈。双击 `campus/OPEN_SAKURA.cmd` 从 Live 大道机位进入。[实机对照](../renders/sakura_avenue/review.html) 包含六组改造前后图、同机位 Diorama，以及单独的贴图前后对照。

## 范围与依据

真实参考保存在 [10张校园地图照片](../references/sakura_avenue/index.html)。保留现有地图轴线、建筑、双池、桥亭和人物布局，以横展低分叉花树、后排高树、路缘和低层植被构成辨识特征。花树形态、种植密度和色彩属于艺术设计，不能视为实测树木清单。先实现约38米样段再扩展到现有大道；`run_sakura.ps1 -Sample` 可单独显示样段。

共享模块 `godot/scripts/sakura_avenue.gd` 添加31株花树、9株后排绿树、258丛灌木与536簇草，花树有3个几何变体。包含路侧铺装、小庭院灯、地面落花和100个缓慢飘落粒子。枝叶轻摆，原有14个人物/动物与5位漫步者保持运行。未增加整座校园的新建筑或室内。

新模型独立保存于 `blender/source/sakura_avenue_kit.blend`，由 `build_sakura.ps1` 重建，仅输出 `sakura_*.glb`。现有地图、建筑和角色资产未重建。每株花树约22万三角形，采用 MultiMesh 复用；高空和更大范围扩建仍应考虑LOD。

## 材质方向

选用莫奈启发的春日印象派色彩：石面奶油灰与淡紫、树皮暖褐与冷灰、绿叶冷暖交错、花瓣粉白与淡玫瑰色。通过内置 ImageGen 生成实际底色贴图，未取用具体画作。文件为 [sakura_monet_atlas_v1.png](../godot/assets/textures/sakura_monet_atlas_v1.png)，实际1254×1254，每格627×627；[完整提示词](../references/sakura_avenue/concept/monet_texture_prompt.txt) 请求2048但工具输出尺寸以文件为准。

`sakura_paint.gd` 与 `sakura_paint.gdshaderinc` 将四个分区按世界米制尺度映射到石材、树干、叶片和草地；花瓣使用独立细尺度采样。草地与铺装效果在大道边缘渐变衰减。保留原有灯光、阴影和适用的法线/粗糙度，未添加屏幕油画滤镜，也未把笔触覆盖到人物脸部。原始 academic/diorama 着色器文件保持不变。

`--sakura-unpainted` 保留新种植但关闭笔触，`--sakura-before` 同时关闭新种植与笔触。概念图只用于方向参考，不能当作实机成果。当前三维树冠仍明显有几何造型，效果不等同于完整油画风格渲染。

## 检查与复现

两版布局分别通过8组检查：17条连续步行、9项禁入、地面与水体、人物数量和路线、实际树干视觉/碰撞对齐等。最初发现新增后排树靠长椅过近，已扩大长椅避让距离并完整重跑。Live检查全部114株树；Diorama新增花树按实际低干几何检查。最终纹理接入后两版原生截图正常输出，无脚本/着色器错误。材质修改未动碰撞几何。

历史59冻结文件检查通过，另有本轮104个既有资产/数据文件哈希保护，两份清单有重叠。[Live记录](../renders/sakura_avenue/qa_live/validation.json)、[Diorama记录](../renders/sakura_avenue/qa_diorama/validation.json)、[保护记录](../renders/sakura_avenue/preservation.json)。

运行 `tools/capture_sakura.gd` 输出1920×1080原生截图，加 `--sakura-diorama` 拍另一版。`tools/validate_sakura.gd` 重跑场景检查，`tools/profile_sakura.gd` 输出实时性能；都通过 Godot `--path campus/godot --script res://../tools/…` 调用。`python campus/tools/sakura_review.py` 重新生成画廊。

性能条件为RTX5060Ti、1600×900、Forward+、4×MSAA和TAA、关闭垂直同步、14个生命元素与动画运行；每机位预热90帧后采样180帧。比较包含整个种植和材质升级的成本，不能解释为单独贴图成本。具体数据见画廊及 `performance_before.json` / `performance_after.json`，不代表长期游玩或其他显卡表现。截图与性能程序退出时仍有7个Texture RID清理警告，修改前也存在。
