# frozen_string_literal: true

module Cmdx
  # Rails generator for creating CMDx workflow files.
  #
  # This generator creates workflow files in the app/cmds directory with proper
  # class naming conventions and inheritance. It ensures workflow names end with
  # "Workflow" suffix and creates files in the correct location within the Rails
  # application structure.
  class WorkflowGenerator < Rails::Generators::NamedBase

    source_root File.expand_path("templates", __dir__)
    check_class_collision suffix: "Workflow"

    desc "Creates a workflow with the given NAME"

    # Creates the workflow file from the template.
    #
    # Generates a new workflow file in the app/cmds directory based on the provided
    # name. The file name is normalized to ensure it ends with "_workflow.rb" and
    # is placed in the appropriate subdirectory structure.
    #
    # @return [void]
    #
    # @raise [Thor::Error] if the destination file cannot be created or already exists without force
    #
    # @example Generate a user workflow
    #   rails generate cmdx:workflow user
    #   # => Creates app/cmds/user_workflow.rb
    #
    # @example Generate a nested workflow
    #   rails generate cmdx:workflow admin/users
    #   # => Creates app/cmds/admin/users_workflow.rb
    def copy_files
      name = file_name.sub(/_?workflow$/i, "")
      path = File.join("app/cmds", class_path, "#{name}_workflow.rb")
      template("workflow.rb.tt", path)
    end

    private

    # Ensures the class name ends with "Workflow" suffix.
    #
    # Takes the provided class name and appends "Workflow" if it doesn't already
    # end with that suffix, ensuring consistent naming conventions across
    # all generated workflow classes.
    #
    # @return [String] the class name with "Workflow" suffix
    #
    # @example Class name without suffix
    #   # Given name: "User"
    #   class_name # => "UserWorkflow"
    #
    # @example Class name with suffix
    #   # Given name: "UserWorkflow"
    #   class_name # => "UserWorkflow"
    def class_name
      @class_name ||= super.end_with?("Workflow") ? super : "#{super}Workflow"
    end

    # Determines the parent class for the generated workflow.
    #
    # Attempts to use ApplicationWorkflow as the parent class if it exists in the
    # application, otherwise falls back to CMDx::Workflow as the base class.
    # This allows applications to define their own base workflow class with
    # common functionality.
    #
    # @return [Class] the parent class for the generated workflow
    #
    # @raise [StandardError] if neither ApplicationWorkflow nor CMDx::Workflow are available
    #
    # @example With ApplicationWorkflow defined
    #   parent_class_name # => ApplicationWorkflow
    #
    # @example Without ApplicationWorkflow
    #   parent_class_name # => CMDx::Workflow
    def parent_class_name
      ApplicationWorkflow
    rescue StandardError
      CMDx::Workflow
    end

  end
end
