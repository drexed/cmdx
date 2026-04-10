# frozen_string_literal: true

module CMDx
  module Middlewares
    # Tracks task execution time using a monotonic clock.
    class Runtime

      def call(task, options = {})
        return yield if options.key?(:if) && !Callable.evaluate(options[:if], task)

        return yield if options.key?(:unless) && Callable.evaluate(options[:unless], task)

        started_at = Time.now.utc
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        result = yield

        end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        ended_at = Time.now.utc
        runtime_ms = ((end_time - start_time) * 1000).round

        if result
          result.metadata[:started_at] = started_at.iso8601
          result.metadata[:ended_at] = ended_at.iso8601
          result.metadata[:runtime] = runtime_ms
        end

        result
      end

    end
  end
end
