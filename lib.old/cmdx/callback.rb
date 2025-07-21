# frozen_string_literal: true

module CMDx
  # Base class for implementing callback functionality in task processing.
  #
  # Callbacks are executed at specific points in the task lifecycle, such as
  # before execution, after success, or on failure. All callback implementations
  # must inherit from this class and implement the abstract call method.
  class Callback

    # Executes a callback by creating a new instance and calling it.
    #
    # @param task [CMDx::Task] the task instance triggering the callback
    # @param type [Symbol] the callback type being executed (e.g., :before_execution, :on_success, :on_failure)
    #
    # @return [void]
    #
    # @raise [UndefinedCallError] when the callback subclass doesn't implement call
    #
    # @example Execute a callback for task success
    #   LogSuccessCallback.call(task, :on_success)
    #
    # @example Execute a callback before task execution
    #   SetupCallback.call(task, :before_execution)
    def self.call(task, type)
      new.call(task, type)
    end

    # Abstract method that must be implemented by callback subclasses.
    #
    # This method contains the actual callback logic to be executed at the
    # specified point in the task lifecycle. Subclasses must override this method
    # to provide their specific callback implementation.
    #
    # @param task [CMDx::Task] the task instance triggering the callback
    # @param type [Symbol] the callback type being executed
    #
    # @return [void]
    #
    # @raise [UndefinedCallError] always raised in the base class
    #
    # @example Implement in a subclass
    #   class NotificationCallback < CMDx::Callback
    #     def call(task, type)
    #       puts "Task #{task.class.name} triggered #{type} callback"
    #     end
    #   end
    def call(task, type) # rubocop:disable Lint/UnusedMethodArgument
      raise UndefinedCallError, "call method not defined in #{self.class.name}"
    end

  end
end
