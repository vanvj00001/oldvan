# oldvan 多笔记本同步说明

解决"多台笔记本各自提交造成版本混乱"的问题。

## 核心机制

**233 NAS 上的裸仓库是唯一权威源**，所有机器都以它为准：

```
        ┌──────────────────────────────┐
        │  233 NAS (权威源)             │
        │  /vol1/1000/代码/oldvan.git   │
        │      (裸仓库 bare)            │
        └───────────┬──────────────────┘
                    │
        ┌───────────┼───────────┬─────────────┐
        │           │           │             │
    笔记本A      笔记本B      笔记本C      GitHub/Gitee
                                            (异地备份)
```

- **NAS** = 家里那台 233，局域网走 `192.168.2.233`，在外走 Tailscale `100.66.233.2`，脚本自动切换
- **GitHub / Gitee** = 异地容灾备份，NAS 挂了还有一份

## 日常使用（两个命令）

### 1. 开始编辑前 —— 先同步

```bash
cd /Users/fanweijun/project/oldvan
./sync-pull.sh
```

它会：
- 探测 NAS（局域网优先，自动回退 Tailscale）
- 检查有没有未提交的改动（有就中止，防止冲突）
- 从 NAS 拉取最新，自动处理分叉（rebase）
- 汇总提示

**看到 `✓ 同步完成，可以开始编辑了` 就可以动手写文章了。**

### 2. 写完发布 —— 一条命令

```bash
./deploy.sh
```

它会自动：
- **提交前先从 NAS 拉取并 rebase**（关键：消除分叉）
- 提交 → 推 NAS（权威源）
- 推 GitHub / Gitee（异地备份）
- 构建 Hugo、发布到 GitHub Pages / Cloudflare / 阿里云 / NAS

**NAS 推送失败会直接中止**，不会再出现"本地以为发布了、实际没同步"的情况。

## 退出码说明（sync-pull.sh）

| 码 | 含义 | 怎么办 |
|---|---|---|
| 0 | 同步完成，可以编辑 | 直接开始写 |
| 1 | 连不上 NAS | 检查网络 / Tailscale |
| 2 | 有未提交改动或冲突 | 按提示 commit / stash / 解冲突 |
| 3 | 本机有未推送提交 | 可编辑，完事记得跑 deploy.sh |

## 出问题怎么办

### 显示"分叉"
正常，脚本会自动 rebase 处理。若提示冲突：
```bash
git status                    # 看哪些文件冲突
# 手动编辑冲突文件
git add <文件>
git rebase --continue
./deploy.sh                   # 重新跑
```

### 想放弃这次 rebase
```bash
git rebase --abort
```

### 完全搞乱了，想回到某个状态
```bash
git reflog                    # 看历史操作
git reset --hard <哈希>
```

## 技术备注

- NAS 裸仓库路径：`/vol1/1000/代码/oldvan.git`
- **旧的 `/vol1/1000/代码/oldvan`（非裸仓库）已废弃**，那是 2026-06 的遗留副本，不要再往里推
- `themes/ananke` 是历史遗留的 gitlink（无 `.gitmodules`），脚本会自动忽略这个噪音条目
- 脚本用 `PIPESTATUS[0]` 判断 git 退出码——用管道时不能直接看 `$?`，否则冲突会被误判为成功
