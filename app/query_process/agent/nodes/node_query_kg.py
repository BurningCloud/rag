#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
项目: rag
文件名: node_query_kg.py
作者: ply
创建日期: 2026/5/29 11:16
"""
import time
import sys
from app.utils.task_utils import add_running_task, add_done_task

def node_query_kg(state):
    """
    节点功能：在 Neo4j 知识图谱中查询实体关系。
    """
    print("=== node_query_kg 图谱查询处理 ===")
    add_running_task(state["session_id"], sys._getframe().f_code.co_name, state.get("is_stream"))

    time.sleep(1)
    # ...
    add_done_task(state['session_id'], sys._getframe().f_code.co_name, state.get("is_stream"))