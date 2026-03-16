#!/bin/bash
set -euo pipefail

BASEURL="https://vanvj00001.github.io/oldvan/"
REMOTE="origin"
BRANCH="gh-pages"
WORKTREE_DIR=".gh-pages"

echo "准备 GitHub Pages 工作区..."
if [ -d "$WORKTREE_DIR" ]; then
  : # 已存在
else
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
