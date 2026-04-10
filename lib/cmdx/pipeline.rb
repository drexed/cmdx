# frozen_string_literal: true

module CMDx
  # Runs a sequence of child tasks within a workflow.
  # Supports sequential steps and parallel groups.
  module Pipeline

    # @param entries [Array<Hash>] workflow pipeline entries
    # @param context [Context]
    # @param chain [Chain]
    # @param trace [Trace]
    # @param on_failure [Symbol, nil]
    # @return [void]
    #
    # @rbs (Array[Hash[Symbol, untyped]] entries, Context context, Chain chain, Trace trace, ?Symbol? on_failure) -> void
    def self.call(entries, context, chain, trace, on_failure = nil)
      entries.each do |entry|
        if entry[:parallel]
          run_parallel(entry[:tasks], context, chain, trace, on_failure)
        else
          run_sequential(entry, context, chain, trace, on_failure)
        end
      end
    end

    # @rbs (Hash[Symbol, untyped] entry, Context context, Chain chain, Trace trace, Symbol? on_failure) -> void
    def self.run_sequential(entry, context, _chain, trace, on_failure)
      task_class = entry[:task_class]
      options = entry[:options] || {}

      return unless condition_met?(options, context)

      trace.child
      result = task_class.execute(**context.to_h)
      context.merge!(result.context.to_h) if result.success?

      return if result.success?

      handle_failure(result, on_failure, entry)
    end

    # @rbs (Array[Array[untyped]] tasks, Context context, Chain chain, Trace trace, Symbol? on_failure) -> void
    def self.run_parallel(tasks, context, chain, trace, on_failure)
      results = Parallelizer.call(tasks, context, chain, trace)

      results.each do |result|
        context.merge!(result.context.to_h) if result.success?
        handle_failure(result, on_failure, {}) unless result.success?
      end
    end

    # @rbs (Hash[Symbol, untyped] options, Context context) -> bool
    def self.condition_met?(options, context)
      return Utils::Condition.evaluate(context, options[:if]) if options[:if]

      return !Utils::Condition.evaluate(context, options[:unless]) if options[:unless]

      true
    end

    # @rbs (Result result, Symbol? on_failure, Hash[Symbol, untyped] entry) -> void
    def self.handle_failure(result, on_failure, entry)
      strategy = entry.dig(:options, :on_failure) || on_failure

      case strategy
      when :skip, :none then nil
      else
        raise FailFault.new(result.reason, result:) if result.strict?
      end
    end

    private_class_method :run_sequential, :run_parallel, :condition_met?, :handle_failure

  end
end
