# frozen_string_literal: true

module CMDx
  module Testing
    # Middleware builder utilities for creating test middleware classes
    #
    # This module provides convenient methods for creating CMDx::Middleware classes
    # for testing purposes. While tests can use manual `Class.new(CMDx::Middleware)`
    # patterns, these builders offer semantic shortcuts for common test scenarios.
    #
    # @note These builders are optional - tests can use direct `Class.new(CMDx::Middleware)`
    #   for maximum control and transparency, or these builders for convenience
    #   and improved semantic clarity.
    #
    # @example Manual vs Builder Approach
    #   # Manual approach (explicit, full control)
    #   middleware_class = Class.new(CMDx::Middleware) do
    #     def self.name
    #       "LoggingMiddleware"
    #     end
    #
    #     def call(task, callable)
    #       # Custom middleware logic
    #       task.logger&.info("Before task execution")
    #       result = callable.call(task)
    #       task.logger&.info("After task execution")
    #       result
    #     end
    #   end
    #
    #   # Builder approach (semantic, convenient)
    #   middleware_class = create_simple_middleware(name: "LoggingMiddleware")
    #
    # @example When to Use Manual vs Builder
    #   # Use manual approach when:
    #   # - You need complex custom behavior
    #   # - The test scenario is unique or highly specific
    #   # - You want maximum transparency in the test
    #
    #   # Use builder approach when:
    #   # - Testing common middleware scenarios
    #   # - You want semantic clarity in test intent
    #   # - You need consistent test patterns across the codebase
    #
    # @since 1.0.0
    module MiddlewareBuilders

      # @group Basic Middleware Creation

      # Creates a new middleware class with optional configuration
      #
      # This is the foundation method for creating CMDx middleware classes. It provides
      # a clean interface for creating middleware classes with optional naming and
      # custom behavior through block evaluation.
      #
      # @param name [String] name for the middleware class (defaults to "AnonymousMiddleware")
      # @param block [Proc] optional block to evaluate in middleware class context
      # @return [Class] new middleware class inheriting from CMDx::Middleware
      #
      # @example Basic middleware class creation
      #   middleware_class = create_middleware_class do
      #     def call(task, callable)
      #       task.context.middleware_executed = true
      #       callable.call(task)
      #     end
      #   end
      #
      # @example Named middleware class with custom behavior
      #   middleware_class = create_middleware_class(name: "TimingMiddleware") do
      #     def call(task, callable)
      #       start_time = Time.now
      #       result = callable.call(task)
      #       end_time = Time.now
      #       task.context.execution_time = end_time - start_time
      #       result
      #     end
      #   end
      #
      # @example Middleware class with error handling
      #   middleware_class = create_middleware_class(name: "ErrorHandlingMiddleware") do
      #     def call(task, callable)
      #       begin
      #         callable.call(task)
      #       rescue StandardError => e
      #         task.logger&.error("Task failed: #{e.message}")
      #         task.result.fail!(reason: e.message, original_exception: e)
      #       end
      #     end
      #   end
      def create_middleware_class(name: "AnonymousMiddleware", &block)
        middleware_class = Class.new(CMDx::Middleware)
        middleware_class.define_singleton_method(:name) { name }
        middleware_class.class_eval(&block) if block_given?
        middleware_class
      end

      # Creates a simple middleware that performs basic pass-through functionality
      #
      # This is the most basic middleware type, useful for testing middleware execution
      # flow without complex logic. It simply calls the task and passes through the result.
      # This can be extended with additional behavior through the block parameter.
      #
      # @param name [String] name for the middleware class (defaults to "SimpleMiddleware")
      # @param block [Proc] optional block for additional configuration
      # @return [Class] middleware class with basic call method implementation
      #
      # @example Basic usage
      #   middleware_class = create_simple_middleware
      #   middleware_instance = middleware_class.new
      #   result = middleware_instance.call(task, callable) # Passes through
      #
      # @example Named simple middleware
      #   middleware_class = create_simple_middleware(name: "ProcessingMiddleware")
      #   expect(middleware_class.name).to eq("ProcessingMiddleware")
      #
      # @example Simple middleware with additional behavior
      #   middleware_class = create_simple_middleware(name: "AuditMiddleware") do
      #     # Override the call method for custom behavior
      #     define_method :call do |task, callable|
      #       task.context.audit_log ||= []
      #       task.context.audit_log << "middleware_before"
      #       result = super(task, callable) # Call the default implementation
      #       task.context.audit_log << "middleware_after"
      #       result
      #     end
      #   end
      #
      # @example Using in RSpec tests
      #   let(:middleware_class) { create_simple_middleware(name: "TestMiddleware") }
      #
      #   it "executes middleware without error" do
      #     middleware = middleware_class.new
      #     callable = -> (task) { task.call }
      #     expect { middleware.call(task, callable) }.not_to raise_error
      #   end
      def create_simple_middleware(name: "SimpleMiddleware", &block)
        create_middleware_class(name: name) do
          define_method :call do |task, callable|
            callable.call(task)
          end

          class_eval(&block) if block_given?
        end
      end

    end
  end
end
