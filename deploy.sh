#!/bin/bash
set -euo pipefail
# 发布脚本

# 主站点 baseURL，用于在构建 `public/` 时生成正确的绝对/相对链接
BASEURL_MAIN="https://oldvan.top/"

echo "备份到 vanbak..."
tar -czf /Users/fanweijun/vanbak/oldvan-content-$(date '+%Y%m%d-%H%M%S').tar.gz -C /Users/fanweijun/oldvan content/



# 飞牛备份：https://share.fnnas.net/s/afbbf814191643b98b


echo "构建 Hugo (主站) ..."
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

echo "完成！"
