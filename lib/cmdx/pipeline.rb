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
      queue     = Queue.new
      results   = Array.new(tasks.size)
      mutex     = Mutex.new
      failed    = nil

      tasks.each_with_index { |tc, i| queue << [tc, i] }
      size.times { queue << nil }

      workers = Array.new(size) do
        Thread.new do
          Fiber[Chain::STORAGE_KEY] = chain
          while (entry = queue.pop)
            task_class, index = entry
            ctx_copy = @workflow.context.deep_dup
            result   = task_class.execute(ctx_copy)
            mutex.synchronize do
              results[index] = result

              if fail_fast && result.failed? && failed.nil?
                failed = result
                queue.clear
                size.times { queue << nil }
              end
            end
          end
        end
      end

      workers.each(&:join)

      results.each do |result|
        next if result.nil?

        if result.failed?
          failed ||= result
        else
          @workflow.context.merge(result.context)
        end
      end

      failed
    end

  end
end
