# frozen_string_literal: true

module CMDx
  module Middlewares
    # Enforces wall-clock limits via Ruby +Timeout+ (optional middleware).
    module Timeout

      extend self

      DEFAULT_LIMIT = 3

      # @param env [MiddlewareEnv]
      # @param options [Hash]
      # @return [Object]
      def call(env, **options, &)
        handler = env.handler
        return yield unless Utils::Condition.evaluate(handler, options)

        limit =
          case callable = options[:seconds]
          when Numeric then callable
          when Symbol then handler.send(callable)
          when Proc then handler.instance_eval(&callable)
          else callable.respond_to?(:call) ? callable.call(handler) : DEFAULT_LIMIT
          end

        limit = Float(limit)
        return yield unless limit.positive?

        ::Timeout.timeout(limit, CMDx::TimeoutError, "execution exceeded #{limit} seconds", &)
      rescue CMDx::TimeoutError => e
        env.session.outcome.fail!(
          Utils::Normalize.exception(e),
          halt: false,
          cause: e,
          source: :timeout,
          limit: limit
        )
      end

    end
  end
end
