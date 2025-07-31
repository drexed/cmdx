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

    def register(middleware)
      registry << middleware
      self
    end

    def call!(task, &block)
      raise ArgumentError, "block required" unless block_given?

      return yield(task) if registry.empty?

      registry.reverse_each.reduce(block) do |next_callable, middleware|
        proc { |task| middleware.call(task, next_callable) }
      end.call(task)
    end

  end
end
