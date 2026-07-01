#!/bin/bash
set -euo pipefail
# 发布脚本

# 主站点 baseURL，用于在构建 `public/` 时生成正确的绝对/相对链接
BASEURL_MAIN="https://oldvan.top/"

echo "备份到 vanbak..."
BAK_DIR="/Users/fanweijun/vanbak"

# 清理旧备份: 只保留最新 3 个 oldvan-content-*.tar.gz, 多余的删掉
KEEP_COUNT=3
EXISTING=$(ls -t "$BAK_DIR"/oldvan-content-*.tar.gz 2>/dev/null || true)
EXISTING_COUNT=$(echo "$EXISTING" | grep -c . || true)
if [ "$EXISTING_COUNT" -gt "$KEEP_COUNT" ]; then
    REMOVE=$(echo "$EXISTING" | tail -n +$((KEEP_COUNT + 1)))
    echo "清理旧备份 (保留最新 $KEEP_COUNT 个, 删除 $((EXISTING_COUNT - KEEP_COUNT)) 个)..."
    echo "$REMOVE" | xargs rm -f
    echo "旧备份已删除"
fi

tar -czf "$BAK_DIR"/oldvan-content-$(date '+%Y%m%d-%H%M%S').tar.gz -C /Users/fanweijun/oldvan content/

echo "压缩备份到飞牛NAS..."
echo "正在压缩备份..."
BACKUP_DIR="/Volumes/vanvj-INT-1T/备份/代码"
BACKUP_FILE="$BACKUP_DIR/oldvan-$(date '+%Y%m%d-%H%M%S').zip"
if [ -d "$BACKUP_DIR" ]; then
  zip -rq "$BACKUP_FILE" /Users/fanweijun/oldvan --exclude '*/themes/*' --exclude '*/public/*' --exclude '*/.git/*'
else
  echo "备份目录不存在，跳过飞牛NAS压缩备份：$BACKUP_DIR"
fi

# 飞牛备份：https://share.fnnas.net/s/afbbf814191643b98b


echo "构建 Hugo(主站) ..."
# 使用显式 baseURL 构建 public，确保在不同部署目标下链接正确
hugo -b "$BASEURL_MAIN" -d public

echo "提交代码..."
git add .
if git diff --cached --quiet; then
  echo "无改动，跳过提交。"
else
  git commit -m "更新: $(date '+%Y-%m-%d %H:%M:%S')"
fi

echo "推送到 GitHub..."
git push origin main

echo "发布到 GitHub Pages..."
./deploy_ghpages.sh

echo "发布到 Cloudflare Pages..."
if ! ./deploy_cfpages.sh; then
  echo "Cloudflare Pages 发布失败，继续后续步骤。"
fi

echo "同步到服务器..."
rsync -avz -e "ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no" --delete /Users/fanweijun/oldvan/public/ root@122.51.71.6:/www/wwwroot/oldvan/

echo "构建 NAS 版..."
hugo -b "http://192.168.2.233:8090/" -d public_nas

echo "同步到飞牛 NAS..."
rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no" /Users/fanweijun/oldvan/public_nas/ vanvj@192.168.2.233:/vol3/1000/vanvj-EXT-12T/7900/oldvan-site/

echo "清理 NAS 构建..."
rm -rf public_nas
echo "NAS 部署完成"

echo ""
echo "全部完成！"
echo "  GitHub Pages: https://oldvan.top"
echo "  NAS:         http://192.168.2.233:8090/"
