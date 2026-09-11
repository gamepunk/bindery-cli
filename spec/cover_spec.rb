require_relative "spec_helper"

class CoverSpec < Minitest::Test
  def with_project
    Dir.mktmpdir("bindery-spec") do |tmp|
      FileUtils.mkdir_p(File.join(tmp, "config"))
      File.write(File.join(tmp, "config", "bindery.yml"), "project_name: \"spec\"\n")
      FileUtils.mkdir_p(File.join(tmp, "books"))
      yield Pathname.new(tmp)
    end
  end

  def test_generate_creates_valid_png_and_updates_metadata
    with_project do |root|
      dir = root + "books/demo"
      FileUtils.mkdir_p(dir + "chapters")
      File.write(dir + "metadata.yaml", "title: demo\ncover: cover.jpg\n")
      File.write(dir + "chapters/01.md", "# 一\n")

      book = Bindery::Book.find("demo", root)
      path = Bindery::Cover.generate(book)

      assert File.file?(path)
      assert_equal [600, 800], Bindery::Image.dimensions(path)
      assert_match(/cover: cover\.png/, (dir + "metadata.yaml").read)
    end
  end
end
