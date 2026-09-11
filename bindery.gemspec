require_relative "lib/bindery/version"

Gem::Specification.new do |spec|
  spec.name          = "bindery-cli"
  spec.version       = Bindery::VERSION
  spec.authors        = ["Billow Wang"]
  spec.summary       = "把 Markdown 公版书批量构建为 EPUB 的项目脚手架工具"
  spec.description   = <<~DESC
    bindery 是脚手架工具：
    `bindery init` 在当前目录初始化项目，
    `bindery new book` 为单本书生成骨架（ID 自动生成），
    `bindery build` 调用 Pandoc 批量构建 EPUB。
    仅依赖 Ruby 标准库，不引入任何第三方 gem。
  DESC
  spec.license       = "MIT"
  spec.homepage      = "https://github.com/gamepunk/bindery-cli"
  spec.metadata      = {
    "source_code_uri"      => spec.homepage,
    "rubygems_mfa_required" => "true",
  }
  spec.required_ruby_version = ">= 3.0"

  spec.files         = Dir["lib/**/*", "exe/*", "README.md", "LICENSE"]
  spec.bindir        = "exe"
  spec.executables   = ["bindery"]
  spec.require_paths = ["lib"]

  # 有意不添加任何 runtime_dependency —— 全部使用 Ruby 标准库
  # （YAML: 标准库 Psych / CLI: 标准库 OptionParser / 模板: 标准库 ERB）
end
