#!/bin/bash
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

DEPLOY_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$DEPLOY_DIR")"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  RAG 知识库系统 - 一键部署${NC}"
echo -e "${GREEN}========================================${NC}"

# ======================== 检查 Docker ========================
echo -e "\n${YELLOW}[1/6] 检查运行环境...${NC}"
if ! command -v docker &>/dev/null; then
    echo -e "${RED}错误：未检测到 Docker，请先安装 Docker${NC}"
    exit 1
fi

# 兼容 docker compose v1 和 v2
if docker compose version &>/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &>/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    echo -e "${RED}错误：未检测到 Docker Compose，请先安装${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker 和 Docker Compose 已就绪${NC}"

# ======================== 检查环境配置 ========================
echo -e "\n${YELLOW}[2/6] 检查环境配置...${NC}"
if [ ! -f "$DEPLOY_DIR/.env.docker" ]; then
    echo -e "${RED}错误：未找到 .env.docker 配置文件${NC}"
    echo -e "${YELLOW}请复制 .env.docker 模板并填写实际配置后重试${NC}"
    exit 1
fi

# 检查是否还有未修改的占位符
if grep -q "YOUR_API_KEY_HERE" "$DEPLOY_DIR/.env.docker"; then
    echo -e "${YELLOW}警告：.env.docker 中 OPENAI_API_KEY 仍为占位符，请修改后重试${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 环境配置文件已就绪${NC}"

# ======================== 检查模型文件 ========================
echo -e "\n${YELLOW}[3/6] 检查本地模型文件...${NC}"
MODEL_MISSING=0

if [ ! -d "$PROJECT_ROOT/models/BAAI/bge-m3" ]; then
    echo -e "${RED}✗ BGE-M3 模型目录不存在: $PROJECT_ROOT/models/BAAI/bge-m3${NC}"
    MODEL_MISSING=1
else
    echo -e "${GREEN}✓ BGE-M3 模型已就绪${NC}"
fi

if [ ! -d "$PROJECT_ROOT/models/BAAI/bge-reranker-large" ]; then
    echo -e "${RED}✗ BGE-Reranker 模型目录不存在: $PROJECT_ROOT/models/BAAI/bge-reranker-large${NC}"
    MODEL_MISSING=1
else
    echo -e "${GREEN}✓ BGE-Reranker 模型已就绪${NC}"
fi

if [ $MODEL_MISSING -eq 1 ]; then
    echo -e "${YELLOW}请先下载缺失的模型文件到 models/ 目录${NC}"
    exit 1
fi

# ======================== 构建镜像 ========================
echo -e "\n${YELLOW}[4/6] 构建 Docker 镜像（首次构建较慢，请耐心等待）...${NC}"
cd "$DEPLOY_DIR"
$COMPOSE_CMD build

# ======================== 启动服务 ========================
echo -e "\n${YELLOW}[5/6] 启动服务...${NC}"
$COMPOSE_CMD up -d

# ======================== 等待就绪 ========================
echo -e "\n${YELLOW}[6/6] 等待服务就绪...${NC}"
sleep 5

# 检查服务状态
echo ""
$COMPOSE_CMD ps

# ======================== 部署完成 ========================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  部署完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "访问地址："
echo -e "  智能对话页面：  ${GREEN}http://localhost/chat.html${NC}"
echo -e "  文件导入页面：  ${GREEN}http://localhost/import.html${NC}"
echo -e "  Milvus 管理台： ${GREEN}http://localhost:8080${NC}"
echo -e "  导入服务文档：  ${GREEN}http://localhost:8000/docs${NC}"
echo -e "  查询服务文档：  ${GREEN}http://localhost:8001/docs${NC}"
echo ""
echo -e "常用命令："
echo -e "  查看日志：  cd deploy && $COMPOSE_CMD logs -f"
echo -e "  停止服务：  cd deploy && $COMPOSE_CMD down"
echo -e "  重启服务：  cd deploy && $COMPOSE_CMD restart"
echo -e "  查看状态：  cd deploy && $COMPOSE_CMD ps"
