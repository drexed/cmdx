# frozen_string_literal: true

module CMDx
  # Runs a Workflow's declared task groups. Each group selects a strategy
  # (`:sequential` by default, or `:parallel`). A group failure halts the
  # pipeline by echoing the failed result's signal through `throw!`, which
  # bubbles up through Runtime as the workflow's own failure.
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
      group.tasks.each do |task|
        result = task.execute(@workflow.context)
        return result if result.failed?
      end

      nil
    end

    def run_parallel(group)
      tasks     = group.tasks
      chain     = Chain.current
      size      = group.options[:pool_size] || tasks.size
      fail_fast = group.options[:fail_fast]
      results   = Array.new(tasks.size)
      mutex     = Mutex.new
      failed    = nil
      cancelled = false

      jobs = tasks.each_with_index.to_a

      on_job = lambda do |(task_class, index)|
        mutex.synchronize { return if cancelled }

        Fiber[Chain::STORAGE_KEY] ||= chain
        ctx_copy = @workflow.context.deep_dup
        result   = task_class.execute(ctx_copy)

        mutex.synchronize do
          results[index] = result

          if fail_fast && result.failed? && failed.nil?
            failed    = result
            cancelled = true
          end
        end
      end

      executor = @workflow.class.executors.resolve(group.options[:executor])
      merger   = @workflow.class.mergers.resolve(group.options[:merge_strategy])

      executor.call(jobs:, concurrency: size, on_job:)

      results.each do |result|
        next if result.nil?

        if result.failed?
          failed ||= result
        else
          merger.call(@workflow.context, result)
        end
      end

      failed
    end

  end
end
