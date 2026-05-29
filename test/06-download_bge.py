#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
项目: rag
文件名: 06-download_bge.py
作者: ply
创建日期: 2026/5/28 19:31
"""
from modelscope.hub.snapshot_download import snapshot_download

# 下载模型到当前目录下的 models/bge-m3 文件夹
model_dir = snapshot_download('BAAI/bge-m3', cache_dir='../models')
print(f"模型已下载到: {model_dir}")