FROM rag-base:latest

# 1. 设置工作目录（必须）
WORKDIR /rag


# 4. 复制项目代码（你原文件漏了这一步）
COPY prompts/ prompts/
COPY app/ app/