module Bindery
  # 读取 JPEG/PNG 图片尺寸（纯标准库实现，不依赖第三方 gem）
  module Image
    module_function

    # 返回 [width, height]；无法识别格式时返回 nil
    def dimensions(path)
      return nil unless path.file?

      head = path.binread(24)
      if png?(head)
        width  = head.byteslice(16, 4).unpack1("N")
        height = head.byteslice(20, 4).unpack1("N")
        [width, height]
      elsif jpeg?(head)
        jpeg_dimensions(path)
      end
    rescue StandardError
      nil
    end

    def png?(head)
      head.byteslice(0, 8) == "\x89PNG\r\n\x1a\n".b
    end

    def jpeg?(head)
      head.byteslice(0, 2) == "\xFF\xD8".b
    end

    def jpeg_dimensions(path)
      File.open(path, "rb") do |f|
        f.read(2) # SOI
        loop do
          marker = f.read(2)
          return nil if marker.nil? || marker.bytesize < 2
          return nil unless marker.getbyte(0) == 0xFF

          code = marker.getbyte(1)
          # 跳过 0xFF 填充字节
          while code == 0xFF
            next_byte = f.read(1)
            return nil if next_byte.nil?
            code = next_byte.getbyte(0)
          end

          # SOF 段携带图片尺寸
          if (0xC0..0xCF).cover?(code) && ![0xC4, 0xC8, 0xCC].include?(code)
            f.read(2) # length
            f.read(1) # precision
            height = f.read(2).unpack1("n")
            width  = f.read(2).unpack1("n")
            return [width, height]
          else
            length = f.read(2).unpack1("n")
            return nil if length.nil? || length < 2
            f.read(length - 2)
          end
        end
      end
    rescue StandardError
      nil
    end
  end
end
