# oldvan

Hugo + PaperMod 博客，自动部署到 GitHub Pages。

## 本地预览

```bash
git submodule update --init --recursive
hugo server
```

## 新建文章

```bash
hugo new content posts/your-post-title.md
```

默认 `draft = false`，提交到 `main` 后会自动发布。

## 批量导入现有文章

目录规范：

- `imports/inbox/`：放待导入的原稿（支持 `.md`、`.markdown`、`.txt`，可分子目录）
- `imports/done/`：导入后自动归档原稿
- `content/posts/YYYY-MM/`：脚本自动生成的 Hugo 文章目录

导入命令：

```bash
python3 scripts/import_posts.py
```

先预览不落盘：

```bash
python3 scripts/import_posts.py --dry-run
```

不移动原稿（仅复制导入）：

```bash
python3 scripts/import_posts.py --no-archive
```

说明：

- 有 Front Matter 的 Markdown 会原样保留
- 无 Front Matter 的文件会自动补：`title`、`date`、`draft=false`、`tags=["导入"]`
- 同名文件会自动追加后缀避免覆盖
