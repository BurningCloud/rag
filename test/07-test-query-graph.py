#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
项目: rag
文件名: 07-test-query-graph.py
作者: ply
创建日期: 2026/5/29 11:25
"""
from app.query_process.agent.main_graph import query_app
from app.query_process.agent.state import QueryGraphState
import sys

def test_pdf_flow():
    print("\n==测试PDF文件处理流程==")
    # 模拟初始化状态
    initial_state = QueryGraphState(
        session_id="session_id_001",
        original_query="asdfafdsfasd",
        is_stream=True,
        # 确保相关开关被正确初始化（根据您的 state 定义，有些可能是默认值）
        answer=""
    )

    # 运行图
    print("开始运行....")
    try:
        # 修正点：使用 .invoke() 方法
        result = query_app.invoke(initial_state)
        print("运行结束，最终的状态 keys:", result.keys())
    except Exception as e:
        print(f"运行报错：{e}")
        # 打印详细堆栈以便调试
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    print("----", sys.path)
    test_pdf_flow()