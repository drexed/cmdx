# frozen_string_literal: true

module CMDx
  module Middlewares
    class Debug < CMDx::Middleware

      # @return [Hash] The conditional options for timeout application
      attr_reader :conditional

      ##
      # Initializes the debug middleware.
      #
      # @param options [Hash] Configuration options for the debug middleware
      # @option options [Symbol, Proc] :if Condition that must be truthy for debug to be applied
      # @option options [Symbol, Proc] :unless Condition that must be falsy for debug to be applied
      def initialize(options = {})
        @conditional = options.slice(:if, :unless)
      end

      def call(task, callable)
        callable.call(task)
        puts task.run if task.result.index.zero? && task.__cmdx_eval(conditional)
        task.result
      end

    end
  end
end

# class SampleTask < CMDx::Task

#   def call
#     # Do work...
#   end

# end

# class TestTask < CMDx::Task

#   use CMDx::Middlewares::Debug

#   def call
#     SampleTask.call(context)
#   end

# end; TestTask.call
