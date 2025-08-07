# frozen_string_literal: true

module CMDx
  module Middlewares
    module Correlate

      extend self

      THREAD_KEY = :cmdx_correlate

      def id
        Thread.current[THREAD_KEY]
      end

      def id=(id)
        Thread.current[THREAD_KEY] = id
      end

      def clear
        Thread.current[THREAD_KEY] = nil
      end

      def use(new_id)
        old_id = id
        self.id = new_id
        yield
      ensure
        self.id = old_id
      end

      def call(task, **options, &)
        return yield unless Utils::Condition.evaluate(task, options)

        correlation_id =
          case callable = options[:id]
          when Symbol then task.send(callable)
          when Proc then task.instance_eval(&callable)
          else
            if callable.respond_to?(:call)
              callable.call(task)
            else
              callable || id || Identifier.generate
            end
          end

        result = use(correlation_id, &)
        task.result.metadata[:correlation_id] = correlation_id
        result
      end

    end
  end
end
