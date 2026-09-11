require "yaml"
require "pathname"

module Bindery
  # 代表一本书：对应 books/<id>/ 目录
  class Book
    attr_reader :id, :dir

    def initialize(dir)
      @dir = Pathname.new(dir)
      @id = @dir.basename.to_s
    end

    def self.all(project_root = Project.root!)
      books_dir = Project.books_dir(project_root)
      return [] unless books_dir.directory?

      books_dir.children.select(&:directory?).sort.map { |d| new(d) }
    end

    def self.find(id, project_root = Project.root!)
      dir = Project.books_dir(project_root) + id
      raise Bindery::BookNotFoundError, "找不到书籍: #{id}（#{dir} 不存在）" unless dir.directory?

      new(dir)
    end

    def metadata_file
      dir + "metadata.yaml"
    end

    def metadata
      raise Bindery::Error, "缺少 metadata.yaml: #{metadata_file}" unless metadata_file.file?

      @metadata ||= YAML.safe_load(metadata_file.read, permitted_classes: [Symbol]) || {}
    end

    def title
      metadata["title"] || id
    rescue Bindery::Error
      id
    end

    def author
      metadata["author"] || "佚名"
    rescue Bindery::Error
      "佚名"
    end

    def cover_path
      name = metadata["cover"] || "cover.jpg"
      path = dir + name
      path.file? ? path : nil
    end

    def chapters_dir
      dir + "chapters"
    end

    # 平铺的章节文件（直接在 chapters/ 下，按文件名排序）
    def chapters
      return [] unless chapters_dir.directory?

      chapters_dir.children.select { |f| f.file? && f.extname == ".md" }.sort
    end

    def valid?
      metadata_file.file? && chapters.any?
    end

    def epub_output(project_root = Project.root!)
      Project.output_dir(project_root) + "epub" + "#{id}.epub"
    end

    def built?(project_root = Project.root!)
      epub_output(project_root).file?
    end

    def cover?
      !cover_path.nil?
    end

    def built_at(project_root = Project.root!)
      path = epub_output(project_root)
      path.file? ? path.mtime : nil
    end
  end
end
