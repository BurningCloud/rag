#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
项目: rag
文件名: 06-download_reranker.py
作者: ply
创建日期: 2026/5/29 16:59
"""
#modelscope：字节跳动旗下的魔搭 AI 社区（国内主流的开源模型仓库，类似 Hugging Face，适配国内网络环境）
from modelscope.hub.snapshot_download import snapshot_download

local_dir = r"D:\pythonProject\rag\models"

snapshot_download(
  #北京人工智能研究院（BAAI） 发布的大尺寸 BGE 重排序模型，专为文本相关性排序设计，精度较高
  model_id="BAAI/bge-reranker-large",
  cache_dir=local_dir,
)

print("下载完成，模型目录：", local_dir)