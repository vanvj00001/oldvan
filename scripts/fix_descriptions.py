#!/usr/bin/env python3
"""
修复所有文章的 description 字段 — 去掉引号问题，用安全的YAML格式
"""
import os
import re

CONTENT_DIR = os.path.expanduser("~/project/oldvan/content/posts")

def fix_description_line(line: str) -> str:
    """修复 description 行中的引号问题"""
    # 提取 description 值
    m = re.match(r'^description:\s*(.*)', line)
    if not m:
        return line
    
    value = m.group(1).strip()
    
    # 去掉外层引号
    if (value.startswith('"') and value.endswith('"')) or \
       (value.startswith("'") and value.endswith("'")):
        value = value[1:-1]
    
    # 替换所有引号为安全字符
    value = value.replace('"', '').replace("'", '')
    value = value.replace('\u201c', '').replace('\u201d', '')  # 左右双引号
    value = value.replace('\u2018', '').replace('\u2019', '')  # 左右单引号
    value = value.replace('\u300c', '').replace('\u300d', '')  # 「」
    value = value.replace('\u300e', '').replace('\u300f', '')  # 『』
    
    # 清理多余空格
    value = ' '.join(value.split())
    
    # 截断到155字符（SEO最佳长度）
    if len(value) > 155:
        value = value[:150]
        # 在句号处截断
        for sep in ['。', '！', '？']:
            idx = value.rfind(sep)
            if idx > 50:
                value = value[:idx + 1]
                break
    
    return f'description: "{value}"'

def process_file(filepath: str):
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    changed = False
    new_lines = []
    for line in lines:
        if line.startswith('description:'):
            new_line = fix_description_line(line.rstrip('\n'))
            if new_line != line.rstrip('\n'):
                changed = True
            new_lines.append(new_line + '\n')
        else:
            new_lines.append(line)
    
    if changed:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
        return True
    return False

def main():
    count = 0
    for year_dir in sorted(os.listdir(CONTENT_DIR)):
        year_path = os.path.join(CONTENT_DIR, year_dir)
        if not os.path.isdir(year_path):
            continue
        for md_file in sorted(os.listdir(year_path)):
            if not md_file.endswith('.md'):
                continue
            filepath = os.path.join(year_path, md_file)
            if process_file(filepath):
                count += 1
                print(f"  FIXED: {year_dir}/{md_file}")
    
    print(f"\n修复了 {count} 个文件")

if __name__ == "__main__":
    main()
