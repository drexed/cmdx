# frozen_string_literal: true

module CMDx
  class Executors
    # Fiber-scheduler backed executor. Spawns one fiber per job, bounded by
    # `concurrency` via a `SizedQueue` semaphore. Requires a Fiber scheduler to
    # be installed on the current thread (e.g. inside `Async { ... }` from the
    # `async` gem). `pool_size` caps in-flight fibers. Exceptions raised inside
    # `on_job` are captured and re-raised once every fiber has completed.
    #
    # @api private
    module Fiber

      extend self

      # @param jobs [Array]
      # @param concurrency [Integer] max in-flight fibers (must be >= 1)
      # @param on_job [#call]
      # @return [void]
      # @raise [ArgumentError] when `concurrency` is not a positive Integer
      # @raise [RuntimeError] when no `Fiber.scheduler` is installed
      # @raise [StandardError] re-raises the first exception captured from any fiber
      def call(jobs:, concurrency:, on_job:)
        raise ArgumentError, "executor concurrency must be a positive Integer (got #{concurrency.inspect})" unless concurrency.is_a?(Integer) && concurrency.positive?

        raise "executor: :fibers requires Fiber.scheduler; run the workflow inside a scheduler block (e.g. Async { ... })" unless ::Fiber.scheduler

        slots = SizedQueue.new(concurrency)
        concurrency.times { slots << :slot }
        done   = Queue.new
        errors = Queue.new

        jobs.each do |job|
          slots.pop
          ::Fiber.schedule do
            begin
              on_job.call(job)
            rescue StandardError => e
              errors << e
            end
          ensure
            slots << :slot
            done << true
          end
        end

        jobs.size.times { done.pop }

        raise errors.pop unless errors.empty?
      end

    end
  end
end
