# frozen_string_literal: true

module Cmdx
  class WorkflowGenerator < Rails::Generators::NamedBase

    source_root File.expand_path("templates", __dir__)

    desc "Creates a workflow with the given NAME"

    def copy_files
      path = File.join("app/tasks", class_path, "#{file_name}.rb")
      template("workflow.rb.tt", path)
    end

    private

    def parent_class_name
      ApplicationTask
    rescue NameError
      CMDx::Task
    end

  end
end
