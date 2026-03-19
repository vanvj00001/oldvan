#!/bin/bash
set -euo pipefail

BASEURL="https://oldvan.pages.dev/"
OUTDIR="public"
PROJECT="oldvan"

echo "构建 Hugo (Cloudflare Pages)..."
hugo -b "$BASEURL" -d "$OUTDIR"

if ! command -v wrangler >/dev/null 2>&1; then
  echo "未找到 wrangler，请先安装并登录："
  echo "  npm i -g wrangler"
  echo "  wrangler login"
  exit 1
fi

echo "发布到 Cloudflare Pages..."
wrangler pages deploy "$OUTDIR" --project-name "$PROJECT"
