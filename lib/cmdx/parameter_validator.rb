# frozen_string_literal: true

module CMDx
  # Parameter validation orchestration module for CMDx tasks.
  #
  # The ParameterValidator module provides high-level parameter validation
  # coordination for task instances. It triggers validation of all task
  # parameters and handles validation failure by setting task failure state
  # with appropriate error messages.
  #
  # @example Basic parameter validation
  #   class ProcessOrderTask < CMDx::Task
  #     required :order_id, type: :integer
  #     required :email, type: :string, format: { with: /@/ }
  #   end
  #
  #   task = ProcessOrderTask.new
  #   ParameterValidator.call(task)  # Validates all parameters
  #   # If validation fails, task.failed? => true
  #
  # @example Validation with error handling
  #   task = ProcessOrderTask.new
  #   ParameterValidator.call(task)
  #
  #   if task.failed?
  #     puts task.result.metadata[:reason] # => "order_id is a required parameter. email is invalid"
  #     puts task.errors.messages          # => { order_id: ["is a required parameter"], email: ["is invalid"] }
  #   end
  #
  # @example Successful validation
  #   task = ProcessOrderTask.call(order_id: 123, email: "user@example.com")
  #   # ParameterValidator runs automatically and validation passes
  #   task.success?  # => true
  #
  # @see CMDx::Parameters Parameter collection validation
  # @see CMDx::Parameter Individual parameter definitions
  # @see CMDx::Task Task execution and parameter integration
  module ParameterValidator

    module_function

    # Validates all parameters for a task instance.
    #
    # Triggers validation of all task parameters through the Parameters collection.
    # If any validation errors occur, sets the task to failed state with a
    # comprehensive error message and detailed error information.
    #
    # @param task [CMDx::Task] The task instance to validate parameters for
    # @return [void]
    #
    # @example Validating task parameters
    #   task = MyTask.new
    #   ParameterValidator.call(task)
    #
    #   # If validation fails:
    #   task.failed?                  # => true
    #   task.result.metadata[:reason] # => "Combined error messages from all failed parameters"
    #   task.errors.empty?            # => false
    #
    # @example Validation success
    #   task = MyTask.new  # with valid parameters
    #   ParameterValidator.call(task)
    #
    #   task.errors.empty?  # => true
    #   # Task continues normal execution
    #
    # @note This method is typically called automatically during task execution
    #   before the main task logic runs, ensuring parameter validation occurs
    #   early in the task lifecycle.
    def call(task)
      task.cmd_parameters.validate!(task)
      return if task.errors.empty?

      task.fail!(
        reason: task.errors.full_messages.join(". "),
        messages: task.errors.messages
      )
    end

  end
end
