#!/bin/bash
# RAG 知识库系统一键部署脚本
# 步骤：环境校验 → 构建镜像 → 启动服务 → 清理冗余

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
IMAGE_NAME="rag-app"
IMAGE_TAG="1.0"
BASE_IMAGE="rag-base:latest"

# 需要存在的宿主机目录（与 docker-compose.yml volumes 对应）
REQUIRED_DIRS=(
    "/rag/models"
    "/rag/output"
    "/rag/logs"
)

cd "$PROJECT_DIR"

# ========================================================
# 第一步：环境校验
# ========================================================
info "===== 第一步：环境校验 ====="

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

# 必要文件
for f in .env Dockerfile docker-compose.yml; do
    if [ ! -f "$PROJECT_DIR/$f" ]; then
        error "$f 不存在，请先准备"
    fi
done
info "项目文件校验通过"

# 基础镜像
if ! docker image inspect "$BASE_IMAGE" &> /dev/null; then
    error "基础镜像 $BASE_IMAGE 不存在，请先构建基础镜像"
fi
info "基础镜像 $BASE_IMAGE 已存在"

# 宿主机挂载目录
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        warn "目录不存在，自动创建: $dir"
        sudo mkdir -p "$dir"
    fi
done

# 模型文件检查
if [ -z "$(ls -A /rag/models 2>/dev/null)" ]; then
    warn "/rag/models 目录为空，请确保已放入 bge-m3 和 bge-reranker-large 模型"
fi
info "环境校验完成"

# ========================================================
# 第二步：构建 rag-app:1.0 镜像
# ========================================================
info "===== 第二步：构建 ${IMAGE_NAME}:${IMAGE_TAG} 镜像 ====="

# 如果同名镜像已存在，先打旧标签保留，方便回滚
OLD_IMAGE_ID=$(docker images --format '{{.ID}}' "${IMAGE_NAME}:${IMAGE_TAG}" 2>/dev/null || true)
if [ -n "$OLD_IMAGE_ID" ]; then
    docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${IMAGE_NAME}:previous" 2>/dev/null || true
    info "已将旧镜像标记为 ${IMAGE_NAME}:previous（可用于回滚）"
fi

docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .
info "镜像 ${IMAGE_NAME}:${IMAGE_TAG} 构建完成"

# ========================================================
# 第三步：启动服务
# ========================================================
info "===== 第三步：启动服务 ====="

$COMPOSE_CMD up -d
info "服务启动完成"

# 健康检查
info "等待服务就绪..."
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
    echo "  查看日志:  $COMPOSE_CMD logs -f rag-app"
else
    warn "服务尚未就绪，请检查日志:"
    echo "  $COMPOSE_CMD logs -f rag-app"
    echo "  回滚命令:  docker tag ${IMAGE_NAME}:previous ${IMAGE_NAME}:${IMAGE_TAG} && $COMPOSE_CMD up -d"
fi

# ========================================================
# 第四步：清理冗余镜像和容器
# ========================================================
info "===== 第四步：清理冗余资源 ====="

# 删除已停止的容器
STOPPED=$(docker ps -a --filter "status=exited" -q 2>/dev/null || true)
if [ -n "$STOPPED" ]; then
    docker rm $STOPPED 2>/dev/null || true
    info "已清理停止的容器"
else
    info "无停止的容器需要清理"
fi

# 删除悬空镜像（无标签的 <none> 镜像）
DANGLING=$(docker images --filter "dangling=true" -q 2>/dev/null || true)
if [ -n "$DANGLING" ]; then
    docker rmi $DANGLING 2>/dev/null || true
    info "已清理悬空镜像"
else
    info "无悬空镜像需要清理"
fi

# 清理旧的 previous 标签（保留最近一次回滚用）
PREV_COUNT=$(docker images --format '{{.Tag}}' "${IMAGE_NAME}" 2>/dev/null | grep -c "previous" || true)
if [ "$PREV_COUNT" -gt 1 ]; then
    # 只保留最新的 previous，删除更早的
    OLD_PREV_IDS=$(docker images --format '{{.ID}} {{.CreatedAt}}' "${IMAGE_NAME}:previous" 2>/dev/null | tail -n +2 | awk '{print $1}' || true)
    if [ -n "$OLD_PREV_IDS" ]; then
        echo "$OLD_PREV_IDS" | xargs docker rmi 2>/dev/null || true
        info "已清理多余的 previous 镜像"
    fi
fi

info "清理完成"
