#!/bin/bash

set -e

REPO_DIR="/Users/vanvj/my-blog"
COMMIT_MSG="${1:-deploy: $(date '+%Y-%m-%d %H:%M:%S')}"

echo "=========================================="
echo "开始部署博客到 GitHub"
echo "=========================================="

cp -u /Users/fanweijun/oldvan/content/posts/2026-03/* /Users/vanvj/my-blog/content/posts/2026/03/


cd "$REPO_DIR"

# Clean build
echo "[1/4] 清理旧构建..."
rm -rf public resources/_gen

# Build
echo "[2/4] 构建博客..."
hugo --minify

# Deploy to gh-pages branch
echo "[3/4] 部署到 gh-pages..."
cd public

# Init git in public folder if needed
if [ ! -d .git ]; then
    git init
fi

if git remote get-url origin >/dev/null 2>&1; then
    git remote set-url origin https://github.com/vanvj00002/monkvan.git
else
    git remote add origin https://github.com/vanvj00002/monkvan.git
fi

git checkout -B gh-pages
git add -A
if git diff --cached --quiet; then
    echo "没有更改需要提交"
else
    git commit -m "$COMMIT_MSG"
fi
git push -u origin gh-pages --force

echo "=========================================="
echo "部署完成！"
echo "博客地址: https://vanvj00002.github.io/monkvan"
echo "=========================================="
