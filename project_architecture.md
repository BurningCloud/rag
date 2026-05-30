# RAG 知识库系统 — 项目架构分析

## 技术架构

### 语言与框架
- **Python 3.11+**，使用 **FastAPI** 提供 HTTP 服务，**Uvicorn** 作为 ASGI 服务器
- **LangGraph** 作为工作流编排引擎，用 `StateGraph` 将业务流程组织为有向图

### AI/LLM 层
- **LLM**: 智谱 GLM-5.1（默认）、GLM-4.6V（视觉模型），通过 OpenAI 兼容接口调用；可选 SiliconFlow/阿里百炼的 Qwen 系列模型
- **Embedding**: BAAI/bge-m3 本地部署（支持 GPU/CPU），生成 1024 维向量
- **Reranker**: BAAI/bge-reranker-large 本地部署，用于检索结果重排序
- **PDF 解析**: MinerU API（云端），将 PDF 转为 Markdown

### 存储层
- **Milvus 2.4**: 向量数据库，存储文档切片的稠密/稀疏向量（3 个 Collection：chunks、item_names、graph_entity_names）
- **MongoDB**: 存储会话历史和对话记录
- **MinIO**: 对象存储，保存上传的 PDF 文件和解析后的图片
- **Redis**: 作为 Milvus 的缓存组件

### 基础设施
- **Docker Compose** 编排 Milvus（含 etcd + MinIO + Redis + Attu 管理界面）
- 日志: **Loguru**，支持控制台 + 文件双输出，自动轮转

---

## 业务架构

项目是一个 **RAG（检索增强生成）知识库系统**，核心业务分为两大流程：

### 1. 知识导入流程（import_process）— 端口 8000

```
PDF/MD上传 → PDF转MD → MD图片处理 → 文档分块 → 商品名识别 → BGE向量化 → Milvus入库
```

| 节点 | 说明 |
|------|------|
| `node_entry` | 入口初始化，条件路由（PDF 或 MD 分支） |
| `node_pdf_to_md` | 调用 MinerU API 将 PDF 解析为 Markdown |
| `node_md_img` | 提取/下载 Markdown 中的图片，上传至 MinIO，修复图片路径 |
| `node_document_split` | 文档切分为文本块（chunk） |
| `node_item_name_recognition` | 用 LLM 识别文档对应的商品/设备名称 |
| `node_bge_embedding` | 用 bge-m3 生成稠密 + 稀疏向量 |
| `node_import_milvus` | 将向量数据写入 Milvus |

### 2. 知识查询流程（query_process）— 端口 8001

```
用户提问 → 商品名确认 → 多路并发检索(4路) → RRF融合排序 → Reranker重排 → LLM生成答案
```

| 节点 | 说明 |
|------|------|
| `node_item_name_confirm` | 用 LLM 确认用户查询的商品型号；不确定则反问/拒绝 |
| `node_search_embedding` | 普通向量检索 |
| `node_search_embedding_hyde` | HyDE（假设性文档嵌入）检索 |
| `node_query_kg` | 知识图谱检索 |
| `node_web_search_mcp` | 网络搜索（MCP 协议） |
| `node_rrf` | RRF（倒数排名融合）合并四路结果 |
| `node_rerank` | bge-reranker-large 精排 |
| `node_answer_output` | 组装 Prompt，LLM 生成最终答案，支持 SSE 流式输出 |

### 数据流向

```
doc/(PDF文件) → 导入服务 → Milvus/MongoDB/MinIO
                                       ↓
用户提问 → 查询服务 → 多路检索 → 融合重排 → LLM → 答案
```

---

## 项目目录结构

```
rag/
├── main.py                          # 项目入口（预留）
├── pyproject.toml                   # 项目依赖配置
├── .env                             # 环境变量配置
├── doc/                             # 原始 PDF 文档（设备手册）
├── prompts/                         # LLM Prompt 模板
├── scripts/
│   └── docker-compose.yml           # Milvus 等基础设施编排
├── app/
│   ├── config/                      # 配置模块
│   │   ├── lm_config.py             # LLM 配置
│   │   ├── embedding_config.py      # Embedding 模型配置
│   │   ├── milvus_config.py         # Milvus 配置
│   │   ├── minio_config.py          # MinIO 配置
│   │   ├── mineru_config.py         # MinerU API 配置
│   │   └── reranker_config.py       # Reranker 配置
│   ├── core/                        # 核心工具
│   │   ├── logger.py                # 日志工具
│   │   └── load_prompt.py           # Prompt 加载器
│   ├── llm/                         # LLM 相关工具
│   │   ├── glm_client.py            # 智谱 GLM 客户端
│   │   ├── llm_util.py              # LLM 通用工具
│   │   ├── embedding_utils.py       # Embedding 工具
│   │   └── reranker_util.py         # Reranker 工具
│   ├── clients/                     # 外部服务客户端
│   │   ├── milvus_utils.py          # Milvus 客户端
│   │   ├── minio_utils.py           # MinIO 客户端
│   │   └── mongo_util.py            # MongoDB 客户端
│   ├── utils/                       # 通用工具
│   │   ├── path_util.py             # 路径工具
│   │   ├── task_utils.py            # 任务状态管理
│   │   ├── sse_utils.py             # SSE 流式推送工具
│   │   ├── format_utils.py          # 格式化工具
│   │   ├── rate_limit_utils.py      # 限流工具
│   │   ├── escape_milvus_string_utils.py  # Milvus 字符串转义
│   │   └── normalize_sparse_vector.py     # 稀疏向量归一化
│   ├── import_process/              # 知识导入流程
│   │   ├── agent/
│   │   │   ├── state.py             # 导入状态定义
│   │   │   ├── main_graph.py        # 导入工作流图
│   │   │   └── nodes/               # 各业务节点
│   │   ├── api/
│   │   │   └── file_import_service.py  # 导入 FastAPI 服务
│   │   └── page/
│   │       └── import.html          # 导入前端页面
│   └── query_process/               # 知识查询流程
│       ├── agent/
│       │   ├── state.py             # 查询状态定义
│       │   ├── main_graph.py        # 查询工作流图
│       │   └── nodes/               # 各业务节点
│       ├── api/
│       │   └── query_service.py     # 查询 FastAPI 服务
│       └── page/
│           └── chat.html            # 查询前端页面
```

---

## 核心特色

1. **商品名识别消歧**: 查询时先通过 LLM 确认具体商品型号，避免模糊检索
2. **四路检索融合**: 向量检索 + HyDE检索 + 知识图谱 + 网络搜索，RRF 排序融合
3. **LangGraph 工作流编排**: 导入和查询两个核心流程均用 StateGraph 管理，节点可组合、可条件路由
4. **多模型支持**: LLM 层支持智谱/SiliconFlow/阿里百炼切换，Embedding/Reranker 本地部署
