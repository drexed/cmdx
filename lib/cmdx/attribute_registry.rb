# frozen_string_literal: true

module CMDx
  class AttributeRegistry

    attr_reader :registry
    alias to_a registry

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

    def deregister(names)
      Array(names).each do |name|
        @registry.reject! { |attribute| matches_attribute_tree?(attribute, name.to_sym) }
      end

      self
    end

    def define_and_verify(task)
      registry.each do |attribute|
        attribute.task = task
        attribute.define_and_verify_tree
      end
    end

    private

    def matches_attribute_tree?(attribute, name)
      return true if attribute.method_name == name

      attribute.children.any? { |child| matches_attribute_tree?(child, name) }
    end

  end
end
