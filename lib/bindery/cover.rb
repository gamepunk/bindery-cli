require "zlib"
require "digest"

module Bindery
  # 纯 Ruby 生成装饰性封面 PNG：配色由书名稳定派生，不含文字（文字渲染需要字体光栅化，超出标准库能力）
  module Cover
    WIDTH  = 600
    HEIGHT = 800

    module_function

    # 为书籍生成 cover.png，并把 metadata.yaml 的 cover 字段指向它；返回文件路径
    def generate(book)
      png = encode_png(WIDTH, HEIGHT, build_pixels(WIDTH, HEIGHT, book.title))
      path = book.dir + "cover.png"
      path.binwrite(png)
      update_metadata_cover(book)
      path
    end

    def update_metadata_cover(book)
      meta_file = book.metadata_file
      return unless meta_file.file?

      text = meta_file.read
      text = if text =~ /^cover:.*$/
               text.sub(/^cover:.*$/, "cover: cover.png")
             else
               text.chomp + "\ncover: cover.png\n"
             end
      meta_file.write(text)
    end

    # 逐像素生成 RGB 位图，返回行数组（每行是一串 RGB 字节）
    def build_pixels(width, height, title)
      hue = Digest::MD5.hexdigest(title).to_i(16) % 360
      top    = hsl_to_rgb(hue, 0.45, 0.92)
      bottom = hsl_to_rgb(hue, 0.60, 0.28)
      accent = hsl_to_rgb((hue + 40) % 360, 0.55, 0.50)
      frame  = hsl_to_rgb(hue, 0.50, 0.18)

      margin = 44
      thickness = 4

      (0...height).map do |y|
        t = y.to_f / (height - 1)
        base = lerp(top, bottom, t)
        row = (+"").b
        (0...width).each do |x|
          c =
            if border?(x, y, width, height, margin, thickness)
              frame
            elsif ring?(x, y, width, height)
              accent
            else
              base
            end
          row << c.pack("C3")
        end
        row
      end
    end

    def border?(x, y, w, h, margin, thickness)
      in_x = x >= margin && x < w - margin
      in_y = y >= margin && y < h - margin
      return false unless in_x && in_y

      near_x = (x - margin).abs < thickness || (x - (w - margin - 1)).abs < thickness
      near_y = (y - margin).abs < thickness || (y - (h - margin - 1)).abs < thickness
      near_x || near_y
    end

    # 居中的方框纹样（外方框 + 内镂空）
    def ring?(x, y, w, h)
      cx = w / 2
      cy = h / 2
      outer = 220
      inner = 150
      dx = (x - cx).abs
      dy = (y - cy).abs
      in_outer = dx <= outer / 2 && dy <= outer / 2
      in_inner = dx <= inner / 2 && dy <= inner / 2
      in_outer && !in_inner
    end

    def lerp(c1, c2, t)
      [
        c1[0] + (c2[0] - c1[0]) * t,
        c1[1] + (c2[1] - c1[1]) * t,
        c1[2] + (c2[2] - c1[2]) * t,
      ].map(&:round)
    end

    def hsl_to_rgb(h, s, l)
      h = (h % 360) / 360.0
      if s.zero?
        r = g = b = l
      else
        q = l < 0.5 ? l * (1 + s) : l + s - l * s
        p = 2 * l - q
        r = hue_to_rgb(p, q, h + 1 / 3.0)
        g = hue_to_rgb(p, q, h)
        b = hue_to_rgb(p, q, h - 1 / 3.0)
      end
      [(r * 255).round, (g * 255).round, (b * 255).round]
    end

    def hue_to_rgb(p, q, t)
      t += 1 if t.negative?
      t -= 1 if t > 1
      if t < 1 / 6.0
        p + (q - p) * 6 * t
      elsif t < 1 / 2.0
        q
      elsif t < 2 / 3.0
        p + (q - p) * (2 / 3.0 - t) * 6
      else
        p
      end
    end

    def encode_png(width, height, rows)
      sig = "\x89PNG\r\n\x1a\n".b
      ihdr = [width, height, 8, 2, 0, 0, 0].pack("N2C5")
      raw = rows.map { |row| "\x00".b + row }.join
      idat = Zlib::Deflate.deflate(raw, 9)
      sig + chunk("IHDR", ihdr) + chunk("IDAT", idat) + chunk("IEND", "")
    end

    def chunk(type, data)
      [data.bytesize].pack("N") + type + data + [Zlib.crc32(type + data)].pack("N")
    end
  end
end
