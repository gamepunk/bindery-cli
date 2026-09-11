require "optparse"

module Bindery
  # 命令行入口：解析子命令并分发
  # 支持: new / generate(g) / build / status / version / help
  class CLI
    def self.start(argv)
      new.run(argv)
    end

    def run(argv)
      command, *rest = argv
      case command
      when "new"
        cmd_new(rest)
      when "generate", "g"
        cmd_generate(rest)
      when "build"
        cmd_build(rest)
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

    # ---------- bindery new <项目名> ----------
    def cmd_new(args)
      name = args.first
      if name.nil? || name.empty?
        warn "用法: bindery new <项目名>"
        exit 1
      end
      Generators::ProjectGenerator.call(name)
    end

    # ---------- bindery generate book <id> <title> [选项] ----------
    def cmd_generate(args)
      type, *rest = args
      case type
      when "book"
        cmd_generate_book(rest)
      when nil
        warn "用法: bindery generate book <id> <书名> [--author NAME] [--dynasty 朝代] [--category 分类]"
        exit 1
      else
        warn "未知的生成器类型: #{type}（目前只支持 book）"
        exit 1
      end
    end

    def cmd_generate_book(args)
      options = { author: "佚名", dynasty: "", category: "" }
      parser = OptionParser.new do |o|
        o.on("--author NAME") { |v| options[:author] = v }
        o.on("--dynasty NAME") { |v| options[:dynasty] = v }
        o.on("--category NAME") { |v| options[:category] = v }
      end
      positional = parser.parse(args)
      id, title = positional
      if id.nil? || title.nil?
        warn "用法: bindery generate book <id> <书名> [--author NAME] [--dynasty 朝代] [--category 分类]"
        exit 1
      end

      Generators::BookGenerator.call(
        id, title,
        author: options[:author], dynasty: options[:dynasty], category: options[:category]
      )
    end

    # ---------- bindery build [<id>] [--all] ----------
    def cmd_build(args)
      options = { all: false }
      parser = OptionParser.new do |o|
        o.on("--all") { options[:all] = true }
      end
      positional = parser.parse(args)

      project_root = Project.root!
      books = options[:all] ? Bindery::Book.all(project_root) : [book_from_arg(positional.first, project_root)]

      if books.empty?
        warn "books/ 目录下没有任何书籍"
        return
      end

      success = 0
      failure = 0
      books.each do |book|
        builder = Builder.new(book, project_root: project_root)
        if builder.build_epub
          puts "✅ [#{book.id}] epub 构建成功"
          success += 1
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

    # ---------- bindery status ----------
    def cmd_status(_args)
      project_root = Project.root!
      books = Bindery::Book.all(project_root)
      if books.empty?
        puts "books/ 目录下没有任何书籍"
        return
      end

      printf("%-16s %-16s %-8s %-6s\n", "书籍ID", "标题", "章节数", "EPUB")
      puts "-" * 50
      books.each do |book|
        printf(
          "%-16s %-16s %-8d %-6s\n",
          book.id, book.title, book.chapters.size,
          book.built?(project_root) ? "✅" : "—"
        )
      end
      puts "-" * 50
      puts "共 #{books.size} 本书"
    end

    def print_help
      puts <<~HELP
        bindery #{Bindery::VERSION} — 再读经典项目脚手架工具

        用法:
          bindery new <项目名>                              创建新项目
          bindery generate book <id> <书名> [选项]           为项目生成一本新书
            简写: bindery g book <id> <书名>
            选项: --author NAME  --dynasty 朝代  --category 分类
          bindery build <id>                                构建单本书的 epub
          bindery build --all                               批量构建所有书
          bindery status                                     查看所有书籍状态
          bindery version                                    查看版本号
      HELP
    end
  end
end
