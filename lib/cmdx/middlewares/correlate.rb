# frozen_string_literal: true

module CMDx
  module Middlewares
    module Correlate

      STORAGE_KEY = :cmdx_correlation_id

      # @param env [MiddlewareEnv]
      # @param key [Symbol]
      #
      # @rbs (MiddlewareEnv env, ?key: Symbol) { () -> void } -> void
      def self.call(env, key: :correlation_id)
        cid = current || Identifier.generate
        self.current = cid
        env.session.context[key] = cid
        env.session.outcome.merge_metadata!(key => cid)
        yield
      ensure
        self.current = nil
      end

      # @rbs () -> String?
      def self.current
        if Fiber.respond_to?(:[])
          Fiber[STORAGE_KEY]
        else
          Thread.current[STORAGE_KEY]
        end
      end

      # @rbs (String? value) -> void
      def self.current=(value)
        if Fiber.respond_to?(:[]=)
          Fiber[STORAGE_KEY] = value
        else
          Thread.current[STORAGE_KEY] = value
        end
      end

      # @rbs () -> void
      def self.clear
        self.current = nil
      end

    end
  end
end
