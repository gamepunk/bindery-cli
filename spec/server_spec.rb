require_relative "spec_helper"
require "net/http"
require "uri"
require "json"
require "base64"

class ServerSpec < Minitest::Test
  def teardown
    @sockets&.each { |s| s.close if s && !s.closed? }
  end

  def track(server)
    @sockets ||= []
    @sockets << server.instance_variable_get(:@server)
    server
  end

  def with_project
    Dir.mktmpdir("bindery-spec") do |tmp|
      FileUtils.mkdir_p(File.join(tmp, "config"))
      File.write(File.join(tmp, "config", "bindery.yml"), "project_name: \"spec\"\n")
      FileUtils.mkdir_p(File.join(tmp, "books"))
      yield Pathname.new(tmp)
    end
  end

  def make_book(root, id, title: "示例书", author: "某某")
    dir = root + "books" + id
    FileUtils.mkdir_p(dir + "chapters")
    (dir + "metadata.yaml").write("title: #{title}\nauthor: #{author}\n")
    (dir + "chapters" + "chapter-0001.md").write("### 第一章\n\n正文\n")
    dir
  end

  # 启动一个真实监听的 Server，yield 给调用方；结束后清理线程与 socket
  def with_running_server(root)
    server = Bindery::Server.new(root, host: "127.0.0.1", port: nil)
    server.listen
    thread = Thread.new { server.start }
    sleep 0.05 # 等 accept 循环起来
    yield server
  ensure
    thread&.kill
    thread&.join(1)
    server&.instance_variable_get(:@server)&.close
  end

  # net/http 返回的 body 默认是 ASCII-8BIT 编码，与含中文的 UTF-8 正则/字面量比较会报编码不兼容，统一校正回来
  def get(server, path)
    res = Net::HTTP.get_response(URI("http://127.0.0.1:#{server.port}#{path}"))
    res.body&.force_encoding(Encoding::UTF_8)
    res
  end

  def post_json(server, path, hash)
    uri = URI("http://127.0.0.1:#{server.port}#{path}")
    res = Net::HTTP.post(uri, JSON.generate(hash), "Content-Type" => "application/json")
    res.body&.force_encoding(Encoding::UTF_8)
    res
  end

  # ---------- 端口 ----------

  def test_listen_picks_a_free_port_when_unspecified
    Dir.mktmpdir("bindery-spec") do |tmp|
      server = track(Bindery::Server.new(Pathname.new(tmp), port: nil))
      port = server.listen

      assert_kind_of Integer, port
      assert port.positive?
      assert_equal port, server.port
    end
  end

  def test_listen_is_idempotent
    Dir.mktmpdir("bindery-spec") do |tmp|
      server = track(Bindery::Server.new(Pathname.new(tmp), port: nil))
      first = server.listen
      second = server.listen

      assert_equal first, second
    end
  end

  def test_listen_raises_friendly_error_when_port_in_use
    Dir.mktmpdir("bindery-spec") do |tmp|
      first = track(Bindery::Server.new(Pathname.new(tmp), port: nil))
      busy_port = first.listen

      second = Bindery::Server.new(Pathname.new(tmp), port: busy_port)
      error = assert_raises(Bindery::Error) { second.listen }
      assert_match(/已被占用/, error.message)
    end
  end

  # ---------- 路由：书库 / 封面生成器页面 ----------

  def test_root_serves_library_page
    with_project do |root|
      with_running_server(root) do |server|
        res = get(server, "/")
        assert_equal "200", res.code
        assert_match(/text\/html/, res["Content-Type"])
        assert_match(/书库/, res.body)
      end
    end
  end

  def test_index_html_is_an_alias_for_root
    with_project do |root|
      with_running_server(root) do |server|
        res = get(server, "/index.html")
        assert_equal "200", res.code
        assert_match(/书库/, res.body)
      end
    end
  end

  def test_cover_route_serves_generator_page
    with_project do |root|
      with_running_server(root) do |server|
        res = get(server, "/cover")
        assert_equal "200", res.code
        assert_match(/封面生成器/, res.body)
      end
    end
  end

  # ---------- 路由：books.json ----------

  def test_books_json_route_serves_index_data
    with_project do |root|
      make_book(root, "demo", title: "论语", author: "孔子及弟子")
      Bindery::Index.rebuild(root)

      with_running_server(root) do |server|
        res = get(server, "/books.json")
        assert_equal "200", res.code
        data = JSON.parse(res.body)
        assert_equal 1, data["count"]
        assert_equal "demo", data["books"].first["id"]
        assert_equal "论语", data["books"].first["title"]
      end
    end
  end

  def test_books_json_route_404_when_missing
    with_project do |root|
      with_running_server(root) do |server|
        res = get(server, "/books.json")
        assert_equal "404", res.code
      end
    end
  end

  # ---------- 路由：epub 下载 ----------

  def test_epub_route_serves_built_file
    with_project do |root|
      epub_dir = root + "output" + "epub"
      FileUtils.mkdir_p(epub_dir)
      (epub_dir + "demo.epub").binwrite("fake epub content")

      with_running_server(root) do |server|
        res = get(server, "/epub/demo.epub")
        assert_equal "200", res.code
        assert_equal "application/epub+zip", res["Content-Type"]
        assert_equal "fake epub content", res.body
      end
    end
  end

  def test_epub_route_404_when_not_built
    with_project do |root|
      with_running_server(root) do |server|
        res = get(server, "/epub/demo.epub")
        assert_equal "404", res.code
      end
    end
  end

  # ---------- 路由：书籍封面图片 ----------

  def test_cover_image_route_serves_existing_cover
    with_project do |root|
      dir = make_book(root, "demo")
      (dir + "cover.jpg").binwrite("\xFF\xD8\xFFfakejpeg".b)

      with_running_server(root) do |server|
        res = get(server, "/cover/demo")
        assert_equal "200", res.code
        assert_equal "image/jpeg", res["Content-Type"]
      end
    end
  end

  def test_cover_image_route_404_for_unknown_book
    with_project do |root|
      with_running_server(root) do |server|
        res = get(server, "/cover/does-not-exist")
        assert_equal "404", res.code
      end
    end
  end

  # ---------- 未知路由 ----------

  def test_unknown_route_returns_404
    with_project do |root|
      with_running_server(root) do |server|
        res = get(server, "/nope")
        assert_equal "404", res.code
        assert_match(/404/, res.body)
      end
    end
  end

  # ---------- POST /cover/save ----------

  def test_save_cover_writes_png_and_updates_metadata
    with_project do |root|
      make_book(root, "demo")

      with_running_server(root) do |server|
        png_data = Base64.strict_encode64("\x89PNG\r\n\x1a\nfake".b)
        res = post_json(server, "/cover/save", {
          book: "demo",
          data: "data:image/png;base64,#{png_data}",
        })

        assert_equal "200", res.code
        payload = JSON.parse(res.body)
        assert payload["ok"]
        assert File.file?(root + "books" + "demo" + "cover.png")
        assert_match(/cover: cover\.png/, (root + "books" + "demo" + "metadata.yaml").read)
      end
    end
  end

  def test_save_cover_returns_404_for_unknown_book
    with_project do |root|
      with_running_server(root) do |server|
        res = post_json(server, "/cover/save", {
          book: "does-not-exist",
          data: "data:image/png;base64,#{Base64.strict_encode64('x')}",
        })

        assert_equal "404", res.code
        refute JSON.parse(res.body)["ok"]
      end
    end
  end

  def test_save_cover_returns_400_for_invalid_json
    with_project do |root|
      with_running_server(root) do |server|
        uri = URI("http://127.0.0.1:#{server.port}/cover/save")
        res = Net::HTTP.post(uri, "not json", "Content-Type" => "application/json")
        res.body&.force_encoding(Encoding::UTF_8)

        assert_equal "400", res.code
        refute JSON.parse(res.body)["ok"]
      end
    end
  end
end
