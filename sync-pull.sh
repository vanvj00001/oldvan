#!/bin/bash
# ==============================================================
# sync-pull.sh —— 编辑文章前先同步（从 233 NAS 拉取）
# ==============================================================
# 用途：每次开始修改 oldvan 目录前，先运行本脚本。
#      它会从家里的 233 NAS（权威源）拉取最新内容，
#      确保你在这台笔记本上编辑时，起点和其他机器一致，
#      从而避免"多台笔记本各自提交造成的版本混乱"。
#
# 用法：
#     ./sync-pull.sh
#
# 退出码：
#     0 = 同步完成，可以开始编辑
#     1 = 无法连接 NAS（已中止，请检查 Tailscale / 网络）
#     2 = 本地有未提交改动且与远端冲突（需手工处理）
#     3 = 本地有未推送的提交（已拉取，但请留意）
# ==============================================================

set -uo pipefail

REPO_DIR="/Users/fanweijun/project/oldvan"

# ===== 233 NAS 地址（局域网优先，回退 Tailscale）=====
NAS_HOST_LAN="192.168.2.233"
NAS_HOST_TS="100.66.233.2"
NAS_USER="vanvj"
NAS_REPO_PATH="/vol1/1000/代码/oldvan.git"

GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'
CYAN=$'\033[36m'; BOLD=$'\033[1m'; RESET=$'\033[0m'

ok()   { echo "${GREEN}✓${RESET} $*"; }
warn() { echo "${YELLOW}!${RESET} $*"; }
err()  { echo "${RED}✗${RESET} $*"; }
step() { echo; echo "${BOLD}${CYAN}▸ $*${RESET}"; }

cd "$REPO_DIR" 2>/dev/null || { err "找不到仓库目录: $REPO_DIR"; exit 1; }

echo "${BOLD}═══ oldvan 同步拉取（编辑前）═══${RESET}"
echo "仓库: $REPO_DIR"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"

# ---------------------------------------------------------------
# 0. 安全检查：确保不在错误的仓库里操作
# ---------------------------------------------------------------
if [ ! -d .git ]; then
  err "当前目录不是 git 仓库，中止。"
  exit 1
fi

# ---------------------------------------------------------------
# 1. 选择可达的 NAS 地址
# ---------------------------------------------------------------
step "1/6 探测 233 NAS"

NAS_ACTIVE=""
# 用真实 SSH 连接探测（TUN 代理下 nc 会误判，故不用端口扫描）
for h in "$NAS_HOST_LAN" "$NAS_HOST_TS"; do
  if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=4 -o BatchMode=yes \
        "$NAS_USER@$h" "test -d '$NAS_REPO_PATH'" >/dev/null 2>&1; then
    NAS_ACTIVE="$h"; break
  fi
done

if [ -z "$NAS_ACTIVE" ]; then
  err "无法连接 233 NAS（试过 $NAS_HOST_LAN 与 $NAS_HOST_TS）"
  echo
  echo "  可能原因："
  echo "    · 不在家里网络，且 Tailscale 未连接"
  echo "    · NAS 关机或休眠"
  echo "  请检查后重试。为安全起见，本次未做任何改动。"
  exit 1
fi
ok "NAS 可达: $NAS_ACTIVE"

# 确保 nas remote 指向可达地址（局域网/Tailscale 自动切换）
git remote set-url nas "$NAS_USER@$NAS_ACTIVE:$NAS_REPO_PATH"

# ---------------------------------------------------------------
# 2. 检查本地未提交改动
# ---------------------------------------------------------------
step "2/6 检查本地工作区"

# 用 awk 提取路径后做精确匹配（BSD grep 的 .{2} 在中文/特殊字符下不可靠）
GHOST_TMP=$(mktemp)
DIRTY_TMP=$(mktemp)
trap 'rm -f "$GHOST_TMP" "$DIRTY_TMP"' EXIT

git status --porcelain | grep -v '^??' | while IFS= read -r line; do
  p=$(printf '%s' "$line" | cut -c4-)
  case "$p" in
    themes/ananke|themes/LoveIt|themes/PaperMod)
      printf '%s\n' "$line" >> "$GHOST_TMP" ;;
    *)
      printf '%s\n' "$line" >> "$DIRTY_TMP" ;;
  esac
done

DIRTY=$(cat "$DIRTY_TMP")
GHOST=$(cat "$GHOST_TMP")
UNTRACKED=$(git status --porcelain | grep '^??' || true)

if [ -n "$GHOST" ]; then
  warn "忽略已知噪音条目（主题 gitlink，无 .gitmodules 映射）："
  echo "$GHOST" | sed 's/^/    /'
fi

if [ -n "$DIRTY" ]; then
  warn "本地有未提交的改动："
  echo "$DIRTY" | sed 's/^/    /'
  echo
  echo "  这些改动会妨碍安全拉取。请选择："
  echo "    a) 先提交:   git add -A && git commit -m '...'"
  echo "    b) 先暂存:   git stash"
  echo "    c) 丢弃改动: git checkout -- ."
  echo
  # 若改动文件与远端将要更新的文件重叠，风险更高
  err "为免冲突，已中止。处理完上面的改动后再运行本脚本。"
  exit 2
fi
ok "工作区干净（无未提交改动）"

if [ -n "$UNTRACKED" ]; then
  warn "存在未跟踪文件（不影响同步）："
  echo "$UNTRACKED" | sed 's/^/    /'
fi

# ---------------------------------------------------------------
# 3. 记录拉取前的本地提交（用于判断是否有未推送提交）
# ---------------------------------------------------------------
step "3/6 记录当前状态"

LOCAL_BEFORE=$(git rev-parse HEAD 2>/dev/null || echo "none")
LOCAL_BRANCH=$(git rev-parse --abbrev-ref HEAD)
ok "当前分支: $LOCAL_BRANCH"
ok "当前提交: ${LOCAL_BEFORE:0:8}"

# ---------------------------------------------------------------
# 4. 从 NAS 拉取
# ---------------------------------------------------------------
step "4/6 从 NAS 拉取最新内容"

if ! git fetch nas "$LOCAL_BRANCH" 2>&1 | sed 's/^/    /'; then
  err "git fetch 失败。"
  exit 1
fi
ok "fetch 完成"

REMOTE_HEAD=$(git rev-parse "nas/$LOCAL_BRANCH" 2>/dev/null || echo "none")

if [ "$REMOTE_HEAD" = "none" ]; then
  warn "NAS 上还没有 $LOCAL_BRANCH 分支（首次推送后即会出现）"
  BEHIND=0
  AHEAD=0
else
  BEHIND=$(git rev-list --count "$LOCAL_BEFORE".."$REMOTE_HEAD" 2>/dev/null || echo 0)
  AHEAD=$(git rev-list --count "$REMOTE_HEAD".."$LOCAL_BEFORE" 2>/dev/null || echo 0)

  if [ "$BEHIND" -eq 0 ] && [ "$AHEAD" -eq 0 ]; then
    ok "已是最新，无需拉取（NAS 与本机一致）"
  elif [ "$BEHIND" -gt 0 ] && [ "$AHEAD" -eq 0 ]; then
    echo "    NAS 领先 $BEHIND 个提交，正在快进合并..."
    if git merge --ff-only "nas/$LOCAL_BRANCH" 2>&1 | sed 's/^/    /'; then
      ok "已更新到 NAS 最新版本（快进 $BEHIND 个提交）"
    else
      err "快进合并失败。"
      exit 2
    fi
  elif [ "$BEHIND" -eq 0 ] && [ "$AHEAD" -gt 0 ]; then
    warn "本机领先 NAS $AHEAD 个提交（有未推送的内容）"
    echo "    建议编辑完成后运行 ./deploy.sh 推送。"
  else
    # 双向分叉：本机与 NAS 各有独立提交 —— 这正是版本混乱的典型症状
    warn "分叉！本机领先 $AHEAD 个，NAS 领先 $BEHIND 个。"
    echo "    正在以 rebase 方式把本机提交叠到 NAS 之上..."
    if git pull --rebase nas "$LOCAL_BRANCH" 2>&1 | sed 's/^/    /'; then
      ok "rebase 成功，已合并双方内容"
    else
      err "rebase 出现冲突，需手工解决："
      echo "      1) 编辑冲突文件"
      echo "      2) git add <文件>"
      echo "      3) git rebase --continue"
      exit 2
    fi
  fi
fi

# ---------------------------------------------------------------
# 5. 同步其他 remote（GitHub/Gitee，作为异地备份，失败不阻断）
# ---------------------------------------------------------------
step "5/6 同步异地备份（GitHub / Gitee）"

for r in origin gitee; do
  if ! git remote | grep -qx "$r"; then continue; fi
  if git fetch "$r" "$LOCAL_BRANCH" >/dev/null 2>&1; then
    RB=$(git rev-list --count "HEAD..$r/$LOCAL_BRANCH" 2>/dev/null || echo 0)
    if [ "$RB" -gt 0 ]; then
      warn "$r 领先本机 $RB 个提交（可能是别的机器推的）"
      echo "    如需合并: git merge $r/$LOCAL_BRANCH"
    else
      ok "$r 已同步"
    fi
  else
    warn "$r 不可达（不影响本次同步）"
  fi
done

# ---------------------------------------------------------------
# 6. 最终状态汇总
# ---------------------------------------------------------------
step "6/6 汇总"

echo "  分支:     $LOCAL_BRANCH"
echo "  提交:     $(git rev-parse --short HEAD)  $(git log -1 --format='%s')"
echo "  时间:     $(git log -1 --format='%ci')"
echo

PENDING=$(git rev-list --count "nas/$LOCAL_BRANCH"..HEAD 2>/dev/null || echo 0)
if [ "$PENDING" -gt 0 ]; then
  warn "本机有 $PENDING 个提交尚未推送到 NAS"
  echo
  echo "${GREEN}${BOLD}可以开始编辑。${RESET}（编辑完记得跑 ./deploy.sh 推送）"
  exit 3
else
  echo "${GREEN}${BOLD}✓ 同步完成，可以开始编辑了。${RESET}"
  echo "  编辑完成后运行 ./deploy.sh 提交并发布。"
  exit 0
fi
