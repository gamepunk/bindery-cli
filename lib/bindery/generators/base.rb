require "erb"
require "fileutils"
require "pathname"

module Bindery
  module Generators
    # 所有生成器的基类：提供"渲染ERB模板 -> 写入目标文件"的公共能力
    # 风格类似 Rails::Generators::Base，但不依赖 Thor / Rails，纯标准库实现
    class Base
      TEMPLATES_ROOT = Pathname.new(__dir__) + "templates"

      class << self
        attr_reader :log_lines
      end

      def initialize(destination)
        @destination = Pathname.new(destination)
      end

      private

      # 把 templates/<template_dir>/foo.erb 渲染后写到 destination 下的 foo
      def template(template_dir, relative_path, locals: {})
        src = TEMPLATES_ROOT + template_dir + "#{relative_path}.erb"
        dest = @destination + relative_path
        render_and_write(src, dest, locals)
      end

      # 直接复制一个非模板文件（比如 .gitignore、style.css）
      def copy_file(template_dir, relative_path, dest_relative_path = relative_path)
        src = TEMPLATES_ROOT + template_dir + relative_path
        dest = @destination + dest_relative_path
        FileUtils.mkdir_p(dest.dirname)
        FileUtils.cp(src, dest)
        say "create", dest
      end

      def empty_directory(relative_path)
        dest = @destination + relative_path
        FileUtils.mkdir_p(dest)
        say "create", "#{dest}/"
      end

      def render_and_write(src, dest, locals)
        FileUtils.mkdir_p(dest.dirname)
        content = ERB.new(src.read, trim_mode: "-").result(binding_for(locals))
        dest.write(content)
        say "create", dest
      end

      def binding_for(locals)
        b = binding
        locals.each { |k, v| b.local_variable_set(k, v) }
        b
      end

      def say(action, path)
        rel = Pathname.new(path).relative_path_from(Pathname.pwd) rescue path
        puts "  #{action.rjust(8)}  #{rel}"
      end
    end
  end
end
