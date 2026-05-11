# frozen_string_literal: true

module CMDx
  class Coercions
    # Invokes an inline `:coerce` handler (Symbol method name, Proc, or
    # anything with `#call`). Used by {Coercions#coerce} for non-built-in
    # rules.
    module Coerce

      extend self

      # @param task [Task] receiver for Symbol/Proc handlers, also passed to callable handlers
      # @param value [Object]
      # @param handler [Symbol, Proc, #call]
      # @return [Object] the handler's return value
      # @raise [ArgumentError] when `handler` isn't a supported type
      def call(task, value, handler)
        case handler
        when ::Symbol
          task.send(handler, value)
        when ::Proc
          task.instance_exec(value, &handler)
        else
          return handler.call(value, task) if handler.respond_to?(:call)

          raise ArgumentError,
            "coerce handler must be a Symbol, Proc, or respond to #call (got #{handler.class}). " \
            "See https://drexed.github.io/cmdx/inputs/coercions/"
        end
      end

    end
  end
end
