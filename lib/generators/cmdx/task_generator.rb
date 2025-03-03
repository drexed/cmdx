# frozen_string_literal: true

module Cmdx
  class TaskGenerator < Rails::Generators::NamedBase

    source_root File.expand_path("../templates", __FILE__)
    check_class_collision suffix: "Task"

    def copy_files
      path = File.join("app/cmds", class_path, "#{file_name}_task.rb")
      template("task.rb.tt", path)
    end

    private

    def file_name
      @_file_name ||= remove_possible_suffix(super)
    end

    def remove_possible_suffix(name)
      name.sub(/_?task$/i, "")
    end

  end
end
