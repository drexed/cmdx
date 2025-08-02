# frozen_string_literal: true

module CMDx
  class AttributeRegistry

    attr_reader :registry

    def initialize(registry = [])
      @registry = registry
    end

    def dup
      self.class.new(registry.dup)
    end

    def register(attributes)
      @registry.concat(Array(attributes))
      self
    end

    def define_and_verify!(task)
      registry.each do |attribute|
        attribute.task = task
        attribute.define_and_verify!
      end
    end

  end
end
