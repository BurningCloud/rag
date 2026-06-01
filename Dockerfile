# =============================================
# RAG 知识库系统 - CPU 部署版
# 阿里云镜像加速 pip + PyTorch CPU
# =============================================

FROM python:3.11-slim AS base

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 阿里云 apt 镜像源
RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources

# 系统依赖（gcc 编译 numpy/pymilvus 等需要）
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc g++ libffi-dev && \
    rm -rf /var/lib/apt/lists/*


# ============ 构建阶段 ============
FROM base AS builder

# 阿里云 pip 镜像
RUN pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/ && \
    pip config set global.trusted-host mirrors.aliyun.com

WORKDIR /build

# 先拷贝依赖声明，利用 Docker 缓存层
COPY pyproject.toml ./



# ============ 运行阶段 ============
FROM base AS runtime

# 从构建阶段拷贝已安装的包
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# 创建非 root 用户
RUN groupadd -r appuser && useradd -r -g appuser -d /app -s /sbin/nologin appuser

WORKDIR /app

# 拷贝项目代码（.env 由 docker-compose environment 注入，不打入镜像）
COPY app/ app/
COPY prompts/ prompts/

# 创建日志和输出目录
RUN mkdir -p /app/output /app/logs && chown -R appuser:appuser /app

# 切换非 root 用户
USER appuser

# 启动命令由 docker-compose.yml 的 command 指定
EXPOSE 8001 8002
