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
end
