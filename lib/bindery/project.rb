require "pathname"

module Bindery
  # 负责在目录树中定位 bindery 项目根目录（含 config/bindery.yml 标记文件的目录）
  # 用法和 Rails / Bundler 一样：在项目内任意子目录执行命令都能定位到项目根
  module Project
    MARKER = "config/bindery.yml"

    module_function

    def root(start_dir = Dir.pwd)
      dir = Pathname.new(start_dir).expand_path
      loop do
        return dir if (dir + MARKER).file?
        return nil if dir.root?
        dir = dir.parent
      end
    end

    def root!(start_dir = Dir.pwd)
      root(start_dir) || raise(
        Bindery::ProjectNotFoundError,
        "找不到 bindery 项目（未发现 #{MARKER}）。请在项目目录内执行，" \
        "或先用 `bindery new <项目名>` 创建一个新项目。"
      )
    end

    def books_dir(project_root = root!)
      project_root + "books"
    end

    def templates_dir(project_root = root!)
      project_root + "templates"
    end

    def output_dir(project_root = root!)
      project_root + "output"
    end

    def index_file(project_root = root!)
      project_root + "books.json"
    end
  end
end
