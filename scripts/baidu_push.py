#!/usr/bin/env python3
"""
百度搜索资源平台 - 链接提交脚本
使用方法:
  1. 先在 https://ziyuan.baidu.com 注册并验证站点
  2. 在「链接提交」页面获取 token
  3. 运行: python3 baidu_push.py YOUR_TOKEN
  4. 或设置环境变量: export BAIDU_PUSH_TOKEN=xxx && python3 baidu_push.py

支持两种模式:
  - 默认: 从 public/sitemap.xml 读取所有 URL 批量推送
  - 指定文件: python3 baidu_push.py TOKEN urls.txt (每行一个URL)
"""

import sys
import os
import json
import urllib.request
import urllib.error
import xml.etree.ElementTree as ET
from pathlib import Path

BAIDU_PUSH_API = "http://data.zz.baidu.com/urls"
SITE = "https://oldvan.top"
BATCH_SIZE = 1000  # 百度每次最多接收 1000 条


def load_urls_from_sitemap(sitemap_path):
    """从 sitemap.xml 提取所有 URL"""
    tree = ET.parse(sitemap_path)
    root = tree.getroot()
    ns = {"s": "http://www.sitemaps.org/schemas/sitemap/0.9"}
    urls = []
    for url_elem in root.findall("s:url", ns):
        loc = url_elem.find("s:loc", ns)
        if loc is not None and loc.text:
            urls.append(loc.text.strip())
    return urls


def load_urls_from_file(filepath):
    """从文本文件读取 URL（每行一个）"""
    urls = []
    with open(filepath, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and line.startswith("http"):
                urls.append(line)
    return urls


def push_to_baidu(token, urls):
    """推送 URL 列表到百度"""
    # 百度 API 要求 POST，body 是换行分隔的 URL
    body = "\n".join(urls).encode("utf-8")
    url = f"{BAIDU_PUSH_API}?site={SITE}&token={token}"

    req = urllib.request.Request(url, data=body, method="POST")
    req.add_header("Content-Type", "text/plain")

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            result = json.loads(resp.read().decode("utf-8"))
            return result
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        return {"error": True, "status": e.code, "message": body}
    except Exception as e:
        return {"error": True, "message": str(e)}


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    token = sys.argv[1]
    project_dir = Path(__file__).parent.parent

    # 确定 URL 来源
    if len(sys.argv) >= 3:
        # 从指定文件读取
        urls = load_urls_from_file(sys.argv[2])
        print(f"从文件加载 {len(urls)} 个 URL")
    else:
        # 从 sitemap 读取
        sitemap_path = project_dir / "public" / "sitemap.xml"
        if not sitemap_path.exists():
            print(f"错误: 找不到 {sitemap_path}")
            print("请先运行 hugo 构建，或指定 URL 文件")
            sys.exit(1)
        urls = load_urls_from_sitemap(sitemap_path)
        print(f"从 sitemap 加载 {len(urls)} 个 URL")

    if not urls:
        print("没有找到可推送的 URL")
        sys.exit(0)

    # 分批推送
    total = len(urls)
    success = 0
    fail = 0

    for i in range(0, total, BATCH_SIZE):
        batch = urls[i : i + BATCH_SIZE]
        batch_num = i // BATCH_SIZE + 1
        total_batches = (total + BATCH_SIZE - 1) // BATCH_SIZE

        print(f"\n推送第 {batch_num}/{total_batches} 批 ({len(batch)} 条)...")
        result = push_to_baidu(token, batch)

        if "error" not in result:
            remain = result.get("remain", "?")
            success += result.get("success", len(batch))
            print(f"  ✓ 成功: {result.get('success', 0)} 条, 剩余配额: {remain}")
        else:
            fail += len(batch)
            msg = result.get("message", result.get("status", "未知错误"))
            print(f"  ✗ 失败: {msg}")

    print(f"\n完成: 共 {total} 条, 成功 {success}, 失败 {fail}")


if __name__ == "__main__":
    main()
