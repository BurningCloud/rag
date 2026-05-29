# !/usr/bin/env python
# -*- coding: utf-8 -*-

"""
项目: rag
文件名: node_web_search_mcp.py
作者: ply
创建日期: 2026/5/29 11:16
"""
import sys
import json
import asyncio
from app.utils.task_utils import add_done_task, add_running_task
from app.config.lm_config import lm_config

from app.core.logger import logger
from zai import ZhipuAiClient



def node_web_search_mcp(state):
    """
    LangGraph同步节点函数：处理MCP搜索逻辑，作为整个搜索流程的入口。

    该节点会调用 mcp_call 异步函数获取搜索结果，并将其解析为结构化数据存储到 state 中。

    :param state: LangGraph的全局状态对象，包含 session_id, rewritten_query 等信息
    :return: 字典，包含结构化的搜索结果 web_search_docs，供后续节点使用
    """
    logger.info("---node_web_search_mcp 开始处理---")

    # 1. 标记任务开始
    add_running_task(state["session_id"], sys._getframe().f_code.co_name, state.get("is_stream"))

    # 2. 获取查询词
    query = state.get("rewritten_query", "")
    if not query:
        # 尝试回退到原始查询
        query = state.get("original_query", "")

    docs = []

    # 3. 执行搜索
    if query:
        try:
            logger.info(f"启动异步 MCP 调用，Query: {query}")

            result = asyncio.run(mcp_call_plus(query))

            if result and result.search_result and len(result.search_result)>0:

                logger.info(f"MCP 返回原始页面数量: {len(result.search_result)}")

                # 遍历结果，统一封装为结构化格式
                for item in result.search_result:
                    url = (item.get("link") or "").strip()
                    title = (item.get("title") or "").strip()
                    docs.append({"title": title, "url": url,"snippet": item.get("content")})

            else:
                logger.warning("MCP 返回结果为空或无效")

        except Exception as e:
            logger.error(f"MCP 搜索节点执行异常: {e}", exc_info=True)
    else:
        logger.warning("查询词为空，跳过 MCP 搜索")

    # 5. 标记任务结束
    add_done_task(state["session_id"], sys._getframe().f_code.co_name, state.get("is_stream"))

    logger.info("---node_web_search_mcp 处理结束---")

    # 若有有效搜索结果，返回结果供后续节点使用；无则返回空字典
    if docs:
        return {"web_search_docs": docs}
    return {}




def mcp_call_plus(query: str):
    client = ZhipuAiClient(api_key=lm_config.api_key)
    response = client.web_search.web_search(
    search_engine="search_pro",
    search_query=query,
    # count=15,  # 返回结果的条数，范围1-50，默认10
    # search_domain_filter="www.sohu.com",  # 只访问指定域名的内容
    # search_recency_filter="noLimit",  # 搜索指定日期范围内的内容
    # content_size="high"  # 控制网页摘要的字数，默认medium
    )
    logger.info(f"mcp_call_plus resp ----> f{response}")
    return response




if __name__ == '__main__':
    # 测试代码：单独运行该文件时，验证MCP搜索功能是否正常
    print("\n" + "=" * 50)
    print(">>> 启动 node_web_search_mcp 本地测试")
    print("=" * 50)

    test_state = {
        "session_id": "test_mcp_session",
        "rewritten_query": "HAK 180 在出厂默认状态下，若想在纸张上只把烫金膜转印到顶部 50 mm–170 mm 的局部区域，应在操作面板上如何设置",
        "is_stream": False
    }

    try:
        # 调用MCP搜索节点函数，执行测试
        result_state = node_web_search_mcp(test_state)

        print("\n" + "=" * 50)
        print(">>> 测试结果摘要:")
        search_results = result_state.get('web_search_docs', [])
        print(f"搜索结果数量: {len(search_results)}")
        if search_results:
            print("首条结果预览:")
            print(json.dumps(search_results[0], indent=2, ensure_ascii=False))
        else:
            print("未获取到搜索结果")
        print("=" * 50)

    except Exception as e:
        logger.exception(f"测试运行期间发生未捕获异常: {e}")




















