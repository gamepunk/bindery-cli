require_relative "spec_helper"
require "stringio"

class CliSpec < Minitest::Test
  def capture_io
    out = StringIO.new
    err = StringIO.new
    original_out, original_err = $stdout, $stderr
    $stdout, $stderr = out, err
    yield
    [out.string, err.string]
  ensure
    $stdout, $stderr = original_out, original_err
  end

  def test_version_prints_version
    out, = capture_io { Bindery::CLI.start(["version"]) }
    assert_match(/bindery #{Regexp.escape(Bindery::VERSION)}/, out)
  end

  def test_help_without_arguments
    out, = capture_io { Bindery::CLI.start([]) }
    assert_match(/用法:/, out)
    assert_match(/bindery build --all/, out)
  end

  def test_unknown_command_exits
    assert_raises(SystemExit) do
      capture_io { Bindery::CLI.start(["nope"]) }
    end
  end

  def test_build_all_with_empty_books_still_rebuilds_index
    Dir.mktmpdir("bindery-spec") do |tmp|
      FileUtils.mkdir_p(File.join(tmp, "config"))
      File.write(File.join(tmp, "config", "bindery.yml"), "project_name: \"spec\"\n")
      FileUtils.mkdir_p(File.join(tmp, "books"))

      Dir.chdir(tmp) do
        capture_io { Bindery::CLI.start(["build", "--all"]) }
      end

      index = Pathname.new(tmp) + "books.json"
      assert index.file?, "books.json 应在 books/ 为空时仍然生成"
      data = JSON.parse(index.read)
      assert_equal 0, data["count"]
      assert_equal [], data["books"]
    end
  end

  def test_clean_removes_epub_artifacts
    Dir.mktmpdir("bindery-spec") do |tmp|
      FileUtils.mkdir_p(File.join(tmp, "config"))
      File.write(File.join(tmp, "config", "bindery.yml"), "project_name: \"spec\"\n")
      FileUtils.mkdir_p(File.join(tmp, "books"))
      epub_dir = File.join(tmp, "output", "epub")
      FileUtils.mkdir_p(epub_dir)
      File.write(File.join(epub_dir, "a.epub"), "x")
      File.write(File.join(epub_dir, "b.epub"), "x")

      Dir.chdir(tmp) do
        capture_io { Bindery::CLI.start(["clean"]) }
      end

      assert_empty Dir.children(epub_dir)
    end
  end

  def test_validate_reports_problems_for_incomplete_book
    Dir.mktmpdir("bindery-spec") do |tmp|
      FileUtils.mkdir_p(File.join(tmp, "config"))
      File.write(File.join(tmp, "config", "bindery.yml"), "project_name: \"spec\"\n")
      FileUtils.mkdir_p(File.join(tmp, "books", "nobook", "chapters"))
      File.write(File.join(tmp, "books", "nobook", "metadata.yaml"), "title: nobook\n")

      Dir.chdir(tmp) do
        assert_raises(SystemExit) do
          capture_io { Bindery::CLI.start(["validate", "nobook"]) }
        end
      end
    end
  end

  def test_init_creates_project_in_current_dir
    Dir.mktmpdir("bindery-spec") do |tmp|
      Dir.chdir(tmp) do
        capture_io { Bindery::CLI.start(["init"]) }
      end

      assert File.file?(File.join(tmp, "config", "bindery.yml"))
      assert File.directory?(File.join(tmp, "books"))
      assert File.file?(File.join(tmp, "README.md"))
    end
  end

  def test_new_book_generates_id_from_title
    Dir.mktmpdir("bindery-spec") do |tmp|
      FileUtils.mkdir_p(File.join(tmp, "config"))
      File.write(File.join(tmp, "config", "bindery.yml"), "project_name: \"spec\"\n")
      FileUtils.mkdir_p(File.join(tmp, "books"))

      Dir.chdir(tmp) do
        capture_io { Bindery::CLI.start(["new", "book", "1984"]) }
      end

      assert File.directory?(File.join(tmp, "books", "1984"))
    end
  end

  def test_new_book_auto_id_for_chinese_title
    Dir.mktmpdir("bindery-spec") do |tmp|
      FileUtils.mkdir_p(File.join(tmp, "config"))
      File.write(File.join(tmp, "config", "bindery.yml"), "project_name: \"spec\"\n")
      FileUtils.mkdir_p(File.join(tmp, "books"))

      Dir.chdir(tmp) do
        capture_io { Bindery::CLI.start(["new", "book", "论语"]) }
      end

      books = Dir.children(File.join(tmp, "books"))
      assert_equal 1, books.size
      assert_match(/\Abook-[0-9a-f]{8}\z/, books.first)
    end
  end

  def test_new_chapter_creates_files_after_existing
    Dir.mktmpdir("bindery-spec") do |tmp|
      FileUtils.mkdir_p(File.join(tmp, "config"))
      File.write(File.join(tmp, "config", "bindery.yml"), "project_name: \"spec\"\n")
      books = File.join(tmp, "books")
      FileUtils.mkdir_p(File.join(books, "demo", "chapters"))
      File.write(File.join(books, "demo", "metadata.yaml"), "title: demo\n")
      File.write(File.join(books, "demo", "chapters", "01-chapter.md"), "# 第一章\n")

      Dir.chdir(tmp) do
        capture_io { Bindery::CLI.start(["new", "chapter", "demo", "3"]) }
      end

      dir = File.join(books, "demo", "chapters")
      assert File.file?(File.join(dir, "02-chapter.md"))
      assert File.file?(File.join(dir, "03-chapter.md"))
      assert File.file?(File.join(dir, "04-chapter.md"))
    end
  end

  def test_new_book_with_chapter_creates_total_chapters
    Dir.mktmpdir("bindery-spec") do |tmp|
      FileUtils.mkdir_p(File.join(tmp, "config"))
      File.write(File.join(tmp, "config", "bindery.yml"), "project_name: \"spec\"\n")
      FileUtils.mkdir_p(File.join(tmp, "books"))

      Dir.chdir(tmp) do
        capture_io { Bindery::CLI.start(["new", "book", "1984", "chapter", "3"]) }
      end

      dir = File.join(tmp, "books", "1984", "chapters")
      assert File.file?(File.join(dir, "01-chapter.md"))
      assert File.file?(File.join(dir, "02-chapter.md"))
      assert File.file?(File.join(dir, "03-chapter.md"))
      refute File.exist?(File.join(dir, "04-chapter.md"))
    end
  end

  def test_new_volume_creates_directory_with_chapters
    Dir.mktmpdir("bindery-spec") do |tmp|
      FileUtils.mkdir_p(File.join(tmp, "config"))
      File.write(File.join(tmp, "config", "bindery.yml"), "project_name: \"spec\"\n")
      books = File.join(tmp, "books")
      FileUtils.mkdir_p(File.join(books, "demo", "chapters"))
      File.write(File.join(books, "demo", "metadata.yaml"), "title: demo\n")

      Dir.chdir(tmp) do
        capture_io { Bindery::CLI.start(["new", "volume", "demo", "学而", "--chapters", "2"]) }
      end

      vol = File.join(books, "demo", "chapters", "01-学而")
      assert File.directory?(vol)
      assert File.file?(File.join(vol, "01.md"))
      assert File.file?(File.join(vol, "02.md"))
    end
  end

  def test_cover_generates_png
    Dir.mktmpdir("bindery-spec") do |tmp|
      FileUtils.mkdir_p(File.join(tmp, "config"))
      File.write(File.join(tmp, "config", "bindery.yml"), "project_name: \"spec\"\n")
      books = File.join(tmp, "books")
      FileUtils.mkdir_p(File.join(books, "demo", "chapters"))
      File.write(File.join(books, "demo", "metadata.yaml"), "title: demo\n")
      File.write(File.join(books, "demo", "chapters", "01.md"), "# 一\n")

      Dir.chdir(tmp) do
        capture_io { Bindery::CLI.start(["cover", "demo"]) }
      end

      assert File.file?(File.join(books, "demo", "cover.png"))
    end
  end
end
