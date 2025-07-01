# frozen_string_literal: true

require "table_tennis"

module CMDx
  module Middlewares
    ##
    # Debug middleware that displays a formatted table of chain execution results
    # when debugging conditions are met.
    #
    # This middleware automatically outputs a visual representation of the entire
    # chain execution using TableTennis formatting. It only displays output for
    # the first task in a chain (index 0) and when the specified conditional
    # criteria are satisfied.
    #
    # @example Basic usage
    #   class MyTask < CMDx::Task
    #     middleware CMDx::Middlewares::Debug
    #   end
    #
    # @example Conditional debugging
    #   class MyTask < CMDx::Task
    #     middleware CMDx::Middlewares::Debug, if: :development?
    #   end
    #
    # @example Debug only on failure
    #   class MyTask < CMDx::Task
    #     middleware CMDx::Middlewares::Debug, unless: -> { result.success? }
    #   end
    class Debug < CMDx::Middleware

      # @return [Hash] The conditional options for debug output application
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

      ##
      # Executes the middleware logic and conditionally displays debug output.
      #
      # This method calls the next middleware/task in the chain, then checks if
      # debug output should be displayed. Debug output is shown only for the first
      # task in a chain (index 0) and when conditional criteria are met.
      #
      # The debug output includes a formatted table showing:
      # - Task index, type, class, and ID
      # - Task tags and outcome status
      # - Metadata and runtime information
      # - Final chain outcome and total runtime
      #
      # @param task [CMDx::Task] The task being executed
      # @param callable [Proc] The next middleware or task to call
      # @return [CMDx::Result] The result from the task execution
      def call(task, callable)
        callable.call(task)

        if task.result.index.zero? && task.__cmdx_eval(conditional)
          h = task.chain.to_h
          r = h[:results]
          r << {
            index: nil,
            type: nil,
            class: nil,
            id: nil,
            tags: nil,
            outcome: h[:outcome],
            metadata: nil,
            runtime: h[:runtime]
          }

          puts TableTennis.new(
            r,
            title: "#{task.class.name} Chain: #{h[:id]}",
            headers: { index: "idx", runtime: "runtime (ms)" },
            columns: %i[index type class id tags outcome metadata runtime],
            mark: ->(row) { ["white", ResultAnsi.color(row[:outcome]).to_s, :bold] if row[:index].nil? },
            titleize: true
          )
        end

        task.result
      end

    end
  end
end
