# 角色注册表

**2026-09-13更新：优化入口新增 grove_photo 与 grove_reader 两位普通学生实例，现为16（4 Hero / 8 Ambient / 4 Creature）。** 部署读取 `west_grove.json`，范围与行为见 [WEST_GROVE.md](WEST_GROVE.md)。原模型与14人部署文件保持；下方14人口是历史入口状态。

当前共享入口：**LookDev Live 与 Diorama 都实际加载同一14实例（4 Hero / 6 Ambient / 4 Creature）及五位漫步者，本轮无增员、无身份 GLB 重建**。角色数据、home、路线与坐写/坐读例外仍共用下述事实来源；变化是环境造型、材质和光照。Live 场景 QA 8/8与原生物理通过，见 [同内容说明](LOOKDEV_VS_DIORAMA.md)；新灯光下的截图属于本轮复核，不自动成为用户已接受的新身份基准。历史59项冻结和本轮88文件/21旧图留档均保持，范围有重叠，不相加计数。

更新：2026-09-08，**Diorama 0.7，实际总人口14：4 Hero + 6 Ambient + 4 Creature，本轮未增员**。五位 Wave2 角色已获得真实迈步路线，三月七与豆包迁入北轴。整合6/6与原生物理5/5通过；59项冻结资源保持，包括角色 GLB。新图和新动作已代理实机复核，不等于用户逐一批准。

一个角色身份可以有多个场景实例，人数按实例计。旧人口由 `population.json` 执行；Wave2身份来自 `wave2_nodes.json`，home 由 `scene_modules.story_nodes()` 合并 `module_layout.json` 与 `north_axis_layout.json`，路线偏移由 `wander_routes.json` 执行。以下坐标仅为文档快照，移动角色的实时位置应读取运行状态，不能用 home 代替。

| 运行 ID / 名称 | 类型 | 区域与锚点（米） | 当前状态 | 资产与备注 |
|---|---|---|---|---|
| `solver` 做题家·长椅版 | Hero | 北前场西侧长椅，根节点 (-17,.64,147) | 用户已接受，冻结 | `tiku_boy1.glb`；32秒写题/思考/侧目/扶镜；本子在腿上，无桌 |
| `roadside` 做题家·校服版 | Hero，同身份变体 | 北前场东侧路灯边 (3.4,.978,145) | 用户已接受，冻结 | `tiku_boy1_uniform.glb`；共用头脸，左臂夹书 |
| `photo` 樱花拍照女生 | Ambient，重点节点 | 樱花区 (10.4,.005,140.8) | 原节点外观升级，已通过本轮 QA | `ambient_photographer.glb` 替换 `student_photo`；22秒举手机/微调/查看照片 |
| `reader` 背资料慢走同学 | Ambient | (14,.105,155.6) 至 (19.3,.105,155.6) | 原节点外观升级，已通过本轮 QA | `ambient_study_walk.glb` 替换 `student_reader`；46秒慢走/停读/翻页/回转 |
| `cyclist` 骑车归来的同学 | Ambient | (30,.095,157) 至 (55.9,.095,157) | 新节点，已通过本轮 QA | `ambient_cyclist.glb`；64秒慢骑/减速/推车/停顿，靠近2.1米让行 |
| `bench_reader` 后院长椅读者 | Ambient | 后院长椅根节点 (-27,.08,218.8)，朝向π | 新节点，已通过本轮 QA | `ambient_bench_reader.glb`；32秒坐读/抬眼/翻页；地垫顶.07、鞋底.075 |
| `cat` 校园猫 | Creature | 写题长椅边 (-18.22,.025,146.26) | 已在场景，保留 | `campus_cat.glb`；趴卧、呼吸、舔爪、尾巴微动，尚非完整漫游 |
| `bird0` 公告栏小鸟 | Creature | (25.15,2.56,151.3) | 已在场景，保留 | `campus_sparrow.glb`；停、转向、翅膀微动，公告栏承托 |
| `bird1` 地面小鸟 | Creature | (19.7,.11,157.4) | 已在场景，保留 | `campus_sparrow.glb`；小跳、转向，与另一只错相 |
| `raiden` 雷电将军·树荫书页 | Hero，校园 cameo | 西南 home (-123,.08,243)，在既有小径往返 | 0.7漫步与实机QA通过；尚非用户批准的新身份基准 | `cameo_raiden.glb` 冻结；捧书慢走、停顿、回原处翻页；约99.69秒完整周期 |
| `march7` 三月七·取景漫步 | Hero，校园 cameo | 北轴天使路 home (89.1,.08,88)，至北侧摄影走廊 | 0.7迁入北轴，漫步与实机QA通过 | `cameo_march7.glb` 冻结；低位持相机慢走、停下取景；约138.63秒 |
| `meituan` 美团袋鼠·等候取餐 | Ambient | 东侧 home (95,.08,160)，附近小圈 | 0.7漫步与实机QA通过 | `wave2_meituan.glb` 冻结；手机随手、箱子留原地，返回查单/开箱；约115.46秒 |
| `doubao` 豆包·共读伙伴 | Ambient | 老北门附近 home (1.6,.08,39)，沿南北铺装缓行 | 0.7迁入北轴，漫步与实机QA通过 | `wave2_doubao.glb` 冻结；官方头像参考、原创身体；捧平板慢走/停读；约182.71秒 |
| `leaf_cat` 校园狸花猫·落叶 | Creature | 西南 home (-106,.08,239)，草边小圈 | 0.7四足漫步与实机QA通过 | `wave2_leaf_cat.glb` 冻结；落叶留原处，回来闻叶；约97.65秒；区别旧长椅趴猫 |
| `black_swan` / `wild_duck` 黑天鹅 / 野鸭 | Creature | 眼镜湖后续动物层 | 未制作，不计入当前人数 | 0.7双池环境已建；以后仍需核实动物资料、停留区与水面路线，不因有湖自动增员 |

0.5历史人口为 **2 Hero 实例（1个身份）+ 4 Ambient + 3 Creature**，当时新增骑车、后院阅读两个节点，统一升级既有拍照、背资料两个节点；四套 Ambient 由同一生成器生产，分别为21,468 / 16,484 / 17,044 / 16,400三角面（依次骑车/后院/拍照/慢走），见 `renders/population/asset_manifest.json`。0.6加入五个节点，0.7只改变其路线和部分区域部署；最终全人口密度检查见 `renders/north_axis/validation.json`。

旧 `student_solver.glb` Q 版做题学生留在资产库，不在当前长椅实例化；保留文件不是新增人口。花瓣、风、草和云属于环境动态，不与角色数量混算。0.5的12米接段不设置新的故事 home；0.7把三月七、豆包迁到更北侧的不同走廊，保留中心连接处留白。

Hero 身份依据：[TIKU_IDENTITY_REVIEW.md](characters/TIKU_IDENTITY_REVIEW.md)、[原实际对照页](../renders/tiku_identity/review.html)。0.5的 [12张4K实机与对照](../renders/population/review.html)、[20项运行验证](../renders/population/validation.json) 保留。0.7当前18张图、五位漫步近景和做题家回归见 [north_axis/capture_report.json](../renders/north_axis/capture_report.json)，动作接口见 [WANDERING_BEHAVIORS.md](WANDERING_BEHAVIORS.md)。本轮96秒影片的元数据与首/中/末三帧解码通过，见 [video_validation.json](../renders/north_axis/video_validation.json)，不声称GUI连续播放或全帧验收。

新增条目保留稳定 ID、类型、变体关系、资产引用、区域/路径、周期、状态和证据。状态仅用“待研究 / 制作中 / 已接入待 QA / 已通过 / 冻结 / 停用”，不以文件存在自动认定已通过。
