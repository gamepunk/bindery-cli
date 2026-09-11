require "securerandom"
require_relative "base"

module Bindery
  module Generators
    # bindery new book <title> [--author] [--dynasty] [--category] [--translator] [--isbn] [--id]
    class BookGenerator < Base
      # 根据书名自动生成书籍 ID（目录名）：英文/数字转 slug，纯中文等回退为随机 ID
      def self.auto_id(title)
        slug = title.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
        slug.empty? ? "book-#{SecureRandom.hex(4)}" : slug
      end

      def self.call(id, title, author:, dynasty:, category:, translator: "", isbn: "", project_root: Project.root!)
        dest = Project.books_dir(project_root) + id
        raise Bindery::Error, "书籍目录已存在: #{dest}" if dest.exist?

        config = Project.config(project_root)
        puts "创建书籍: #{id}"
        new(dest).generate(
          id: id, title: title, author: author, dynasty: dynasty, category: category,
          translator: translator, isbn: isbn,
          lang: config["lang"] || "zh-CN",
          publisher: config["publisher"] || "再读经典",
          rights: config["rights"] || "公共领域"
        )
        Bindery::Index.rebuild(project_root)
        puts ""
        puts "完成！接下来编辑 #{dest}/chapters/ 下的章节文件，然后："
        puts "  bindery build #{id}"
      end

      def generate(id:, title:, author:, dynasty:, category:, translator:, isbn:, lang:, publisher:, rights:)
        empty_directory("chapters")

        template("book", "metadata.yaml", locals: {
          id: id, title: title, author: author, dynasty: dynasty, category: category,
          translator: translator, isbn: isbn,
          lang: lang, publisher: publisher, rights: rights,
        })
        template("book", "chapters/chapter-0001.md", locals: { title: title })
      end
    end
  end
end
