# 校园知识 NPC 与行动 Agent

这套服务为科大云宇宙的 15 位校园角色提供资料问答与向导行动。客户端为 Godot，后台为 FastAPI；默认统一调用科大大模型公共服务平台，以角色提示词和独立知识范围区分人物。普通 NPC 问答和 K 键行动向导使用相同的服务端配置。

[项目展示](../../README.md) · [架构与演示](../../docs/AI_NPC_DEMO.md)

## 请求链路

```text
Godot HTTPRequest
  → FastAPI /chat
  → 按 npc_id 过滤资料
  → Qwen3-Embedding-0.6B 向量检索 + BM25
  → RRF 融合，取 4 段证据
  → 角色提示词 + 最近对话 + 带编号证据
  → 科大 API /chat/completions（可配置模型）
  → 中文回答、来源与原文
```

随仓库提供的知识快照包含 17 份来源、191 个片段。PDF 或网页正文按 900 字符切分，重叠 140 字符；保留来源地址、版本、抓取时间与 PDF 物理页码。原始整份资料不入库，可通过 `ingest.py` 按 `sources.json` 获取。资料与索引分别为 `knowledge/chunks.json`、`knowledge/vectors.npz`。

当前知识量较小，使用 NumPy 直接计算向量相似度。检索前限定角色范围，最近两条玩家提问参与追问检索；客户端为各角色保存当前会话最近五轮对话。角色风格通过提示词设定，没有为每个 NPC 分别训练模型。

## 配置科大 API

从本目录复制 `.env.example` 为 `.env`，填写：

```dotenv
AI_PROVIDER=ustc
USTC_BASE_URL=https://api.llm.ustc.edu.cn/v1
USTC_MODEL=deepseek-v4-flash
USTC_API_KEY=你的科大平台APIKey
EMBEDDING_DEVICE=cpu
```

后台自动读取本目录 `.env`，系统环境变量优先；修改后重启后台。`.env` 已加入 Git 忽略规则。主机 Key 不放进游戏导出包或 GitHub。游戏仍连接 `http://127.0.0.1:8787`，无需逐个修改 NPC。

玩家可在游戏的 **AI 设置**（或人物名单中的 **API Key 设置**）填写个人 Key，点击“应用并测试”。个人 Key 只覆盖该玩家的请求，不修改主机 `.env`，也不进入对话、向导状态或共享健康缓存；清空后恢复主机配置。默认只保留在本次运行的内存中。主动勾选“在此设备记住 Key”后，电脑端写入用户数据目录的 `campus_ai_key.cfg`，网页端写入当前网站的浏览器本地存储；两者均为未加密本地存储，共享设备不应勾选。取消勾选或“清除个人 Key”会删除保存记录。

个人 Key 通过 `X-Campus-API-Key` 请求头传给校园后台，网页版还会经过本站服务器和已授权中继；服务端不保存此请求头。本机游戏只向 localhost 后台发送个人 Key，网页版只向本站接口发送。校园网、后台和中继仍须可用；填写 Key 不能替代这些服务。所有玩家继续共用主机的模型调用限流预算。

平台入口是 <https://llm.ustc.edu.cn/>，接口地址与网页登录地址不同。配置以[官方 API 文档](https://llm.ustc.edu.cn/guide/api-usage/)为准；默认模型取自文档示例，实际须填写当前项目有权调用的**完整模型 ID**（包括后缀）。校园网络接通、Key 填好后，运行下方在线检查核实权限和一次真实生成。

## 启动服务

建议使用 Python 3.12。以下命令从本目录执行：

```powershell
python -m venv .venv
.venv/Scripts/python.exe -m pip install -r requirements.txt
./run_ai.ps1 -Check   # 只检查本地配置，不访问科大接口、不打印 Key
./run_ai.ps1 -Online  # 接通校园网并填 Key 后，检查权限和一次真实生成（消耗少量额度）
./run_ai.ps1          # 启动 127.0.0.1:8787 后台
```

也可从仓库根目录双击 `OPEN_AI_SERVICE.cmd` 启动已安装的后台。`run_ai.ps1 -PythonExe '完整路径'` 可指定 Python。

Linux/macOS 使用 `.venv/bin/python`，启动命令为 `python -m uvicorn app:app --host 127.0.0.1 --port 8787`；本地/在线检查分别为 `python check_api.py`、`python check_api.py --online`。

**问答生成使用科大 API，向量检索仍在本地 CPU 上运行**，保留 Qwen3-Embedding-0.6B 与已有索引，不在本机加载聊天大模型。向量模型首次运行需要下载；已有本地模型时，在 `.env` 设置 `EMBEDDING_MODEL_PATH` 为模型目录。`/health` 返回模型状态与不含密钥的错误提示；未填 Key 时返回 `configuration_required`，不会向平台发送请求。健康检查只核对模型列表，真实生成能力以在线检查和 NPC 实测为准。

## 可选：原有本地 Qwen 生成服务

需要切回原有本地服务时，将 `.env` 中 `AI_PROVIDER` 改为 `qwen`，配置 `QWEN_BASE_URL`、`QWEN_MODEL` 和可选 `QWEN_API_KEY`。例如：

```dotenv
AI_PROVIDER=qwen
QWEN_BASE_URL=http://127.0.0.1:8000/v1
QWEN_MODEL=Qwen/Qwen3-8B
```

也可在具有合适 GPU 的主机使用本仓库的 Transformers 演示服务：

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
.venv/Scripts/python.exe -m pytest test_rag.py test_campus_agent.py test_model_api.py -q
```

`ingest.py` 会更新知识片段，随后必须重建索引。网页内容随来源站点变化，新抓取结果可能与随库快照不同。

`RAG_LEXICAL_ONLY=1` 用于明确的 BM25 接口测试；`/health` 会标识该模式。单元测试模拟模型响应，检查全部 15 位 NPC 和向导的科大请求地址、Bearer 鉴权、角色隔离、引用编号、工具决策和游戏回执处理。也检查缺失 Key 不出网、鉴权/额度错误和异常回复。离线通过不代表校园网或真实 Key 已连通。

真实模型评估用 `evaluate.py`、`evaluate_cast.py`；后者会向全部 15 位 NPC 提问并消耗平台额度。已有 `evaluation.json` 和 `cast_evaluation.json` 是此前本地模型的记录，不能作为此次科大接入成功的证明。引用编号正确只能说明编号与返回资料对应，回答事实仍需对照原文。

模型不可用时返回错误并在游戏中显示连接状态。

## 网页 AI 按需运行

普通网页校园漫游无需启动本机 AI。需要 NPC 在线回答时，在已完成配置并连接校园网络的主机上，进入 `campus/ai` 目录，用 PowerShell 运行 `.\run_web_ai.ps1 -Watch`。监控会恢复本脚本记录的退出进程，并在隧道地址变化后重新注册网站。再次启动不会重复创建监控。

用完在同一目录运行 `.\run_web_ai.ps1 -Stop`，停止监控、独立隧道及本脚本拥有的后端，释放约 2.7 GB 内存。仅关闭游戏网页不会停止主机服务。

主机离线、服务关闭或校园网络中断时，网站会显示 AI 离线；对话问题会保留，可在服务恢复后手动重连。启动监控不能替代校园网络，也不保证免费临时隧道持续可用。科大 API Key 仅保留在本机 `.env`。

## 游戏内真实接口验证

先启动后台，再从仓库根目录运行（使用真实 API 额度）：

```powershell
& $env:GODOT_EXE --headless --path campus/godot --script res://tests/ustc_api_smoke.gd -- --ustc-api-smoke
```

此检查使用实际游戏的 HTTPRequest，逐一提问 15 位 NPC、追问图书馆员，再让向导查资料、前往并打开对话；动作完成由游戏实际坐标和窗口状态确认。结果写入 `campus/renders/ustc_api_game_validation.json`。加 `--ustc-agent-only` 可单独复测向导，结果写入 `ustc_api_agent_validation.json`。全角色检查在请求间留出间隔以减少触发平台限流；遇到限流可稍候再试。
