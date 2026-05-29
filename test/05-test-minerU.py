#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
项目: rag
文件名: 05-test-minerU.py
作者: ply
创建日期: 2026/5/27 17:48
"""


import requests

token = "eyJ0eXBlIjoiSldUIiwiYWxnIjoiSFM1MTIifQ.eyJqdGkiOiI0NzIwMDYyNyIsInJvbCI6IlJPTEVfUkVHSVNURVIiLCJpc3MiOiJPcGVuWExhYiIsImlhdCI6MTc3OTg3MzY1OSwiY2xpZW50SWQiOiJsa3pkeDU3bnZ5MjJqa3BxOXgydyIsInBob25lIjoiMTM4MjY1NzczODYiLCJvcGVuSWQiOm51bGwsInV1aWQiOiIzYzc0YzQ2ZS01OTRkLTQyNzctYWZiNS1iNDVlZTgxNjEzZTgiLCJlbWFpbCI6IiIsImV4cCI6MTc4NzY0OTY1OX0.WYf8C5lphwTLXwcn9GDeXjzV_1pt26cKCa_Z4L37YHrCOrK01qe5pkYuSmOW4T3F9XrLnnTYaxAGFZNgteP8ig"
def upload(file_path:list):
    url = "https://mineru.net/api/v4/file-urls/batch"
    header = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}"
    }
    data = {
        "files": [
            {"name": "万用表RS-12的使用.pdf", "data_id": "abcd"}
        ],
        "model_version": "vlm"
    }
    batch_id = ""
    try:
        response = requests.post(url, headers=header, json=data)
        if response.status_code == 200:
            result = response.json()
            print('response success. result:{}'.format(result))
            if result["code"] == 0:
                batch_id = result["data"]["batch_id"]
                urls = result["data"]["file_urls"]
                print('batch_id:{},urls:{}'.format(batch_id, urls))
                for i in range(0, len(urls)):
                    with open(file_path[i], 'rb') as f:
                        res_upload = requests.put(urls[i], data=f)
                        if res_upload.status_code == 200:
                            print(f"{urls[i]} upload success")
                        else:
                            print(f"{urls[i]} upload failed")
            else:
                print('apply upload url failed,reason:{}'.format(result["msg"]))
        else:
            print('response not success. status:{} ,result:{}'.format(response.status_code, response))
    except Exception as err:
        print(err)
    return batch_id

def getResp(batch_id:str):
    url = f"https://mineru.net/api/v4/extract-results/batch/{batch_id}"
    header = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}"
    }

    res = requests.get(url, headers=header)
    print(res.status_code)
    print(res.json())
    return res.json()["data"]




if __name__ == '__main__':
    # batch_id = upload(["../doc/万用表RS-12的使用.pdf"])

    data = getResp("8ee9b71a-cc33-44bb-b9dc-ded8241a4f34")
    print(data)

    # {'batch_id': '8ee9b71a-cc33-44bb-b9dc-ded8241a4f34', 'extract_result': [{'data_id': 'abcd', 'file_name': '万用表RS-12的使用.pdf', 'state': 'done', 'err_msg': '', 'full_zip_url': 'https://cdn-mineru.openxlab.org.cn/pdf/2026-05-08/9079dc92-130f-4e9a-b0da-d1216357fea5.zip'}]}