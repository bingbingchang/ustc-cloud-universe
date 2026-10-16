# 眼镜湖东池—一鉴亭：第二个完整流程区域

2026-09-09。用户接受樱花大道的流程后，选择相邻东池湖园执行第二轮。入口 `OPEN_LAKE.cmd`，Live与Diorama共享。成果以 [原生实机对照](../renders/yijian_garden/review.html) 为准，概念图不作为实机完成证据。

## 从参考到全域

1. 从校园地图眼镜湖POI10842下载6张原图，保存来源、尺寸、SHA与图库；一鉴亭独立POI没有有效相册。提取六角飞檐、低栏平曲桥、大片荷叶和多层树群。真实依据与推断见 [FEATURES.md](../references/yijian_garden/FEATURES.md)。
2. 内置ImageGen依据照片03和05生成 [概念图](../references/yijian_garden/concept/direction_v1.png)，采用与樱花大道连续的莫奈方向；浅石桥引导视线，柳枝侧向框景，水面保留留白。[概念提示词](../references/yijian_garden/concept/prompt.txt)。
3. 生成一张1254×1254四分区底色图，用于水面、苔色石材、叶片与冷灰瓦面。[纹理](../godot/assets/textures/lake_monet_atlas_v1.png)及[提示词](../references/yijian_garden/concept/texture_prompt.txt)。树皮和花瓣复用上一轮莫奈图集，源照片不作为游戏贴图。
4. 独立创建两种柳树、四组荷叶/荷花、两种岸草与一组岸石，共9个GLB。先在东岸约23×36米范围内生成样段：1株柳、15组荷叶、19丛岸草、9组岸石、14丛灌木。六机位检查后修复水面被Live隐藏的问题，并改善花瓣弧度、花蕊比例和柳叶密度。最终近景重拍保存在 `sample_live/01*`、`02*`；03–06为同一布局的上一轮样段材质检查。
5. 扩展到整个东池及岸边。实际新增3株柳、242组荷叶、44丛岸草、39组岸石、28丛灌木。六组Live和Diorama原生1920×1080前后对照均保留。最后降低亭柱旧化强度，桥面石材加入笔触，水面高光收敛。

## 共享与边界

`north_axis_layout.json` 的水域外环、亭岛、桥、建筑、道路和人物位置不变；未扩展地图面积。新种植由 `lake_garden.gd` 按陆地、水域、路径及设施净空筛选；柳树碰撞来自实际低干三角形。小岸石放在原不可进入水域，岸草不构成新的墙。总树数从114到117，14个生命元素和5位漫步者不变。

笔触接在物体表面，保留场景照明和细微风动。东池水面仍用原多边形和原禁入碰撞，独立材质提供纹理缓移与连续微波法线。Live原来的底座清理按“材质是否等于原水材质”判断，误把新水材质的低位网格隐藏；现在显式识别 `lake_water` 标记。失败样段图保存在 `sample_water_hidden`，没有以填平湖面修复。

`build_lake.ps1` 只重建 `lake_*.glb`，使用Blender factory startup，避免用户启动文件的本地化节点名影响脚本。可编辑资产板为 `blender/source/yijian_garden_kit.blend`。柳树每个约1.98万三角形，荷叶组525–1481三角形，细花岸草4789三角形，采用MultiMesh复用。`run_lake.ps1 -Sample` 重现样段，`-Diorama` 切另一表现，`-Ultra` 高画质。`--lake-before` 关闭此轮改造，仍保留已完成樱花大道。

## 验证与实际限制

验证分别保存为 `renders/yijian_garden/qa_live/validation.json`、`qa_diorama/validation.json`。复用17条CharacterBody连续步行、9项禁入、陆水地面、人物和路线、历史59文件保护等检查。Live对全部117株树做实际视觉/碰撞对齐；Diorama对31株樱花和3株新柳做实际低干对齐。最终材质调整后重新捕获两版截图，未改碰撞几何。

本轮 `baseline.json` 保护修改前91个既有GLB、PNG纹理和JSON部署文件，最终哈希全部保持；`preservation.json` 是复核结果。新QA和截图输出到独立目录，上一轮樱花大道与更早验收记录不覆盖。完整生成器、截图器、验证器和画廊工具保存在 `blender/scripts/build_lake_garden.py`、`tools/capture_lake.gd`、`tools/validate_lake.gd`、`tools/lake_review.py`。

性能用RTX5060Ti、1600×900、4×MSAA/TAA、VSync关闭，14个生命元素与动画运行；四个同机位每处预热90帧后测180帧。原始报告保留窗口焦点和帧时间，数值是短时桌面实测，不是持续游玩保证。此前也存在退出时7个Texture RID清理警告，当前没有据此声称零警告。

最终短测，桥头/水岸/樱花大道/总览依次为：修改前50.6/55.9/46.1/44.3 FPS，修改后44.2/46.8/43.1/44.2 FPS。修改前窗口焦点比例为1，修改后为0，因此不能把全部差值归因于新增资产；记录供参考，未声称稳定60帧。

美术上，参考中繁茂林墙和复杂水中倒影尚未完全对应到实时版本，当前仍有明显的几何化叶片和树形；新增荷叶密度、岸草、柳树位置是艺术化设计。春日樱花与少量开放荷花并置，不宣称自然花期一致。此次完成东池湖园，西池和其他校园区域不属于本轮全域范围。
