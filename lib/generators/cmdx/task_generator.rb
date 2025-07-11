# frozen_string_literal: true

module Cmdx
  class TaskGenerator < Rails::Generators::NamedBase

    source_root File.expand_path("templates", __dir__)
    check_class_collision suffix: "Task"

    desc "Creates a task with the given NAME"

    def copy_files
      name = file_name.sub(/_?task$/i, "")
      path = File.join("app/cmds", class_path, "#{name}_task.rb")
      template("task.rb.tt", path)
    end

    private

    def class_name
      @class_name ||= super.end_with?("Task") ? super : "#{super}Task"
    end

    def parent_class_name
      ApplicationTask
    rescue StandardError
      CMDx::Task
    end

  end
end
