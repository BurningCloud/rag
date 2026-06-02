#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
项目: rag
文件名: main.py
作者: ply
创建日期: 2026/6/2
描述: 统一服务入口，合并文件导入和知识查询两个子服务
"""
import os
import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.import_process.api.file_import_service import router as import_router
from app.query_process.api.query_service import router as query_router

# 创建统一的FastAPI应用
app = FastAPI(
    title="RAG Knowledge Base System",
    description="知识库文件导入 + 查询服务（PDF/MD → 解析 → 切分 → 向量化 → Milvus入库 → 四路检索融合问答）"
)

# 跨域中间件
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 挂载两个子路由
app.include_router(import_router)
app.include_router(query_router)


if __name__ == "__main__":
    uvicorn.run(
        app=app,
        host=os.getenv("HOST", "0.0.0.0"),
        port=int(os.getenv("PORT", "8000"))
    )
