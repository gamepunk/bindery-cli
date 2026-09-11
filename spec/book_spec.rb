require_relative "spec_helper"

class BookSpec < Minitest::Test
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

  def test_title_stays_string_for_numeric_name
    with_project do |root|
      make_book(root, "1984", metadata: "title: \"1984\"\nauthor: \"乔治·奥威尔\"\n", chapters: ["# 一\n"])
      book = Bindery::Book.find("1984", root)
      assert_equal "1984", book.title
      assert_equal "乔治·奥威尔", book.author
    end
  end

  def test_chapters_ignores_directories
    with_project do |root|
      make_book(root, "demo", metadata: "title: demo\n", chapters: ["# 一\n"])
      FileUtils.mkdir_p(root + "books/demo/chapters/02.md")
      book = Bindery::Book.find("demo", root)
      assert_equal 1, book.chapters.size
    end
  end

  def test_title_falls_back_to_id_when_metadata_missing
    with_project do |root|
      FileUtils.mkdir_p(root + "books/stray")
      book = Bindery::Book.new(root + "books/stray")
      assert_equal "stray", book.title
      assert_equal "佚名", book.author
    end
  end

  def test_volumes_and_all_chapters
    with_project do |root|
      dir = root + "books/demo"
      FileUtils.mkdir_p(dir + "chapters/01-学而")
      FileUtils.mkdir_p(dir + "chapters/02-为政")
      File.write(dir + "metadata.yaml", "title: demo\n")
      File.write(dir + "chapters/01-学而/01.md", "# 一\n")
      File.write(dir + "chapters/01-学而/02.md", "# 二\n")
      File.write(dir + "chapters/02-为政/01.md", "# 三\n")

      book = Bindery::Book.find("demo", root)
      assert_equal 2, book.volumes.size
      assert_equal 3, book.all_chapters.size
      assert book.valid?
    end
  end
end
