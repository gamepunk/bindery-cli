require "json"
require "time"

module Bindery
  # 扫描所有书籍，重新生成 books.json（供后续静态网站读取）
  module Index
    module_function

    def rebuild(project_root = Project.root!)
      books = Bindery::Book.all(project_root).select(&:valid?).map do |book|
        {
          "id"       => book.id,
          "title"    => book.title,
          "author"   => book.author,
          "dynasty"  => book.metadata["dynasty"],
          "category" => book.metadata["category"],
          "epub"     => book.built?(project_root) ? "output/epub/#{book.id}.epub" : nil,
        }
      end

      data = {
        "generated_at" => Time.now.iso8601,
        "count"        => books.size,
        "books"        => books,
      }

      Project.index_file(project_root).write(JSON.pretty_generate(data))
      data
    end
  end
end
