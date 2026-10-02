#!/bin/bash
set -uo pipefail
# 发布脚本
# 注意: 这里刻意不使用 `set -e`。
# 备份服务器不可达、或某个部署目标失败时, 脚本应继续执行后续步骤,
# 而不是整体中断。每个关键步骤自行判断成败并给出提示。

# 主站点 baseURL，用于在构建 `public/` 时生成正确的绝对/相对链接
BASEURL_MAIN="https://oldvan.top/"

# ===== NAS 地址（主备回退）=====
# 192.168.2.233 是家里的局域网地址（快）；100.66.233.2 是 Tailscale 地址（在外可用）。
# 两者是同一台飞牛 NAS。脚本会优先用局域网地址，不通时自动回退到 Tailscale。
NAS_HOST_LAN="192.168.2.233"
NAS_HOST_TS="100.66.233.2"
NAS_USER="vanvj"
# 233 NAS 上的裸仓库（权威源）——多笔记本通过它同步，避免版本混乱
NAS_GIT_PATH="/vol1/1000/代码/oldvan.git"

# 探测某个地址是否可作为 NAS 使用（3 秒超时）
# 用真实 SSH 连接探测，比端口扫描可靠：
# 本机若有 Clash 等 TUN 代理，nc 会把不可达地址误判为可达。
nas_reachable() {
  local host="$1"
  ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes \
      "$NAS_USER@$host" "true" >/dev/null 2>&1
}

# 选出可用地址，结果写入全局变量 NAS_HOST / NAS_HOSTNAME_ACTIVE
NAS_HOST=""
NAS_HOSTNAME_ACTIVE=""
select_nas_host() {
  if nas_reachable "$NAS_HOST_LAN"; then
    NAS_HOSTNAME_ACTIVE="$NAS_HOST_LAN"
  elif nas_reachable "$NAS_HOST_TS"; then
    echo "局域网地址 $NAS_HOST_LAN 不可达，回退到 Tailscale 地址 $NAS_HOST_TS"
    NAS_HOSTNAME_ACTIVE="$NAS_HOST_TS"
  else
    NAS_HOSTNAME_ACTIVE=""
  fi
  NAS_HOST="$NAS_USER@$NAS_HOSTNAME_ACTIVE"
}

select_nas_host
if [ -z "$NAS_HOSTNAME_ACTIVE" ]; then
  echo "警告: 局域网($NAS_HOST_LAN)与 Tailscale($NAS_HOST_TS) 均不可达，NAS 相关步骤将被跳过。"
else
  echo "NAS 地址: $NAS_HOSTNAME_ACTIVE"
fi

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
NAS_BACKUP_DIR="/vol2/1000/vanvj-EXT-12T/7900/backup/oldvan"
NAS_KEEP_COUNT=3
STAMP=$(date '+%Y%m%d-%H%M%S')

# 确保 NAS 备份目录存在
if ! $NAS_SSH -o ConnectTimeout=10 "$NAS_HOST" "mkdir -p '$NAS_BACKUP_DIR'" 2>/dev/null; then
  echo "警告: 无法连接备份服务器 ($NAS_HOSTNAME_ACTIVE)，尝试另一个地址..."
  if [ "$NAS_HOSTNAME_ACTIVE" = "$NAS_HOST_LAN" ]; then
    NAS_HOSTNAME_ACTIVE="$NAS_HOST_TS"
  else
    NAS_HOSTNAME_ACTIVE="$NAS_HOST_LAN"
  fi
  NAS_HOST="$NAS_USER@$NAS_HOSTNAME_ACTIVE"
  if ! $NAS_SSH -o ConnectTimeout=10 "$NAS_HOST" "mkdir -p '$NAS_BACKUP_DIR'" 2>/dev/null; then
    echo "警告: 两个地址均不可达，跳过 NAS 备份，继续后续步骤。"
    NAS_HOSTNAME_ACTIVE=""
  else
    echo "改用 $NAS_HOSTNAME_ACTIVE 连接成功。"
  fi
fi

if [ -n "$NAS_HOSTNAME_ACTIVE" ]; then
  # 打包源码(排除 themes/public/.git 及构建产物)并通过 SSH 管道直接写入 NAS
  echo "打包并传输到飞牛NAS ($NAS_HOSTNAME_ACTIVE:$NAS_BACKUP_DIR)..."
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
# ==============================================================
# 多笔记本协作：以 233 NAS 为权威源
# --------------------------------------------------------------
# 旧流程的问题：直接 git add . && commit && push，
#   若另一台笔记本已推送过内容，就会分叉 → 版本混乱。
# 新流程：
#   1) 提交前先从 NAS 拉取并 rebase，把自己的改动叠在最新之上
#   2) 先推 NAS（权威源），成功后再推 GitHub / Gitee（异地备份）
#   3) NAS 推送失败则中止后续部署，避免"本地以为发布了、实际没同步"
# ==============================================================

# ---- 建立 NAS remote（若未配置）----
NAS_GIT_HOST=""
for h in "$NAS_HOST_LAN" "$NAS_HOST_TS"; do
  if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=4 -o BatchMode=yes \
        "$NAS_USER@$h" "test -d '$NAS_GIT_PATH'" >/dev/null 2>&1; then
    NAS_GIT_HOST="$h"; break
  fi
done
if [ -n "$NAS_GIT_HOST" ]; then
  git remote remove nas 2>/dev/null || true
  git remote add nas "$NAS_USER@$NAS_GIT_HOST:$NAS_GIT_PATH"
  echo "NAS git 源: $NAS_GIT_HOST:$NAS_GIT_PATH"
else
  echo "警告: 无法连接 NAS git 仓库，将跳过 NAS 同步（仅推送 GitHub/Gitee）。"
fi

# ---- 1) 提交前先拉取（避免分叉）----
if [ -n "$NAS_GIT_HOST" ]; then
  echo "从 NAS 拉取最新（rebase）..."
  # 注意: 不能用 `cmd | sed` 的退出码判断成败——管道返回的是 sed 的状态(恒为0)。
  # 必须用 PIPESTATUS[0] 取 git 本身的退出码，否则 rebase 冲突会被误判为成功。
  git fetch nas main 2>&1 | sed 's/^/    /'
  if [ "${PIPESTATUS[0]}" -ne 0 ]; then
    echo "警告: fetch 失败，跳过预拉取。"
  else
    BEHIND=$(git rev-list --count HEAD..nas/main 2>/dev/null || echo 0)
    AHEAD=$(git rev-list --count nas/main..HEAD 2>/dev/null || echo 0)
    if [ "$BEHIND" -gt 0 ] && [ "$AHEAD" -eq 0 ]; then
      git merge --ff-only nas/main && echo "已快进到 NAS 最新版本。"
    elif [ "$BEHIND" -gt 0 ] && [ "$AHEAD" -gt 0 ]; then
      echo "检测到分叉（本机领先 $AHEAD，NAS 领先 $BEHIND），正在 rebase..."
      # 提交前先 stash 未提交改动，rebase 后再恢复
      STASHED=0
      if ! git diff --quiet || ! git diff --cached --quiet; then
        git stash push -u -m "deploy-autostash" >/dev/null 2>&1 && STASHED=1
      fi
      git rebase nas/main 2>&1 | sed 's/^/    /'
      if [ "${PIPESTATUS[0]}" -ne 0 ]; then
        echo
        echo "错误: rebase 发生冲突，已中止部署。"
        echo "  解决办法："
        echo "    1) 查看冲突:  git status"
        echo "    2) 编辑冲突文件，解决后:  git add <文件>"
        echo "    3) 继续:      git rebase --continue"
        echo "    4) 完成后重新运行 ./deploy.sh"
        echo "  若想放弃本次 rebase:  git rebase --abort"
        if [ "$STASHED" -eq 1 ]; then
          echo "  注意: 你未提交的改动已暂存，解决后用 git stash pop 恢复。"
        fi
        exit 1
      fi
      echo "rebase 成功。"
      [ "$STASHED" -eq 1 ] && { git stash pop >/dev/null 2>&1 && echo "已恢复暂存的改动。"; }
    fi
  fi
fi

git add .
if git diff --cached --quiet; then
  echo "无改动，跳过提交。"
else
  git commit -m "更新: $(date '+%Y-%m-%d %H:%M:%S')" || echo "提交失败，继续后续步骤。"
fi

# ---- 2) 推送：NAS 优先（权威源）----
NAS_PUSH_OK=0
if [ -n "$NAS_GIT_HOST" ]; then
  echo "推送到 233 NAS（权威源）..."
  git push nas main 2>&1 | sed 's/^/    /'
  if [ "${PIPESTATUS[0]}" -ne 0 ]; then
    echo
    echo "错误: 推送到 NAS 失败（权威源未更新）。"
    echo "  为免版本混乱，已中止后续部署。"
    echo "  常见原因：NAS 上有他人提交（需先 rebase）、网络不通、权限问题。"
    echo "  请处理后重新运行 ./deploy.sh"
    exit 1
  fi
  NAS_PUSH_OK=1
  echo "NAS 推送成功。"
fi

# ---- 3) 推送异地备份（失败不阻断）----
echo "推送到 GitHub（异地备份）..."
git push origin main || echo "推送到 GitHub 失败，继续后续步骤。"

if git remote | grep -qx gitee; then
  echo "推送到 Gitee（异地备份）..."
  git push gitee main || echo "推送到 Gitee 失败，继续后续步骤。"
fi

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
# NAS 版用局域网地址作为 baseURL（页面链接以局域网为准）
if ! hugo -b "http://$NAS_HOST_LAN:8093/" -d public_nas; then
  echo "错误: NAS 版构建失败，跳过 NAS 部署。"
else
  echo "同步到飞牛 NAS..."
  # 优先用当前选中的地址；若未选中，再试局域网/Tailscale 两个地址
  NAS_DEPLOY_OK=0
  for try_host in "$NAS_HOSTNAME_ACTIVE" "$NAS_HOST_LAN" "$NAS_HOST_TS"; do
    [ -z "$try_host" ] && continue
    echo "尝试部署到 $try_host ..."
    if rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10" \
        /Users/fanweijun/project/oldvan/public_nas/ \
        "$NAS_USER@$try_host:/vol2/1000/vanvj-EXT-12T/7900/site/oldvan-site/"; then
      echo "NAS 部署完成 ($try_host)"
      NAS_DEPLOY_OK=1
      break
    else
      echo "部署到 $try_host 失败，尝试下一个地址..."
    fi
  done

  if [ "$NAS_DEPLOY_OK" -eq 0 ]; then
    echo "部署到 233(NAS) 失败（两个地址均不可达），继续后续步骤。"
  fi

  echo "清理 NAS 构建..."
  rm -rf public_nas
fi

echo ""
echo "全部完成！"
echo "  GitHub Pages: https://oldvan.top"
if [ -n "$NAS_HOSTNAME_ACTIVE" ]; then
  echo "  NAS:         http://$NAS_HOSTNAME_ACTIVE:8093/"
else
  echo "  NAS:         未部署（局域网与 Tailscale 地址均不可达）"
fi
