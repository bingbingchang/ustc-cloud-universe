# 数据与素材来源

校园建筑、道路和校界的主要轮廓来自 OpenStreetMap，使用项目既有米制坐标转换。地图数据署名为 **© OpenStreetMap contributors**，适用 [Open Database License 1.0](https://www.openstreetmap.org/copyright)。相应地图数据及其派生数据按该许可使用，原始OSM快照位于 `campus/renders/coverage/osm_east_full.xml`。

中国科学技术大学校园GIS图片与官方校园总图用于核对建筑身份、色彩、场地分组和相邻关系；Esri World Imagery用于地面形态参考。参考地址：[校园GIS](https://gis.ustc.edu.cn/)、[官方校园地图](https://indico.pnp.ustc.edu.cn/event/3091/attachments/6396/12868/科大东区校园地图.pdf)、[Esri World Imagery](https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer)。原始参考瓦片与研究照片不随公开试玩包分发，主要映射记录在 `campus/references/` 的JSON文件中。

校园建筑和植被等运行资产由项目的Blender脚本生成；部分层数、未见立面与入口细节为近似处理。公开演示版采用项目原创的校园学生人物与动物，本地研究使用的既有游戏与品牌角色未纳入公开发行资产。

Godot运行时使用MIT许可。试玩包附带Godot许可与第三方组件说明。字体采用系统字体显示，建模过程中的文字几何已随模型生成，不分发Windows字体文件。

此仓库公开项目源码与演示成果，未为全部原创代码和资产另行指定统一的开源许可；第三方数据和运行时遵循各自的许可。项目为独立探索，不代表学校官方发布或已有合作背书。
