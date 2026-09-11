# bindery

把 Markdown 公版书批量构建为 EPUB 的项目脚手架工具。

- `bindery new <项目名>` 创建整套项目结构
- `bindery generate book <id> <书名>` 为单本书生成骨架
- `bindery build` 调用 [Pandoc](https://pandoc.org) 批量构建 EPUB

仅依赖 Ruby 标准库，不引入任何第三方 gem。

## 安装

```bash
gem install bindery
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
# 1. 创建项目
bindery new my-books
cd my-books

# 2. 新建一本书
bindery generate book lunyu "论语" --author "孔子及弟子" --dynasty "先秦"

# 3. 编辑 books/lunyu/chapters/ 下的章节文件

# 4. 构建 EPUB
bindery build lunyu

# 批量构建所有书
bindery build --all

# 查看书籍状态
bindery status
```

## 项目结构

```
my-books/
├── config/bindery.yml     # 项目标记文件，不要删除
├── books/                 # 每本书一个子目录
│   └── <id>/
│       ├── metadata.yaml  # 书籍元信息
│       ├── cover.jpg      # 封面（可选）
│       └── chapters/      # Markdown 章节，按文件名排序合并
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
