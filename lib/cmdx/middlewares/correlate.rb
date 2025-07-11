# frozen_string_literal: true

module CMDx
  module Middlewares
    # Middleware that manages correlation IDs for task execution tracing.
    # Automatically generates or uses provided correlation IDs to track task execution
    # across complex workflows, enabling better debugging and monitoring.
    class Correlate < CMDx::Middleware

      # @return [String, Symbol, Proc, nil] The explicit correlation ID to use, or callable that generates one
      attr_reader :id

      # @return [Hash] The conditional options for correlation application
      attr_reader :conditional

      # Initializes the correlation middleware with optional configuration.
      #
      # @param options [Hash] configuration options for the middleware
      # @option options [String, Symbol, Proc] :id explicit correlation ID or callable to generate one
      # @option options [Symbol, Proc] :if condition that must be truthy to apply correlation
      # @option options [Symbol, Proc] :unless condition that must be falsy to apply correlation
      #
      # @return [Correlate] new instance of the middleware
      #
      # @example Register with a middleware instance
      #   use :middleware, CMDx::Middlewares::Correlate.new(id: "request-123")
      #
      # @example Register with explicit ID
      #   use :middleware, CMDx::Middlewares::Correlate, id: "request-123"
      #
      # @example Register with dynamic ID generation
      #   use :middleware, CMDx::Middlewares::Correlate, id: -> { SecureRandom.uuid }
      #
      # @example Register with conditions
      #   use :middleware, CMDx::Middlewares::Correlate, if: :production?, unless: :testing?
      def initialize(options = {})
        @id          = options[:id]
        @conditional = options.slice(:if, :unless)
      end

      # Executes the middleware, wrapping task execution with correlation context.
      # Evaluates conditions, determines correlation ID, and executes the task within
      # the correlation context for tracing purposes.
      #
      # @param task [CMDx::Task] the task being executed
      # @param callable [Proc] the callable that executes the task
      #
      # @return [Object] the result of the task execution
      #
      # @example Task using correlation middleware
      #   class ProcessOrderTask < CMDx::Task
      #     use :middleware, CMDx::Middlewares::Correlate, id: "trace-123"
      #
      #     def call
      #       # Task execution is automatically wrapped with correlation
      #     end
      #   end
      #
      # @example Global configuration with conditional tracing
      #   CMDx.configure do |config|
      #     config.middlewares.register CMDx::Middlewares::Correlate, if: :should_trace?
      #   end
      def call(task, callable)
        # Check if correlation should be applied based on conditions
        return callable.call(task) unless task.cmdx_eval(conditional)

        # Get correlation ID using yield for dynamic generation
        correlation_id = task.cmdx_yield(id) ||
                         CMDx::Correlator.id ||
                         task.chain.id ||
                         CMDx::Correlator.generate

        # Execute task with correlation context
        CMDx::Correlator.use(correlation_id) do
          callable.call(task)
        end
      end

    end
  end
end
