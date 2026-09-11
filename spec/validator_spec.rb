require_relative "spec_helper"

class ValidatorSpec < Minitest::Test
  def with_project
    Dir.mktmpdir("bindery-spec") do |tmp|
      FileUtils.mkdir_p(File.join(tmp, "config"))
      File.write(File.join(tmp, "config", "bindery.yml"), "project_name: \"spec\"\n")
      FileUtils.mkdir_p(File.join(tmp, "books"))
      yield Pathname.new(tmp)
    end
  end

  def make_book(root, id, metadata:, chapters: [])
    dir = root + "books" + id
    FileUtils.mkdir_p(dir + "chapters")
    File.write(dir + "metadata.yaml", metadata)
    chapters.each_with_index do |content, i|
      File.write(dir + "chapters" + format("%02d.md", i + 1), content)
    end
  end

  def test_check_flags_missing_chapters
    with_project do |root|
      make_book(root, "nobook", metadata: "title: nobook\n")
      book = Bindery::Book.find("nobook", root)

      issues = Bindery::Validator.check(book, project_root: root)
      assert_includes issues.join, "没有任何 .md 文件"
    end
  end

  def test_warnings_missing_cover
    with_project do |root|
      make_book(root, "demo", metadata: "title: demo\n", chapters: ["# 一\n"])
      book = Bindery::Book.find("demo", root)

      warns = Bindery::Validator.warnings(book, project_root: root)
      assert_includes warns.join, "封面"
    end
  end

  def test_warnings_cover_too_small
    with_project do |root|
      make_book(root, "demo", metadata: "title: demo\ncover: cover.png\n", chapters: ["# 一\n"])
      sig = "\x89PNG\r\n\x1a\n".b + [13].pack("N") + "IHDR" + [10].pack("N") + [10].pack("N")
      File.binwrite(root + "books/demo/cover.png", sig)
      book = Bindery::Book.find("demo", root)

      warns = Bindery::Validator.warnings(book, project_root: root)
      assert_includes warns.join, "偏小"
    end
  end
end
