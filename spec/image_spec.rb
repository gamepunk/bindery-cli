require_relative "spec_helper"

class ImageSpec < Minitest::Test
  def test_png_dimensions
    Dir.mktmpdir("bindery-spec") do |tmp|
      path = File.join(tmp, "cover.png")
      sig = "\x89PNG\r\n\x1a\n".b + [13].pack("N") + "IHDR" + [600].pack("N") + [800].pack("N")
      File.binwrite(path, sig)

      assert_equal [600, 800], Bindery::Image.dimensions(Pathname.new(path))
    end
  end

  def test_jpeg_dimensions
    Dir.mktmpdir("bindery-spec") do |tmp|
      path = File.join(tmp, "cover.jpg")
      # SOI + SOF0 段：宽度 600，高度 800
      jpeg = "\xFF\xD8".b + "\xFF\xC0".b + [17].pack("n") + "\x08".b + [800].pack("n") + [600].pack("n")
      File.binwrite(path, jpeg)

      assert_equal [600, 800], Bindery::Image.dimensions(Pathname.new(path))
    end
  end

  def test_returns_nil_for_unknown_format
    Dir.mktmpdir("bindery-spec") do |tmp|
      path = File.join(tmp, "cover.txt")
      File.write(path, "not an image")

      assert_nil Bindery::Image.dimensions(Pathname.new(path))
    end
  end
end
