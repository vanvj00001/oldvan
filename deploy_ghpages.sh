#!/bin/bash
set -euo pipefail

BASEURL="https://vanvj00001.github.io/oldvan/"
REMOTE="origin"
BRANCH="gh-pages"
WORKTREE_DIR=".gh-pages"

echo "准备 GitHub Pages 工作区..."
git fetch --prune "$REMOTE"
# 检查现有 worktree 是否可用：目录存在 + .git 链接指向有效路径 + 在 worktree 列表里
if [ -d "$WORKTREE_DIR" ] && [ -f "$WORKTREE_DIR/.git" ] && \
   git -C "$WORKTREE_DIR" rev-parse --git-dir >/dev/null 2>&1 && \
   git worktree list --porcelain | grep -q "^worktree.*$WORKTREE_DIR\$"; then
  : # 已存在且有效
else
  # 清理无效 worktree（指向旧路径/死链接）
  if [ -d "$WORKTREE_DIR" ]; then
    echo "清理无效 worktree: $WORKTREE_DIR"
    git worktree remove --force "$WORKTREE_DIR" 2>/dev/null || rm -rf "$WORKTREE_DIR"
    git worktree prune
  fi
  if git show-ref --quiet "refs/remotes/${REMOTE}/${BRANCH}"; then
    git worktree add "$WORKTREE_DIR" "${REMOTE}/${BRANCH}"
  else
    git worktree add -B "$BRANCH" "$WORKTREE_DIR"
  fi
fi

echo "清理并构建..."
find "$WORKTREE_DIR" -mindepth 1 -maxdepth 1 ! -name ".git" -exec rm -rf {} +
hugo -b "$BASEURL" -d "$WORKTREE_DIR"

echo "提交并推送 gh-pages..."
git -C "$WORKTREE_DIR" add -A
if git -C "$WORKTREE_DIR" diff --cached --quiet; then
  echo "无改动，跳过提交。"
else
  git -C "$WORKTREE_DIR" commit -m "Deploy: $(date '+%Y-%m-%d %H:%M:%S')"
fi
git -C "$WORKTREE_DIR" push "$REMOTE" "$BRANCH"
