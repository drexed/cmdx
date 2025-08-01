# frozen_string_literal: true

module CMDx
  class MiddlewareRegistry

    attr_reader :registry

    def initialize(registry = [])
      @registry = registry
    end

    def dup
      self.class.new(registry.map(&:dup))
    end

    def register(middleware, at: -1, **options)
      registry.insert(at, [middleware, options])
      self
    end

    def call!(task, &)
      raise ArgumentError, "block required" unless block_given?

      recursively_call_middleware_for(0, task, &)
    end

    private

    def recursively_call_middleware_for(index, task, &block)
      return yield(task) if index >= registry.size

      middleware, options = registry[index]
      middleware.call(task, **options) { recursively_call_middleware_for(index + 1, task, &block) }
    end

  end
end
