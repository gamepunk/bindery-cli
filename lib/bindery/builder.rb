require "open3"
require "yaml"
require "fileutils"
require "tmpdir"
require "pathname"

module Bindery
  # 负责把一本书的多个章节 md 文件合并，并调用 Pandoc 生成 EPUB
  class Builder
    class BuildError < Bindery::Error; end

    def initialize(book, project_root: Project.root!, verbose: false)
      @book = book
      @project_root = project_root
      @verbose = verbose
    end

    # 返回 true/false 表示是否成功；详细错误信息可通过 #last_error 获取
    def build_epub
      if @book.has_volumes?
        if @book.all_chapters.empty?
          @last_error = "#{@book.id} 的卷目录下没有任何 .md 文件"
          return false
        end
      elsif @book.chapters.empty?
        @last_error = "#{@book.id} 的 chapters/ 目录下没有任何 .md 文件"
        return false
      end

      meta = @book.metadata
      ensure_pandoc!

      Dir.mktmpdir("bindery-#{@book.id}-") do |tmp|
        if @book.has_volumes?
          merged = merge_volumes(tmp)
          split_level = 2
        else
          merged = merge_chapters(@book.chapters, tmp)
          split_level = nil
        end

        meta_file = write_pandoc_metadata(tmp, meta)

        out_dir = Project.output_dir(@project_root) + "epub"
        FileUtils.mkdir_p(out_dir)
        out_path = out_dir + "#{@book.id}.epub"

        cmd = ["pandoc", merged.to_s, "-o", out_path.to_s,
               "--metadata-file", meta_file.to_s, "--toc"]
        cmd += ["--split-level", split_level.to_s] if split_level

        css = Project.templates_dir(@project_root) + "style.css"
        cmd += ["--css", css.to_s] if css.file?

        cover = @book.cover_path
        cmd += ["--epub-cover-image", cover.to_s] if cover

        puts "  $ #{cmd.join(' ')}" if @verbose
        run(cmd)
      end
    rescue Bindery::Error => e
      @last_error = e.message
      false
    end

    def last_error
      @last_error
    end

    # 运行 epubcheck 校验单个 epub，返回 [成功?, 输出]
    def epubcheck(path)
      unless system("epubcheck", "--version", out: File::NULL, err: File::NULL)
        return [false, "未安装 epubcheck（参考 https://github.com/w3c/epubcheck/releases）"]
      end

      stdout, stderr, status = Open3.capture3("epubcheck", path.to_s)
      [status.success?, stderr.empty? ? stdout : stderr]
    end

    private

    def ensure_pandoc!
      return if system("pandoc", "--version", out: File::NULL, err: File::NULL)

      raise BuildError, "找不到 pandoc 命令，请先安装：apt-get install -y pandoc（或参考 https://pandoc.org/installing.html）"
    end

    def merge_chapters(chapters, tmp_dir)
      path = Pathname.new(tmp_dir) + "merged.md"
      path.open("w") do |out|
        chapters.each_with_index do |chapter, i|
          out.puts if i.positive?
          out.puts chapter.read
        end
      end
      path
    end

    # 卷式书：每卷生成一个 ## 卷名（h2）页，卷内章节标题降级为 h3
    def merge_volumes(tmp_dir)
      path = Pathname.new(tmp_dir) + "merged.md"
      path.open("w") do |out|
        @book.volumes.each_with_index do |vol_dir, i|
          out.puts if i.positive?
          name = vol_dir.basename.to_s.sub(/\A\d+-/, "")
          out.puts "## #{name}"
          out.puts
          @book.volume_chapters(vol_dir).each do |chapter|
            out.puts demote_headings(chapter.read, 2)
            out.puts
          end
        end
      end
      path
    end

    # 把 ATX 标题降级指定级数（跳过代码围栏内部）
    def demote_headings(text, levels)
      in_fence = false
      text.lines.map do |line|
        if line =~ /^\s*(`{3,}|~{3,})/
          in_fence = !in_fence
          line
        elsif in_fence
          line
        elsif line =~ /^(\#{1,6})(\s|$)/
          ("#" * levels) + line
        else
          line
        end
      end.join
    end

    def write_pandoc_metadata(tmp_dir, meta)
      config = Project.config(@project_root)
      pandoc_meta = {
        "title"     => meta["title"] || @book.id,
        "author"    => meta["author"] || "佚名",
        "lang"      => meta["lang"] || config["lang"] || "zh-CN",
        "rights"    => meta["rights"] || config["rights"] || "公共领域",
        "publisher" => meta["publisher"] || config["publisher"] || "再读经典",
      }
      pandoc_meta["date"] = meta["dynasty"] if meta["dynasty"] && !meta["dynasty"].to_s.empty?
      # 可选元数据：ISBN / 译者 / 分类，映射到 Pandoc 识别的字段
      pandoc_meta["identifier"] = meta["isbn"] if meta["isbn"] && !meta["isbn"].to_s.empty?
      pandoc_meta["contributor"] = meta["translator"] if meta["translator"] && !meta["translator"].to_s.empty?
      pandoc_meta["subject"] = meta["category"] if meta["category"] && !meta["category"].to_s.empty?

      path = Pathname.new(tmp_dir) + "metadata.yaml"
      path.write(pandoc_meta.to_yaml)
      path
    end

    def run(cmd)
      stdout, stderr, status = Open3.capture3(*cmd)
      if status.success?
        true
      else
        @last_error = stderr.empty? ? stdout : stderr
        false
      end
    end
  end
end
