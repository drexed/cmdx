# frozen_string_literal: true

module CMDx
  # Executes a chain of middleware around the inner work block.
  # Each middleware must yield to proceed to the next layer.
  module MiddlewareStack

    # @param entries [Array<Array>] [[klass, opts], ...]
    # @param env [MiddlewareEnv]
    # @return [void]
    #
    # @rbs (Array[Array[untyped]] entries, MiddlewareEnv env) { () -> void } -> void
    def self.call(entries, env, &inner)
      return yield if entries.empty?

      chain = entries.reverse.reduce(inner) do |next_step, (klass, opts)|
        proc do
          yielded = false
          klass.call(env, **(opts || {})) do
            yielded = true
            next_step.call
          end
          raise MiddlewareError, "#{klass} did not yield" unless yielded
        end
      end

      chain.call
    end

  end
end
