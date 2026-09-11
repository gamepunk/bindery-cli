require "fileutils"
require_relative "base"

module Bindery
  module Generators
    # bindery new volume <book-id> <卷名> [--chapters N]
    # 在书籍下创建一个卷目录（编号自动接续），可选批量创建卷内章节
    class VolumeGenerator < Base
      def self.call(book_id, volume_name, chapters: 0, project_root: Project.root!)
        book = Bindery::Book.find(book_id, project_root)
        volume_name = volume_name.to_s.strip
        raise Bindery::Error, "卷名不能为空" if volume_name.empty?

        if book.volumes.empty? && book.chapters.any?
          warn "注意：chapters/ 下已有平铺章节文件（#{book.chapters.size} 个），卷式书构建时会忽略它们"
        end

        chapters_dir = book.chapters_dir
        FileUtils.mkdir_p(chapters_dir) unless chapters_dir.directory?

        n = next_volume_number(chapters_dir)
        vol_dir = chapters_dir + format("%02d-%s", n, volume_name)
        raise Bindery::Error, "卷目录已存在: #{vol_dir}" if vol_dir.exist?

        chapters = chapters.to_i
        raise Bindery::Error, "章节数必须是正整数" if chapters.negative?

        FileUtils.mkdir_p(vol_dir)
        puts "创建卷: #{volume_name}"
        say_rel(vol_dir, trailing: "/")

        chapters.times do |i|
          file = vol_dir + format("%02d.md", i + 1)
          file.write("# 第#{i + 1}章\n\n")
          say_rel(file)
        end

        puts ""
        summary = chapters.positive? ? "，含 #{chapters} 章" : ""
        puts "完成！已创建卷 #{format('%02d', n)}（#{volume_name}）#{summary}"
      end

      def self.next_volume_number(chapters_dir)
        max = 0
        if chapters_dir.directory?
          chapters_dir.children.each do |d|
            next unless d.directory?

            m = d.basename.to_s[/\A(\d+)/, 1]
            max = m.to_i if m && m.to_i > max
          end
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
