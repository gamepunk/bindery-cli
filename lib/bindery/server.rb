require "socket"
require "uri"
require "json"
require "yaml"
require "base64"
require "pathname"

module Bindery
  # 极简静态服务器：展示书库并提供 EPUB 下载。
  # 仅用标准库 socket 实现（Ruby 3.0 起 WEBrick 已移出标准库）。
  class Server
    MIME = {
      ".html" => "text/html; charset=utf-8",
      ".json" => "application/json; charset=utf-8",
      ".epub" => "application/epub+zip",
      ".css"  => "text/css; charset=utf-8",
      ".jpg"  => "image/jpeg",
      ".jpeg" => "image/jpeg",
      ".png"  => "image/png",
      ".svg"  => "image/svg+xml",
    }.freeze

    # 书库与封面编辑器页面（随 gem 一起打包）
    ASSETS_DIR = Pathname.new(__dir__) + "assets"

    attr_reader :port

    # port 为 nil 时不预先指定端口，由操作系统自动分配一个空闲端口
    def initialize(project_root, host: "127.0.0.1", port: nil)
      @project_root = project_root
      @host = host
      @port = port
    end

    # 绑定监听地址，并返回实际监听的端口号（未指定 --port 时可用于提前拿到自动分配的端口）
    def listen
      return @port if @server

      @server = TCPServer.new(@host, @port || 0)
      @port = @server.addr[1]
    rescue Errno::EADDRINUSE
      raise Bindery::Error, "端口 #{@port} 已被占用，换个端口试试（--port N），或不指定 --port 让系统自动分配"
    end

    def start
      listen
      puts "服务已启动: http://#{@host}:#{@port} （Ctrl-C 退出）"
      loop do
        client = @server.accept
        begin
          respond(client)
        rescue StandardError => e
          warn "请求处理失败: #{e.message}"
        ensure
          begin
            client.close
          rescue StandardError
            nil
          end
        end
      end
    rescue Interrupt
      puts "\n服务已停止"
    ensure
      begin
        @server&.close
      rescue StandardError
        nil
      end
    end

    private

    def respond(client)
      request_line = client.gets
      return unless request_line

      method, raw_path, = request_line.split(" ")
      # 读取请求头，POST 需要 Content-Length
      content_length = 0
      while (line = client.gets)
        break if line.nil? || line == "\r\n" || line == "\n"
        if line =~ /\AContent-Length:\s*(\d+)/i
          content_length = Regexp.last_match(1).to_i
        end
      end

      path = (URI::RFC2396_PARSER.unescape(raw_path.split("?").first) rescue raw_path)
      path = "/" if path.nil? || path.empty?
      path = path.gsub("..", "") # 防目录穿越

      if method == "POST" && path == "/cover/save"
        save_cover(client, content_length)
        return
      end
      return unless method == "GET" || method == "HEAD"

      case path
      when "/", "/index.html"
        serve_file(client, ASSETS_DIR + "index.html", MIME[".html"], method)
      when "/books.json"
        serve_file(client, Project.index_file(@project_root), MIME[".json"], method)
      when "/cover"
        serve_file(client, ASSETS_DIR + "cover.html", MIME[".html"], method)
      when %r{\A/epub/([\w\-.]+\.epub)\z}
        serve_file(client, Project.output_dir(@project_root) + "epub" + Regexp.last_match(1), MIME[".epub"], method)
      when %r{\A/cover/([\w\-]+)\z}
        serve_cover(client, Regexp.last_match(1), method)
      else
        not_found(client, method)
      end
    end

    def serve_cover(client, id, method)
      book_dir = Project.books_dir(@project_root) + id
      return not_found(client, method) unless book_dir.directory?

      name = "cover.jpg"
      meta_file = book_dir + "metadata.yaml"
      if meta_file.file?
        begin
          meta = YAML.safe_load(meta_file.read, permitted_classes: [Symbol]) || {}
          name = meta["cover"] || "cover.jpg"
        rescue StandardError
          nil
        end
      end

      path = book_dir + name
      path = (book_dir + "cover.jpg") unless path.file?
      path = (book_dir + "cover.png") unless path.file?

      serve_file(client, path, nil, method)
    end

    # 保存封面编辑器生成的 PNG 到书籍目录，并更新 metadata 的 cover 字段
    def save_cover(client, content_length)
      body = client.read(content_length).to_s
      return send_json(client, 400, { ok: false, error: "请求体为空" }) if body.empty?

      data = JSON.parse(body)
      book_id = data["book"].to_s
      data_url = data["data"].to_s

      book_dir = Project.books_dir(@project_root) + book_id
      return send_json(client, 404, { ok: false, error: "书籍不存在: #{book_id}" }) unless book_dir.directory?

      b64 = data_url.sub(/\Adata:image\/\w+;base64,/, "")
      png = Base64.decode64(b64)
      path = book_dir + "cover.png"
      path.binwrite(png)

      meta_file = book_dir + "metadata.yaml"
      if meta_file.file?
        text = meta_file.read
        text = if text =~ /^cover:.*$/
                 text.sub(/^cover:.*$/, "cover: cover.png")
               else
                 text.chomp + "\ncover: cover.png\n"
               end
        meta_file.write(text)
      end

      send_json(client, 200, { ok: true, path: "books/#{book_id}/cover.png" })
    rescue JSON::ParserError => e
      send_json(client, 400, { ok: false, error: "JSON 解析失败: #{e.message}" })
    end

    def send_json(client, status, hash)
      send_response(client, status, MIME[".json"], JSON.generate(hash), "POST")
    end

    def serve_file(client, path, content_type, method)
      return not_found(client, method) unless path.file?

      body = path.binread
      content_type ||= MIME[path.extname.downcase] || "application/octet-stream"
      send_response(client, 200, content_type, body, method)
    end

    def not_found(client, method)
      body = "<h1>404 Not Found</h1>"
      send_response(client, 404, MIME[".html"], body, method)
    end

    def send_response(client, status, content_type, body, method)
      reason = { 200 => "OK", 404 => "Not Found" }[status] || "OK"
      headers = "HTTP/1.1 #{status} #{reason}\r\n" \
                "Content-Type: #{content_type}\r\n" \
                "Content-Length: #{body.bytesize}\r\n" \
                "Connection: close\r\n\r\n"
      client.write(headers)
      client.write(body) unless method == "HEAD"
    end
  end
end
