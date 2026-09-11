require "yaml"

module Bindery
  # 构建前校验：检查一本书是否具备构建条件
  module Validator
    module_function

    # 硬性问题（会导致构建失败），返回字符串数组，空数组表示通过
    def check(book, project_root: Project.root!)
      issues = []

      if book.metadata_file.file?
        begin
          meta = book.metadata
          issues << "metadata.yaml 缺少 title" if meta["title"].to_s.strip.empty?
        rescue Psych::SyntaxError, Bindery::Error => e
          issues << "metadata.yaml 解析失败: #{e.message}"
        end
      else
        issues << "缺少 metadata.yaml"
      end

      issues << "chapters/ 目录下没有任何 .md 文件" if book.chapters.empty?
      issues << "未安装 pandoc（构建前请先安装）" unless pandoc_installed?

      issues
    end

    # 软性警告（不影响构建，但建议修正），返回字符串数组
    def warnings(book, project_root: Project.root!)
      warns = []

      cover = book.cover_path
      if cover.nil?
        warns << "缺少封面（可在书籍目录放置 cover.jpg）"
      else
        dims = Bindery::Image.dimensions(cover)
        if dims.nil?
          warns << "封面不是有效的 JPEG/PNG 图片"
        elsif dims[0] < 600 || dims[1] < 800
          warns << "封面尺寸偏小（#{dims[0]}×#{dims[1]}，建议至少 600×800）"
        end
      end

      warns
    end

    def pandoc_installed?
      system("pandoc", "--version", out: File::NULL, err: File::NULL)
    end
  end
end
