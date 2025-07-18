# frozen_string_literal: true

module CMDx
  # Base class for implementing middleware functionality in task processing pipelines.
  #
  # Middleware provides a way to wrap task execution with custom logic that runs before
  # and after task processing. Middleware can be used for cross-cutting concerns such as
  # logging, authentication, caching, error handling, and other aspects that should be
  # applied consistently across multiple tasks. All middleware implementations must
  # inherit from this class and implement the abstract call method.
  class Middleware

    # Executes middleware by creating a new instance and calling it.
    #
    # This class method provides a convenient way to execute middleware without
    # manually instantiating the middleware class. It creates a new instance
    # and delegates to the instance call method with the provided arguments.
    #
    # @param task [CMDx::Task] the task instance being processed
    # @param callable [Proc] the callable that executes the next middleware or task logic
    #
    # @return [Object] the result returned by the middleware implementation
    #
    # @raise [UndefinedCallError] when the middleware subclass doesn't implement call
    #
    # @example Execute middleware on a task
    #   class LoggingMiddleware < CMDx::Middleware
    #     def call(task, callable)
    #       task.logger.info "Starting #{task.class.name}"
    #       result = callable.call
    #       task.logger.info "Completed #{task.class.name}"
    #       result
    #     end
    #   end
    #
    #   LoggingMiddleware.call(my_task, -> { my_task.process })
    def self.call(task, callable)
      new.call(task, callable)
    end

    # Abstract method that must be implemented by middleware subclasses.
    #
    # This method contains the actual middleware logic that wraps task execution.
    # Subclasses must override this method to provide their specific middleware
    # implementation. The method should call the provided callable to continue
    # the middleware chain or execute the task logic.
    #
    # @param _task [CMDx::Task] the task instance being processed
    # @param _callable [Proc] the callable that executes the next middleware or task logic
    #
    # @return [Object] the result of the middleware processing
    #
    # @raise [UndefinedCallError] always raised in the base class
    #
    # @example Implement middleware in a subclass
    #   class TimingMiddleware < CMDx::Middleware
    #     def call(task, callable)
    #       start_time = Time.now
    #       result = callable.call
    #       duration = Time.now - start_time
    #       task.logger.info "Task completed in #{duration}s"
    #       result
    #     end
    #   end
    def call(_task, _callable)
      raise UndefinedCallError, "call method not defined in #{self.class.name}"
    end

  end
end
