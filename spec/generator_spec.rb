require_relative "spec_helper"

class GeneratorSpec < Minitest::Test
  def test_generated_metadata_round_trips_special_characters
    Dir.mktmpdir("bindery-spec") do |tmp|
      FileUtils.mkdir_p(File.join(tmp, "config"))
      File.write(File.join(tmp, "config", "bindery.yml"), "project_name: \"spec\"\n")
      FileUtils.mkdir_p(File.join(tmp, "books"))

      root = Pathname.new(tmp)
      Bindery::Generators::BookGenerator.call(
        "b1", "1984",
        author: "甲#乙:丙", dynasty: "", category: "",
        project_root: root
      )

      book = Bindery::Book.find("b1", root)
      assert_equal "1984", book.title
      assert_equal "甲#乙:丙", book.author
    end
  end

  def test_generated_metadata_uses_project_config_defaults
    Dir.mktmpdir("bindery-spec") do |tmp|
      FileUtils.mkdir_p(File.join(tmp, "config"))
      File.write(File.join(tmp, "config", "bindery.yml"), <<~YAML)
        project_name: "spec"
        lang: zh-TW
        publisher: 我的出版社
        rights: CC0
      YAML
      FileUtils.mkdir_p(File.join(tmp, "books"))

      root = Pathname.new(tmp)
      Bindery::Generators::BookGenerator.call(
        "b1", "书", author: "作者", dynasty: "", category: "", project_root: root
      )

      meta = YAML.safe_load((root + "books/b1/metadata.yaml").read)
      assert_equal "zh-TW", meta["lang"]
      assert_equal "我的出版社", meta["publisher"]
      assert_equal "CC0", meta["rights"]
    end
  end

  def test_generated_metadata_includes_translator_and_isbn
    Dir.mktmpdir("bindery-spec") do |tmp|
      FileUtils.mkdir_p(File.join(tmp, "config"))
      File.write(File.join(tmp, "config", "bindery.yml"), "project_name: \"spec\"\n")
      FileUtils.mkdir_p(File.join(tmp, "books"))

      root = Pathname.new(tmp)
      Bindery::Generators::BookGenerator.call(
        "b1", "书", author: "作者", dynasty: "", category: "哲学",
        translator: "译者甲", isbn: "9780000000000", project_root: root
      )

      meta = YAML.safe_load((root + "books/b1/metadata.yaml").read)
      assert_equal "译者甲", meta["translator"]
      assert_equal "9780000000000", meta["isbn"]
    end
  end
end
