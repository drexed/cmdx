# frozen_string_literal: true

module Cmdx
  class TaskGenerator < Rails::Generators::NamedBase

    source_root File.expand_path("templates", __dir__)

    desc "Creates a task with the given NAME"

    def copy_files
      path = File.join("app/tasks", class_path, "#{file_name}.rb")
      template("task.rb.tt", path)
    end

    private

    def parent_class_name
      ApplicationTask
    rescue NameError
      CMDx::Task
    end

  end
end
