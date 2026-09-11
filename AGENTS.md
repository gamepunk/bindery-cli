# Project Guidelines

`bindery-cli` 是一个 Ruby gem：把 Markdown 公版书批量构建为 EPUB 的脚手架 CLI，调用 Pandoc。纯 Ruby 标准库实现，无第三方 gem。

## 代码风格

- 代码注释与 CLI 面向用户的提示信息用中文。
- 类/方法沿用既有命名与结构，风格参考 `lib/bindery/` 下的现有代码。
- 所有模块挂在 `Bindery` 命名空间下，`lib/bindery.rb` 统一 require。

## 架构

- `lib/bindery/cli.rb`：OptionParser 解析子命令（init / new book / build / clean / validate / watch / serve / status / version / help）并分发。
- `lib/bindery/project.rb`：从任意子目录向上定位项目根（含 `config/bindery.yml`）。
- `lib/bindery/book.rb`：建模 `books/<id>/`，读取 metadata.yaml 与 chapters/\*.md。
- `lib/bindery/builder.rb`：合并章节并调用 `pandoc` 构建 EPUB。
- `lib/bindery/index.rb`：重建 `books.json` 索引。
- `lib/bindery/generators/`：`Base` 提供 ERB 模板渲染，`ProjectGenerator` / `BookGenerator` 生成骨架。
- `lib/bindery/errors.rb`：`Bindery::Error` 及子类。

## 构建与测试

- 测试：`rake test`（minitest）
- 本地运行：`ruby -Ilib exe/bindery --help`
- 构建 gem：`gem build bindery.gemspec`

## 约定

- 仅用 Ruby 标准库，**不得**新增第三方 gem 依赖；`bindery.gemspec` 保持零 `runtime_dependency`。
- 兼容 Ruby >= 3.0。
- 错误用 `Bindery::Error` 及子类表达，在 `cli.rb` 顶层统一 rescue。
- 不擅自改动 `lib/bindery/version.rb`，除非用户明确要求发版。
