require "optparse"
require "fileutils"

module Bindery
  # 命令行入口：解析子命令并分发
  # 支持: init / new book / build / clean / validate / watch / serve / status / version / help
  class CLI
    def self.start(argv)
      new.run(argv)
    end

    def run(argv)
      command, *rest = argv
      case command
      when "init"
        cmd_init(rest)
      when "new"
        cmd_new(rest)
      when "build"
        cmd_build(rest)
      when "clean"
        cmd_clean(rest)
      when "validate"
        cmd_validate(rest)
      when "cover"
        cmd_cover(rest)
      when "rename"
        cmd_rename(rest)
      when "watch"
        cmd_watch(rest)
      when "serve"
        cmd_serve(rest)
      when "status"
        cmd_status(rest)
      when "version", "-v", "--version"
        puts "bindery #{Bindery::VERSION}"
      when nil, "help", "-h", "--help"
        print_help
      else
        warn "未知命令: #{command}"
        print_help
        exit 1
      end
    rescue OptionParser::ParseError => e
      warn "参数错误: #{e.message}"
      exit 1
    rescue Bindery::Error => e
      warn "错误: #{e.message}"
      exit 1
    end

    private

    # ---------- bindery init ----------
    def cmd_init(args)
      unless args.empty?
        warn "用法: bindery init（不接受参数）"
        exit 1
      end
      Generators::ProjectGenerator.call
    end

    # ---------- bindery new book|chapter|volume ... ----------
    def cmd_new(args)
      type, *rest = args
      case type
      when "book"
        cmd_new_book(rest)
      when "chapter"
        cmd_new_chapter(rest)
      when "volume"
        cmd_new_volume(rest)
      when nil
        warn "用法: bindery new book <书名> [chapter <章数>] [选项]"
        warn "      bindery new chapter <book-id> <数量>"
        warn "      bindery new volume <book-id> <卷名> [--chapters N]"
        exit 1
      else
        warn "未知的生成器类型: #{type}（支持 book / chapter / volume）"
        exit 1
      end
    end

    # ---------- bindery new chapter <book-id> <数量> ----------
    def cmd_new_chapter(args)
      book_id, count = args
      if book_id.nil? || count.nil?
        warn "用法: bindery new chapter <book-id> <数量>"
        exit 1
      end
      Generators::ChapterGenerator.call(book_id, count)
    end

    # ---------- bindery new volume <book-id> <卷名> [--chapters N] ----------
    def cmd_new_volume(args)
      options = { chapters: 0 }
      parser = OptionParser.new do |o|
        o.on("--chapters N", Integer) { |v| options[:chapters] = v }
      end
      positional = parser.parse(args)
      book_id, volume_name = positional
      if book_id.nil? || volume_name.nil?
        warn "用法: bindery new volume <book-id> <卷名> [--chapters N]"
        exit 1
      end
      Generators::VolumeGenerator.call(book_id, volume_name, chapters: options[:chapters])
    end

    # ---------- bindery cover <book-id> ----------
    def cmd_cover(args)
      id = args.first
      if id.nil?
        warn "用法: bindery cover <book-id>"
        exit 1
      end
      project_root = Project.root!
      book = Bindery::Book.find(id, project_root)
      path = Bindery::Cover.generate(book)
      puts "已生成封面: #{path}"
    end

    # ---------- bindery rename chapters <book-id> ----------
    def cmd_rename(args)
      type, book_id = args
      if type != "chapters" || book_id.nil?
        warn "用法: bindery rename chapters <book-id>"
        exit 1
      end
      project_root = Project.root!
      book = Bindery::Book.find(book_id, project_root)
      count = Bindery::Renamer.rename_chapters(book)
      puts "重命名完成：更新 #{count} 个文件"
    end

    def cmd_new_book(args)
      options = { author: "佚名", dynasty: "", category: "", translator: "", isbn: "", id: nil, cover: false }
      parser = OptionParser.new do |o|
        o.on("--author NAME") { |v| options[:author] = v }
        o.on("--dynasty NAME") { |v| options[:dynasty] = v }
        o.on("--category NAME") { |v| options[:category] = v }
        o.on("--translator NAME") { |v| options[:translator] = v }
        o.on("--isbn ISBN") { |v| options[:isbn] = v }
        o.on("--id ID") { |v| options[:id] = v }
        o.on("--cover") { options[:cover] = true }
      end
      positional = parser.parse(args)
      title = positional.first
      if title.nil? || title.empty?
        warn "用法: bindery new book <书名> [chapter <章数>] [--cover] [--author NAME] [--dynasty 朝代] [--category 分类] [--translator 译者] [--isbn ISBN] [--id ID]"
        exit 1
      end

      # 可选组合参数：bindery new book <书名> chapter <章数>
      # 语义：总共 N 章（默认已含第一章，所以再补 N-1 章）
      chapters = nil
      unless positional[1].nil?
        if positional[1] == "chapter"
          chapters = positional[2].to_i
          unless chapters.positive?
            warn "章节数必须是正整数"
            exit 1
          end
        else
          warn "未知参数: #{positional[1]}"
          exit 1
        end
      end

      id = options[:id] || Generators::BookGenerator.auto_id(title)
      Generators::BookGenerator.call(
        id, title,
        author: options[:author], dynasty: options[:dynasty], category: options[:category],
        translator: options[:translator], isbn: options[:isbn]
      )
      Generators::ChapterGenerator.call(id, chapters - 1) if chapters && chapters > 1
      Bindery::Cover.generate(Bindery::Book.find(id)) if options[:cover]
    end

    # ---------- bindery build [<id>] [--all] [--check] [--dry-run] [--verbose] ----------
    def cmd_build(args)
      options = { all: false, check: false, dry_run: false, verbose: false, epubcheck: false }
      parser = OptionParser.new do |o|
        o.on("--all") { options[:all] = true }
        o.on("--check") { options[:check] = true }
        o.on("--dry-run") { options[:dry_run] = true }
        o.on("--verbose") { options[:verbose] = true }
        o.on("--epubcheck") { options[:epubcheck] = true }
      end
      positional = parser.parse(args)

      project_root = Project.root!
      books = options[:all] ? Bindery::Book.all(project_root) : [book_from_arg(positional.first, project_root)]

      if options[:check]
        # 仅做构建前校验，不实际调用 Pandoc
        exit 1 unless check_books(books, project_root)
        return
      end

      if books.empty?
        warn "books/ 目录下没有任何书籍"
        # 即使没有书也重建索引，保证 books.json 存在（供 CI / 静态站读取）
        Index.rebuild(project_root)
        puts "" if options[:all]
        puts "完成：成功 0 本，失败 0 本" if options[:all]
        return
      end

      if options[:dry_run]
        books.each do |book|
          puts "[#{book.id}] 将构建 → #{book.epub_output(project_root)}（#{book.chapters.size} 个章节）"
        end
        return
      end

      success = 0
      failure = 0
      books.each do |book|
        builder = Builder.new(book, project_root: project_root, verbose: options[:verbose])
        if builder.build_epub
          puts "✅ [#{book.id}] epub 构建成功"
          success += 1
          if options[:epubcheck]
            ok, msg = builder.epubcheck(book.epub_output(project_root))
            if ok
              puts "   ✅ epubcheck 通过"
            else
              puts "   ⚠️ epubcheck 未通过：#{msg.lines.first&.strip}"
            end
          end
        else
          puts "❌ [#{book.id}] epub 构建失败"
          puts "   #{builder.last_error}"
          failure += 1
        end
      end

      Index.rebuild(project_root)
      puts "" if options[:all]
      puts "完成：成功 #{success} 本，失败 #{failure} 本" if options[:all]
    end

    def book_from_arg(id, project_root)
      if id.nil?
        warn "请指定书籍 id，或使用 --all 构建全部"
        exit 1
      end
      Bindery::Book.find(id, project_root)
    end

    # ---------- bindery clean [--all] ----------
    def cmd_clean(args)
      options = { all: false }
      parser = OptionParser.new do |o|
        o.on("--all") { options[:all] = true }
      end
      parser.parse(args)

      project_root = Project.root!
      epub_dir = Project.output_dir(project_root) + "epub"
      count = 0
      if epub_dir.directory?
        epub_dir.children.each do |f|
          FileUtils.rm_rf(f)
          count += 1
        end
      end

      if options[:all]
        index = Project.index_file(project_root)
        if index.file?
          index.delete
          count += 1
        end
      end

      puts "清理完成：移除 #{count} 项"
    end

    # ---------- bindery validate [<id>] [--all] ----------
    def cmd_validate(args)
      options = { all: false }
      parser = OptionParser.new do |o|
        o.on("--all") { options[:all] = true }
      end
      positional = parser.parse(args)

      project_root = Project.root!
      books = options[:all] ? Bindery::Book.all(project_root) : [book_from_arg(positional.first, project_root)]
      exit 1 unless check_books(books, project_root)
    end

    # 校验并打印结果，返回是否全部通过（供 validate 与 build --check 共用）
    def check_books(books, project_root)
      return true if books.empty?

      ok = true
      books.each do |book|
        issues = Bindery::Validator.check(book, project_root: project_root)
        warns  = Bindery::Validator.warnings(book, project_root: project_root)
        if issues.empty?
          puts "✅ [#{book.id}] 校验通过"
          warns.each { |w| puts "   ⚠️ #{w}" }
        else
          ok = false
          puts "❌ [#{book.id}] 发现问题："
          issues.each { |i| puts "   - #{i}" }
          warns.each { |w| puts "   ⚠️ #{w}" }
        end
      end
      ok
    end

    # ---------- bindery watch [--interval SECONDS] ----------
    def cmd_watch(args)
      options = { interval: 2.0 }
      parser = OptionParser.new do |o|
        o.on("--interval SECONDS", Float) { |v| options[:interval] = v }
      end
      parser.parse(args)

      project_root = Project.root!
      puts "监听 books/ 变化，检测到改动会自动重建全部书籍（Ctrl-C 退出）..."
      previous = books_fingerprint(project_root)
      loop do
        sleep options[:interval]
        current = books_fingerprint(project_root)
        next if current == previous

        previous = current
        puts "\n[#{Time.now.strftime('%H:%M:%S')}] 检测到变化，重新构建..."
        cmd_build(["--all"])
      end
    rescue Interrupt
      puts "\n已停止监听"
    end

    def books_fingerprint(project_root)
      books_dir = Project.books_dir(project_root)
      return nil unless books_dir.directory?

      sig = []
      Pathname.glob(books_dir + "**" + "*").each do |f|
        sig << [f.to_s, f.mtime.to_f, f.size] if f.file?
      end
      sig.hash
    end

    # ---------- bindery serve [--port N] [--host H] ----------
    def cmd_serve(args)
      options = { port: 8000, host: "127.0.0.1" }
      parser = OptionParser.new do |o|
        o.on("--port N", Integer) { |v| options[:port] = v }
        o.on("--host H") { |v| options[:host] = v }
      end
      parser.parse(args)

      project_root = Project.root!
      Index.rebuild(project_root) # 确保书库索引是最新的
      Bindery::Server.new(project_root, host: options[:host], port: options[:port]).start
    end

    # ---------- bindery status ----------
    def cmd_status(_args)
      project_root = Project.root!
      books = Bindery::Book.all(project_root)
      if books.empty?
        puts "books/ 目录下没有任何书籍"
        return
      end

      printf("%-16s %-16s %-6s %-4s %-6s %-16s\n", "书籍ID", "标题", "章节数", "封面", "EPUB", "构建时间")
      puts "-" * 66
      books.each do |book|
        printf(
          "%-16s %-16s %-6d %-4s %-6s %-16s\n",
          book.id, book.title, book.chapters.size,
          book.cover? ? "✅" : "—",
          book.built?(project_root) ? "✅" : "—",
          book.built_at(project_root)&.strftime("%m-%d %H:%M") || "—"
        )
      end
      puts "-" * 66
      puts "共 #{books.size} 本书"
    end

    def print_help
      puts <<~HELP
        bindery #{Bindery::VERSION} — 再读经典项目脚手架工具

        用法:
          bindery init                                      在当前目录初始化项目
          bindery new book <书名> [chapter <章数>] [选项]    新建一本书（ID 自动生成）
            可组合: chapter <章数> 一并批量创建章节（N = 正文章节数，封面/目录不计入）
            选项: --id ID（可选） --author NAME  --dynasty 朝代  --category 分类
                  --translator 译者  --isbn ISBN  --cover 自动生成封面
          bindery new chapter <book-id> <数量>               批量创建章节（编号自动接续）
          bindery new volume <book-id> <卷名> [--chapters N] 新建卷（平铺 md，h2=卷名/h3=章名）
          bindery cover <book-id>                           自动生成装饰性封面
          bindery rename chapters <book-id>                 按标题自动更新章节文件名
          bindery build <id>                                构建单本书的 epub
          bindery build --all                               批量构建所有书
          bindery build <id> --check                        构建前校验（不实际构建）
          bindery build <id> --dry-run                      仅打印将构建的目标
          bindery build <id> --verbose                      打印 pandoc 命令
          bindery build <id> --epubcheck                    构建后用 epubcheck 校验
          bindery validate <id>                             校验单本书
          bindery validate --all                            校验所有书
          bindery clean [--all]                             清理构建产物（--all 连 books.json 一起删）
          bindery watch [--interval 秒]                      监听 books/ 自动重建
          bindery serve [--port N] [--host H]                启动本地书库站点
          bindery status                                     查看所有书籍状态
          bindery version                                    查看版本号
      HELP
    end
  end
end
