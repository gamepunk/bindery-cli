# bindery

把 Markdown 公版书批量构建为 EPUB 的项目脚手架工具。

- `bindery init` 在当前目录初始化项目
- `bindery new book <书名>` 新建一本书（ID 自动生成）
- `bindery build` 调用 [Pandoc](https://pandoc.org) 批量构建 EPUB
- `bindery validate` / `clean` / `watch` / `serve` / `status` 管理书籍与产物
- `bindery web` 打开 Web 封面生成器（自动填充书籍信息）

仅依赖 Ruby 标准库，不引入任何第三方 gem。

## 安装

```bash
gem install bindery-cli
```

系统需要另外安装 Pandoc：

```bash
# Debian/Ubuntu
apt-get install -y pandoc

# macOS
brew install pandoc
```

## 快速开始

```bash
# 1. 创建并进入项目目录
mkdir my-books
cd my-books

# 2. 就地初始化项目
bindery init

# 3. 新建一本书（ID 自动生成，可 --id 指定；--cover 自动生成封面）
#    也可以一步到位建好章节：bindery new book "论语" chapter 20 --author "孔子及弟子"
#    （N = 正文章节数，封面/目录由构建自动生成）
bindery new book "论语" --author "孔子及弟子" --dynasty "先秦" --translator "译者甲" --isbn "9781234567890" --cover

# 4. （可选）卷式结构：卷由标题层级定义（h2=卷名，h3=章名），每卷在 EPUB 中独立成页
bindery new volume <id> "学而" --chapters 5
bindery new volume <id> "为政" --chapters 5

# 5. 编辑 books/<id>/chapters/ 下的章节文件
#    （可选）单独批量创建章节：bindery new chapter <id> 10
#    （可选）按标题自动重命名章节：bindery rename chapters <id>
#    （可选）单独生成封面：bindery cover <id>

# 6. 构建 EPUB
bindery build --all

# 构建前校验（不实际构建）
bindery validate --all
bindery build --all --check

# 构建后用 epubcheck 校验
bindery build --all --epubcheck

# 查看书籍状态
bindery status

# 监听书籍目录，改动自动重建
bindery watch

# 本地启动书库站点
bindery serve

# 打开 Web 封面生成器（自动填充书籍信息）
bindery web

# 清理构建产物
bindery clean --all
```

## 项目结构

```
my-books/
├── config/bindery.yml     # 项目标记文件，不要删除
├── books/                 # 每本书一个子目录（ID 即目录名）
│   └── <id>/
│       ├── metadata.yaml  # 书籍元信息
│       ├── cover.png      # 封面（可选，bindery cover 自动生成）
│       └── chapters/      # 平铺 Markdown，卷结构由标题层级定义（## 卷名 / ### 章名）
│           ├── 01-chapter.md
│           ├── 卷01-学而.md
│           └── 卷02-为政.md
├── templates/style.css    # 全项目共用的 EPUB 样式
├── output/epub/           # 构建产物
└── books.json             # 自动生成的书目索引
```

## 开发

```bash
# 运行本地版本
ruby -Ilib exe/bindery --help

# 构建 gem
gem build bindery.gemspec
```

## License

MIT
