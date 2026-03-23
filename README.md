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

## 阅读量接口

当前主题里的文章阅读量会请求同域接口 `/api/page-views`。

如果暂时无法把 Worker 直接挂到 `oldvan.top/api/page-views`，也可以先把
`params.pageViews.endpoint` 指向一个 `workers.dev` 地址。

Cloudflare 侧需要额外配置一个 Worker 和一个 D1 数据库：

1. 创建 D1 数据库，例如 `oldvan-page-views`
2. 执行 [workers/page-views.schema.sql](/Users/fanweijun/oldvan/workers/page-views.schema.sql)
3. 复制 [wrangler.page-views.toml.example](/Users/fanweijun/oldvan/wrangler.page-views.toml.example) 为本地 `wrangler.toml`
4. 把 `database_id` 改成真实的 D1 Database ID
5. 部署 [workers/page-views.js](/Users/fanweijun/oldvan/workers/page-views.js) 到路由 `oldvan.top/api/page-views`

接口职责：

- 文章详情页调用 `mode=hit`，浏览量加一
- 首页/归档页调用 `mode=get`，只读取，不加一

计数键规则：

- 默认优先使用文章源文件路径生成 key，不再直接依赖 `RelPermalink`
- 如果你希望某篇文章在将来改路径、改文件名后仍保留同一计数，可以在 Front Matter 里手动加 `pageViewsKey`
- 当前前端在接口异常时会显示 `--`，避免把临时故障误看成“清零”

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
- 无 Front Matter 的文件会自动补：`title`、`url`、`pageViewsKey`、`date`、`draft=false`、`tags=["导入"]`
- 同名文件会自动追加后缀避免覆盖




---
• 已配置好并推送到仓库。

  本次新增：

  - 批量导入脚本：scripts/import_posts.py
  - 导入目录规范：
      - imports/inbox/.gitkeep（放待导入原稿）
      - imports/done/.gitkeep（导入后归档）
  - 使用说明更新：README.md

  已验证：

  - 脚本 dry-run 和实际导入流程可用
  - hugo --minify 构建通过

  你现在直接这样用：

  cd /Users/fanweijun/oldvan
  python3 scripts/import_posts.py --dry-run
  python3 scripts/import_posts.py
  git add .
  git commit -m "Import articles"
  git push

  说明：

  - 支持 .md/.markdown/.txt（递归扫描 imports/inbox/）
  - 无 front matter 会自动补 title/date/draft=false/tags=["导入"]
  - 目标目录自动按 content/posts/YYYY-MM/ 归档
  - 同名文件自动防覆盖（追加 -2/-3）
  - 默认导入后会把原稿移动到 imports/done/（可用 --no-archive 关闭）

---
好，流程已经闭环了。接下来你每周只要重复这 4 步：

  cd /Users/fanweijun/oldvan
  python3 scripts/import_posts.py
  git add .
  git commit -m "Import weekly posts"
  git push
