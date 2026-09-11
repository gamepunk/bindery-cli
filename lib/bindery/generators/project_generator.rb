require_relative "base"

module Bindery
  module Generators
    # bindery new <项目名>
    # 生成一整套项目骨架：books/、templates/（样式+字体说明）、output/、
    # config/bindery.yml（项目标记文件）、README、.gitignore、GitHub Actions
    class ProjectGenerator < Base
      def self.call(project_name)
        dest = Pathname.pwd + project_name
        if dest.exist?
          raise Bindery::Error, "目录已存在: #{dest}"
        end

        puts "创建项目: #{project_name}"
        new(dest).generate(project_name)
        puts ""
        puts "完成！接下来："
        puts "  cd #{project_name}"
        puts "  bindery generate book lunyu \"论语\" --author \"孔子及弟子\""
        puts "  bindery build lunyu"
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
