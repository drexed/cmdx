# frozen_string_literal: true

module CMDx
  class MiddlewareRegistry

    attr_reader :registry

    def initialize(registry = {})
      @registry = registry
    end

    def dup
      self.class.new(
        registry.transform_values do |config|
          args, kwargs, block = config
          [args.dup, kwargs.dup, block]
        end
      )
    end

    def register(middleware, *args, **kwargs, &block)
      registry[middleware] = [args, kwargs, block]
      self
    end

    def call!(task, &)
      raise ArgumentError, "block required" unless block_given?

      if registry.empty?
        yield(task)
      else
        middleware_chain(&).call(task)
      end
    end

    private

    def middleware_chain(&call_block)
      registry.reverse_each.reduce(call_block) do |next_callable, (middleware, config)|
        proc do |task|
          args, kwargs, block = config
          instance = middleware.respond_to?(:new) ? middleware.new(*args, **kwargs, &block) : middleware
          instance.call(task, next_callable)
        end
      end
    end

  end
end
