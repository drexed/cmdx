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

      # @param workflow [Task & Workflow]
      # @return [void]
      def execute(workflow)
        new(workflow).execute
      end

    end

    # @param workflow [Task & Workflow]
    def initialize(workflow)
      @workflow = workflow
    end

    # Iterates every group in the workflow's pipeline, respecting
    # `:if`/`:unless` and the `:strategy` key. Any group that produces a
    # failed result halts execution by throwing through the workflow.
    #
    # @return [void]
    # @raise [ArgumentError] for an unknown strategy
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

        @workflow.send(:throw!, halt) if halt
      end
    end

    private

    def run_sequential(group)
      continue = group.options[:continue_on_failure]
      failures = group.tasks.each_with_object([]) do |task, bucket|
        result = task.execute(@workflow.context)
        next unless result.failed?

        bucket << result
        break bucket unless continue
      end

      aggregate(failures, continue:)
    end

    def run_parallel(group)
      tasks     = group.tasks
      chain     = Chain.current
      size      = group.options[:pool_size] || tasks.size
      continue  = group.options[:continue_on_failure]
      results   = Array.new(tasks.size)
      mutex     = Mutex.new
      seen_fail = false
      cancelled = false

      jobs = tasks.each_with_index.to_a

      on_job = lambda do |(task_class, index)|
        mutex.synchronize { return if cancelled }

        Fiber[Chain::STORAGE_KEY] ||= chain
        ctx_copy = @workflow.context.deep_dup
        result   = task_class.execute(ctx_copy)

        mutex.synchronize do
          results[index] = result

          if result.failed? && !continue && !seen_fail
            seen_fail = true
            cancelled = true
          end
        end
      end

      executor = @workflow.class.executors.resolve(group.options[:executor])
      merger   = @workflow.class.mergers.resolve(group.options[:merge_strategy])

      executor.call(jobs:, concurrency: size, on_job:)

      failures = []
      results.each do |result|
        next if result.nil?

        if result.failed?
          failures << result
        else
          merger.call(@workflow.context, result)
        end
      end

      aggregate(failures, continue:)
    end

    def aggregate(failures, continue:)
      return if failures.empty?
      return failures.first unless continue

      failures.each do |result|
        prefix = result.task.name

        if result.errors.empty?
          message = result.reason || I18nProxy.t("cmdx.reasons.unspecified")
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
