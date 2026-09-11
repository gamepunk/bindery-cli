require "fileutils"
require_relative "base"

module Bindery
  module Generators
    # bindery new chapter <book-id> <数量>
    # 在指定书籍里批量创建章节文件，编号自动接续已有章节（01-chapter.md 之后是 02-chapter.md…）
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
          file = chapters_dir + format("%02d-chapter.md", n)
          file.write("# 第#{n}章\n\n")
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

      # 扫描已有章节文件名开头的数字，返回下一个可用编号
      def self.next_number(chapters_dir)
        max = 0
        return max + 1 unless chapters_dir.directory?

        chapters_dir.children.each do |f|
          next unless f.file? && f.extname == ".md"

          n = f.basename.to_s[/\A(\d+)/, 1].to_i
          max = n if n > max
        end
        max + 1
      end
    end
  end
end
