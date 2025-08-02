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
      registry.each_with_object(Errors.new) do |attribute, errors|
        attribute.task = task
        attribute.define_and_verify!

        recursively_attach_errors_for(attribute, errors)
      end
    end

    private

    def recursively_attach_errors_for(attribute, errors)
      errors.add(attribute.method_name, attribute.errors)
      attribute.children.each { |attr| recursively_attach_errors_for(attr, errors) }
    end

  end
end
