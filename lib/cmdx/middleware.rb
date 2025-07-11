# frozen_string_literal: true

module CMDx
  # Base class for implementing middleware functionality in task execution.
  #
  # Middleware provides a way to wrap task execution with custom behavior
  # such as logging, timing, authentication, or other cross-cutting concerns.
  # All middleware implementations must inherit from this class and implement
  # the abstract call method.
  #
  # @since 1.0.0
  class Middleware

    # Executes middleware by creating a new instance and calling it.
    #
    # @param task [Task] the task instance being wrapped by the middleware
    # @param callable [Proc] the callable object to execute within the middleware
    #
    # @return [Object] the result of the middleware execution
    #
    # @raise [UndefinedCallError] when the middleware subclass doesn't implement call
    #
    # @example Execute middleware on a task
    #   MyMiddleware.call(task, -> { task.perform })
    def self.call(task, callable)
      new.call(task, callable)
    end

    # Abstract method that must be implemented by middleware subclasses.
    #
    # This method contains the actual middleware logic to be executed.
    # Subclasses must override this method to provide their specific
    # middleware implementation that wraps the callable execution.
    #
    # @param _task [Task] the task instance being wrapped by the middleware
    # @param _callable [Proc] the callable object to execute within the middleware
    #
    # @return [Object] the result of the middleware execution
    #
    # @raise [UndefinedCallError] always raised in the base class
    #
    # @example Implement in a subclass
    #   def call(task, callable)
    #     puts "Before #{task.class.name} execution"
    #     result = callable.call
    #     puts "After #{task.class.name} execution"
    #     result
    #   end
    def call(_task, _callable)
      raise UndefinedCallError, "call method not defined in #{self.class.name}"
    end

  end
end
