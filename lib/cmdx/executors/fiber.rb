# frozen_string_literal: true

module CMDx
  class Executors
    # Fiber-scheduler backed executor. Spawns one fiber per job, bounded by
    # `concurrency` via a `SizedQueue` semaphore. Requires a Fiber scheduler to
    # be installed on the current thread (e.g. inside `Async { ... }` from the
    # `async` gem). `pool_size` caps in-flight fibers.
    #
    # @api private
    module Fiber

      extend self

      # @param jobs [Array]
      # @param concurrency [Integer] max in-flight fibers
      # @param on_job [#call]
      # @return [void]
      # @raise [RuntimeError] when no `Fiber.scheduler` is installed
      def call(jobs:, concurrency:, on_job:)
        raise "executor: :fibers requires Fiber.scheduler; run the workflow inside a scheduler block (e.g. Async { ... })" unless ::Fiber.scheduler

        slots = SizedQueue.new(concurrency)
        concurrency.times { slots << :slot }
        done = Queue.new

        jobs.each do |job|
          slots.pop
          ::Fiber.schedule do
            on_job.call(job)
          ensure
            slots << :slot
            done << true
          end
        end

        jobs.size.times { done.pop }
      end

    end
  end
end
