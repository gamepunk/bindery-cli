require "fileutils"
require_relative "base"

module Bindery
  module Generators
    # bindery new chapter <book-id> <数量>
    # 在指定书籍里批量创建章节文件，编号自动接续已有章节（chapter-0001.md 之后是 chapter-0002.md…）
    class ChapterGenerator < Base
      def self.call(book_id, count, project_root: Project.root!)
        book = Bindery::Book.find(book_id, project_root)
        count = count.to_i
        raise Bindery::Error, "章节数量必须是正整数" unless count.positive?

        chapters_dir = book.chapters_dir
        FileUtils.mkdir_p(chapters_dir) unless chapters_dir.directory?

        start = next_number(chapters_dir)
        puts "创建章节: #{book.id}"
        count.times do |i|
          n = start + i
          file = chapters_dir + format("chapter-%04d.md", n)
          file.write("### 第#{n}章\n\n")
          rel = begin
            file.relative_path_from(Pathname.pwd)
          rescue StandardError
            file
          end
          puts "  create  #{rel}"
        end
        puts ""
        puts "完成！已创建 #{count} 个章节（从第 #{start} 章开始）"
      end

      # 扫描已有章节文件名中的编号（chapter-0001），返回下一个可用编号
      def self.next_number(chapters_dir)
        max = 0
        return max + 1 unless chapters_dir.directory?

        chapters_dir.children.each do |f|
          next unless f.file? && f.extname == ".md"

          n = f.basename.to_s[/\Achapter-(\d+)/, 1]
          max = n.to_i if n && n.to_i > max
        end
        max + 1
      end
    end
  end
end
