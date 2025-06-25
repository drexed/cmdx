# frozen_string_literal: true

module Cmdx
  ##
  # Rails generator for creating CMDx task classes.
  #
  # This generator creates individual task files that encapsulate specific
  # business logic operations. Tasks inherit from CMDx::Task and provide
  # parameter validation, hooks, result tracking, and error handling
  # capabilities for focused business operations.
  #
  # The generator handles name normalization, ensuring "Task" suffix
  # and proper file naming conventions. Generated tasks inherit from
  # ApplicationTask when available, falling back to CMDx::Task.
  #
  # @example Generate a task
  #   rails generate cmdx:task SendEmail
  #   rails generate cmdx:task ProcessPayment
  #   rails generate cmdx:task ProcessPaymentTask  # "Task" suffix preserved
  #
  # @example Generated file location
  #   app/cmds/send_email_task.rb
  #   app/cmds/process_payment_task.rb
  #
  # @since 1.0.0
  class TaskGenerator < Rails::Generators::NamedBase

    source_root File.expand_path("templates", __dir__)
    check_class_collision suffix: "Task"

    desc "Creates a task with the given NAME"

    ##
    # Copies the task template to the application commands directory.
    #
    # Creates a new task file in `app/cmds/` with the normalized name.
    # The generator automatically handles:
    # - Removing "Task" suffix from file naming
    # - Converting to snake_case for file naming
    # - Adding "_task" suffix to the filename
    # - Setting up proper class inheritance
    #
    # @return [void]
    # @raise [Thor::Error] if the destination file cannot be created
    #
    # @example Generated task structure
    #   class SendEmailTask < ApplicationTask
    #     def call
    #       # Task business logic
    #     end
    #   end
    def copy_files
      name = file_name.sub(/_?task$/i, "")
      path = File.join("app/cmds", class_path, "#{name}_task.rb")
      template("task.rb.tt", path)
    end

    private

    ##
    # Normalizes the class name by ensuring "Task" suffix.
    #
    # Ensures consistent class naming by adding "Task" suffix if not
    # already present, allowing users to specify either "SendEmail"
    # or "SendEmailTask".
    #
    # @return [String] the normalized class name with "Task" suffix
    #
    # @example Class name normalization
    #   # Input: "SendEmail"
    #   # Output: "SendEmailTask"
    #
    #   # Input: "SendEmailTask"
    #   # Output: "SendEmailTask"
    def class_name
      @class_name ||= super.end_with?("Task") ? super : "#{super}Task"
    end

    ##
    # Determines the parent class for the generated task.
    #
    # Attempts to use ApplicationTask as the parent class if available,
    # falling back to CMDx::Task if ApplicationTask is not defined.
    # This allows applications to define custom base task behavior.
    #
    # @return [String] the parent class name to inherit from
    #
    # @example Parent class resolution
    #   # If ApplicationTask exists: "ApplicationTask"
    #   # If ApplicationTask missing: "CMDx::Task"
    def parent_class_name
      ApplicationTask
    rescue StandardError
      CMDx::Task
    end

  end
end
