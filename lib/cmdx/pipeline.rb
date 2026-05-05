# frozen_string_literal: true

module CMDx
  # Runs a Workflow's declared task groups. Each group selects a strategy
  # (`:sequential` by default, or `:parallel`). A group failure halts the
  # pipeline by echoing the failed result's signal through `throw!`, which
  # bubbles up through Runtime as the workflow's own failure.
  #
  # Groups may opt into batch semantics with `continue_on_failure: true`,
  # in which case every task in the group runs to completion and all
  # failures are aggregated into the workflow's `errors` (keyed as
  # `"TaskClass.input"` for input/validation errors and `"TaskClass.<status>"`
  # for bare `fail!` reasons) before the pipeline halts on the first
  # failure (declaration order).
  #
  # @see Workflow
  class Pipeline

    class << self

      # @param workflow [Task] workflow instance whose class includes {Workflow}
      # @return [void]
      def execute(workflow)
        new(workflow).execute
      end

    end

    # @param workflow [Task] workflow instance whose class includes {Workflow}
    def initialize(workflow)
      @workflow = workflow
      @executed = []
    end

    # Iterates every group in the workflow's pipeline, respecting
    # `:if`/`:unless` and the `:strategy` key. Any group that produces a
    # failed result halts execution by throwing through the workflow.
    #
    # On halt, every previously executed task instance whose result is
    # `success?` is sent `#rollback` (when defined) in reverse execution
    # order, providing saga-style compensation. Each compensated result
    # has its `:rolled_back` option flipped to `true`. Skipped tasks are
    # excluded; the failing task itself is rolled back by {Runtime} and
    # is not re-invoked here. Exceptions raised inside a compensator
    # propagate — handling them is the developer's responsibility.
    #
    # @return [void]
    # @raise [ArgumentError] for an unknown strategy
    # @raise [StandardError] anything raised by a task's `#rollback`
    def execute
      @workflow.class.pipeline.each do |group|
        next unless Util.satisfied?(group.options[:if], group.options[:unless], @workflow)

        halt =
          case strategy = group.options[:strategy]
          when :sequential, NilClass
            run_sequential(group)
          when :parallel
            run_parallel(group)
          else
            raise ArgumentError, "invalid strategy: #{strategy.inspect}"
          end

        next unless halt

        rollback_executed!
        @workflow.send(:throw!, halt)
      end
    end

    private

    # @param group [Workflow::ExecutionGroup]
    # @return [Result, nil] failed result to halt on, or nil when the group succeeds
    def run_sequential(group)
      continue = group.options[:continue_on_failure]
      failures = group.tasks.each_with_object([]) do |task_class, bucket|
        instance = task_class.new(@workflow.context)
        result   = instance.execute(strict: false)
        @executed << [instance, result]
        next unless result.failed?

        bucket << result
        break bucket unless continue
      end

      aggregate(failures, continue:)
    end

    # @param group [Workflow::ExecutionGroup]
    # @return [Result, nil] failed result to halt on, or nil when the group succeeds
    def run_parallel(group)
      tasks     = group.tasks
      chain     = Chain.current
      size      = group.options[:pool_size] || tasks.size
      continue  = group.options[:continue_on_failure]
      entries   = Array.new(tasks.size)
      mutex     = Mutex.new
      seen_fail = false
      cancelled = false

      jobs = tasks.each_with_index.to_a

      on_job = lambda do |(task_class, index)|
        mutex.synchronize { return if cancelled }

        Fiber[Chain::STORAGE_KEY] ||= chain
        ctx_copy = @workflow.context.deep_dup
        instance = task_class.new(ctx_copy)
        result   = instance.execute(strict: false)

        mutex.synchronize do
          entries[index] = [instance, result]

          if result.failed? && !continue && !seen_fail
            seen_fail = true
            cancelled = true
          end
        end
      end

      executor = @workflow.class.executors.resolve(group.options[:executor])
      merger   = @workflow.class.mergers.resolve(group.options[:merger])

      executor.call(jobs:, concurrency: size, on_job:)

      failures = []
      entries.each do |entry|
        next if entry.nil?

        @executed << entry
        _instance, result = entry

        if result.failed?
          failures << result
        else
          merger.call(@workflow.context, result)
        end
      end

      aggregate(failures, continue:)
    end

    def rollback_executed!
      @executed.reverse_each do |instance, result|
        next unless result.success?
        next unless instance.respond_to?(:rollback)

        instance.rollback

        old_opts = result.instance_variable_get(:@options)
        new_opts = old_opts.merge(rolled_back: true).freeze
        result.instance_variable_set(:@options, new_opts)
      end
    end

    # @param failures [Array<Result>]
    # @param continue [Boolean] when true, merges failures into the workflow's errors
    # @return [Result, nil] first failure (echoed upstream), or nil when `failures` is empty
    def aggregate(failures, continue:)
      return if failures.empty?
      return failures.first unless continue

      failures.each do |result|
        prefix = result.task.name

        if result.errors.empty?
          message = I18nProxy.tr(result.reason)
          @workflow.errors.add(:"#{prefix}.#{result.status}", message)
        else
          result.errors.each do |key, messages|
            namespaced = :"#{prefix}.#{key}"
            messages.each { |message| @workflow.errors.add(namespaced, message) }
          end
        end
      end

      failures.first
    end

  end
end
