# RAG 知识库系统

## 项目概述

面向硬件设备手册（路由器、打印机、笔记本等）的 RAG 问答系统。核心特色：**商品名识别消歧** + **四路检索融合（向量/HyDE/知识图谱/网络搜索）** + **LangGraph 工作流编排**。

## 技术栈

- **Python 3.11+** / **FastAPI** / **Uvicorn**
- **LangGraph** 状态图工作流编排
- **LangChain** + **langchain-openai** LLM 调用层
- **Milvus 2.4** 向量数据库（稠密+稀疏混合检索）
- **MongoDB** 会话历史存储
- **MinIO** 对象存储（PDF/图片）
- **BAAI/bge-m3** Embedding 模型（本地部署，1024 维，稠密+稀疏双向量）
- **BAAI/bge-reranker-large** Reranker 模型（本地部署）
- **智谱 GLM-5.1** 默认 LLM（OpenAI 兼容接口，可切换 SiliconFlow/阿里百炼）
- **MinerU API** PDF 解析（云端）
- **Loguru** 日志框架

## 两大核心流程

### 知识导入（import_process）— 端口 8000

入口：`app/import_process/api/file_import_service.py`

```
文件上传 → node_entry → node_pdf_to_md → node_md_img → node_document_split → node_item_name_recognition → node_bge_embedding → node_import_milvus
```

- 入口节点后按文件类型条件路由：PDF 走 `node_pdf_to_md`，MD 直接走 `node_md_img`
- 工作流定义：`app/import_process/agent/main_graph.py`
- 状态定义：`app/import_process/agent/state.py`（`ImportGraphState`）

### 知识查询（query_process）— 端口 8001

入口：`app/query_process/api/query_service.py`

```
用户提问 → node_item_name_confirm → [四路并发检索] → node_join → node_rrf → node_rerank → node_answer_output
```

- 四路并发：`node_search_embedding` / `node_search_embedding_hyde` / `node_query_kg` / `node_web_search_mcp`
- 商品名确认节点可条件跳过检索：多选一反问 / 查无此人时直接生成 answer
- 虚拟节点 `node_multi_search`（分叉点）和 `node_join`（合并点）用 `lambda x: x` / `lambda x: {}` 实现
- 工作流定义：`app/query_process/agent/main_graph.py`
- 状态定义：`app/query_process/agent/state.py`（`QueryGraphState`）

## 目录结构

```
rag/
├── .env                          # 环境变量（LLM/Embedding/Milvus/MongoDB/MinIO/MinerU 配置）
├── pyproject.toml                # 项目依赖
├── prompts/                      # LLM Prompt 模板（.prompt 文件，用 {var} 占位符）
├── doc/                          # 原始 PDF 文档
├── scripts/docker-compose.yml    # Milvus 基础设施（etcd + MinIO + Milvus + Redis + Attu）
├── app/
│   ├── config/                   # 配置类（@dataclass，从 .env 读取）
│   │   ├── lm_config.py          # LLM 配置（模型名/API密钥/温度）
│   │   ├── embedding_config.py   # BGE-M3 配置（模型路径/设备/FP16）
│   │   ├── reranker_config.py    # Reranker 配置
│   │   ├── milvus_config.py      # Milvus 连接配置
│   │   ├── minio_config.py       # MinIO 配置
│   │   └── mineru_config.py      # MinerU API 配置
│   ├── core/
│   │   ├── logger.py             # Loguru 日志（控制台+文件双输出，自动定位业务调用位置）
│   │   └── load_prompt.py        # Prompt 加载器（读 .prompt 文件 + format 渲染占位符）
│   ├── llm/
│   │   ├── llm_util.py           # LLM 客户端工厂（全局缓存，ChatOpenAI 实例复用）
│   │   ├── glm_client.py         # 智谱 VL 多模态图片描述
│   │   ├── embedding_utils.py    # BGE-M3 向量生成（单例模型，稠密+稀疏双向量）
│   │   └── reranker_util.py      # BGE-Reranker 重排序（单例模型）
│   ├── clients/
│   │   ├── milvus_utils.py       # Milvus 客户端（单例，混合搜索，chunk_id 批量查询）
│   │   ├── minio_utils.py        # MinIO 客户端（文件上传/下载）
│   │   └── mongo_util.py         # MongoDB 客户端（会话历史 CRUD，单例）
│   ├── utils/
│   │   ├── path_util.py          # 路径工具（PROJECT_ROOT 常量）
│   │   ├── task_utils.py         # 任务状态管理（内存态，running/done/status 追踪 + SSE 推送）
│   │   ├── sse_utils.py          # SSE 流式推送（queue + event/delta/final 协议）
│   │   ├── format_utils.py       # 状态格式化
│   │   ├── rate_limit_utils.py   # 限流
│   │   ├── escape_milvus_string_utils.py  # Milvus 字符串转义
│   │   └── normalize_sparse_vector.py     # 稀疏向量归一化
│   ├── import_process/
│   │   ├── agent/
│   │   │   ├── state.py          # ImportGraphState 定义 + 默认值
│   │   │   ├── main_graph.py     # 导入工作流图（StateGraph 编译）
│   │   │   └── nodes/            # 各业务节点
│   │   ├── api/
│   │   │   └── file_import_service.py  # 导入 FastAPI 服务（/upload, /status）
│   │   └── page/import.html      # 导入前端页面
│   └── query_process/
│       ├── agent/
│       │   ├── state.py          # QueryGraphState 定义
│       │   ├── main_graph.py     # 查询工作流图（StateGraph 编译）
│       │   └── nodes/            # 各业务节点
│       ├── api/
│       │   └── query_service.py  # 查询 FastAPI 服务（/query, /stream, /history）
│       └── page/chat.html        # 查询前端页面
```

## 代码约定

### LangGraph 节点编写规范

- 节点函数签名：`def node_xxx(state: XxxGraphState) -> dict`，返回字典会自动合并回状态
- 每个节点开头用 `sys._getframe().f_code.co_name` 获取函数名，避免硬编码
- 节点入口调用 `add_running_task(task_id, func_name)`，出口调用 `add_done_task(task_id, func_name)`
- 查询流程的 task_id 是 `session_id`，导入流程的 task_id 是 UUID
- 节点内部可拆分为 `step_1_xxx / step_2_xxx` 辅助函数，核心节点函数保持简洁

### 单例模式

- Milvus / BGE-M3 / Reranker / MongoDB 均采用模块级全局变量 + `get_xxx()` 懒加载单例
- LLM 客户端用字典缓存 `_llm_client_cache`，key 为 `(model_name, json_mode)` 元组

### 配置管理

- 所有配置集中在 `.env` 文件，通过 `python-dotenv` 加载
- 配置类统一用 `@dataclass`，模块级实例化（如 `lm_config`、`embedding_config`）
- 配置类文件放在 `app/config/`，与业务逻辑解耦

### Prompt 管理

- Prompt 模板放在 `prompts/` 目录，文件名即模板名，后缀 `.prompt`
- 使用 Python `str.format()` 占位符语法：`{variable_name}`
- 通过 `app/core/load_prompt.py` 的 `load_prompt(name, **kwargs)` 加载并渲染

### 日志规范

- 全局使用 `from app.core.logger import logger`
- 日志自动穿透 loguru 内部帧，显示业务代码的真实调用位置
- 日志级别通过 `.env` 独立配置控制台/文件输出

### 任务状态

- 内存态任务追踪（`task_utils.py`），单进程内有效
- 任务状态：pending → processing → completed/failed
- 流式场景通过 `sse_utils.py` 的 queue 机制推送进度

### SSE 流式协议

事件类型：`ready`（连接建立） / `progress`（节点进度） / `delta`（LLM 增量） / `final`（最终答案+图片） / `error`（异常）

## 环境依赖

### 基础设施（Docker Compose 启动）

```bash
cd scripts && docker-compose up -d
```

不包含：Milvus（etcd + MinIO + standalone）+ Redis + Attu 管理界面，外部组件单独部署。

### 本地模型

- `BGE_M3_PATH` 指向本地 bge-m3 模型目录（默认 `models/BAAI/bge-m3`）
- `BGE_RERANKER_LARGE` 指向本地 bge-reranker-large 模型目录
- CPU 模式设置 `BGE_DEVICE=cpu`、`BGE_FP16=0`；GPU 模式设置 `BGE_DEVICE=cuda:0`、`BGE_FP16=1`

## 常用启动命令

```bash
# 启动导入服务（端口 8000）
python -m app.import_process.api.file_import_service

# 启动查询服务（端口 8001）
python -m app.query_process.api.query_service
```

## Milvus Collection 说明

| Collection | 环境变量 | 用途 |
|---|---|---|
| `kb_chunks` | `CHUNKS_COLLECTION` | 文档切片向量（稠密+稀疏双向量） |
| `kb_item_names` | `ITEM_NAME_COLLECTION` | 文档对应的商品/设备名称 |
| `kb_graph_entity_names` | `ENTITY_NAME_COLLECTION` | 知识图谱实体名称（预留） |

## 关键设计决策

1. **混合检索**：Milvus 稠密向量（COSINE）+ 稀疏向量（IP），WeightedRanker 加权融合，默认权重 (0.8, 0.2)
2. **多路检索融合**：Embedding / HyDE / KG / Web 四路结果通过 RRF（k=60）倒数排名融合，去重后 Top-K
3. **Embedding 文本拼接**：`商品：{item_name}，介绍：{content}`，核心词前置原则
4. **向量归一化**：bge-m3 开启 `normalize_embeddings=True`，适配 Milvus IP 内积检索
5. **Embedding 批量处理**：每批 5 条，避免 GPU OOM
6. **Prompt 长度控制**：`MAX_CONTEXT_CHARS = 12000`，参考文档 + 历史对话共享额度
