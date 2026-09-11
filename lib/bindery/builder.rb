require "open3"
require "yaml"
require "fileutils"
require "tmpdir"
require "pathname"

module Bindery
  # 负责把一本书的多个章节 md 文件合并，并调用 Pandoc 生成 EPUB
  class Builder
    class BuildError < Bindery::Error; end

    def initialize(book, project_root: Project.root!)
      @book = book
      @project_root = project_root
    end

    # 返回 true/false 表示是否成功；详细错误信息可通过 #last_error 获取
    def build_epub
      chapters = @book.chapters
      if chapters.empty?
        @last_error = "#{@book.id} 的 chapters/ 目录下没有任何 .md 文件"
        return false
      end

      ensure_pandoc!

      Dir.mktmpdir("bindery-#{@book.id}-") do |tmp|
        merged = merge_chapters(chapters, tmp)
        meta_file = write_pandoc_metadata(tmp)

        out_dir = Project.output_dir(@project_root) + "epub"
        FileUtils.mkdir_p(out_dir)
        out_path = out_dir + "#{@book.id}.epub"

        cmd = ["pandoc", merged.to_s, "-o", out_path.to_s,
               "--metadata-file", meta_file.to_s, "--toc"]

        css = Project.templates_dir(@project_root) + "style.css"
        cmd += ["--css", css.to_s] if css.file?

        cover = @book.cover_path
        cmd += ["--epub-cover-image", cover.to_s] if cover

        run(cmd)
      end
    rescue BuildError => e
      @last_error = e.message
      false
    end

    def last_error
      @last_error
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

    def write_pandoc_metadata(tmp_dir)
      meta = @book.metadata
      pandoc_meta = {
        "title"     => meta["title"] || @book.id,
        "author"    => meta["author"] || "佚名",
        "lang"      => meta["lang"] || "zh-CN",
        "rights"    => meta["rights"] || "公共领域",
        "publisher" => meta["publisher"] || "再读经典",
      }
      pandoc_meta["date"] = meta["dynasty"] if meta["dynasty"] && !meta["dynasty"].to_s.empty?

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
