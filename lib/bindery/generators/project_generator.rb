require_relative "base"

module Bindery
  module Generators
    # bindery init
    # 在当前目录就地生成一整套项目骨架：books/、templates/（样式）、output/、
    # config/bindery.yml（项目标记文件）、README、.gitignore、GitHub Actions
    class ProjectGenerator < Base
      def self.call(project_name = Pathname.pwd.basename.to_s)
        dest = Pathname.pwd
        if (dest + "config/bindery.yml").file?
          raise Bindery::Error, "当前目录已经是 bindery 项目（已存在 config/bindery.yml）"
        end

        conflicts = ["books", "templates", "output", "README.md", ".gitignore",
                     ".github/workflows/build.yml"]
        existing = conflicts.select { |f| (dest + f).exist? }
        unless existing.empty?
          raise Bindery::Error, "以下文件/目录已存在，为避免覆盖，无法初始化：#{existing.join('、')}"
        end

        puts "初始化项目: #{project_name}"
        new(dest).generate(project_name)
        puts ""
        puts "完成！接下来："
        puts "  bindery new book \"论语\" --author \"孔子及弟子\" --dynasty \"先秦\""
        puts "  bindery build --all"
      end

      def generate(project_name)
        empty_directory("books")
        empty_directory("output/epub")

        template("project", "config/bindery.yml", locals: { project_name: project_name })
        template("project", "README.md", locals: { project_name: project_name })
        copy_file("project", "gitignore", ".gitignore")
        copy_file("project", "style.css", "templates/style.css")
        copy_file("project", "workflow.yml", ".github/workflows/build.yml")
      end
    end
  end
end
