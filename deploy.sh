#!/bin/bash
set -uo pipefail
# 发布脚本
# 注意: 这里刻意不使用 `set -e`。
# 备份服务器不可达、或某个部署目标失败时, 脚本应继续执行后续步骤,
# 而不是整体中断。每个关键步骤自行判断成败并给出提示。

# 主站点 baseURL，用于在构建 `public/` 时生成正确的绝对/相对链接
BASEURL_MAIN="https://oldvan.top/"

echo "备份到 vanbak..."
BAK_DIR="/Users/fanweijun/vanbak"
mkdir -p "$BAK_DIR"

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

tar -czf "$BAK_DIR"/oldvan-content-$(date '+%Y%m%d-%H%M%S').tar.gz -C /Users/fanweijun/project/oldvan content/

echo "压缩备份到飞牛NAS..."
echo "正在压缩备份..."
NAS_SSH="ssh -o StrictHostKeyChecking=no"
NAS_HOST="vanvj@192.168.2.233"
NAS_BACKUP_DIR="/vol2/1000/vanvj-EXT-12T/7900/backup/oldvan"
NAS_KEEP_COUNT=3
STAMP=$(date '+%Y%m%d-%H%M%S')

# 确保 NAS 备份目录存在
if ! $NAS_SSH -o ConnectTimeout=10 "$NAS_HOST" "mkdir -p '$NAS_BACKUP_DIR'"; then
  echo "警告: 无法连接备份服务器 ($NAS_HOST)，跳过 NAS 备份，继续后续步骤。"
else
  # 打包源码(排除 themes/public/.git 及构建产物)并通过 SSH 管道直接写入 NAS
  echo "打包并传输到飞牛NAS ($NAS_BACKUP_DIR)..."
  if tar -czf - -C /Users/fanweijun/project/oldvan \
      --exclude='./.git' --exclude='./themes' --exclude='./public' \
      --exclude='./public_nas' --exclude='./.gh-pages' --exclude='./.cf-pages' \
      --exclude='./resources' --exclude='./.DS_Store' --exclude='./.hugo_build.lock' \
      . | $NAS_SSH -o ConnectTimeout=10 "$NAS_HOST" "cat > '$NAS_BACKUP_DIR/oldvan-$STAMP.tar.gz'"; then
    echo "NAS 备份成功: $NAS_BACKUP_DIR/oldvan-$STAMP.tar.gz"
  else
    echo "NAS 备份失败，继续后续步骤。"
  fi

  # 清理 NAS 旧备份: 只保留最新 $NAS_KEEP_COUNT 个
  $NAS_SSH -o ConnectTimeout=10 "$NAS_HOST" "cd '$NAS_BACKUP_DIR' && ls -t oldvan-*.tar.gz 2>/dev/null | tail -n +$((NAS_KEEP_COUNT+1)) | xargs -r rm -f" || true
fi

# 飞牛备份：https://share.fnnas.net/s/afbbf814191643b98b


echo "构建 Hugo(主站) ..."
# 使用显式 baseURL 构建 public，确保在不同部署目标下链接正确
if ! hugo -b "$BASEURL_MAIN" -d public; then
  echo "错误: Hugo 主站构建失败，后续部署将使用旧产物继续。"
fi

echo "提交代码..."
git add .
if git diff --cached --quiet; then
  echo "无改动，跳过提交。"
else
  git commit -m "更新: $(date '+%Y-%m-%d %H:%M:%S')" || echo "提交失败，继续后续步骤。"
fi

echo "推送到 GitHub..."
git push origin main || echo "推送到 GitHub 失败，继续后续步骤。"

echo "发布到 GitHub Pages..."
if ! ./deploy_ghpages.sh; then
  echo "GitHub Pages 发布失败，继续后续步骤。"
fi

echo "发布到 Cloudflare Pages..."
if ! ./deploy_cfpages.sh; then
  echo "Cloudflare Pages 发布失败，继续后续步骤。"
fi

echo "同步到阿里云服务器..."
if ! rsync -avz -e "ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o ConnectTimeout=10" --delete /Users/fanweijun/project/oldvan/public/ root@122.51.71.6:/www/wwwroot/oldvan/; then
  echo "阿里云同步失败，继续后续步骤。"
fi

echo "构建 NAS 版..."
if ! hugo -b "http://192.168.2.233:8093/" -d public_nas; then
  echo "错误: NAS 版构建失败，跳过 NAS 部署。"
else
  echo "同步到飞牛 NAS..."
  if ! rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10" /Users/fanweijun/project/oldvan/public_nas/ vanvj@192.168.2.233:/vol2/1000/vanvj-EXT-12T/7900/site/oldvan-site/; then
    echo "部署到 233(NAS) 失败，继续后续步骤。"
  else
    echo "NAS 部署完成"
  fi

  echo "清理 NAS 构建..."
  rm -rf public_nas
fi

echo ""
echo "全部完成！"
echo "  GitHub Pages: https://oldvan.top"
echo "  NAS:         http://192.168.2.233:8093/"
