# frozen_string_literal: true

module CMDx
  # Executes a series of task entries sequentially or in parallel.
  # Used by Workflow to orchestrate multi-task execution.
  class Pipeline

    # @param entries [Array<Hash>] the task entries to execute
    # @param context [Context] shared execution context
    # @param chain [Chain] the result chain
    #
    # @return [Chain] the chain with all results
    #
    # @rbs (Array[Hash[Symbol, untyped]] entries, Context context, Chain chain) -> Chain
    def self.call(entries, context, chain)
      new(entries, context, chain).call
    end

    # @rbs (Array[Hash[Symbol, untyped]] entries, Context context, Chain chain) -> void
    def initialize(entries, context, chain)
      @entries = entries
      @context = context
      @chain = chain
    end

    # @rbs () -> Chain
    def call
      @entries.each do |entry|
        if entry[:parallel]
          execute_parallel(entry[:tasks])
        else
          result = execute_task(entry)
          break if should_halt?(result, entry)
        end
      end
      @chain
    end

    private

    # @rbs (Hash[Symbol, untyped] entry) -> Result
    def execute_task(entry)
      task_class = entry[:task]
      options = entry.fetch(:options, {})

      result = task_class.execute(**@context.to_h)

      if result.bad? && options[:on_failure] == :skip
        # Continue execution despite failure
      elsif result.bad? && result.strict?
        # Halt on strict failures (default)
      end

      result
    end

    # @rbs (Array[Hash[Symbol, untyped]] tasks) -> Array[Result]
    def execute_parallel(tasks)
      pool_size = tasks.first&.dig(:options, :pool_size) || 5
      parallelizer = Parallelizer.new(pool_size)

      parallelizer.call(tasks) do |entry|
        entry[:task].execute(**@context.to_h)
      end
    end

    # @rbs (Result result, Hash[Symbol, untyped] entry) -> bool
    def should_halt?(result, entry)
      return false if result.success?

      on_failure = entry.dig(:options, :on_failure)
      return false if %i[skip none].include?(on_failure)

      result.strict?
    end

  end
end
