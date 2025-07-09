# frozen_string_literal: true

module CMDx
  ##
  # Base class for CMDx middleware that follows Rack-style interface.
  #
  # Middleware components can wrap task execution to provide cross-cutting
  # concerns like logging, authentication, caching, or error handling.
  # Each middleware must implement the `call` method which receives the
  # task instance and a callable that represents the next middleware
  # in the chain.
  #
  # @example Basic middleware implementation
  #   class LoggingMiddleware < CMDx::Middleware
  #     def call(task, callable)
  #       puts "Before executing #{task.class.name}"
  #       result = callable.call(task)
  #       puts "After executing #{task.class.name}"
  #       result
  #     end
  #   end
  #
  # @example Middleware with initialization parameters
  #   class AuthenticationMiddleware < CMDx::Middleware
  #     def initialize(required_role)
  #       @required_role = required_role
  #     end
  #
  #     def call(task, callable)
  #       unless task.context.user&.has_role?(@required_role)
  #         task.fail!(reason: "Insufficient permissions")
  #         return task.result
  #       end
  #       callable.call(task)
  #     end
  #   end
  #
  # @example Short-circuiting middleware
  #   class CachingMiddleware < CMDx::Middleware
  #     def call(task, callable)
  #       cache_key = "#{task.class.name}:#{task.context.to_h.hash}"
  #
  #       if cached_result = Rails.cache.read(cache_key)
  #         task.result.merge!(cached_result)
  #         return task.result
  #       end
  #
  #       result = callable.call(task)
  #       Rails.cache.write(cache_key, result.to_h) if result.success?
  #       result
  #     end
  #   end
  #
  # @see MiddlewareRegistry management
  # @see Task middleware integration
  class Middleware

    def self.call(task, callable)
      new.call(task, callable)
    end

    ##
    # Executes the middleware logic.
    #
    # This method must be implemented by subclasses to define the middleware
    # behavior. The method receives the task instance and a callable that
    # represents the next middleware in the chain or the final task execution.
    #
    # @param task [Task] the task instance being executed
    # @param callable [#call] the next middleware or task execution callable
    # @return [Result] the task execution result
    # @abstract Subclasses must implement this method
    def call(_task, _callable)
      raise UndefinedCallError, "call method not defined in #{self.class.name}"
    end

  end
end
