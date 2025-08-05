# frozen_string_literal: true

module CMDx

  TimeoutError = Class.new(Interrupt)

  module Middlewares
    module Timeout

      extend self

      DEFAULT_LIMIT = 3

      def call(task, **options, &)
        limit =
          case callable = options[:seconds]
          when Numeric then callable
          when Symbol then task.send(callable)
          when Proc then task.instance_eval(&callable)
          else callable.respond_to?(:call) ? callable.call(task) : DEFAULT_LIMIT
          end

        ::Timeout.timeout(limit, TimeoutError, "execution exceeded #{limit} seconds", &)
      rescue TimeoutError => e
        task.result.tap { |r| r.fail!("[#{e.class}] #{e.message}", cause: e, limit:) }
      end

    end
  end

end
