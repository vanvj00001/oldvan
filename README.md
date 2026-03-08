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
