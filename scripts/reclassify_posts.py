#!/usr/bin/env python3
"""
oldvan 博客全站重分类 → 7 大类
- 把 14 种老 categories 合并到 7 大类
- 给 47 篇空分类补 categories
- 直接改 .md frontmatter 的 categories 行
"""
import os
import re
import sys

POSTS_DIR = "/Users/fanweijun/project/oldvan/content/posts"

TARGETS = {'佛学','佛学开示','修验实参','修行随笔','修行日记','认知论','人生随笔'}

# 现有非 7 类的 → 7 类
MAPPING = {
    '佛学':'佛学',
    '佛学开示':'佛学开示',
    '佛经解读':'佛学',
    '佛法修行':'佛学开示',
    '佛法随笔':'佛学开示',
    '佛学随笔':'修行随笔',
    '修行随笔':'修行随笔',
    '修行反思':'修行随笔',
    '修行日记':'修行日记',
    '修验实参':'修验实参',
    '认知论':'认知论',
    '认识论':'认知论',
    '认知随笔':'认知论',
    '人生随笔':'人生随笔',
    '哲学随笔':'认知论',
    '思想随笔':'认知论',
    '思想方法':'认知论',
    '哲学思考':'认知论',
    '心灵成长':'认知论',
    '物理随笔':'认知论',
    '社会观察':'认知论',
    'AI观察':'认知论',
}

# 47 篇空分类按标题的建议分类(filename → 7 类)
PROPOSED_EMPTY = {
    '认知的世界和多元的世界.md':'认知论',
    '世间皆苦唯有自渡.md':'佛学',
    '修行路上的失重感.md':'修行随笔',
    '宇宙是一场巨型程序.md':'认知论',
    '时间的本质.md':'认知论',
    '浮世行舟者.md':'人生随笔',
    '素食的祛魅和扶正.md':'人生随笔',
    '苦和乐.md':'佛学',
    '见相非相.md':'佛学',
    '关系炼金术.md':'人生随笔',
    '助人的真相.md':'人生随笔',
    '如何获得自由.md':'佛学',
    '精神之饥.md':'人生随笔',
    '羡慕嫉妒恨.md':'人生随笔',
    '道韵与精神体.md':'修验实参',
    '人性和佛性.md':'佛学',
    '化城之喻.md':'佛学',
    '如何自在放下.md':'佛学',
    '孩子的智商.md':'认知论',
    '无为而为.md':'佛学开示',
    '盂兰盆节的由来.md':'佛学',
    '自由的真相.md':'佛学',
    '世间疾苦.md':'佛学',
    '什么是我.md':'佛学',
    '修行的路怎么走.md':'佛学开示',
    '大乘人的婚姻观.md':'佛学开示',
    '大乘毒药.md':'佛学开示',
    '洞穴之喻.md':'认知论',
    '自造苦旅.md':'佛学',
    '赌博狂舞.md':'人生随笔',
    '道场的迷雾和生活的死水.md':'修行随笔',
    '修行本相.md':'佛学开示',
    '关于怒气.md':'修行随笔',
    '完美就是是个什么样的存在.md':'认知论',
    '我对这个世界的认知（故事篇）.md':'认知论',
    '我是谁.md':'佛学',
    '拉普拉斯恶魔.md':'认知论',
    '欲望是洪水猛兽吗.md':'佛学',
    '神通.md':'修验实参',
    '聊聊沟通.md':'人生随笔',
    '菩萨道.md':'佛学',
    '言语的力量.md':'修行随笔',
    '一阐提.md':'佛学',
    '东西方AI之争.md':'认知论',
    '四依四不依.md':'佛学',
    '崇拜偶像的背后.md':'人生随笔',
    '科学角度下的不净观与慈悲观.md':'佛学',
}


def fix_file(path, current_cat, new_cat):
    """把 frontmatter 里的 categories: <old> 替换为 categories: <new>
    格式: categories:\n  - <name>"""
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    if current_cat:
        # 替换现有 categories 块(可能跨多行,YAML list 格式)
        # 匹配: categories:\n  - <old>
        pattern = re.compile(
            r'(^categories:\s*\n)((?:\s*-\s*.+\n)+)',
            re.MULTILINE
        )
        def repl(m):
            return f"{m.group(1)}  - {new_cat}\n"
        new_content, n = pattern.subn(repl, content, count=1)
        if n == 0:
            # 也可能是单行: categories: <name>
            pattern2 = re.compile(r'^categories:\s*.+$', re.MULTILINE)
            new_content, n = pattern2.subn(f"categories:\n  - {new_cat}", content, count=1)
            if n == 0:
                return False, "no categories block"
    else:
        # 在 frontmatter 末尾加 categories
        # frontmatter 闭合 ---
        m = re.search(r'^---\s*$', content, re.MULTILINE)
        if not m:
            return False, "no frontmatter close"
        # 找到第一个 --- 的位置
        # 第二个 --- 是 frontmatter 闭合
        ends = [m.start() for m in re.finditer(r'^---\s*$', content, re.MULTILINE)]
        if len(ends) < 2:
            return False, "frontmatter not closed properly"
        close_pos = ends[1]
        # 在 --- 之前插入
        new_block = f"categories:\n  - {new_cat}\n"
        new_content = content[:close_pos] + new_block + content[close_pos:]

    if new_content != content:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        return True, "ok"
    return False, "no change"


def main():
    stats = {
        'mapped': [],     # 17 篇非 7 类 → 7 类
        'filled': [],     # 47 篇空 → 7 类
        'unchanged': 0,   # 已是 7 类
        'errors': [],
    }

    for root, _, files in os.walk(POSTS_DIR):
        for f in files:
            if not f.endswith('.md'):
                continue
            path = os.path.join(root, f)
            with open(path, 'r', encoding='utf-8') as fp:
                content = fp.read(2000)

            # 提取当前 category
            m = re.search(r'^categories:\s*\n((?:\s*-\s*.+\n)+)', content, re.M)
            current_cat = None
            if m:
                current_cat = re.search(r'-\s*(.+)', m.group(1)).group(1).strip()
            else:
                m2 = re.search(r'^categories:\s*([^\n]+)', content, re.M)
                if m2:
                    current_cat = m2.group(1).strip().strip('"').strip("'")

            if current_cat and current_cat in TARGETS:
                stats['unchanged'] += 1
                continue

            if current_cat and current_cat in MAPPING:
                new_cat = MAPPING[current_cat]
            elif current_cat is None:
                fn = os.path.basename(f)
                if fn not in PROPOSED_EMPTY:
                    stats['errors'].append((path, f"no proposed mapping for empty: {fn}"))
                    continue
                new_cat = PROPOSED_EMPTY[fn]
            else:
                stats['errors'].append((path, f"unknown category: {current_cat}"))
                continue

            ok, msg = fix_file(path, current_cat, new_cat)
            if ok:
                if current_cat:
                    stats['mapped'].append((path, current_cat, new_cat))
                else:
                    stats['filled'].append((path, new_cat))
            else:
                stats['errors'].append((path, msg))

    print(f"=== 重分类结果 ===")
    print(f"  未改(已是 7 类): {stats['unchanged']}")
    print(f"  合并(非 7 类 → 7 类): {len(stats['mapped'])}")
    for p, old, new in stats['mapped']:
        rel = p.replace(POSTS_DIR + '/', '')
        print(f"    {old:8s} → {new:8s}  {rel}")
    print(f"  补分类(空 → 7 类): {len(stats['filled'])}")
    for p, new in stats['filled']:
        rel = p.replace(POSTS_DIR + '/', '')
        print(f"    → {new:8s}  {rel}")
    if stats['errors']:
        print(f"  错误 {len(stats['errors'])}:")
        for p, e in stats['errors']:
            print(f"    [ERR] {p}: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
