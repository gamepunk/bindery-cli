module Bindery
  # 根据章节 md 里的首个标题，自动把文件名更新为 chapter-xxxx-标题.md
  module Renamer
    module_function

    # 返回重命名的文件数
    def rename_chapters(book)
      dir = book.chapters_dir
      return 0 unless dir.directory?

      renamed = 0
      dir.children.select { |f| f.file? && f.extname == ".md" }.sort.each do |f|
        base = f.basename.to_s
        m = base.match(/\A(chapter-\d+)(?:-.*)?\.md\z/)
        next unless m

        title = extract_title(f)
        next if title.nil? || title.empty?

        safe = sanitize(title)
        new_name = "#{m[1]}-#{safe}.md"
        next if new_name == base

        new_path = f.dirname + new_name
        raise Bindery::Error, "目标文件已存在: #{new_path}" if new_path.exist?

        File.rename(f, new_path)
        renamed += 1
        puts "  rename  #{base} -> #{new_name}"
      end
      renamed
    end

    # 取文件里的首个 ATX 标题文本
    def extract_title(path)
      path.each_line do |line|
        next unless line =~ /^(\#{1,6})\s+(.+)$/

        title = Regexp.last_match(2).sub(/\s*#+\s*$/, "").strip
        return title unless title.empty?
      end
      nil
    end

    # 清理标题里的非法文件名字符，跨平台安全（Windows 也兼容）
    def sanitize(text)
      s = text
        .gsub(/[\\\/:*?"<>|\r\n\t]/, "-")
        .gsub(/\s+/, "-")
        .gsub(/-+/, "-")
        .gsub(/\A-+|-\z/, "")
        .gsub(/\A\.+|\.+\z/, "")
      s = "章节" if s.empty?
      s[0, 40]
    end
  end
end
