#!/bin/bash
# 发布脚本

echo "构建 Hugo..."
hugo

echo "提交代码..."
git add . 
git commit -m "更新: $(date '+%Y-%m-%d %H:%M:%S')"

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
