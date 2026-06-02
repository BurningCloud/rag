#FROM python:3.11-slim
FROM rag:1.0

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 阿里云 apt 镜像源
RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources

# 系统依赖（gcc 编译 numpy/pymilvus 等需要）
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc g++ libffi-dev && \
    rm -rf /var/lib/apt/lists/*

# 1. 设置工作目录（必须）
WORKDIR /app

# 2. 配置 pip 使用阿里云镜像（或直接写入配置文件）
RUN mkdir -p /root/.pip && \
    echo "[global]\nindex-url = https://mirrors.aliyun.com/pypi/simple/\ntrusted-host = mirrors.aliyun.com" > /root/.pip/pip.conf

# 3. 先单独安装 torch 三件套（从 PyTorch 官方 CPU 源下载，避免阿里云镜像超时）
RUN pip install --no-cache-dir --timeout 300 \
    torch==2.6.0+cpu torchvision==0.21.0+cpu torchaudio==2.6.0+cpu \
    --extra-index-url https://download.pytorch.org/whl/cpu

# 4. 再安装其余依赖（阿里云镜像 + 超时时间 300 秒）
#    用 constraint 锁住 torch 版本，防止 pip 把 CPU 版升级为 CUDA 版
COPY requirements.txt .
RUN echo "torch==2.6.0+cpu" > /tmp/constraints.txt && \
    echo "torchvision==0.21.0+cpu" >> /tmp/constraints.txt && \
    echo "torchaudio==2.6.0+cpu" >> /tmp/constraints.txt && \
    pip install --no-cache-dir --timeout 300 -c /tmp/constraints.txt -r requirements.txt

# 4. 复制项目代码（你原文件漏了这一步）
COPY . .