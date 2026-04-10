# frozen_string_literal: true

module CMDx
  module Middlewares
    # Records monotonic runtime and timestamps on the outcome metadata.
    module Runtime

      extend self

      # @param env [MiddlewareEnv]
      # @param options [Hash]
      # @return [Object]
      def call(env, **options)
        handler = env.handler
        return yield unless Utils::Condition.evaluate(handler, options)

        started_m = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
        started_u = Time.now.utc.iso8601
        result = yield
        env.session.outcome.merge_metadata!(
          runtime: Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond) - started_m,
          started_at: started_u,
          ended_at: Time.now.utc.iso8601
        )
        result
      end

    end
  end
end
