---
description: "为 bindery-cli 新增一个 CLI 子命令（含 OptionParser 参数解析与 minitest 测试）。Use when 添加/扩展 bindery 命令。"
name: "新增 CLI 子命令"
argument-hint: "子命令名与行为，例如：bindery clean 清理 output/epub"
agent: "bindery-dev"
---

为 `bindery-cli` 新增一个 CLI 子命令，行为由用户描述决定。

## 要求

- 在 `lib/bindery/cli.rb` 的 `run` 中用 `case` 分发新命令，并在 `private` 区实现对应的 `cmd_*` 方法。
- 参数解析使用标准库 `OptionParser`，风格与现有 `cmd_new_book` / `cmd_build` 保持一致。
- 面向用户的提示信息用中文，完成/错误提示沿用现有文案风格。
- 如涉及业务逻辑，优先复用 `Project` / `Book` / `Builder` / `Index` 现有能力。
- 在 `spec/` 下补充对应测试，沿用 minitest 风格（参考现有 spec）。
- 不新增第三方 gem，不修改 `lib/bindery/version.rb`。

## 完成后

- 运行 `rake test`，确保全部通过。
- 必要时用 `ruby -Ilib exe/bindery <新命令> --help` 手工验证 CLI 行为。
