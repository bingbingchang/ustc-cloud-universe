# 校园知识 NPC 与行动 Agent

这套服务为科大云宇宙的 15 位校园角色提供资料问答与向导行动。客户端为 Godot，后台为 FastAPI；共享 Qwen3-8B 生成服务，以角色提示词和独立知识范围区分人物。

[项目展示](../../README.md) · [架构与演示](../../docs/AI_NPC_DEMO.md)

## 请求链路

```text
Godot HTTPRequest
  → FastAPI /chat
  → 按 npc_id 过滤资料
  → Qwen3-Embedding-0.6B 向量检索 + BM25
  → RRF 融合，取 4 段证据
  → 角色提示词 + 最近对话 + 带编号证据
  → Qwen3-8B
  → 中文回答、来源与原文
```

随仓库提供的知识快照包含 17 份来源、191 个片段。PDF 或网页正文按 900 字符切分，重叠 140 字符；保留来源地址、版本、抓取时间与 PDF 物理页码。原始整份资料不入库，可通过 `ingest.py` 按 `sources.json` 获取。资料与索引分别为 `knowledge/chunks.json`、`knowledge/vectors.npz`。

当前知识量较小，使用 NumPy 直接计算向量相似度。检索前限定角色范围，最近两条玩家提问参与追问检索；客户端为各角色保存当前会话最近五轮对话。角色风格通过提示词设定，没有为每个 NPC 分别训练模型。

## 启动服务

建议使用 Python 3.12。以下命令从本目录执行：

```powershell
python -m venv .venv
.venv/Scripts/python.exe -m pip install -r requirements.txt
$env:QWEN_BASE_URL='http://127.0.0.1:8000/v1'
$env:QWEN_MODEL='Qwen/Qwen3-8B'
$env:EMBEDDING_DEVICE='cpu'
.venv/Scripts/python.exe -m uvicorn app:app --host 127.0.0.1 --port 8787
```

Linux/macOS 将 `.venv/Scripts/python.exe` 换为 `.venv/bin/python`，环境变量按对应 shell 设置。向量模型默认从官方模型 ID 加载；已有本地模型时设置 `EMBEDDING_MODEL_PATH`。环境变量示例见 `.env.example`，程序不自动读取 `.env`。

`QWEN_BASE_URL` 应指向已启动的兼容模型接口；需要密钥时设置 `QWEN_API_KEY`。也可在具有合适 GPU 的主机使用本仓库的 Transformers 演示服务：

```powershell
.venv/Scripts/python.exe -m uvicorn qwen_server:app --host 127.0.0.1 --port 8000
```

该服务使用 BF16 和单卡串行生成；模型与权重不随仓库提供。校园漫游和 NPC 外观无需启动模型即可查看，对话需要连接真实服务。

## 连接游戏

使用 Godot 4.7.1 打开 `../godot/project.godot` 并运行。在 J 人物面板中填写后台地址，或从仓库根目录运行：

```powershell
$env:GODOT_EXE='你的 Godot 可执行文件完整路径'
./campus/run_game.ps1 -Heroes -AiUrl http://127.0.0.1:8787
```

J 搜索人物并快速前往，靠近按 E 对话。回答后可展开检索原文，来源链接可打开对应页面。K 打开向导 Agent。

## 行动 Agent

`POST /agent` 接收用户目标，由模型逐步选择工具：

| 工具 | 行为 |
|---|---|
| `search_npcs` | 查找角色与所在位置 |
| `query_npc_knowledge` | 查询指定角色的资料 |
| `request_game_action` | 请求快速前往或打开角色对话 |

游戏动作先返回待执行状态。Godot 执行后，将 `action_id`、结果、坐标与窗口状态通过 `observations` 回传，后台再继续推理。客户端保留返回的 `state`，其中包含本次会话目标、工具结果和动作回执。

示例目标：“查学生能借几本书、借多久，带我找对应老师并打开对话”。快速前往使用位置切换；当前记忆属于本次会话。

## 更新资料与评估

```powershell
.venv/Scripts/python.exe ingest.py
.venv/Scripts/python.exe build_index.py
.venv/Scripts/python.exe -m pip install pytest
.venv/Scripts/python.exe -m pytest test_rag.py test_campus_agent.py -q
```

`ingest.py` 会更新知识片段，随后必须重建索引。网页内容随来源站点变化，新抓取结果可能与随库快照不同。

`RAG_LEXICAL_ONLY=1` 用于明确的 BM25 接口测试；`/health` 会标识该模式。单元测试模拟模型响应，检查角色隔离、引用编号、工具决策和游戏回执处理。真实模型评估用 `evaluate.py`、`evaluate_cast.py`，已有记录见 `evaluation.json` 和 `cast_evaluation.json`。引用编号正确只能说明编号与返回资料对应，回答事实仍需对照原文。

模型不可用时返回错误并在游戏中显示连接状态。
