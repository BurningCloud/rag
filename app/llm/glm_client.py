#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
项目: rag
文件名: glm_client.py
作者: ply
创建日期: 2026/5/27 19:47
"""
from zai import ZhipuAiClient
from app.config.lm_config import lm_config
from app.utils.path_util import PROJECT_ROOT
import base64


def getGLMClient(img_base: str):

    client = ZhipuAiClient(api_key=lm_config.api_key)  # 填写您自己的APIKey

    response = client.chat.completions.create(
        model=lm_config.llm_model,
        temperature=lm_config.llm_temperature,
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": img_base
                        }
                    },

                    {
                        "type": "text",
                        "text": "请仔细识别并用中文描述这张图片的全部内容，回复控制在300字以内。\n"
                                    "要求：\n"
                                    "1. 图片中出现的所有数学公式、方程式、数学符号，必须用LaTeX格式完整输出，"
                                    "例如：$E=mc^2$、$\\sum_{i=1}^{n} x_i$、$\\frac{a}{b}$\n"
                                    "2. 英文字母、希腊字母（如α、β、θ）、上下标都要准确识别\n"
                                    "3. 如果是表格，逐行描述表头和关键数据\n"
                                    "4. 如果是流程图或架构图，描述各节点和逻辑关系\n"
                                    "5. 如果是纯文字截图，原文转录全部文字内容"
                    }
                ]
            }
        ]
    )
    return response.choices[0].message


if __name__ == "__main__":
    img_path = PROJECT_ROOT / "output/hak180产品安全手册/images/048c005b198be5c9fff80ad6a6ba02496f38fa109ec20dbaabde3110f3eb1574.jpg"
    with open(img_path, "rb") as img_file:
        img_base = base64.b64encode(img_file.read()).decode("utf-8")

    message = getGLMClient(img_base)
    print(message)


