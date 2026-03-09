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
---


 以后回滚到这个点可用：

  git checkout snapshot-20260308-125622

  或把 main 回到该点并推送：

  git checkout main
  git reset --hard snapshot-20260308-125622
  git push -f origin main



  ---

  腾讯域名购买
  下一步，您可以：
1. 核对域名实名信息：登录 域名注册管理控制台，确认域名是否已经完成实名认证。 重要：域名注册成功后必须进行域名实名认证，否则域名会处于 ServerHold（暂停解析）状态，无法正常使用。查看详情
2. 如您需要域名解析，请前往 解析控制台，添加域名及设置对应的解析记录。查看各记录类型的设置方法
3. 域名购买成功后，需等待实名认证和命名审核结果，平均审核时长 1-2 个工作日。查看详情
4. 域名注册成功后，如需进行 ICP 备案，请等待腾讯云向工信部上报实名信息，平均等待时长 3-5 个工作日。查看详情
开发票请至费用中心 发票申请。详细操作指引参见： 发票指引。

