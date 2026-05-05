# frozen_string_literal: true

module CMDx
  class Executors
    # Default executor. Uses a fixed-size `Thread` pool drained via a `Queue`;
    # sentinel `nil`s terminate workers. Workers inherit the parent's chain via
    # fiber-local storage.
    #
    # @api private
    module Thread

      extend self

      # @param jobs [Array] opaque job objects forwarded to `on_job`
      # @param concurrency [Integer] worker count
      # @param on_job [#call] unary callable invoked per job
      # @return [void]
      def call(jobs:, concurrency:, on_job:)
        queue = Queue.new
        jobs.each { |job| queue << job }
        concurrency.times { queue << nil }

        workers = Array.new(concurrency) do
          ::Thread.new do
            while (job = queue.pop)
              on_job.call(job)
            end
          end
        end

        workers.each(&:join)
      end

    end
  end
end
