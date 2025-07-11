# frozen_string_literal: true

module Cmdx
  class WorkflowGenerator < Rails::Generators::NamedBase

    source_root File.expand_path("templates", __dir__)
    check_class_collision suffix: "Workflow"

    desc "Creates a workflow with the given NAME"

    def copy_files
      name = file_name.sub(/_?workflow$/i, "")
      path = File.join("app/cmds", class_path, "#{name}_workflow.rb")
      template("workflow.rb.tt", path)
    end

    private

    def class_name
      @class_name ||= super.end_with?("Workflow") ? super : "#{super}Workflow"
    end

    def parent_class_name
      ApplicationWorkflow
    rescue StandardError
      CMDx::Workflow
    end

  end
end
