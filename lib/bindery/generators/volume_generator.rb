require "fileutils"
require_relative "base"

module Bindery
  module Generators
    # bindery new volume <book-id> <卷名> [--chapters N]
    # 在书籍下创建一个平铺卷文件（卷01-学而.md），卷结构由标题层级定义：
    #   ## 卷名（h2）
    #   ### 第1章（h3）
    class VolumeGenerator < Base
      def self.call(book_id, volume_name, chapters: 0, project_root: Project.root!)
        book = Bindery::Book.find(book_id, project_root)
        volume_name = volume_name.to_s.strip
        raise Bindery::Error, "卷名不能为空" if volume_name.empty?

        chapters_dir = book.chapters_dir
        FileUtils.mkdir_p(chapters_dir) unless chapters_dir.directory?

        n = next_volume_number(chapters_dir)
        file = chapters_dir + format("卷%02d-%s.md", n, volume_name)
        raise Bindery::Error, "卷文件已存在: #{file}" if file.exist?

        chapters = chapters.to_i
        raise Bindery::Error, "章节数必须是正整数" if chapters.negative?

        content = +"## #{volume_name}\n\n"
        chapters.times do |i|
          content << "### 第#{i + 1}章\n\n"
        end
        file.write(content)

        puts "创建卷: #{volume_name}"
        say_rel(file)
        puts ""
        summary = chapters.positive? ? "，含 #{chapters} 章" : ""
        puts "完成！已创建卷 #{format('%02d', n)}（#{volume_name}）#{summary}"
      end

      def self.next_volume_number(chapters_dir)
        max = 0
        return max + 1 unless chapters_dir.directory?

        chapters_dir.children.each do |f|
          next unless f.file? && f.extname == ".md"

          m = f.basename.to_s[/\A卷(\d+)/, 1]
          max = m.to_i if m && m.to_i > max
        end
        max + 1
      end

      def self.say_rel(path, trailing: "")
        rel = begin
          path.relative_path_from(Pathname.pwd)
        rescue StandardError
          path
        end
        puts "  create  #{rel}#{trailing}"
      end
    end
  end
end
