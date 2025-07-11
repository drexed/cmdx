# frozen_string_literal: true

module CMDx
  # Base class for implementing callback functionality in task execution.
  #
  # Callbacks are executed at specific points during task lifecycle to
  # provide hooks for custom behavior, logging, validation, or cleanup.
  # All callback implementations must inherit from this class and implement
  # the abstract call method.
  #
  # @since 1.0.0
  class Callback

    # Executes a callback by creating a new instance and calling it.
    #
    # @param task [Task] the task instance executing the callback
    # @param type [Symbol] the callback type identifier
    #
    # @return [Object] the result of the callback execution
    #
    # @raise [UndefinedCallError] when the callback subclass doesn't implement call
    #
    # @example Execute a callback on a task
    #   MyCallback.call(task, :before)
    def self.call(task, type)
      new.call(task, type)
    end

    # Abstract method that must be implemented by callback subclasses.
    #
    # This method contains the actual callback logic to be executed.
    # Subclasses must override this method to provide their specific
    # callback implementation.
    #
    # @param _task [Task] the task instance executing the callback
    # @param _type [Symbol] the callback type identifier
    #
    # @return [Object] the result of the callback execution
    #
    # @raise [UndefinedCallError] always raised in the base class
    #
    # @example Implement in a subclass
    #   def call(task, type)
    #     puts "Executing #{type} callback for #{task.class.name}"
    #   end
    def call(_task, _type)
      raise UndefinedCallError, "call method not defined in #{self.class.name}"
    end

  end
end
