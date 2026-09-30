#!/bin/bash
set -euo pipefail

BASEURL="https://vanvj00001.github.io/oldvan/"
REMOTE="origin"
BRANCH="gh-pages"
WORKTREE_DIR=""

echo "准备 GitHub Pages 工作区..."
git fetch --prune "$REMOTE"
WORKTREE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/oldvan-gh-pages.XXXXXX")
rmdir "$WORKTREE_DIR"
cleanup() {
  git worktree remove --force "$WORKTREE_DIR" >/dev/null 2>&1 || rm -rf "$WORKTREE_DIR"
}
trap cleanup EXIT

if git show-ref --quiet "refs/remotes/${REMOTE}/${BRANCH}"; then
  git worktree add --detach "$WORKTREE_DIR" "${REMOTE}/${BRANCH}"
else
  git worktree add --detach "$WORKTREE_DIR" HEAD
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
git -C "$WORKTREE_DIR" push "$REMOTE" "HEAD:$BRANCH"
