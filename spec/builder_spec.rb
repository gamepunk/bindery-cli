require_relative "spec_helper"

class BuilderSpec < Minitest::Test
  def with_project
    Dir.mktmpdir("bindery-spec") do |tmp|
      FileUtils.mkdir_p(File.join(tmp, "config"))
      File.write(File.join(tmp, "config", "bindery.yml"), "project_name: \"spec\"\n")
      FileUtils.mkdir_p(File.join(tmp, "books"))
      yield Pathname.new(tmp)
    end
  end

  def test_build_returns_false_for_book_without_chapters
    with_project do |root|
      dir = root + "books/emptybook"
      FileUtils.mkdir_p(dir + "chapters")
      File.write(dir + "metadata.yaml", "title: emptybook\n")

      builder = Bindery::Builder.new(Bindery::Book.find("emptybook", root), project_root: root)
      refute builder.build_epub
      assert_match(/没有任何 \.md 文件/, builder.last_error)
    end
  end

  def test_build_returns_false_for_missing_metadata
    with_project do |root|
      dir = root + "books/nometa"
      FileUtils.mkdir_p(dir + "chapters")
      File.write(dir + "chapters/01.md", "# 一\n")

      builder = Bindery::Builder.new(Bindery::Book.find("nometa", root), project_root: root)
      refute builder.build_epub
      assert_match(/metadata\.yaml/, builder.last_error)
    end
  end
end
