# frozen_string_literal: true

module CMDx
  # Iterative middleware chain; each middleware must yield exactly once to continue.
  class MiddlewareStack

    # @param entries [Array<Array(Object, Hash)>]
    def initialize(entries)
      @entries = entries.freeze
    end

    # @param env [MiddlewareEnv]
    # @yield runs inner execution
    # @return [Object] yield result
    def call(env, &inner)
      raise ArgumentError, "block required" unless inner

      dispatch(env, 0, &inner)
    end

    private

    # @param env [MiddlewareEnv]
    # @param index [Integer]
    # @return [Object]
    def dispatch(env, index, &inner)
      return yield if index >= @entries.size

      callable, options = @entries[index]
      callable.call(env, **options) { dispatch(env, index + 1, &inner) }
    end

  end
end
