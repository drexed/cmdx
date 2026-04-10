# frozen_string_literal: true

module CMDx
  module Middlewares
    module Timeout

      DEFAULT_SECONDS = 30

      # @param env [MiddlewareEnv]
      # @param seconds [Numeric]
      #
      # @rbs (MiddlewareEnv env, ?seconds: Numeric) { () -> void } -> void
      def self.call(env, seconds: DEFAULT_SECONDS, &block)
        ::Timeout.timeout(seconds, CMDx::TimeoutError, &block)
      rescue CMDx::TimeoutError => e
        env.session.outcome.fail!("Execution timed out after #{seconds}s", cause: e)
      end

    end
  end
end
