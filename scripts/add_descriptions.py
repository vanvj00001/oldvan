#!/usr/bin/env python3
"""
批量给文章 frontmatter 添加 description 字段（SEO优化）
从文章正文前200字自动提取摘要作为 description。
用法: python3 add_descriptions.py [--dry-run]
"""
import os
import re
import sys

CONTENT_DIR = os.path.expanduser("~/project/oldvan/content/posts")
DRY_RUN = "--dry-run" in sys.argv

def extract_description(content: str, max_len: int = 155) -> str:
    """从文章正文提取前N个汉字作为description"""
    # 跳过 frontmatter
    parts = content.split("---", 2)
    if len(parts) < 3:
        return ""
    body = parts[2]
    
    # 去除HTML标签
    body = re.sub(r'<[^>]+>', '', body)
    # 去除Markdown格式
    body = re.sub(r'[#*_`>\[\]()!~]', '', body)
    # 去除引用行
    body = re.sub(r'^\s*>.*$', '', body, flags=re.MULTILINE)
    # 去除分隔线
    body = re.sub(r'^[\s\-\*_]{3,}$', '', body, flags=re.MULTILINE)
    
    # 取非空行，拼接
    lines = [l.strip() for l in body.split('\n') if l.strip()]
    text = ''
    for line in lines:
        # 跳过标题行和关键词行
        if line.startswith('关键词') or line.startswith('前言'):
            continue
        text += line
        if len(text) >= max_len:
            break
    
    # 截断到最近的句号
    if len(text) > max_len:
        cut = text[:max_len]
        # 在句号、问号、感叹号处截断
        for sep in ['。', '？', '！', '.', '!', '?']:
            idx = cut.rfind(sep)
            if idx > max_len // 2:
                cut = cut[:idx + 1]
                break
        text = cut
    
    # 清理首尾
    text = text.strip()
    # 去掉末尾不完整的句子
    if text and text[-1] not in '。？！.!?':
        # 找最后一个完整句子
        for sep in ['。', '？', '！', '.', '!', '?']:
            idx = text.rfind(sep)
            if idx > max_len // 3:
                text = text[:idx + 1]
                break
    
    return text

def process_file(filepath: str, dry_run: bool) -> bool:
    """处理单个文章文件，添加 description"""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 检查是否已有 description
    if re.search(r'^description:', content, re.MULTILINE):
        return False
    
    # 提取正文摘要
    desc = extract_description(content)
    if not desc:
        print(f"  SKIP (无法提取摘要): {filepath}")
        return False
    
    # 在 frontmatter 的 title 行后面插入 description
    lines = content.split('\n')
    insert_idx = None
    for i, line in enumerate(lines):
        if line.startswith('title:'):
            insert_idx = i + 1
            break
    
    if insert_idx is None:
        print(f"  SKIP (无 title): {filepath}")
        return False
    
    # 插入 description
    desc_line = f'description: "{desc}"'
    lines.insert(insert_idx, desc_line)
    
    if dry_run:
        print(f"  WOULD ADD: {desc[:60]}...")
        return True
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))
    
    print(f"  ADDED: {desc[:60]}...")
    return True

def main():
    count = 0
    skipped = 0
    
    for year_dir in sorted(os.listdir(CONTENT_DIR)):
        year_path = os.path.join(CONTENT_DIR, year_dir)
        if not os.path.isdir(year_path):
            continue
        
        for md_file in sorted(os.listdir(year_path)):
            if not md_file.endswith('.md'):
                continue
            filepath = os.path.join(year_path, md_file)
            if process_file(filepath, DRY_RUN):
                count += 1
            else:
                skipped += 1
    
    print(f"\n{'预览' if DRY_RUN else '完成'}: 新增 {count} 个 description, 跳过 {skipped} 个")

if __name__ == "__main__":
    main()
