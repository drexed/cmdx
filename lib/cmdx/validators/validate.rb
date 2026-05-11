# frozen_string_literal: true

module CMDx
  class Validators
    # Invokes an inline `:validate` handler. Used by {Validators#validate}
    # for each handler passed under the `:validate` option.
    module Validate

      extend self

      # @param task [Task] receiver for Symbol/Proc handlers, also passed to callable handlers
      # @param value [Object]
      # @param handler [Symbol, Proc, #call]
      # @return [Validators::Failure, nil, Object] handler's return value
      # @raise [ArgumentError] when `handler` isn't a supported type
      def call(task, value, handler)
        case handler
        when Symbol
          task.send(handler, value)
        when Proc
          task.instance_exec(value, &handler)
        else
          return handler.call(value, task) if handler.respond_to?(:call)

          raise ArgumentError,
            "validate handler must be a Symbol, Proc, or respond to #call (got #{handler.class}). " \
            "See https://drexed.github.io/cmdx/inputs/validations/"
        end
      end

    end
  end
end
