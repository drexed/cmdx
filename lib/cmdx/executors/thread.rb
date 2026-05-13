# frozen_string_literal: true

module CMDx
  class Executors
    # Default executor. Uses a fixed-size `Thread` pool drained via a `Queue`;
    # sentinel `nil`s terminate workers. Workers inherit the parent's chain via
    # fiber-local storage. Exceptions raised inside `on_job` are captured per
    # worker and re-raised on the main thread once every worker has joined, so
    # callers see failures instead of silently dropped jobs.
    #
    # @api private
    module Thread

      extend self

      # @param jobs [Array] opaque job objects forwarded to `on_job`
      # @param concurrency [Integer] worker count (must be >= 1)
      # @param on_job [#call] unary callable invoked per job
      # @return [void]
      # @raise [ArgumentError] when `concurrency` is not a positive Integer
      # @raise [StandardError] re-raises the first exception captured from any worker
      def call(jobs:, concurrency:, on_job:)
        raise ArgumentError, "executor concurrency must be a positive Integer (got #{concurrency.inspect})" unless concurrency.is_a?(Integer) && concurrency.positive?

        queue  = Queue.new
        errors = Queue.new

        jobs.each { |job| queue << job }
        concurrency.times { queue << nil }

        workers = Array.new(concurrency) do
          ::Thread.new do
            while (job = queue.pop)
              begin
                on_job.call(job)
              rescue StandardError => e
                errors << e
              end
            end
          end
        end

        workers.each(&:join)

        raise errors.pop unless errors.empty?
      end

    end
  end
end
