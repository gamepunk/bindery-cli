require_relative "base"

module Bindery
  module Generators
    # bindery generate book <id> <title> [--author] [--dynasty] [--category]
    class BookGenerator < Base
      def self.call(id, title, author:, dynasty:, category:, project_root: Project.root!)
        dest = Project.books_dir(project_root) + id
        raise Bindery::Error, "书籍目录已存在: #{dest}" if dest.exist?

        puts "创建书籍: #{id}"
        new(dest).generate(id: id, title: title, author: author, dynasty: dynasty, category: category)
        Bindery::Index.rebuild(project_root)
        puts ""
        puts "完成！接下来编辑 #{dest}/chapters/ 下的章节文件，然后："
        puts "  bindery build #{id}"
      end

      def generate(id:, title:, author:, dynasty:, category:)
        empty_directory("chapters")

        template("book", "metadata.yaml", locals: {
          id: id, title: title, author: author, dynasty: dynasty, category: category,
        })
        template("book", "chapters/01-chapter.md", locals: { title: title })
      end
    end
  end
end
