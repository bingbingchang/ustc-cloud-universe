# 北轴建筑资产 / North Axis Architecture

本轮只重建老北门、一鉴亭与真实曲桥、专家楼，以及 3 栋既有 OSM 邻楼。已接受的一教、角色及其 GLB 未改动。全部几何在本项目制作，单位米；Godot `(x,y,z)` 存为 Blender `(x,-z,y)`，GLB 不需要额外旋转、缩放或平移。

## 研究与实际看图记录

| 来源 | 本次实际观察 | 使用方式与限制 |
|---|---|---|
| [科大报《致新同学》2016](https://zgkdb.ustc.edu.cn/ndetail/3705) | `references/buildings/hall_2.jpg` 老北门仰视；`hall_3.jpg` 亭桥与人体比例 | 四柱三开口、浅色横梁、细石缝、檐底分格；亭桥关系与座椅。参考，不作为纹理。 |
| [党建思政网：东区老北门，2016-05-30](https://djyszw.ustc.edu.cn/info/1041/3325.htm) | 新下载并查看 `northgate_official_2016.jpg` 完整门与公交车尺度 | 复核三门格局、上缘藤叶、非纪念牌坊式轮廓。无开放资产许可声明。 |
| [招办：夏日一鉴亭](https://zsb.ustc.edu.cn/2024/0310/c35540a631898/page.htm) | `pavilion_4.jpg`，近看暖米色柱、红色卷瓦、浅灰低桥栏、木座/背栏 | 亭与桥的主要中尺度造型来源；背景仅提供专家楼方向的局部灰坡屋面与暖墙色线索。 |
| [新闻网转载：半亩方塘映书香，2026-04-07](https://news.ustc.edu.cn/info/1056/94500.htm) | 新下载并查看 `pavilion_official_2026.jpg`，原图署名李丰 | 验证六角、上扬檐角、柱顶简洁矩形木格、钝圆柱状顶饰、临水平台。无开放资产许可声明。 |
| [苏州研究院校园相册](https://sz.ustc.edu.cn/wdxz_show/61.html) | `东区眼镜湖.jpg` 和原目录名 `东区一鉴亭.jpg` | 前者可见荷塘与低桥栏；后者实际是湖岸叠石与小径，不能仅按文件名当作亭身参考。 |
| [科大报：科大的门道](https://zgkdb.ustc.edu.cn/ndetail/4877) | 文本复核四个门垛、横梁、三门及紫藤记忆 | 不将老北门误换成黄山路新入口。 |
| [官方校园地图](https://indico.pnp.ustc.edu.cn/event/3091/attachments/6396/12868/科大东区校园地图.pdf)、[OSM](https://www.openstreetmap.org/copyright) | 本地 `site.json` 与本轮 `north_axis_layout.json` | 后者包含重新提取的桥道及亭轮廓。© OpenStreetMap contributors，衍生布局保留 ODbL 归属。 |

`pavilion_0/2/5.jpg` 经实际查看是网页 logo、横幅或二维码，未被当作建筑资料。网络照片均不进入最终游戏材质；字形是本机楷体经 GLB 导出为几何，字体文件没有打包。它不是郭沫若题字的精确描摹。

## 造型与空间取舍

- 老北门中心 `(-1, 2.65)`，横梁宽 21.7m；四柱 x=`[-11.175,-5.1,3.1,9.175]`，柱宽 1.35m、深 1.9m。横梁推定深 2.2m、建筑最高 6.52m。OSM 外包深约 5m 可能包括檐/藤包络，不当作实测结构深度。分缝、檐底细格、浅石色、红楷字和紫藤各有独立几何层。
- 一鉴亭采用真实 OSM 六点平台，中心 `(42.501,80.789)`；平台顶 `.34m`，柱圈向中心缩至 footprint 的 70%，柱高至 `3.83m`；六片曲面瓦顶在角部提起，钝顶饰最高 `7.15m`。这些竖向尺寸为照片比例估计，未作测绘精度声明。
- 桥采用 `north_axis_layout.json` 的 east_north / east_east / west_curve / west_spur 四条真实线；废弃旧 `site.json` 中 `[12,64]` 起点的手绘桥。主桥宽 2.6m，西短支 2.0m，统一桥面 `.34m`，主体板厚 `.26m`。低石栏最高 `1.01m`，短石墩、下腰板与铺装接缝形成真实尺度；折点使用 miter 相接，岔口留出侧向通过空间。
- 专家楼保留 OSM 270537516 的凹凸平面，约 12.5m 墙身和灰色复合坡屋面；增加窗台、窗格、浅色墙带、简洁入口。照片对整栋立面的覆盖不足，窗数、屋脊分段、入口构造属于中低置信度艺术推断，不能声称逐窗复原。
- 3 栋周边楼保留实际平面，不缩楼适应底座：267646978 西侧斜向长条楼、298741850 北侧住宅、298741849 另一栋住宅。住宅按本轮 layout 12m 估高，西楼 9.9m；使用克制灰米色、清楚窗列与檐口，作为中低精度围合。

## 输出与构建

- `blender/scripts/build_north_axis.py`：独立构建器。仅执行旧 builder 的 helper 前缀，不运行旧导出循环，不改 `site.json`。
- `blender/source/north_axis_architecture.blend`：可继续编辑的 Blender 源；包含主建筑和周边独立命名组。
- `blender/exports/north_axis_architecture.glb` → `godot/assets/north_axis_architecture.glb`
- `blender/exports/north_axis_surroundings.glb` → `godot/assets/north_axis_surroundings.glb`
- `godot/assets/north_axis_assets_manifest.json` / `renders/north_axis/asset_manifest.json`：逐组包围盒、面数、桥线和实体支持尺寸。

```powershell
& 'D:\productivity\blender.exe' --factory-startup -b --python campus/blender/scripts/build_north_axis.py
# 独立 Blender proof（渲染前协调 GPU）
& 'D:\productivity\blender.exe' --factory-startup -b --python campus/blender/scripts/build_north_axis.py -- --proof
```

## 碰撞分工

manifest 内 `collision_solids` 的 `box/cylinder/beam` 且 `load_in_scene=true` 由主场景加载：门柱与门楣、亭柱、固定座椅侧栏、桥侧栏。`beam` 记录 a/b 的 XZ 起止、width、height、中心 y。桥栏代理是连续窄侧面，不是挡在通路上的横向盒。

四个 `polygon` 建筑实体只提供尺寸核对，标记 `owner=environment, load_in_scene=false`，环境模块已建同一碰撞，不应重复。桥面、亭面、桥头坡、陆地和水体阻挡均由环境模块负责。本资产不再创建它们的碰撞。

亭桥在平台角部衔接，柱在桥轴向内侧；玩家应能在柱旁进入，实际步行路线需要通过柱间开口验证，不能只用穿过柱心的直线判断可通行。

## Render → Review → Fix

已完成独立 EEVEE 1800×1200 两轮门/亭/专家楼 proof，并实际查看。第一轮发现门整体裁切、楷书识别不足、藤叶过薄、瓦沟分段感；第二轮退相机、换成清楚楷体几何、加藤冠内层、将瓦沟改为连续 swept mesh。取消小窗框无益 bevel，将专家楼从约 36.9 万三角形降至约 10.4 万，保留窗台深度和窗格节奏。

`gate_front_blender.png` / `gate_campus_blender.png`、`pavilion_bridge_blender.png` / `pavilion_east_blender.png`、`expert_south_blender.png` 是实际 Blender 模型证据。背景平面只是独立检查的中性色接影面，没有作为校园内容导出。这些图不冒称 Godot 实机，也不能代替全场碰撞、材质与构图验收。

已知限制：专家楼与周边建筑非测绘级外立面；独立灯光比校园最终 NPR 更中性；紫藤节奏和亭瓦仍有程序化重复，需要与现场树冠和天空组合后评审。本轮没有宣称达到最终动画电影质量。

## Godot 首轮独立 Art Review

实际查看本轮 `07_pavilion_front.png`、`08_bridge.png`、`10_inside.png`、`11_neighbours.png`、`06_pavilion.png`，对照官方亭桥照片。

- 辨识度：六角红瓦、钝顶饰、暖柱、木座与低浅石栏在 Godot 中保持成立。08 透视桥栏实际留有中间通路，10 内部座只占三边，另三边为入口，不存在整个亭口被实体墙封住的问题；柱旁转入仍需实际步行验证。
- 真实场景层次：官方参考的亭被荷叶、岸石、灌丛和较密的树冠包围，首轮实机的裸草亭岛与空池明显过于清空。后续优先在桥口之外组织稀疏荷叶、岸石和低灌木，保留亭轮廓与水面留白，而不是均匀加树。
- 07 屋瓦条纹在近景仍略规整；色相/粗糙度可微调，但无需重新增加瓦片密度。11 邻楼窗列和围合完成度适于背景，重复灰色平屋顶与整齐窗列仍显概括；不得以此宣称专家楼和住宅完整外立面真实。
- 首轮06屋顶顶饰下出现黑三角。CPU检查证实合批后开放屋面有反向法线，Blender双面预览掩盖了背面剔除问题。已将裸瓦面和檐底分离并强制分别朝上/下，保持原顶点形体、坐标不变，重新导出GLB。`geometry_checks.json` 实测两组零错误朝向，后续 Godot 重新导入画面才是最终证明。
- 首轮水面大三角明暗与岸线材质不属于建筑GLB，交由主场景单独修正。门/西桥相机被树遮挡的构图也由主场景重设。独立渲染通过不能替代这轮实机的发现。

## 湖岸补件

`blender/scripts/build_north_lake_props.py` 独立导出 `north_lily.glb` 与 `north_rock.glb`，源 `blender/source/north_lake_props.blend`；未重导出任何旧角色或一教。

荷叶为5片略起伏的径向浅盘与细茎，约1.9×1.76m，根点放水面（本轮y=-.05），局部水下茎至-.38、最高叶至+.247；5040三角形、3对象。春日不做大片盛花，建议 .8–1.25 倍、分3–4小簇放东池近岸，桥口留约4m空隙。石组约2m宽、1.14m高，3382三角形、1对象，底-.12m埋根；建议 .7–1.45 倍沿真实岛岸分组，不把石头围成整齐一圈。它们不自动改变岸线或生成碰撞，位置由Godot依实际polygon选择。照片只指导形体，没有变成材质。

## 最新资产统计

| 组 | 对象数 | 三角形数 |
|---|---:|---:|
| NorthGate | 5 | 53,916 |
| NorthGateVine | 4 | 48,386 |
| NorthPavilion | 6 | 78,392 |
| NorthPavilionRoofSurface | 1 | 6,192 |
| NorthPavilionRoofSoffit | 1 | 6,704 |
| NorthBridges | 3 | 53,596 |
| NorthExpert | 9 | 103,664 |
| NorthSurrounding_267646978 | 7 | 52,342 |
| NorthSurrounding_298741850 | 7 | 37,420 |
| NorthSurrounding_298741849 | 7 | 36,044 |
