require_relative "spec_helper"

class IndexSpec < Minitest::Test
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

  def test_rebuild_writes_books_json
    with_project do |root|
      make_book(root, "lunyu",
                metadata: "title: \"论语\"\nauthor: \"孔子\"\ndynasty: \"先秦\"\ncategory: \"哲学\"\n",
                chapters: ["# 一\n"])

      data = Bindery::Index.rebuild(root)
      assert_equal 1, data["count"]
      assert_equal "lunyu", data["books"].first["id"]
      assert_equal "论语", data["books"].first["title"]

      parsed = JSON.parse((root + "books.json").read)
      assert_equal data["count"], parsed["count"]
    end
  end

  def test_rebuild_skips_invalid_books
    with_project do |root|
      make_book(root, "valid", metadata: "title: valid\n", chapters: ["# 一\n"])
      FileUtils.mkdir_p(root + "books/nochapters") # 无 metadata / 章节，应被跳过

      data = Bindery::Index.rebuild(root)
      assert_equal 1, data["count"]
      assert_equal "valid", data["books"].first["id"]
    end
  end
end
