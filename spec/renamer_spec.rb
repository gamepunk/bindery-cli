require_relative "spec_helper"

class RenamerSpec < Minitest::Test
  def test_sanitize_replaces_illegal_characters
    assert_equal "学而-时习之", Bindery::Renamer.sanitize("学而/时习之")
    assert_equal "a-b-c", Bindery::Renamer.sanitize('a:b*c?')
    assert_equal "无邪", Bindery::Renamer.sanitize("无邪  ")
  end

  def test_sanitize_falls_back_when_empty
    assert_equal "章节", Bindery::Renamer.sanitize("///")
  end

  def test_extract_title_reads_first_heading
    Dir.mktmpdir("bindery-spec") do |tmp|
      path = File.join(tmp, "chapter.md")
      File.write(path, "正文开头\n\n### 学而时习之\n\n内容\n")
      assert_equal "学而时习之", Bindery::Renamer.extract_title(Pathname.new(path))
    end
  end
end
