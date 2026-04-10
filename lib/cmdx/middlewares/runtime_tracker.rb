# frozen_string_literal: true

module CMDx
  module Middlewares
    module RuntimeTracker

      # @param env [MiddlewareEnv]
      #
      # @rbs (MiddlewareEnv env) { () -> void } -> void
      def self.call(env, **)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        yield
      ensure
        elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(2)
        env.session.outcome.merge_metadata!(
          runtime_ms: elapsed,
          started_at: ::Time.now.utc.iso8601(6)
        )
      end

    end
  end
end
