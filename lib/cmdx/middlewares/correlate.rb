# frozen_string_literal: true

module CMDx
  module Middlewares
    # Pushes +correlation_id+ (from option, handler method, proc, or trace) into metadata.
    module Correlate

      extend self

      # @param env [MiddlewareEnv]
      # @param options [Hash]
      # @return [Object]
      def call(env, **options)
        handler = env.handler
        return yield unless Utils::Condition.evaluate(handler, options)

        correlation_id =
          case callable = options[:id]
          when Symbol then handler.send(callable)
          when Proc then handler.instance_eval(&callable)
          else
            if callable.respond_to?(:call)
              callable.call(handler)
            else
              callable || env.session.trace.id
            end
          end

        env.session.outcome.merge_metadata!(correlation_id: correlation_id)
        yield
      end

    end
  end
end
