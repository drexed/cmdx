# frozen_string_literal: true

module Cmdx
  # Rails generator for creating CMDx task files.
  #
  # This generator creates task files in the app/cmds directory with proper
  # class naming conventions and inheritance. It ensures task names end with
  # "Task" suffix and creates files in the correct location within the Rails
  # application structure.
  class TaskGenerator < Rails::Generators::NamedBase

    source_root File.expand_path("templates", __dir__)
    check_class_collision suffix: "Task"

    desc "Creates a task with the given NAME"

    # Creates the task file from the template.
    #
    # Generates a new task file in the app/cmds directory based on the provided
    # name. The file name is normalized to ensure it ends with "_task.rb" and
    # is placed in the appropriate subdirectory structure.
    #
    # @return [void]
    #
    # @example Generate a user task
    #   rails generate cmdx:task user
    #   #=> Creates app/cmds/user_task.rb
    #
    # @example Generate a nested task
    #   rails generate cmdx:task admin/users
    #   #=> Creates app/cmds/admin/users_task.rb
    def copy_files
      name = file_name.sub(/_?task$/i, "")
      path = File.join("app/cmds", class_path, "#{name}_task.rb")
      template("task.rb.tt", path)
    end

    private

    # Ensures the class name ends with "Task" suffix.
    #
    # Takes the provided class name and appends "Task" if it doesn't already
    # end with that suffix, ensuring consistent naming conventions across
    # all generated task classes.
    #
    # @return [String] the class name with "Task" suffix
    #
    # @example Class name without suffix
    #   # Given name: "User"
    #   class_name #=> "UserTask"
    #
    # @example Class name with suffix
    #   # Given name: "UserTask"
    #   class_name #=> "UserTask"
    def class_name
      @class_name ||= super.end_with?("Task") ? super : "#{super}Task"
    end

    # Determines the parent class for the generated task.
    #
    # Attempts to use ApplicationTask as the parent class if it exists in the
    # application, otherwise falls back to CMDx::Task as the base class.
    # This allows applications to define their own base task class with
    # common functionality.
    #
    # @return [Class] the parent class for the generated task
    #
    # @raise [StandardError] if neither ApplicationTask nor CMDx::Task are available
    #
    # @example With ApplicationTask defined
    #   parent_class_name #=> ApplicationTask
    #
    # @example Without ApplicationTask
    #   parent_class_name #=> CMDx::Task
    def parent_class_name
      ApplicationTask
    rescue StandardError
      CMDx::Task
    end

  end
end
