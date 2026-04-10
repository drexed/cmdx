# frozen_string_literal: true

module CMDx
  module Middlewares
    # Prevents tasks from exceeding a time limit.
    # Raises CMDx::TimeoutError (inherits Interrupt, not StandardError).
    class Timeout

      DEFAULT_SECONDS = 3

      def call(task, options = {}, &)
        seconds = resolve_seconds(task, options)

        return yield if options.key?(:if) && !Callable.evaluate(options[:if], task)

        return yield if options.key?(:unless) && Callable.evaluate(options[:unless], task)

        begin
          ::Timeout.timeout(seconds, CMDx::TimeoutError, &)
        rescue CMDx::TimeoutError => e
          task.result.fail!(
            Messages.resolve("timeout.exceeded", seconds: seconds),
            limit: seconds
          )
          task.result.instance_variable_set(:@cause, e)
          task.result
        end
      end

      private

      def resolve_seconds(task, options)
        value = options[:seconds] || DEFAULT_SECONDS
        case value
        when Numeric then value
        when Symbol  then task.send(value)
        when Proc    then value.call(task)
        else
          value.respond_to?(:call) ? value.call(task) : DEFAULT_SECONDS
        end
      end

    end
  end
end
