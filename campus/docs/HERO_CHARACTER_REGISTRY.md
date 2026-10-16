# Hero与重点故事角色总表

## 当前校园知识角色 · 15位

原五位完成外形与动画更新，另新增10位。由 `hero_interactions.gd` 加载 `hero_npcs.json`；每位使用独立 `npc_<id>.glb` 与 Blender 母版，外形参数在 `npc_appearance.json`。共有六类关键帧动作：待机、职业工作、招呼、交谈、步行、倾听。独立资料范围和会话历史共用云端 Qwen 服务。

| ID | 角色 | 外形与道具 | 职业动作 | 地点 |
| --- | --- | --- | --- | --- |
| solar | 林曜 · 太阳物理研究员 | 短卷发、眼镜、胡茬、研究外套；太阳磁环模型 | 举模型讲解 | 眼镜湖公共步道 |
| finance | 许知衡 · 财务服务老师 | 灰色侧分、眼镜、商务夹克；计算器与票据 | 低头核算与按键 | 第一教学楼北前场西侧 |
| library | 沈书宁 · 图书馆员 | 发髻、开衫、眼镜；书本 | 阅读与翻页手势 | 东区图书馆前步道 |
| history | 程溯 · 校史讲解员 | 马尾、围巾、讲解背心；档案册 | 持档案讲解指引 | 郭沫若广场东侧 |
| ai | 周向量 · AI 研究生 | 蓬松短发、连帽衫、眼镜；平板 | 查看平板与敲击 | 北门校园步道 |
| dining | 唐暖 · 食堂主厨 | 厨师帽、白色短袖、棕色围裙；餐盘与勺 | 持盘搅拌 | 东区学生食堂208前步道 |
| physics | 顾明理 · 物理教师 | 灰发、眼镜、长外套；笔记与粉笔 | 持笔讲解 | 第二教学楼前步道 |
| student | 叶新程 · 本科生向导 | 校队夹克、双肩包；折叠导览图 | 看图与指路 | 老北门内导览点 |
| dorm | 罗安 · 宿舍管理员 | 齐耳短发、绗缝背心；登记册与钥匙串 | 登记与查看钥匙 | 学生公寓320号楼前步道 |
| network | 程联 · 校园网工程师 | 工具背心、短发；路由设备与工具 | 检修设备 | 东区学生活动中心前步道 |
| lab | 苏谨 · 实验安全员 | 马尾、实验服、护目镜；试管架 | 举管观察 | 地球和空间科学前沿研究中心前步道 |
| sports | 贺跃 · 体育教练 | 运动短袖、短裤、白球鞋；篮球 | 持球与肩部热身 | 体育教学部前步道 |
| career | 陆启 · 就业导师 | 商务外套、丝巾；履历板与笔 | 持板书写 | 东区老图书馆（办公楼207）前步道 |
| international | 江语 · 国际交流学伴 | 卷发、围巾、背包；护照与地图 | 持图欢迎与指路 | 国际学院／国际合作与交流中心前步道 |
| botany | 许青禾 · 植物观察学生 | 遮阳帽、田野背心；盆栽与放大镜 | 观察植物 | 眼镜湖南端观察点 |

15位的模型、碰撞、到达点、招呼和职业动作变化检查通过。来源链接、版本、模型与RAG流程见[运行说明](../ai/README.md)，[实机视频](../renders/heroes/animation/campus_life_demo.mp4)。历史摄影入口人口由下文各自注册表决定。

0.7更新：现有5位Wave2角色全部加入漫步，没有新增人物。三月七home迁到湖畔天使路(89.1,.08,88)，豆包迁到玉泉北路(1.6,.08,39)，其余home保留。原身份GLB不变，新增脚掌锁定、腿部弯曲与移动碰撞。详见 [WANDERING_BEHAVIORS](WANDERING_BEHAVIORS.md)。下表的旧区域文字保留制作历史，静态home不再代表角色只能站在此处。

Wave 2，2026-09-08。表名包含Hero，但实际类型保留Hero / Ambient / Creature，不因来自商业IP就把所有角色都计作Hero。新旧所有可见实例一起计入密度；角色注册与具体节点配置是两个层次。

## 已有冻结基准

| 运行ID | 类型 | 身份 / 状态 | 依据 |
|---|---|---|---|
| solver | Hero | 做题家长椅版，用户已接受，保留 | `benchmarks/accepted_v0_4/manifest.json` 与 `renders/tiku_identity/` |
| roadside | Hero，同一身份 | 做题家蓝白校服版，用户已接受，保留 | 同头脸、不同衣着与夹书循环；不重新设计 |
| photo / reader / cyclist / bench_reader | Ambient | 上轮4位已统一，保留 | `godot/data/population.json` 与 `renders/population/` |
| cat / bird0 / bird1 | Creature | 原长椅趴猫与两鸟，保留 | 同上；本轮新猫必须与旧猫区分 |

## 本轮新增5节点

以下为实际 `godot/data/wave2_nodes.json` 中的ID。五套生产GLB已入Godot，14项物理/人口/动作检查通过，15张二轮原生4K图已完成代理实机复核；这不等于用户已逐个接受新增cameo。

| 运行ID / 名称 | 类型 | 来源与身份锚点 | 原创校园叙事 / 周期 | 当前状态 |
|---|---|---|---|---|
| raiden / 雷电将军 | Hero，游戏cameo | HoYoLAB官方；深紫齐刘海和长辫、紫花金簪、白紫交领、酒红束腰、金圆结 | 树荫读书，微抬眼/翻页；32秒 | `cameo_raiden.glb`，4张Blender证明；技术通过、代理实机复核完成，[近景](../renders/wave2/03_raiden_close.png) |
| march7 / 三月七原冰存护装 | Hero，游戏cameo | HoYoLAB官方；粉白外翻发束、蓝侧夹、白蓝上衣、深褶裙、青色实体相机 | 驻足给校园取景；28秒 | `cameo_march7.glb`，4张Blender证明；技术通过、代理实机复核完成，[近景](../renders/wave2/05_march7_close.png) |
| meituan / 美团袋鼠 | Ambient，品牌cameo | 美团媒体包；黄长双耳、大黑鼻、小黑眼、奶油胸口、长尾和粗后脚 | 看订单、检查保温箱、等取餐；32秒 | `wave2_meituan.glb`；技术通过、代理实机复核完成，[开箱](../renders/wave2/08_meituan_order.png) |
| doubao / 豆包共读伙伴 | Ambient，官方头像校园化 | 豆包官网192px头像；深棕偏分bob、露耳、灰棕眼、黑衣浅领 | 原创朴素全身，读平板/手指沿文字/抬眼；30秒 | `wave2_doubao.glb`；技术通过、代理实机复核完成，[近景](../renders/wave2/09_doubao_close.png) |
| leaf_cat / 观察落叶的校园猫 | Creature，原创 | 原创狸花猫，与原趴猫区分毛色和姿态 | 闻叶、伸爪、听风抬头、安静；28秒 | `wave2_leaf_cat.glb`，位置引用`cat2`；技术通过、代理实机复核完成，[叶片故事](../renders/wave2/11_cat_leaf.png) |

暂不制作的候选：奶蛙（原作者、App形象与AI网络变体不唯一）、牛来（本次只取得粉丝站多人剧照，成年/小牛身份未收敛）。不将未选择项算入5个交付节点，不为凑数造泛化黄色动物。

游戏两位的详细方案见 [WAVE2_CAST.md](characters/WAVE2_CAST.md)；品牌两位见 [IP_CHARACTER_PIPELINE.md](IP_CHARACTER_PIPELINE.md)。官方来源、下载原图与未授权状态在 [wave2/sources.json](../../references/characters/wave2/sources.json)，未知许可不能写成CC0或官方合作。

## 完成状态的更新条件

每条记录依次更新：参考已查看 → 静态身份基准成立 → 模型已导出 → Godot近景通过 → 循环/接触通过 → 配置入场 → 同框密度与旧Hero回归通过。当前14项运行验证通过，59个旧受保护文件保持；15张最终实机图、8张游戏Blender证明及4张吉祥物接触/距离证明齐备。五周期150秒MP4已编码，解码验证状态另见本轮媒体报告。用户尚未逐个接受新增cameo，当前标记为技术及代理艺术复核完成。实际资产成本见 `renders/wave2/cameo_manifest.json` 与 `mascot_manifest.json`，简化边界见 [Art Review](WAVE2_ART_REVIEW.md)；成果集中在 [本轮画廊](../renders/wave2/review.html)。

全部5节点已接入，实际总数为4 Hero + 6 Ambient + 4 Creature；这是清点结果，**不是推荐同一100米区域一起展示**。节点分布在资料支持的西南、东花园、东路入口与广场东侧，不移动原Hero；运行时采样滑窗密度与物理已通过，具体位置见 [STORY_NODE_LAYOUT.md](STORY_NODE_LAYOUT.md)。
