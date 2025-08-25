# frozen_string_literal: true

module Cmdx
  # Generates CMDx workflow files for Rails applications
  #
  # This generator creates task classes that inherit from either ApplicationTask
  # (if defined) or CMDx::Task. It generates the task file in the standard
  # Rails tasks directory structure.
  class WorkflowGenerator < Rails::Generators::NamedBase

    source_root File.expand_path("templates", __dir__)

    desc "Creates a workflow with the given NAME"

    # Copies the task template to the Rails application
    #
    # Creates a new task file at `app/tasks/[class_path]/[file_name].rb` using
    # the task template. The file is placed in the standard Rails tasks directory
    # structure, maintaining proper namespacing if the task is nested.
    #
    # @return [void]
    #
    # @example Basic usage
    #   rails generate cmdx:workflow SendNotifications
    #   # => Creates app/tasks/send_notifications.rb
    #
    # @example Nested task
    #   rails generate cmdx:workflow Admin::SendNotifications
    #   # => Creates app/tasks/admin/send_notifications.rb
    def copy_files
      path = File.join("app/tasks", class_path, "#{file_name}.rb")
      template("workflow.rb.tt", path)
    end

    private

    # Determines the appropriate parent class name for the generated task
    #
    # Attempts to use ApplicationTask if it exists in the application, otherwise
    # falls back to CMDx::Task. This allows applications to define their own
    # base task class while maintaining compatibility.
    #
    # @return [Class] The parent class for the generated task
    #
    # @example
    #   parent_class_name # => ApplicationTask
    #
    # @example Fallback behavior
    #   parent_class_name # => CMDx::Task
    def parent_class_name
      ApplicationTask
    rescue NameError
      CMDx::Task
    end

  end
end
