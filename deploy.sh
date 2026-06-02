#!/bin/bash
# RAG 知识库系统一键部署脚本
# 功能：环境校验 → 清理旧容器/镜像 → 构建并启动服务

set -e

# ========== 颜色定义 ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ========== 项目配置 ==========
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="rag-server"
IMAGE_TAG="1.0"

# 需要存在的宿主机目录（与 docker-compose.yml volumes 对应）
REQUIRED_DIRS=(
    "/rag/models"
    "/rag/output"
    "/rag/logs"
)

# ========== 1. 环境校验 ==========
info "===== 环境校验 ====="

# Docker
if ! command -v docker &> /dev/null; then
    error "Docker 未安装，请先安装 Docker"
fi
if ! docker info &> /dev/null; then
    error "Docker 未启动，请执行 systemctl start docker"
fi
info "Docker 已就绪"

# Docker Compose
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    error "Docker Compose 未安装"
fi
info "Docker Compose 已就绪 ($COMPOSE_CMD)"

# .env 文件
if [ ! -f "$PROJECT_DIR/.env" ]; then
    error ".env 文件不存在，请先配置 $PROJECT_DIR/.env"
fi
info ".env 文件已存在"

# nginx.conf 文件
if [ ! -f "$PROJECT_DIR/nginx.conf" ]; then
    error "nginx.conf 不存在，请先创建 $PROJECT_DIR/nginx.conf"
fi
info "nginx.conf 已存在"

# Dockerfile
if [ ! -f "$PROJECT_DIR/Dockerfile" ]; then
    error "Dockerfile 不存在"
fi
info "Dockerfile 已存在"

# ========== 2. 宿主机目录校验 ==========
info "===== 宿主机目录校验 ====="

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        warn "目录不存在，自动创建: $dir"
        sudo mkdir -p "$dir"
    fi
done

# 模型文件检查
if [ -z "$(ls -A /rag/models 2>/dev/null)" ]; then
    warn "/rag/models 目录为空，请确保已将 bge-m3 和 bge-reranker-large 模型放入该目录"
fi
info "宿主机目录校验完成"

# ========== 3. 清理旧容器和镜像 ==========
info "===== 清理旧容器和镜像 ====="

cd "$PROJECT_DIR"

# 停止并移除旧容器
for container in rag-app rag-nginx; do
    if docker ps -a --filter "name=$container" --format '{{.Names}}' | grep -q "$container"; then
        info "停止并移除旧容器: $container"
        docker stop "$container" 2>/dev/null || true
        docker rm "$container" 2>/dev/null || true
    fi
done

## 移除旧镜像
#if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "${IMAGE_NAME}:${IMAGE_TAG}"; then
#    info "移除旧镜像: ${IMAGE_NAME}:${IMAGE_TAG}"
#    docker rmi "${IMAGE_NAME}:${IMAGE_TAG}" 2>/dev/null || true
#fi

# 清理悬空镜像和构建缓存
info "清理悬空镜像和构建缓存"
docker image prune -f 2>/dev/null || true

info "清理完成"

# ========== 4. 构建并启动 ==========
info "===== 构建并启动服务 ====="

$COMPOSE_CMD build --no-cache rag-app
info "镜像构建完成"

$COMPOSE_CMD up -d
info "服务启动完成"

# ========== 5. 健康检查 ==========
info "===== 健康检查 ====="

MAX_RETRY=30
RETRY=0
OK=false

while [ $RETRY -lt $MAX_RETRY ]; do
    if curl -sf http://localhost:80/health > /dev/null 2>&1; then
        OK=true
        break
    fi
    RETRY=$((RETRY + 1))
    echo -n "."
    sleep 2
done
echo ""

if [ "$OK" = true ]; then
    info "服务启动成功！"
    echo ""
    echo "  Swagger 文档:  http://localhost:8080/docs"
    echo "  文件导入页面:  http://localhost:80/import.html"
    echo "  知识查询页面:  http://localhost:80/chat.html"
    echo "  健康检查:      http://localhost:80/health"
    echo ""
else
    warn "服务尚未就绪，请检查日志:"
    echo "  $COMPOSE_CMD logs -f rag-app"
fi
