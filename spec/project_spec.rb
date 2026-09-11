require_relative "spec_helper"

class ProjectSpec < Minitest::Test
  def test_config_reads_bindery_yml
    Dir.mktmpdir("bindery-spec") do |tmp|
      FileUtils.mkdir_p(File.join(tmp, "config"))
      File.write(File.join(tmp, "config", "bindery.yml"), "project_name: \"spec\"\nlang: zh-TW\n")

      config = Bindery::Project.config(Pathname.new(tmp))
      assert_equal "spec", config["project_name"]
      assert_equal "zh-TW", config["lang"]
    end
  end

  def test_config_returns_empty_hash_when_marker_missing
    Dir.mktmpdir("bindery-spec") do |tmp|
      assert_equal({}, Bindery::Project.config(Pathname.new(tmp)))
    end
  end

  def test_root_walks_up_directories
    Dir.mktmpdir("bindery-spec") do |tmp|
      marker_dir = File.join(tmp, "a/b")
      FileUtils.mkdir_p(File.join(marker_dir, "config"))
      File.write(File.join(marker_dir, "config", "bindery.yml"), "")

      expected = Pathname.new(marker_dir)
      assert_equal expected, Bindery::Project.root(marker_dir)
      assert_equal expected, Bindery::Project.root(File.join(marker_dir, "x", "y"))
    end
  end

  def test_root_returns_nil_outside_project
    Dir.mktmpdir("bindery-spec") do |tmp|
      assert_nil Bindery::Project.root(tmp)
    end
  end
end
