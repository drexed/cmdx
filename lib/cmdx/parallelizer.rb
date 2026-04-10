# frozen_string_literal: true

module CMDx
  # Bounded thread pool for parallel workflow steps.
  # Preserves insertion order and re-raises the first error.
  module Parallelizer

    # @param tasks [Array<Array>] [[task_class, options], ...]
    # @param context [Context]
    # @param chain [Chain]
    # @param trace [Trace]
    # @return [Array<Result>]
    #
    # @rbs (Array[Array[untyped]] tasks, Context context, Chain chain, Trace trace) -> Array[Result]
    def self.call(tasks, context, _chain, trace)
      results = ::Array.new(tasks.size)
      errors = []
      threads = tasks.each_with_index.map do |entry, idx|
        Thread.new do
          task_class, = entry
          child_trace = trace.child
          result = task_class.execute(**context.to_h, _trace: child_trace)
          results[idx] = result
        rescue StandardError => e
          errors << e
        end
      end

      threads.each(&:join)
      raise errors.first if errors.any?

      results.compact
    end

  end
end
